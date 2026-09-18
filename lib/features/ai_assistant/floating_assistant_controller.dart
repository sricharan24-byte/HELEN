import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/settings/app_settings_controller.dart';
import '../../data/models/ticket_model.dart';
import '../../data/repositories/transport_repository.dart';
import '../journey/journey_controller.dart';
import '../route_details/route_details_page.dart';
import '../safety/safety_sharing_page.dart';
import '../saved/saved_page.dart';
import '../settings/home_screen_customization_page.dart';
import '../settings/voice_assistant_settings_page.dart';
import '../tickets/booking_page.dart';
import '../tickets/live_location_screen.dart';
import '../tickets/ticket_booking_suite_page.dart';
import '../tickets/ticket_controller.dart';
import 'audio_speech_engine.dart';
import 'floating_chat_message.dart';
import 'gemini_live_screen.dart';
import 'gemini_live_service.dart';
import 'gemini_live_session.dart';

/// Central state controller for the floating BusBuddy AI assistant bubble and mini window.
class FloatingAssistantController extends ChangeNotifier {
  static final FloatingAssistantController instance = FloatingAssistantController._();
  FloatingAssistantController._() {
    _initAudio();
  }

  factory FloatingAssistantController() => instance;

  final AudioSpeechEngine _audioEngine = const AudioSpeechEngine();
  final GeminiLiveService _liveService = const GeminiLiveService();
  GeminiLiveSession? _liveSession;
  String? _connectedApiKey;
  String? _connectedVoice;

  TicketController? ticketController;
  TransportRepository? repository;
  JourneyController? journeyController;

  bool _isWindowOpen = false;
  bool _isMuted = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isFullScreenActive = false;
  bool _hasUnread = false;
  String _liveStatus = 'Ready';
  String? _lastInterimTranscript;

  bool _continuousListening = false;
  Timer? _restartListenTimer;

  Offset _position = const Offset(24, 480);
  bool _hasCustomPosition = false;

  final List<FloatingChatMessage> _messages = [];
  Timer? _speechTimer;
  bool _receivedPcmThisTurn = false;

  // ── Public Getters ─────────────────────────────────────────────────────────
  bool get isWindowOpen => _isWindowOpen;
  bool get isMuted => _isMuted;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isFullScreenActive => _isFullScreenActive;
  bool get hasUnread => _hasUnread;
  bool get isContinuousListening => _continuousListening;
  String get liveStatus => _liveStatus;
  String? get lastInterimTranscript => _lastInterimTranscript;
  Offset get position => _position;
  bool get hasCustomPosition => _hasCustomPosition;
  List<FloatingChatMessage> get messages => List.unmodifiable(_messages);
  Ticket? get activeTicket => ticketController?.activeTicket;

