import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/a11y/announcement_coordinator.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../data/models/ticket_model.dart';
import '../../data/repositories/transport_repository.dart';
import '../../domain/assistant/assistant_command.dart';
import '../journey/journey_controller.dart';
import '../route_details/route_details_page.dart';
import '../safety/safety_sharing_page.dart';
import '../saved/saved_page.dart';
import '../settings/home_screen_customization_page.dart';
import '../settings/voice_assistant_settings_page.dart';
import '../tickets/booking_page.dart';
import '../tickets/live_location_screen.dart';
import '../tickets/ticket_controller.dart';
import 'app_automation_controller.dart';
import 'audio_speech_engine.dart';
import 'floating_chat_message.dart';
import 'gemini_live_screen.dart';
import 'gemini_live_service.dart';
import 'gemini_live_session.dart';
import 'tts_fallback_arbiter.dart';

/// Central state controller for the floating BusBuddy AI assistant bubble and mini window.
class FloatingAssistantController extends ChangeNotifier {
  static final FloatingAssistantController instance = FloatingAssistantController._();
  FloatingAssistantController._() {
    _initAudio();
  }

  factory FloatingAssistantController() => instance;

  final AudioSpeechEngine _audioEngine = const AudioSpeechEngine();
  final GeminiLiveService _liveService = const GeminiLiveService();
  final AppAutomationController automation = AppAutomationController();
  final TtsFallbackArbiter _ttsArbiter = TtsFallbackArbiter.shared;
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

  bool _isPermissionBlocked = false;
  Offset _position = const Offset(24, 480);
  bool _hasCustomPosition = false;

  final List<FloatingChatMessage> _messages = [];
  Timer? _speechTimer;
  Timer? _audioEndConfirmTimer;
  bool _receivedPcmThisTurn = false;
  String _lastSpokenText = '';

  // ── Public Getters ─────────────────────────────────────────────────────────
  bool get isWindowOpen => _isWindowOpen;
  bool get isMuted => _isMuted;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isFullScreenActive => _isFullScreenActive;
  bool get isPermissionBlocked => _isPermissionBlocked;
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
    automation.attach(repo: repository, journeyCtrl: journeyController);

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

  void _setSpeaking(bool value) {
    if (_isSpeaking == value) return;
    _isSpeaking = value;
    AnnouncementCoordinator.instance.setAudioPlaying(value);
  }

  /// Public hook for external audio engines/tests to toggle speaking state.
  /// Synchronizes with [AnnouncementCoordinator.isAudioPlaying] so accessibility
  /// announcements are queued while the assistant voice is active.
  void setSpeaking(bool value) => _setSpeaking(value);

  void _initAudio() {
    AnnouncementCoordinator.instance.onUrgentAlertTriggered = stopSpeaking;
    _registerAudioEndedCallback();
  }

  void _registerAudioEndedCallback() {
    // The web bridge fires this callback after only 250 ms of queued-audio
    // silence, which on a jittery network happens BETWEEN PCM chunks of the
    // same reply. Releasing the speaking state immediately would re-open the
    // screen-reader announcement gate and restart the mic into the reply
    // tail (echo reply over the streaming voice). Confirm the end of speech
    // over a 600 ms window; any new PCM chunk cancels the confirmation.
    _audioEngine.setAudioEndedCallback(() {
      _speechTimer?.cancel();
      _audioEndConfirmTimer?.cancel();
      _audioEndConfirmTimer = Timer(const Duration(milliseconds: 600), () {
        if (_isSpeaking) _setSpeaking(false);
        if (_continuousListening &&
            !_isFullScreenActive &&
            !_isMuted &&
            _isWindowOpen &&
            !_isListening &&
            !_isSpeaking) {
          _scheduleRestartListening(delayMs: 350, playChimeTone: true);
        }
        notifyListeners();
      });
    });
  }

