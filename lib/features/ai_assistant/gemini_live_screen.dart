import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../data/datasources/local_transport_data_source.dart';
import '../../data/models/ticket_model.dart';
import '../../data/repositories/ticket_repository.dart';
import '../../data/repositories/transport_repository.dart';
import '../journey/journey_controller.dart';
import '../safety/safety_sharing_page.dart';
import '../saved/saved_page.dart';
import '../settings/home_screen_customization_page.dart';
import '../tickets/live_location_screen.dart';
import '../tickets/ticket_booking_suite_page.dart';
import '../tickets/ticket_controller.dart';
import '../../core/settings/app_settings_controller.dart';
import 'audio_speech_engine.dart';
import 'floating_assistant_controller.dart';
import 'gemini_live_service.dart';
import 'gemini_live_session.dart';

/// Full-Screen & Modal Interactive Gemini Live Conversational Overlay Screen.
class GeminiLiveScreen extends StatefulWidget {
  const GeminiLiveScreen({
    super.key,
    this.ticketController,
    this.repository,
    this.journeyController,
    this.initialQuery,
  });

  final TicketController? ticketController;
  final TransportRepository? repository;
  final JourneyController? journeyController;
  final String? initialQuery;

  @override
  State<GeminiLiveScreen> createState() => _GeminiLiveScreenState();
}