  void initialize({
    TicketController? ticketCtrl,
    TransportRepository? repo,
    JourneyController? journeyCtrl,
  }) {
    if (ticketCtrl != null) ticketController = ticketCtrl;
    if (repo != null) repository = repo;
    if (journeyCtrl != null) journeyController = journeyCtrl;

    if (_messages.isEmpty) {
      _messages.add(
        FloatingChatMessage(
          id: 'msg-welcome',
          sender: 'ai',
          text: 'Hi, I\'m BusBuddy! Ask me about buses, timings, fares, or tracking along the VIT Katpadi corridor.',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  void _initAudio() {
    _audioEngine.setAudioEndedCallback(() {
      _isSpeaking = false;
      _speechTimer?.cancel();
      if (_continuousListening && !_isFullScreenActive && !_isMuted && _isWindowOpen) {
        _scheduleRestartListening(delayMs: 350, playChimeTone: true);
      }
      notifyListeners();
    });
  }

  void _ensureSession() {
    if (_isFullScreenActive) return;
    final settings = AppSettingsController.instance;
    final currentKey = settings.geminiApiKey.trim();
    final currentVoice = settings.geminiVoice;

    if (_liveSession != null &&
        _connectedApiKey == currentKey &&
        _connectedVoice == currentVoice) {
      return;
    }

    if (currentKey.isEmpty) return;

    _liveSession?.disconnect();
    _connectedApiKey = currentKey;
    _connectedVoice = currentVoice;

    _liveSession = GeminiLiveSession(
      onAudioPcmChunk: (pcmBase64) {
        if (_isMuted || _isFullScreenActive) return;
        _receivedPcmThisTurn = true;
        _speechTimer?.cancel();
        if (!_isSpeaking) {
          _isSpeaking = true;
          notifyListeners();
        }
        _audioEngine.playPcmAudio(pcmBase64);
      },
      onTurnComplete: (fullText, actionType) {
        if (_isFullScreenActive) return;
        _isSpeaking = true;
        _liveStatus = 'Ready';

        final displayText = fullText.trim().isNotEmpty
            ? fullText
            : (actionType != null
                ? 'I found transit actions for you. Tap below to proceed:'
                : '');

        if (displayText.isNotEmpty) {
          _messages.add(
            FloatingChatMessage(
              id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
              sender: 'ai',
              text: displayText,
              timestamp: DateTime.now(),
              actionType: actionType,
              actionLabel: _getActionLabel(actionType),
            ),
          );
          if (!_isWindowOpen) {
            _hasUnread = true;
          }
        }

        _speechTimer?.cancel();
        final fallbackDelay = _receivedPcmThisTurn
            ? const Duration(seconds: 8)
            : const Duration(milliseconds: 1200);
        _speechTimer = Timer(fallbackDelay, () {
          if (_isSpeaking) {
            _isSpeaking = false;
            if (_continuousListening && !_isListening && !_isFullScreenActive && !_isMuted && _isWindowOpen) {
              _scheduleRestartListening(delayMs: 350, playChimeTone: true);
            }
            notifyListeners();
          }
        });

        notifyListeners();
      },
      onInterrupted: () {
        _audioEngine.stop();
        _speechTimer?.cancel();
        _restartListenTimer?.cancel();
        _isSpeaking = false;
        _isListening = false;
        if (_continuousListening && !_isFullScreenActive && !_isMuted && _isWindowOpen) {
          _scheduleRestartListening(delayMs: 300, playChimeTone: true);
        }
        notifyListeners();
      },
      onError: (err) {
        if (_isFullScreenActive) return;
        _liveStatus = 'Notice: $err';
        notifyListeners();
      },
      onStatusChanged: (status, _) {
        if (_isFullScreenActive) return;
        _liveStatus = status;
        notifyListeners();
      },
    );

    _liveSession!.connect();
  }

  // ── Window Controls ────────────────────────────────────────────────────────
  void openWindow() {
    _isWindowOpen = true;
    _hasUnread = false;
    _audioEngine.unlockAudio();
    notifyListeners();
  }

  void closeWindow() {
    _isWindowOpen = false;
    _continuousListening = false;
    _restartListenTimer?.cancel();
    stopListening(disableContinuous: true);
    notifyListeners();
  }

  void toggleWindow() {
    if (_isWindowOpen) {
      closeWindow();
    } else {
      openWindow();
    }
  }

  // ── Mute Controls ──────────────────────────────────────────────────────────
  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _continuousListening = false;
      _restartListenTimer?.cancel();
      stopAllAudio();
      _liveStatus = 'Muted';
    } else {
      _liveStatus = 'Sound On';
    }
    notifyListeners();
  }

  void stopSpeaking() {
    _isSpeaking = false;
    _speechTimer?.cancel();
    _audioEngine.stop();
    notifyListeners();
  }

  void stopListening({bool disableContinuous = true}) {
    if (disableContinuous) {
      _continuousListening = false;
    }
    _restartListenTimer?.cancel();
    _isListening = false;
    _audioEngine.stopListening();
    _liveStatus = 'Ready';
    notifyListeners();
  }

  void stopAllAudio() {
    stopSpeaking();
    stopListening(disableContinuous: true);
  }

  // ── Mic Orb Interaction ────────────────────────────────────────────────────
  void toggleListeningOrMute() {
    _audioEngine.unlockAudio();

    if (_isListening) {
      // Currently listening -> Mute mic
      stopListening(disableContinuous: true);
    } else if (_isSpeaking) {
      // AI speaking -> Mute AI voice immediately
      stopSpeaking();
    } else {
      // Idle -> Start continuous listening
      _continuousListening = true;
      startListening(playChimeTone: true);
    }
  }

  void startListening({bool playChimeTone = true, bool isRestart = false}) {
    if (_isListening && !isRestart) return;
    if (_isSpeaking || _isMuted || _isFullScreenActive) return;
    _restartListenTimer?.cancel();
    stopSpeaking();

    _audioEngine.unlockAudio();
    if (playChimeTone) {
      _audioEngine.playChime(isListening: true);
    }

    _isListening = true;
    _liveStatus = 'Listening...';
    _lastInterimTranscript = null;
    notifyListeners();

    _audioEngine.startListening(
      onResult: (text, isFinal) {
        if (isFinal) {
          _isListening = false;
          _lastInterimTranscript = null;
          sendQuery(text);
        } else {
          _lastInterimTranscript = text;
          _liveStatus = '🗣️ "$text"';
          notifyListeners();
        }
      },
      onError: (err) {
        final isPermission = err.toLowerCase().contains('blocked') ||
            err.toLowerCase().contains('denied') ||
            err.toLowerCase().contains('not-allowed');
        if (isPermission) {
          _continuousListening = false;
          _restartListenTimer?.cancel();
        }
        _isListening = false;
        _liveStatus = 'Mic error: $err';
        notifyListeners();

        if (!isPermission && _continuousListening && !_isSpeaking && !_isMuted && !_isFullScreenActive && _isWindowOpen) {
          _scheduleRestartListening(delayMs: 1200);
        }
      },
      onEnd: () {
        if (_isListening) {
          if (_lastInterimTranscript != null && _lastInterimTranscript!.trim().isNotEmpty) {
            final q = _lastInterimTranscript!;
            _lastInterimTranscript = null;
            _isListening = false;
            sendQuery(q);
          } else {
            if (_continuousListening && !_isSpeaking && !_isMuted && !_isFullScreenActive && _isWindowOpen) {
              // Silence timeout occurred without speech: seamlessly restart continuous listening!
              _scheduleRestartListening(delayMs: 150);
            } else {
              _isListening = false;
              _liveStatus = 'Ready';
              notifyListeners();
            }
          }
        }
      },
    );
  }

  void _scheduleRestartListening({int delayMs = 300, bool playChimeTone = false}) {
    _restartListenTimer?.cancel();
    if (!_continuousListening || _isSpeaking || _isMuted || _isFullScreenActive || !_isWindowOpen) return;

    _restartListenTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_continuousListening && !_isSpeaking && !_isMuted && !_isFullScreenActive && !_isListening && _isWindowOpen) {
        startListening(playChimeTone: playChimeTone, isRestart: true);
      }
    });
  }

  // ── Send Query ─────────────────────────────────────────────────────────────
  void sendQuery(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return;

    _audioEngine.unlockAudio();
    stopSpeaking();
    stopListening(disableContinuous: false);
    _audioEngine.resetTurn();
    _receivedPcmThisTurn = false;

    // Record user message
    _messages.add(
      FloatingChatMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        sender: 'user',
        text: query,
        timestamp: DateTime.now(),
      ),
    );

    _liveStatus = 'Thinking...';
    notifyListeners();

    // Check if live AI Studio WebSocket key is available
    if (AppSettingsController.instance.geminiApiKey.isNotEmpty) {
      _ensureSession();
      _liveSession?.sendQuery(query);
    } else {
      _messages.add(
        FloatingChatMessage(
          id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
          sender: 'ai',
          text: 'BusBuddy voice runs exclusively on Gemini Live. Please connect your Google AI Studio API key in voice settings to enable conversational voice control.',
          timestamp: DateTime.now(),
          actionType: 'open_settings',
          actionLabel: _getActionLabel('open_settings'),
        ),
      );

      _liveStatus = 'Key Needed';
      _isSpeaking = false;
      if (!_isWindowOpen) {
        _hasUnread = true;
      }

      notifyListeners();
    }
  }

  // ── Action Navigation Execution ────────────────────────────────────────────
  void executeAction(BuildContext context, String actionType, GlobalKey<NavigatorState>? navigatorKey) {
    final nav = navigatorKey?.currentState ?? Navigator.of(context, rootNavigator: true);

    switch (actionType) {
      case 'track_bus':
        final currentTicket = activeTicket;
        final currentRepo = repository;
        if (currentTicket != null && currentRepo != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => LiveLocationScreen(
                ticket: currentTicket,
                repository: currentRepo,
              ),
            ),
          );
        } else if (ticketController != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => BookingPage(ticketController: ticketController!),
            ),
          );
        }
        break;

      case 'book_ticket':
        if (ticketController != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => BookingPage(ticketController: ticketController!),
            ),
          );
        }
        break;

      case 'search_route':
        if (journeyController != null && repository != null) {
          if (journeyController!.state.selectedRoute == null && repository!.allRoutes.isNotEmpty) {
            journeyController!.selectRoute(repository!.allRoutes.first);
          }
          nav.push(
            MaterialPageRoute(
              builder: (_) => RouteDetailsPage(
                controller: journeyController!,
                repository: repository!,
              ),
            ),
          );
        } else if (ticketController != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => BookingPage(ticketController: ticketController!),
            ),
          );
        }
        break;

      case 'open_saved':
        if (ticketController != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => SavedPage(ticketController: ticketController!),
            ),
          );
        }
        break;

      case 'emergency_sos':
      case 'share_location':
        nav.push(
          MaterialPageRoute(
            builder: (_) => SafetySharingPage(
              activeTicket: activeTicket,
            ),
          ),
        );
        break;

      case 'customize_home':
        nav.push(
          MaterialPageRoute(
            builder: (_) => const HomeScreenCustomizationPage(),
          ),
        );
        break;

      case 'open_settings':
        nav.push(
          MaterialPageRoute(
            builder: (_) => VoiceAssistantSettingsPage(
              ticketController: ticketController,
              repository: repository,
            ),
          ),
        );
        break;

      case 'reset_home':
        AppSettingsController.instance.resetHomeScreenLayout();
        break;

      case 'full_screen':
        openFullScreen(nav);
        return;
    }

    // Automatically minimize window so the user can interact with the opened screen
    closeWindow();
  }

  void openFullScreen(NavigatorState nav) {
    closeWindow();
    setFullScreenActive(true);

    nav.push(
      MaterialPageRoute(
        builder: (_) => GeminiLiveScreen(
          ticketController: ticketController,
          repository: repository,
          journeyController: journeyController,
        ),
      ),
    ).then((_) {
      setFullScreenActive(false);
    });
  }

  void setFullScreenActive(bool active) {
    _isFullScreenActive = active;
    if (active) {
      closeWindow();
      stopAllAudio();
      _liveSession?.disconnect();
      _liveSession = null;
    }
    notifyListeners();
  }

  // ── Position Clamping ──────────────────────────────────────────────────────
  void updatePosition(Offset newPos, Size screenSize, EdgeInsets safeArea) {
    const double bubbleSize = 64.0;
    const double margin = 16.0;

    final double minX = margin;
    final double maxX = (screenSize.width - bubbleSize - margin).clamp(minX, double.infinity);
    final double minY = safeArea.top + margin;
    final double maxY = (screenSize.height - safeArea.bottom - bubbleSize - margin).clamp(minY, double.infinity);

    _position = Offset(
      newPos.dx.clamp(minX, maxX),
      newPos.dy.clamp(minY, maxY),
    );
    _hasCustomPosition = true;
    notifyListeners();
  }

  void clampToScreen(Size screenSize, EdgeInsets safeArea) {
    const double bubbleSize = 64.0;
    const double margin = 16.0;

    final double minX = margin;
    final double maxX = (screenSize.width - bubbleSize - margin).clamp(minX, double.infinity);
    final double minY = safeArea.top + margin;
    final double maxY = (screenSize.height - safeArea.bottom - bubbleSize - margin).clamp(minY, double.infinity);

    final clampedX = _position.dx.clamp(minX, maxX);
    final clampedY = _position.dy.clamp(minY, maxY);

    if (clampedX != _position.dx || clampedY != _position.dy) {
      _position = Offset(clampedX, clampedY);
    }
  }

  void resetPosition(Size screenSize, EdgeInsets safeArea) {
    const double bubbleSize = 64.0;
    const double margin = 20.0;
    final double defaultX = (screenSize.width - bubbleSize - margin).clamp(16.0, double.infinity);
    final double defaultY = (screenSize.height - safeArea.bottom - bubbleSize - 90.0).clamp(100.0, double.infinity);
    _position = Offset(defaultX, defaultY);
    _hasCustomPosition = false;
    notifyListeners();
  }

  String _getActionLabel(String? actionType) {
    switch (actionType) {
      case 'track_bus':
        return '📍 Open Live Bus Map';
      case 'book_ticket':
        return '🎫 Book Bus Ticket';
      case 'search_route':
        return '🚌 View Route Options';
      case 'open_saved':
        return '⭐ Saved Places';
      case 'open_settings':
        return '⚙️ Setup Gemini Live Key';
      case 'emergency_sos':
        return '🚨 Safety Broadcast';
      default:
        return 'Transit Action';
    }
  }

  @override
  void dispose() {
    _speechTimer?.cancel();
    _liveSession?.disconnect();
    super.dispose();
  }
}