  /// Re-registers this controller's audio-ended callback on the shared web
  /// audio bridge. The fullscreen [GeminiLiveScreen] overwrites the single
  /// global callback while open; it must call this on dispose so the mini
  /// window's mic-restart and speaking state keep working afterwards.
  void rearmAudioCallback() {
    _registerAudioEndedCallback();
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
        // First-starter-wins: drop late PCM once TTS has started.
        if (!_ttsArbiter.tryClaimPcm()) return;
        _receivedPcmThisTurn = true;
        // Audio still streaming: keep the speaking state held (see
        // _registerAudioEndedCallback for the end-of-speech confirmation).
        _audioEndConfirmTimer?.cancel();
        if (!_isSpeaking) {
          _isSpeaking = true;
          notifyListeners();
        }
        _audioEngine.playPcmAudio(pcmBase64);
      },
      onTurnComplete: (fullText, actionType) {
        if (_isFullScreenActive) return;
        final turnGen = _ttsArbiter.generation;
        _isSpeaking = true;
        _liveStatus = 'Ready';

        // Slot-tool protocol turns are silent here too: the onAction handler
        // already posted the bubble, and the follow-up answer carries the
        // voice. Speaking would double the voice on the same words.
        if (AssistantCommandGateway.isSilentProtocol(actionType)) {
          _ttsArbiter.cancel();
          notifyListeners();
          return;
        }

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

        // Single-voice: Live turns get the extended grace; stale turns never
        // speak. Stop-before-speak kills stray audio from a prior turn.
        _ttsArbiter.cancel();
        if (displayText.isNotEmpty) _lastSpokenText = displayText;
        if (!_receivedPcmThisTurn) {
          if (!_isMuted && displayText.isNotEmpty) {
            final spoken = displayText;
            _ttsArbiter.scheduleFallback(() {
              if (turnGen != _ttsArbiter.generation) return;
              if (_isMuted || _isFullScreenActive) return;
              _audioEngine.stop();
              _audioEngine.speak(spoken);
              _armSpeakingWatchdog();
            }, isLive: true);
          }
        }

        notifyListeners();
      },
      onAction: (actionType, args) {
        if (_isFullScreenActive) return;
        applyLiveToolCall(actionType, args);
      },
      onInterrupted: () {
        _audioEngine.stop();
        _ttsArbiter.cancel();
        _speechTimer?.cancel();
        _restartListenTimer?.cancel();
        _audioEndConfirmTimer?.cancel();
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
    if (!_isWindowOpen && !_isListening) return;
    _isWindowOpen = false;
    _continuousListening = false;
    _restartListenTimer?.cancel();
    _isListening = false;
    _audioEngine.stopListening();
    _liveStatus = 'Ready';
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
    _audioEndConfirmTimer?.cancel();
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

    _isPermissionBlocked = false;
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
          _isPermissionBlocked = true;
          _continuousListening = false;
          _restartListenTimer?.cancel();
        }
        _isListening = false;
        _liveStatus = isPermission
            ? 'Microphone permission blocked.'
            : 'Mic error: $err';
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

  bool _isEchoOfSelf(String transcript) {
    final heard = transcript
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final spoken = _lastSpokenText
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (heard.length < 8 || spoken.length < 8) return false;
    if (spoken.contains(heard) || heard.contains(spoken)) return true;
    final heardTokens = heard.split(' ').toSet();
    final spokenTokens = spoken.split(' ').toSet();
    if (heardTokens.isEmpty) return false;
    return heardTokens.intersection(spokenTokens).length / heardTokens.length >=
        0.6;
  }