class _GeminiLiveScreenState extends State<GeminiLiveScreen>
    with SingleTickerProviderStateMixin {
  final GeminiLiveService _liveService = const GeminiLiveService();
  final AudioSpeechEngine _audioEngine = const AudioSpeechEngine();

  late final TicketController _ticketController;
  late final TransportRepository _repository;
  late AnimationController _pulseController;
  late final GeminiLiveSession _liveSession;

  bool _isListening = true;
  bool _isSpeaking = false;
  bool _receivedPcmThisTurn = false;
  String _liveTranscription = 'Listening... Speak into microphone or tap chips below.';
  String _spokenOutput = 'Hi, I\'m BusBuddy! Where would you like to travel today?';
  GeminiLiveResponse? _lastResponse;
  String _liveStatus = 'Ready';

  final TextEditingController _textController = TextEditingController();

  Ticket? get _activeTicket => _ticketController.activeTicket;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? AppServiceLocator.instance.transportRepository;
    _ticketController =
        widget.ticketController ?? AppServiceLocator.instance.ticketController;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _liveSession = GeminiLiveSession(
      onTextChunk: (text) {
        if (!mounted) return;
        setState(() {
          if (_spokenOutput.startsWith('Thinking...')) {
            _spokenOutput = text;
          } else {
            _spokenOutput += text;
          }
        });
      },
      onAudioPcmChunk: (pcmBase64) {
        if (!mounted) return;
        _receivedPcmThisTurn = true;
        _speechTimer?.cancel();
        if (!_isSpeaking || _spokenOutput.startsWith('Thinking...')) {
          setState(() {
            _isSpeaking = true;
            if (_spokenOutput.startsWith('Thinking...')) {
              _spokenOutput = 'Speaking...';
            }
          });
        }
        // Stream native 24kHz audio sequentially from Google AI Studio Live API!
        _audioEngine.playPcmAudio(pcmBase64);
      },
      onTurnComplete: (fullText, actionType) {
        if (!mounted) return;
        setState(() {
          _isSpeaking = true;
          if (fullText.isNotEmpty) {
            _spokenOutput = fullText;
          } else if (!_receivedPcmThisTurn) {
            if (actionType != null) {
              switch (actionType) {
                case 'track_bus':
                  _spokenOutput = 'Here is the live bus tracker on your screen.';
                  break;
                case 'book_ticket':
                  _spokenOutput = 'Opening ticket booking for you now.';
                  break;
                case 'search_route':
                  _spokenOutput = 'Showing available buses between VIT and Katpadi.';
                  break;
                case 'emergency_sos':
                  _spokenOutput = 'Emergency safety broadcast has been triggered.';
                  break;
                case 'open_saved':
                  _spokenOutput = 'Opening your saved places and routes.';
                  break;
                default:
                  _spokenOutput = 'Here are the transit details for your journey.';
              }
            } else {
              _spokenOutput = 'I am here to assist your bus journey.';
            }
          }
        });

        // Safety fallback timer for text-only turns; PCM playback completion is governed by onAudioEnded
        _speechTimer?.cancel();
        if (!_receivedPcmThisTurn) {
          if (_spokenOutput.isNotEmpty) {
            _audioEngine.speak(_spokenOutput);
          }
          final wordCount = _spokenOutput.split(' ').length;
          final fallbackMs = (wordCount * 300).clamp(1500, 10000);
          _speechTimer = Timer(Duration(milliseconds: fallbackMs), () {
            if (mounted && _isSpeaking) {
              setState(() {
                _isSpeaking = false;
              });
              if (_continuousListening && !_isListening) {
                _scheduleRestartListening(delayMs: 350, playChimeTone: true);
              }
            }
          });
        }

        if (actionType != null && !_actionExecutedThisTurn) {
          _executeAction(actionType);
        }
      },
      onAction: (actionType, args) {
        if (!mounted) return;
        _executeAction(actionType);
      },
      onInterrupted: () {
        if (!mounted) return;
        _audioEngine.stop();
        _speechTimer?.cancel();
        _restartListenTimer?.cancel();
        setState(() {
          _isSpeaking = false;
        });
        if (_continuousListening && !_isListening) {
          _scheduleRestartListening(delayMs: 300, playChimeTone: true);
        }
      },
      onError: (err) {
        if (!mounted) return;
        debugPrint('[GeminiLiveScreen] Session error: $err');
        _speechTimer?.cancel();
        _restartListenTimer?.cancel();
        setState(() {
          _isSpeaking = false;
          _isListening = false;
          _liveStatus = 'Error';
          _liveTranscription = 'Connection notice: $err';
          _spokenOutput = 'Gemini Live encountered a connection issue. Please check your API key or network.';
        });
      },
      onStatusChanged: (status, _) {
        if (!mounted) return;
        setState(() {
          _liveStatus = status;
        });
      },
    );

    if (AppSettingsController.instance.geminiApiKey.isNotEmpty) {
      _liveSession.connect();
    }

    // Unlock audio context
    _audioEngine.unlockAudio();

    // Register audio completion callback so _isSpeaking resets cleanly and resumes continuous listening
    _audioEngine.setAudioEndedCallback(() {
      if (mounted) {
        _speechTimer?.cancel();
        setState(() {
          _isSpeaking = false;
        });
        if (_continuousListening) {
          _scheduleRestartListening(delayMs: 350, playChimeTone: true);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FloatingAssistantController.instance.setFullScreenActive(true);
      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        _continuousListening = true;
        _handleVoiceInput(widget.initialQuery!);
      } else {
        _continuousListening = true;
        _startMicrophoneListening(playChimeTone: true);
      }
    });
  }

  String _lastInterimTranscript = '';
  bool _processedFinal = false;
  bool _actionExecutedThisTurn = false;
  DateTime? _lastVoiceInputTime;
  String _lastProcessedQuery = '';

  bool _continuousListening = true;
  Timer? _restartListenTimer;
  Timer? _speechTimer;

  @override
  void dispose() {
    _continuousListening = false;
    _restartListenTimer?.cancel();
    _speechTimer?.cancel();
    FloatingAssistantController.instance.setFullScreenActive(false);
    _liveSession.disconnect();
    _audioEngine.stopListening();
    _audioEngine.stop();
    _pulseController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _startMicrophoneListening({bool playChimeTone = false, bool isRestart = false}) {
    if (!mounted) return;
    if (_isSpeaking) return;
    if (_isListening && !isRestart) return;

    _restartListenTimer?.cancel();
    _lastInterimTranscript = '';
    _processedFinal = false;

    if (playChimeTone) {
      _audioEngine.playChime(isListening: true);
    }

    setState(() {
      _isListening = true;
      _isSpeaking = false;
      _liveTranscription = 'Listening... Speak into your microphone.';
    });

    _audioEngine.startListening(
      onResult: (text, isFinal) {
        if (!mounted) return;
        if (isFinal) {
          _processedFinal = true;
          _handleVoiceInput(text);
        } else {
          _lastInterimTranscript = text;
          setState(() {
            _liveTranscription = '🗣️ "$text"';
          });
        }
      },
      onError: (err) {
        if (!mounted) return;
        debugPrint('[GeminiLiveScreen] Speech recognition error: $err');
        final isPermissionError = err.toLowerCase().contains('blocked') ||
            err.toLowerCase().contains('denied') ||
            err.toLowerCase().contains('not-allowed');

        if (isPermissionError) {
          _continuousListening = false;
          _restartListenTimer?.cancel();
          setState(() {
            _isListening = false;
            _liveTranscription = 'Microphone permission blocked. Please allow mic access in your browser.';
          });
          return;
        }

        if (_continuousListening && !_isSpeaking) {
          _scheduleRestartListening(delayMs: 1200);
        } else {
          setState(() {
            _isListening = false;
            _liveTranscription = '$err Tap mic orb or select a prompt below.';
          });
        }
      },
      onEnd: () {
        if (!mounted) return;
        if (!_processedFinal && _lastInterimTranscript.trim().isNotEmpty) {
          _processedFinal = true;
          _handleVoiceInput(_lastInterimTranscript);
        } else if (!_processedFinal) {
          if (_continuousListening && !_isSpeaking) {
            // Silence timeout occurred without speech: seamlessly restart continuous listening!
            _scheduleRestartListening(delayMs: 150);
          } else {
            setState(() {
              _isListening = false;
              _liveTranscription = 'Tap the microphone orb to speak, or choose a prompt below.';
            });
          }
        }
      },
    );
  }

  void _scheduleRestartListening({int delayMs = 300, bool playChimeTone = false}) {
    _restartListenTimer?.cancel();
    if (!mounted || !_continuousListening || _isSpeaking) return;

    _restartListenTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted && _continuousListening && !_isSpeaking && !_isListening) {
        _startMicrophoneListening(playChimeTone: playChimeTone, isRestart: true);
      }
    });
  }

  void _stopMicrophoneListening() {
    _continuousListening = false;
    _restartListenTimer?.cancel();
    _audioEngine.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
        _liveTranscription = 'Microphone paused. Tap to speak.';
      });
    }
  }

  void _handleVoiceInput(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;

    // Debounce duplicate queries within 1.5s to prevent feedback loops
    final now = DateTime.now();
    if (_lastVoiceInputTime != null &&
        now.difference(_lastVoiceInputTime!) < const Duration(milliseconds: 1500) &&
        _lastProcessedQuery.toLowerCase() == clean.toLowerCase()) {
      return;
    }
    _lastVoiceInputTime = now;
    _lastProcessedQuery = clean;

    _receivedPcmThisTurn = false;
    _actionExecutedThisTurn = false;
    _speechTimer?.cancel();
    _restartListenTimer?.cancel();
    _audioEngine.stop();
    _audioEngine.stopListening();
    _audioEngine.resetTurn();
    _audioEngine.unlockAudio();

    setState(() {
      _isListening = false;
      _isSpeaking = true;
      _liveTranscription = 'Recognized: "$clean"';
    });

    if (AppSettingsController.instance.geminiApiKey.isEmpty) {
      const msg = 'Please connect your Google AI Studio API key to chat with Gemini Live.';
      setState(() {
        _isSpeaking = true;
        _isListening = false;
        _liveStatus = 'Key Needed';
        _liveTranscription = 'Gemini Live API key is required.';
        _spokenOutput = msg;
      });
      _audioEngine.speak(msg);
      final wordCount = msg.split(' ').length;
      final fallbackMs = (wordCount * 300).clamp(1500, 10000);
      _speechTimer?.cancel();
      _speechTimer = Timer(Duration(milliseconds: fallbackMs), () {
        if (mounted && _isSpeaking) {
          setState(() {
            _isSpeaking = false;
          });
        }
      });
      _showApiKeyDialog();
      return;
    }

    setState(() {
      _isSpeaking = true;
      _spokenOutput = 'Thinking... (streaming from Google AI Studio Live API)';
    });
    _liveSession.sendQuery(clean);
  }

  void _showApiKeyDialog() {
    final textCtrl = TextEditingController(text: AppSettingsController.instance.geminiApiKey);
    String selectedModel = AppSettingsController.instance.geminiModel;
    String selectedVoice = AppSettingsController.instance.geminiVoice;

    final modelOptions = const [
      {
        'id': 'models/gemini-3.8-live',
        'label': 'Gemini 3.8 Live (Official Live Audio - Recommended)',
      },
      {
        'id': 'models/gemini-3.8-live-extended-thinking',
        'label': 'Gemini 3.8 Live Extended Thinking (Complex Reasoning)',
      },
      {
        'id': 'models/gemini-2.5-flash',
        'label': 'Gemini 2.5 Flash',
      },
    ];
    if (!modelOptions.any((opt) => opt['id'] == selectedModel)) {
      selectedModel = 'models/gemini-3.8-live';
    }

    final voiceOptions = const [
      {'id': 'Aoede', 'label': 'Aoede (Natural & Conversational - Recommended)'},
      {'id': 'Kore', 'label': 'Kore (Clear & Confident)'},
      {'id': 'Charon', 'label': 'Charon (Calm & Professional)'},
      {'id': 'Puck', 'label': 'Puck (Upbeat & Energetic)'},
      {'id': 'Fenrir', 'label': 'Fenrir (Passionate & Deep)'},
    ];
    if (!voiceOptions.any((opt) => opt['id'] == selectedVoice)) {
      selectedVoice = 'Aoede';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF111C33),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: const [
              Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 24),
              SizedBox(width: 10),
              Text(
                'Gemini Multimodal Live Setup',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connected to Google AI Studio Gemini Multimodal Live API (https://aistudio.google.com/live-api) for low-latency bidirectional voice and audio streaming.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Official Live Voice:',
                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedVoice,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF38BDF8)),
                      items: voiceOptions.map((opt) {
                        return DropdownMenuItem<String>(
                          value: opt['id'],
                          child: Text(opt['label']!),
                        );
                      }).toList(),
                      onChanged: (newVal) {
                        if (newVal != null) {
                          setDialogState(() {
                            selectedVoice = newVal;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Live Model:',
                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedModel,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF38BDF8)),
                      items: modelOptions.map((opt) {
                        return DropdownMenuItem<String>(
                          value: opt['id'],
                          child: Text(opt['label']!),
                        );
                      }).toList(),
                      onChanged: (newVal) {
                        if (newVal != null) {
                          setDialogState(() {
                            selectedModel = newVal;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Google AI Studio API Key',
                    labelStyle: const TextStyle(color: Color(0xFF38BDF8)),
                    hintText: 'Paste key from AI Studio',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (AppSettingsController.instance.geminiApiKey.isNotEmpty)
              TextButton(
                onPressed: () {
                  AppSettingsController.instance.updateGeminiApiKey('');
                  _liveSession.disconnect();
                  Navigator.pop(ctx);
                  setState(() {});
                },
                child: const Text('Clear Key', style: TextStyle(color: Color(0xFFEF4444))),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              onPressed: () {
                final newKey = textCtrl.text.trim();
                AppSettingsController.instance.updateGeminiModel(selectedModel);
                AppSettingsController.instance.updateGeminiVoice(selectedVoice);
                AppSettingsController.instance.updateGeminiApiKey(newKey);
                Navigator.pop(ctx);
                if (newKey.isNotEmpty) {
                  _liveSession.connect(customApiKey: newKey);
                } else {
                  _liveSession.disconnect();
                }
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save & Connect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    ).then((_) => textCtrl.dispose());
  }

  void _executeAction(String actionType) {
    if (_actionExecutedThisTurn) return;
    _actionExecutedThisTurn = true;
    if (actionType == 'book_ticket') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TicketBookingSuitePage(
            ticketController: _ticketController,
            initialStepIndex: 0,
          ),
        ),
      );
    } else if (actionType == 'track_bus') {
      final ticket = _activeTicket;
      if (ticket != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LiveLocationScreen(
              ticket: ticket,
              repository: _repository,
            ),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TicketBookingSuitePage(
              ticketController: _ticketController,
              initialStepIndex: 0,
            ),
          ),
        );
      }
    } else if (actionType == 'search_route') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TicketBookingSuitePage(
            ticketController: _ticketController,
            initialStepIndex: 1,
          ),
        ),
      );
    } else if (actionType == 'share_location') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SafetySharingPage(
            activeTicket: _activeTicket,
          ),
        ),
      );
    } else if (actionType == 'open_saved') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SavedPage(
            ticketController: _ticketController,
          ),
        ),
      );
    } else if (actionType == 'customize_home') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const HomeScreenCustomizationPage(),
        ),
      );
    } else if (actionType == 'reset_home') {
      AppSettingsController.instance.resetHomeScreenLayout();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Home screen layout reset to defaults.'),
          backgroundColor: Color(0xFF15803D),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B101D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B101D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF007AFF), Color(0xFF38BDF8)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'GEMINI LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _liveService.isLiveApiKeyConfigured
                    ? const Color(0xFF16A34A).withValues(alpha: 0.2)
                    : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _liveService.isLiveApiKeyConfigured
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF94A3B8),
                ),
              ),
              child: Text(
                AppSettingsController.instance.geminiApiKey.isNotEmpty ? '⚡ GEMINI LIVE' : 'NOT CONNECTED',
                style: TextStyle(
                  color: AppSettingsController.instance.geminiApiKey.isNotEmpty
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key, color: Color(0xFF38BDF8), size: 22),
            tooltip: 'Gemini Live API Settings',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: _showApiKeyDialog,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // AI Studio Live API Status / Connection Banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: InkWell(
                  onTap: _showApiKeyDialog,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppSettingsController.instance.geminiApiKey.isEmpty
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF16A34A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppSettingsController.instance.geminiApiKey.isEmpty
                            ? const Color(0xFF38BDF8).withValues(alpha: 0.3)
                            : const Color(0xFF22C55E).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          AppSettingsController.instance.geminiApiKey.isEmpty
                              ? Icons.vpn_key
                              : Icons.check_circle_outline,
                          color: AppSettingsController.instance.geminiApiKey.isEmpty
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF4ADE80),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppSettingsController.instance.geminiApiKey.isEmpty
                                ? 'Gemini Live key not set. Tap to connect your API key (aistudio.google.com/live-api)'
                                : 'Gemini Live Active (${AppSettingsController.instance.geminiModel.replaceAll('models/', '')}) • $_liveStatus',
                            style: TextStyle(
                              color: AppSettingsController.instance.geminiApiKey.isEmpty
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF4ADE80),
                              fontSize: 12,
                              fontWeight: AppSettingsController.instance.geminiApiKey.isEmpty
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          AppSettingsController.instance.geminiApiKey.isEmpty ? 'Connect' : 'Change',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right, color: Color(0xFF38BDF8), size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Top Status & Spoken Output Box with TalkBack LiveRegion
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Semantics(
                  liveRegion: true,
                  label: 'Gemini Live announcement: $_spokenOutput',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111C33),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isSpeaking ? Icons.volume_up : Icons.graphic_eq,
                              color: const Color(0xFF38BDF8),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isSpeaking ? 'GEMINI SPEAKING' : 'AUDIO RESPONSE',
                                style: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.volume_up, color: Color(0xFF38BDF8), size: 20),
                              tooltip: 'Voice response powered by Gemini Live',
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Voice is streamed in real-time by Gemini Live.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ExcludeSemantics(
                          child: Text(
                            _spokenOutput,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (_lastResponse?.displayText != null) ...[
                          const Divider(color: Color(0xFF1E293B), height: 20),
                          ExcludeSemantics(
                            child: Text(
                              _lastResponse!.displayText,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                        if (_lastResponse?.actionType != null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF007AFF),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () => _executeAction(_lastResponse!.actionType!),
                              icon: const Icon(Icons.touch_app, size: 18),
                              label: Text(
                                _getActionLabel(_lastResponse!.actionType!),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Center Dynamic Glowing Voice Visualizer Orb
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.14);
                  final alpha = 0.3 + (_pulseController.value * 0.4);
                  return Center(
                    child: Container(
                      width: 110 * scale,
                      height: 110 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF007AFF),
                            const Color(0xFF38BDF8).withValues(alpha: alpha),
                            Colors.transparent,
                          ],
                          stops: const [0.4, 0.8, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.6),
                            blurRadius: 28,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            // Explicitly resume audio context on user gesture (required by browsers)
                            _audioEngine.unlockAudio();
                            if (_isListening) {
                              _stopMicrophoneListening();
                            } else {
                              _continuousListening = true;
                              if (_isSpeaking) {
                                _audioEngine.stop();
                                _speechTimer?.cancel();
                                _restartListenTimer?.cancel();
                                setState(() {
                                  _isSpeaking = false;
                                });
                              }
                              _startMicrophoneListening(playChimeTone: true);
                            }
                          },
                          child: Tooltip(
                            message: _isListening
                                ? 'Microphone listening. Tap to pause.'
                                : 'Microphone paused. Tap to start continuous voice.',
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isListening
                                    ? Icons.mic
                                    : _isSpeaking
                                        ? Icons.graphic_eq
                                        : Icons.mic_off,
                                color: _isListening
                                    ? const Color(0xFF007AFF)
                                    : const Color(0xFF64748B),
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Live Speech Transcription text pill & Continuous status badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_continuousListening && _isListening) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mic, size: 13, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text(
                              'Continuous Mic Active',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Text(
                      _liveTranscription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Quick Spoken Prompt Chips Carousel
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildPromptChip('Where is my bus?'),
                    _buildPromptChip('Find a bus from VIT to Katpadi'),
                    _buildPromptChip('How many stops left?'),
                    _buildPromptChip('Share my location'),
                    _buildPromptChip('Book ticket'),
                    _buildPromptChip('Open saved places'),
                  ],
                ),
              ),

              const SizedBox(height: 14),

            // Text Input Fallback Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Or type your question...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF111C33),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Color(0xFF1E293B)),
                        ),
                      ),
                      onSubmitted: (val) {
                        _audioEngine.unlockAudio();
                        _handleVoiceInput(val);
                        _textController.clear();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      padding: const EdgeInsets.all(14),
                    ),
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () {
                      _audioEngine.unlockAudio();
                      _handleVoiceInput(_textController.text);
                      _textController.clear();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildPromptChip(String prompt) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: const Color(0xFF111C33),
        side: const BorderSide(color: Color(0xFF1E293B)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        avatar: const Icon(Icons.mic, color: Color(0xFF38BDF8), size: 16),
        label: Text(
          prompt,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        onPressed: () {
          _audioEngine.unlockAudio();
          _audioEngine.playChime(isListening: false);
          _handleVoiceInput(prompt);
        },
      ),
    );
  }

  String _getActionLabel(String actionType) {
    switch (actionType) {
      case 'track_bus':
        return 'Open Live GPS Map';
      case 'book_ticket':
        return 'Book Bus Ticket Now';
      case 'search_route':
        return 'View Available Buses';
      case 'share_location':
        return 'Share Location with Contacts';
      case 'open_saved':
        return 'Open Saved Places';
      case 'customize_home':
        return 'Customize Home Screen';
      case 'reset_home':
        return 'Reset Home Screen Layout';
      default:
        return 'Execute Action';
    }
  }
}