  // ── Send Query ─────────────────────────────────────────────────────────────
  void sendQuery(String rawQuery, {bool isUserTap = false}) {
    // While the full-screen Live screen owns the session and the audio
    // bridge, this controller must never process a query — a reply here
    // would speak over the screen's voice.
    if (_isFullScreenActive) return;
    final query = rawQuery.trim();
    if (query.isEmpty) return;

    // Drop mic echo of our own voice (typed/chip taps pass isUserTap: true).
    if (!isUserTap && _isEchoOfSelf(query)) {
      if (_continuousListening &&
          !_isListening &&
          !_isSpeaking &&
          !_isFullScreenActive &&
          !_isMuted &&
          _isWindowOpen) {
        _scheduleRestartListening(delayMs: 350, playChimeTone: false);
      }
      return;
    }

    _audioEngine.unlockAudio();
    stopSpeaking();
    stopListening(disableContinuous: false);
    _audioEngine.resetTurn();
    _audioEndConfirmTimer?.cancel();
    _ttsArbiter.beginTurn();
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
      unawaited(_liveSession?.sendQuery(query));
    } else {
      final ticket = activeTicket;
      final resp = _liveService.processVoiceQuery(query, activeTicket: ticket);
      final responseText = resp.spokenResponse;
      final actionType = resp.actionType;

      _messages.add(
        FloatingChatMessage(
          id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
          sender: 'ai',
          text: responseText,
          timestamp: DateTime.now(),
          actionType: actionType,
          actionLabel: _getActionLabel(actionType),
        ),
      );
      _liveStatus = 'Ready';

      if (!_isMuted) {
        _isSpeaking = true;
        _lastSpokenText = responseText;
        // Offline turns cannot produce PCM: speak immediately (single voice)
        // with stop-before-speak. Completion owns mic restart; watchdog only
        // recovers stuck audio.
        _ttsArbiter.speakNow(() {
          _audioEngine.stop();
          _audioEngine.speak(responseText);
        });
        _armSpeakingWatchdog();
      } else {
        _isSpeaking = false;
      }

      if (!_isWindowOpen) {
        _hasUnread = true;
      }

      notifyListeners();
    }
  }

  /// Applies a Live Gemini function call to the booking draft and posts a
  /// chat bubble so the user sees what the agent did. Safe to call from
  /// [GeminiLiveSession.onAction] (no BuildContext needed for slot setters;
  /// gateway navigation still goes through [executeAction]).
  AutomationResult applyLiveToolCall(
    String actionType,
    Map<String, dynamic>? args,
  ) {
    automation.attach(repo: repository, journeyCtrl: journeyController);
    const agentTools = {
      'set_trip',
      'select_bus',
      'set_passenger',
      'set_payment',
      'confirm_booking',
    };
    if (!agentTools.contains(actionType)) {
      return const AutomationResult(
        spokenHint: '',
        displayText: '',
      );
    }
    final result = automation.handleToolCall(actionType, args);
    if (result.displayText.isNotEmpty) {
      _messages.add(
        FloatingChatMessage(
          id: 'msg-${DateTime.now().millisecondsSinceEpoch}-$actionType',
          sender: 'ai',
          text: result.displayText,
          timestamp: DateTime.now(),
          actionType: result.needsGateway
              ? 'confirm_booking'
              : result.actionType,
          actionLabel: result.needsGateway
              ? (AssistantCommandGateway.getMetadata('confirm_booking')
                      ?.gatewayScreenPrompt ??
                  '🎫 Review & Confirm Booking')
              : result.actionLabel,
        ),
      );
      if (!_isWindowOpen) _hasUnread = true;
      notifyListeners();
    }
    return result;
  }

  // ── Action Navigation Execution ────────────────────────────────────────────
  void executeAction(BuildContext context, String actionType, GlobalKey<NavigatorState>? navigatorKey) {
    final nav = navigatorKey?.currentState ?? Navigator.of(context, rootNavigator: true);

    switch (actionType) {
      case 'set_trip':
      case 'select_bus':
      case 'set_passenger':
      case 'set_payment':
        // Slot already applied via applyLiveToolCall; open pre-filled booking.
        _openPrefilledBooking(nav, autoOpenCheckout: false);
        break;

      case 'confirm_booking':
        final readiness = automation.bookingReadiness();
        if (!readiness.isComplete) {
          _messages.add(
            FloatingChatMessage(
              id: 'msg-${DateTime.now().millisecondsSinceEpoch}-missing',
              sender: 'ai',
              text: readiness.displayText,
              timestamp: DateTime.now(),
            ),
          );
          notifyListeners();
          break;
        }
        _openPrefilledBooking(nav, autoOpenCheckout: true);
        break;
      case 'track_bus':
        final currentTicket = activeTicket;
        final currentRepo = repository;
        if (currentTicket != null && currentRepo != null) {
          unawaited(nav.push(
            MaterialPageRoute<void>(
              builder: (_) => LiveLocationScreen(
                ticket: currentTicket,
                repository: currentRepo,
              ),
            ),
          ));
        } else if (ticketController != null) {
          unawaited(nav.push(
            MaterialPageRoute<void>(
              builder: (_) => BookingPage(ticketController: ticketController!),
            ),
          ));
        }
        break;

      case 'book_ticket':
        if (ticketController != null) {
          unawaited(nav.push(
            MaterialPageRoute<void>(
              builder: (_) => BookingPage(ticketController: ticketController!),
            ),
          ));
        }
        break;

      case 'search_route':
        if (journeyController != null && repository != null) {
          if (journeyController!.state.selectedRoute == null && repository!.allRoutes.isNotEmpty) {
            journeyController!.selectRoute(repository!.allRoutes.first);
          }
          unawaited(nav.push(
            MaterialPageRoute<void>(
              builder: (_) => RouteDetailsPage(
                controller: journeyController!,
                repository: repository!,
              ),
            ),
          ));
        } else if (ticketController != null) {
          unawaited(nav.push(
            MaterialPageRoute<void>(
              builder: (_) => BookingPage(ticketController: ticketController!),
            ),
          ));
        }
        break;

      case 'open_saved':
        if (ticketController != null) {
          unawaited(nav.push(
            MaterialPageRoute<void>(
              builder: (_) => SavedPage(ticketController: ticketController!),
            ),
          ));
        }
        break;

      case 'emergency_sos':
      case 'share_location':
        unawaited(nav.push(
          MaterialPageRoute<void>(
            builder: (_) => SafetySharingPage(
              activeTicket: activeTicket,
            ),
          ),
        ));
        break;

      case 'customize_home':
        unawaited(nav.push(
          MaterialPageRoute<void>(
            builder: (_) => const HomeScreenCustomizationPage(),
          ),
        ));
        break;

      case 'open_settings':
        unawaited(nav.push(
          MaterialPageRoute<void>(
            builder: (_) => VoiceAssistantSettingsPage(
              ticketController: ticketController,
              repository: repository,
            ),
          ),
        ));
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

  void _openPrefilledBooking(NavigatorState nav, {required bool autoOpenCheckout}) {
    if (ticketController == null) return;
    final auto = automation;
    unawaited(nav.push(
      MaterialPageRoute<void>(
        builder: (_) => BookingPage(
          ticketController: ticketController!,
          journeyController: journeyController,
          initialOrigin: auto.origin,
          initialDestination: auto.destination,
          initialBusId: auto.hasCustomBus ? auto.busId : null,
          initialPassengerType: auto.passengerType,
          initialPaymentMethod: auto.paymentMethod,
          initialPassengerName:
              auto.passengerName == 'Passenger' ? null : auto.passengerName,
          autoOpenCheckout: autoOpenCheckout,
        ),
      ),
    ));
  }

  void openFullScreen(NavigatorState nav) {
    closeWindow();
    setFullScreenActive(true);

    unawaited(nav.push(
      MaterialPageRoute<void>(
        builder: (_) => GeminiLiveScreen(
          ticketController: ticketController,
          repository: repository,
          journeyController: journeyController,
        ),
      ),
    ).then((_) {
      setFullScreenActive(false);
    }));
  }

  void setFullScreenActive(bool active) {
    if (_isFullScreenActive == active) return;
    _isFullScreenActive = active;
    if (active) {
      _isWindowOpen = false;
      _continuousListening = false;
      _restartListenTimer?.cancel();
      _isListening = false;
      _audioEngine.stopListening();
      _liveStatus = 'Ready';
      _isSpeaking = false;
      _speechTimer?.cancel();
      _audioEngine.stop();
      _liveSession?.disconnect();
      _liveSession = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
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

  void resetForTesting() {
    _speechTimer?.cancel();
    _restartListenTimer?.cancel();
    _audioEngine.stopListening();
    _audioEngine.stop();
    _liveSession?.disconnect();
    _liveSession = null;
    _connectedApiKey = null;
    _connectedVoice = null;
    _isWindowOpen = false;
    _isMuted = false;
    _isListening = false;
    _isSpeaking = false;
    _isFullScreenActive = false;
    _hasUnread = false;
    _liveStatus = 'Ready';
    _lastInterimTranscript = null;
    _continuousListening = false;
    _hasCustomPosition = false;
    _messages.clear();
    _lastSpokenText = '';
    ticketController = null;
    repository = null;
    journeyController = null;
    automation.resetDraft();
    automation.attach(repo: null, journeyCtrl: null);
    notifyListeners();
  }

  void resetPosition(Size screenSize, EdgeInsets safeArea, {bool notify = false}) {
    const double bubbleSize = 64.0;
    const double margin = 20.0;
    final double defaultX = (screenSize.width - bubbleSize - margin).clamp(16.0, double.infinity);
    final double defaultY = (screenSize.height - safeArea.bottom - bubbleSize - 90.0).clamp(100.0, double.infinity);
    _position = Offset(defaultX, defaultY);
    _hasCustomPosition = false;
    if (notify) {
      notifyListeners();
    }
  }

  void moveToTopLeft(Size screenSize, EdgeInsets safeArea) {
    updatePosition(Offset(16, safeArea.top + 16), screenSize, safeArea);
    AnnouncementCoordinator.instance.announce('Assistant moved to top left', priority: AnnouncementPriority.low);
  }

  void moveToTopRight(Size screenSize, EdgeInsets safeArea) {
    updatePosition(Offset(screenSize.width - 80, safeArea.top + 16), screenSize, safeArea);
    AnnouncementCoordinator.instance.announce('Assistant moved to top right', priority: AnnouncementPriority.low);
  }

  void moveToBottomLeft(Size screenSize, EdgeInsets safeArea) {
    updatePosition(Offset(16, screenSize.height - safeArea.bottom - 150), screenSize, safeArea);
    AnnouncementCoordinator.instance.announce('Assistant moved to bottom left', priority: AnnouncementPriority.low);
  }

  void moveToBottomRight(Size screenSize, EdgeInsets safeArea) {
    resetPosition(screenSize, safeArea, notify: true);
    AnnouncementCoordinator.instance.announce('Assistant position reset to bottom right', priority: AnnouncementPriority.low);
  }

  String _getActionLabel(String? actionType) {
    if (actionType == null) return 'Transit Action';
    final metadata = AssistantCommandGateway.getMetadata(actionType);
    if (metadata != null) {
      return metadata.gatewayScreenPrompt;
    }
    switch (actionType) {
      case 'open_settings':
        return '⚙️ Setup Gemini Live Key';
      case 'customize_home':
        return '🎨 Customize Layout';
      case 'reset_home':
        return '🔄 Restore Layout';
      default:
        return 'Transit Action';
    }
  }

  /// 30s stuck-audio watchdog. The JS audio-ended callback owns normal
  /// completion; this only recovers lost end events so the mic can never
  /// restart mid-speech and echo.
  void _armSpeakingWatchdog() {
    _speechTimer?.cancel();
    final gen = _ttsArbiter.generation;
    _speechTimer = Timer(const Duration(seconds: 30), () {
      if (gen != _ttsArbiter.generation) return;
      if (_isSpeaking) {
        _isSpeaking = false;
        if (_continuousListening &&
            !_isListening &&
            !_isFullScreenActive &&
            !_isMuted &&
            _isWindowOpen) {
          _scheduleRestartListening(delayMs: 350, playChimeTone: true);
        }
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _continuousListening = false;
    _restartListenTimer?.cancel();
    _speechTimer?.cancel();
    _audioEndConfirmTimer?.cancel();
    _ttsArbiter.dispose();
    _audioEngine.stopListening();
    _audioEngine.stop();
    _liveSession?.disconnect();
    super.dispose();
  }
}
