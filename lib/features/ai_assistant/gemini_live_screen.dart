import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/a11y/dispose_guard.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/ticket_model.dart';
import '../../data/repositories/transport_repository.dart';
import '../journey/journey_controller.dart';
import '../safety/safety_sharing_page.dart';
import '../settings/home_screen_customization_page.dart';
import '../tickets/live_location_screen.dart';
import '../tickets/ticket_booking_suite_page.dart';
import '../tickets/ticket_controller.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/widgets/bus_buddy_logo.dart';
import '../../domain/assistant/assistant_command.dart';
import 'android_voice_turn.dart';
import 'app_automation_controller.dart';
import 'audio_speech_engine.dart';
import 'ai_control_glow.dart';
import 'gemini_live_service.dart';
import 'gemini_live_session.dart';
import 'gemini_live_transport.dart';
import 'model_voice_player.dart';
import 'wake_word_service.dart';

/// Full-Screen & Modal Interactive Gemini Live Conversational Overlay Screen.
class GeminiLiveScreen extends StatefulWidget {
  const GeminiLiveScreen({
    super.key,
    this.ticketController,
    this.repository,
    this.journeyController,
    this.initialQuery,
    this.transportFactory,
  });

  final TicketController? ticketController;
  final TransportRepository? repository;
  final JourneyController? journeyController;
  final String? initialQuery;

  /// Injectable socket factory for tests; production uses the platform default.
  final GeminiLiveTransport Function()? transportFactory;

  @override
  State<GeminiLiveScreen> createState() => _GeminiLiveScreenState();
}

class _GeminiLiveScreenState extends State<GeminiLiveScreen>
    with SingleTickerProviderStateMixin {
  final GeminiLiveService _liveService = const GeminiLiveService();
  final AudioSpeechEngine _audioEngine = AudioSpeechEngine();

  /// Gemini's own streamed audio (Android `AudioTrack`). This is the natural
  /// voice; `_audioEngine` stays as the fallback for turns that carry no audio.
  final ModelVoicePlayer _modelVoice = ModelVoicePlayer();
  final AppAutomationController _automation = AppAutomationController();

  late final TicketController _ticketController;
  late final TransportRepository _repository;
  late AnimationController _pulseController;
  late final GeminiLiveSession _liveSession;

  /// Nothing is listening until a start actually succeeds. This used to default
  /// to `true`, which made the screen advertise "Continuous Mic Active" and
  /// "Listening…" before any microphone was open — and worse, made
  /// [_startMicrophoneListening] early-return on its own `_isListening` guard, so
  /// the first open never started capture at all. Honesty and correctness in one:
  /// the flag now tracks a real open microphone (BUS-P1-08).
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isPermissionBlocked = false;

  /// Open Android spoken turn, if any. Android has no on-device speech-to-text,
  /// so a turn is an open microphone stream rather than a pending transcript.
  AndroidVoiceTurn? _voiceTurn;
  int _turnCounter = 0;
  Timer? _watchdogTimer;

  /// Starts neutral rather than claiming to listen: capture is opened by the
  /// post-frame start, which replaces this with the real state.
  String _liveTranscription =
      'Tap the microphone or a chip below to ask BusBuddy something.';
  String _spokenOutput =
      'Hi, I\'m BusBuddy! Where would you like to travel today?';
  GeminiLiveResponse? _lastResponse;
  String _liveStatus = 'Ready';

  final TextEditingController _textController = TextEditingController();

  Ticket? get _activeTicket => _ticketController.activeTicket;

  @override
  void initState() {
    super.initState();
    // Pause background wake word detection while this assistant screen is open
    // to strictly preserve the single-speaker / single-microphone session contract.
    WakeWordService.instance.pause();
    _repository =
        widget.repository ?? AppServiceLocator.instance.transportRepository;
    _ticketController =
        widget.ticketController ?? AppServiceLocator.instance.ticketController;
    _automation.attach(
      repo: _repository,
      journeyCtrl: widget.journeyController,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      // BUS-P2-04 (discarded_futures): `repeat()` returns a TickerFuture that
      // never completes while the screen is alive. Awaiting it would stall
      // initState; it is intentionally fire-and-forget for the pulse loop.
      // ignore: discarded_futures
    )..repeat(reverse: true);

    _liveSession = GeminiLiveSession(
      transportFactory: widget.transportFactory,
      onTextChunk: (text) {
        if (!mounted) return;
        // Streaming text goes to the transcript only. The voice is spoken
        // exactly once from onTurnComplete — never a half-built string.
        setState(() {
          if (_liveTranscription.startsWith('Listening') ||
              _liveTranscription.startsWith('Recognized') ||
              _liveTranscription.startsWith('Preparing') ||
              _liveTranscription.startsWith('Tap the microphone') ||
              _spokenOutput.startsWith('Thinking...')) {
            _liveTranscription = text;
          } else {
            _liveTranscription += text;
          }
        });
      },
      onTurnComplete: (fullText, actionType) {
        if (!mounted) return;
        _turnCounter++;
        // Slot-tool protocol turns are silent: the follow-up answer turn
        // carries the voice, so speaking one would repeat the same words.
        final bool silentProtocol = AssistantCommandGateway.isSilentProtocol(
          actionType,
        );
        setState(() {
          _isSpeaking = true;
          if (fullText.isNotEmpty) {
            _spokenOutput = fullText;
            _liveTranscription = fullText;
          } else if (!silentProtocol) {
            if (actionType != null) {
              switch (actionType) {
                case 'track_bus':
                  _spokenOutput =
                      'Here is the live bus tracker on your screen.';
                  break;
                case 'book_ticket':
                  _spokenOutput = 'Opening ticket booking for you now.';
                  break;
                case 'search_route':
                  _spokenOutput =
                      'Showing available buses between VIT and Katpadi.';
                  break;
                case 'emergency_sos':
                  _spokenOutput =
                      'Emergency safety broadcast has been triggered.';
                  break;
                default:
                  _spokenOutput =
                      'Here are the transit details for your journey.';
              }
            } else {
              // No text and no tool call. With outputAudioTranscription now
              // requested this should not happen, and when it does we must not
              // invent a reply: claiming to "assist with your journey" while
              // saying nothing about what was asked is the same class of lie
              // as the microphone flag in BUS-P1-08. Say plainly that the
              // answer could not be read out.
              _spokenOutput =
                  'I received a reply but could not read it aloud. '
                  'Please try asking again, or type your question.';
            }
          }
        });

        // Single speaker: every reply is spoken exactly once through the one
        // speech engine. The bridge's speak() is stop-before-speak, so even a
        // duplicated call can never layer a second voice.
        if (!silentProtocol && _spokenOutput.isNotEmpty) {
          final spoken = _spokenOutput;
          // Single speaker, part 2: if Gemini streamed its own audio for this
          // turn, that audio IS the reply — speaking the same words again
          // through TTS would be the double-voice bug Chunks 41-43 chased.
          // TTS speaks only when the turn carried no model audio (plain text
          // turn, REST fallback, socket without audio).
          if (_modelVoice.hasModelAudioThisTurn) {
            debugPrint(
              '[SingleVoice] turn $_turnCounter played model audio; '
              'skipping TTS',
            );
            // Keep holding the microphone: playback is still draining, and the
            // drain notification releases it. Do NOT return here — the tool
            // call below must still run (a reply can be both spoken and acted).
            _pauseVoiceTurn();
            // Safety net only: the drain is the normal end-of-turn signal, but
            // a stalled AudioContext must never strand the UI on "Speaking".
            _armWatchdog();
          } else {
            debugPrint(
              '[SingleVoice] speaking turn via TTS (turn $_turnCounter)',
            );
            // Android keeps one microphone stream across turns: withhold its frames
            // while the assistant talks so the reply is never heard as a question.
            _pauseVoiceTurn();
            _audioEngine.stop();
            _audioEngine.speak(spoken);
            _armWatchdog();
          }
        }

        if (actionType != null && !_actionExecutedThisTurn) {
          _executeAction(actionType);
        }
      },
      onAction: (actionType, args) {
        if (!mounted) return;
        _executeAction(actionType, args);
      },
      onUserTranscription: (text) {
        if (!mounted) return;
        // Display only. The microphone audio already reached the model, so this
        // text must never be re-submitted as a new text turn. Rendered with a
        // voice-over icon (see _isVoiceTranscript) instead of the old emoji.
        setState(() {
          _liveTranscription = '"$text"';
        });
      },
      onAudioPcmChunk: (base64Pcm) {
        if (!mounted) return;
        // The model's own voice, straight into the active playback backend
        // (Android AudioTrack, Web Audio on the browser). This is the natural
        // voice the passenger hears; TTS is not involved here.
        if (!_modelVoice.isSupported) return;
        if (!_modelVoice.isPlaying) {
          // First audio of the turn: the assistant has started talking, so hold
          // the microphone frames or the reply is heard as the next question.
          debugPrint(
            '[ModelVoice] turn $_turnCounter: playing Gemini\'s own voice '
            '(model audio, TTS will be skipped)',
          );
          _speechTimer?.cancel();
          _pauseVoiceTurn();
          setState(() {
            _isSpeaking = true;
          });
        }
        // ignore: discarded_futures
        _modelVoice.addChunk(base64Pcm);
      },
      onInterrupted: () {
        if (!mounted) return;
        _audioEngine.stop();
        // Barge-in: the passenger talked over the assistant, so drop the
        // queued model audio instead of letting it finish over them.
        // ignore: discarded_futures
        _modelVoice.stop();
        _speechTimer?.cancel();
        _watchdogTimer?.cancel();
        _restartListenTimer?.cancel();
        setState(() {
          _isSpeaking = false;
        });
        // The passenger talked over the assistant: keep their microphone stream
        // feeding the session so the interruption is understood as a question.
        _resumeVoiceTurn();
        if (_continuousListening && !_isListening) {
          _scheduleRestartListening(delayMs: 300, playChimeTone: true);
        }
      },
      onError: (err) {
        if (!mounted) return;
        debugPrint('[GeminiLiveScreen] Session error: $err');
        _speechTimer?.cancel();
        _watchdogTimer?.cancel();
        _restartListenTimer?.cancel();
        setState(() {
          _isSpeaking = false;
          _isListening = false;
          _liveStatus = 'Error';
          _liveTranscription = 'Connection notice: $err';
          _spokenOutput =
              'Gemini Live encountered a connection issue. Please check your API key or network.';
        });
      },
      onStatusChanged: (status, _) {
        if (!mounted) return;
        setState(() {
          _liveStatus = status;
        });
      },
    );

    // The key, model and voice that the live socket was opened with. The
    // settings listener below reconnects whenever these drift — previously a
    // key saved from the settings page never reached the already-open screen,
    // which sat there looking "not connected" with a valid key stored.
    _lastLiveKey = AppSettingsController.instance.geminiApiKey;
    _lastLiveModel = AppSettingsController.instance.geminiModel;
    _lastLiveVoice = AppSettingsController.instance.geminiVoice;
    AppSettingsController.instance.addListener(_onSettingsChanged);
    unawaited(_connectValidated());

    // Prime the audio context, but do not rely on this to unlock it: initState
    // runs *after* the tap that pushed this screen, so Chrome's autoplay policy
    // leaves the context suspended here. The real unlock happens on the mic-orb
    // and prompt-chip gestures, which each call unlockAudio() directly. The
    // bridge also keeps global gesture listeners installed for the same reason.
    _audioEngine.unlockAudio();

    // Register audio completion callback so _isSpeaking resets cleanly and
    // continuous listening resumes. With the single-speaker bridge this
    // fires exactly once per utterance (utterance onend/onerror).
    _audioEngine.setAudioEndedCallback(() {
      if (!mounted) return;
      _speechTimer?.cancel();
      _watchdogTimer?.cancel();
      setState(() {
        _isSpeaking = false;
      });
      // Android never restarts a stream that stayed open: it just resumes
      // feeding frames, which is why the pause happens in the speak path.
      _resumeVoiceTurn();
      if (_continuousListening && !_isListening) {
        _scheduleRestartListening(delayMs: 350, playChimeTone: true);
      }
    });

    // The real end of a model-audio turn. When Gemini streamed its own voice,
    // no TTS utterance ever ran, so the TTS ended-callback above never fires —
    // the playback drain is what releases the turn and reopens the microphone
    // (Android posts it from the AudioTrack, web from the AudioContext queue).
    // Without this the mic would stay paused forever after the first spoken
    // reply.
    // Cancelled by dispose().
    // ignore: cancel_subscriptions
    _modelDrainSub = _modelVoice.onDrained.listen((_) {
      if (!mounted) return;
      _speechTimer?.cancel();
      _watchdogTimer?.cancel();
      setState(() {
        _isSpeaking = false;
      });
      _resumeVoiceTurn();
      if (_continuousListening && !_isListening) {
        _scheduleRestartListening(delayMs: 350, playChimeTone: true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
  StreamSubscription<void>? _modelDrainSub;

  /// Last connection inputs the socket was opened (or gated) with; the
  /// settings listener compares against these. See initState.
  String _lastLiveKey = '';
  String _lastLiveModel = '';
  String _lastLiveVoice = '';
  Timer? _settingsDebounce;

  /// Abort token for in-flight key validation: a newer connect request wins.
  int _connectGeneration = 0;

  @override
  void dispose() {
    // Every step is isolated and the process-wide reset comes FIRST.
    //
    // [AiControlGlow.instance] is a singleton painted by the frame in
    // `MaterialApp.builder`, so it outlives this screen. When the glow reset
    // sat below `_liveSession.dispose()`, a throw in that live-socket teardown
    // — which only happens on a real device with a live session, so the
    // faked-transport widget tests never saw it — skipped every step below it
    // and left the glow in `listening` over Home for the rest of the process.
    // The microphone release matters for the same reason: leaving it armed is
    // the same class of lie as advertising a mic that is not open (BUS-P1-08).
    //
    // The conversational flags are cleared as plain writes BEFORE the steps:
    // `mounted` stays true for the whole runDisposeSteps window, so a
    // synchronous callback fired by a teardown step (the web JS bridge fires
    // some synchronously) would otherwise re-run setState and re-derive
    // listening/speaking in the override below — re-arming the glow right
    // after this reset. With the flags down, any such re-entrant setState
    // derives idle instead.
    _isListening = false;
    _isSpeaking = false;
    _continuousListening = false;
    // A validation round-trip that lands after dispose must not touch state.
    _connectGeneration++;
    runDisposeSteps([
      (name: 'aiControlGlow', run: AiControlGlow.instance.idle),
      (name: 'wakeWordResume', run: WakeWordService.instance.resume),
      (name: 'continuousListening', run: () => _continuousListening = false),
      (
        name: 'settingsListener',
        run: () {
          AppSettingsController.instance.removeListener(_onSettingsChanged);
          _settingsDebounce?.cancel();
          _settingsDebounce = null;
        },
      ),
      (
        name: 'timers',
        run: () {
          _restartListenTimer?.cancel();
          _speechTimer?.cancel();
          _watchdogTimer?.cancel();
        },
      ),
      (name: 'liveSession', run: _liveSession.dispose),
      (
        name: 'androidVoiceTurn',
        run: () => unawaited(_releaseAndroidVoiceTurn()),
      ),
      (
        name: 'audioEngine',
        run: () {
          _audioEngine.stopListening();
          _audioEngine.stop();
        },
      ),
      (name: 'pulseController', run: _pulseController.dispose),
      (name: 'textController', run: _textController.dispose),
      // Model audio is process-wide too: a playing AudioTrack would outlive
      // the screen and keep talking over whatever the passenger opened next.
      (
        name: 'modelVoice',
        run: () {
          unawaited(_modelDrainSub?.cancel());
          _modelDrainSub = null;
          unawaited(_modelVoice.dispose());
        },
      ),
      // And LAST, not just first: any teardown step above that synchronously
      // re-armed the glow (a web JS bridge callback firing mid-teardown) is
      // undone here, so Home can never inherit an active glow. Duplicate-mode
      // suppression in AiControlGlow makes the no-op case free.
      (name: 'aiControlGlowFinal', run: AiControlGlow.instance.idle),
    ]);
    super.dispose();
  }

  /// Every state change in this screen flows through [setState], so
  /// the AI glow mode is derived here once — mic open (blue), reply
  /// playing (violet), or a tool/screen action in flight (amber).
  /// Mirrors the visible [_isListening]/[_isSpeaking] flags exactly,
  /// so the glow can never advertise a state the screen itself
  /// denies (BUS-P1-08).
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    final glow = AiControlGlow.instance;
    if (_isSpeaking) {
      glow.speaking();
    } else if (_isListening) {
      glow.listening();
    } else if (_actionExecutedThisTurn) {
      glow.acting();
    } else {
      glow.idle();
    }
  }

  /// Single-voice watchdog: the JS `__bb_on_audio_ended` callback is the sole
  /// normal clearer of [_isSpeaking]. This 30s timer only recovers stuck
  /// audio (e.g. a lost end event) so it can never restart the mic mid-speech
  /// and cause echo/self-answer overlap.
  void _armWatchdog() {
    _watchdogTimer?.cancel();
    final turn = _turnCounter;
    _watchdogTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted) return;
      if (turn != _turnCounter) return;
      if (_isSpeaking) {
        setState(() {
          _isSpeaking = false;
        });
        if (_continuousListening && !_isListening) {
          _scheduleRestartListening(delayMs: 350, playChimeTone: true);
        }
      }
    });
  }

  void _startMicrophoneListening({
    bool playChimeTone = false,
    bool isRestart = false,
  }) {
    if (!mounted) return;
    if (_isSpeaking) return;
    if (_isListening && !isRestart) return;

    _restartListenTimer?.cancel();
    _lastInterimTranscript = '';
    _processedFinal = false;

    if (_audioEngine.supportsLiveAudioInput) {
      // Android has no on-device speech-to-text, so the microphone PCM itself is
      // streamed into the live session instead of a locally recognised string.
      //
      // `_isListening` deliberately stays false here: this path awaits a
      // permission dialog and up to 4 s of Live handshake, and promising
      // "Listening…" / "Continuous Mic Active" across that window would tell a
      // TalkBack user the microphone is live while it is not. The turn sets the
      // flag only once capture is genuinely open.
      unawaited(_startAndroidVoiceTurn(playChimeTone: playChimeTone));
      return;
    }

    if (playChimeTone) {
      _audioEngine.playChime(isListening: true);
    }

    setState(() {
      _isPermissionBlocked = false;
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
            _liveTranscription = '"$text"';
          });
        }
      },
      onError: (err) {
        if (!mounted) return;
        debugPrint('[GeminiLiveScreen] Speech recognition error: $err');
        final isPermissionError =
            err.toLowerCase().contains('blocked') ||
            err.toLowerCase().contains('denied') ||
            err.toLowerCase().contains('not-allowed');

        if (isPermissionError) {
          _continuousListening = false;
          _restartListenTimer?.cancel();
          setState(() {
            _isPermissionBlocked = true;
            _isListening = false;
            _liveTranscription =
                'Microphone permission blocked. Please allow mic access in your browser.';
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
              _liveTranscription =
                  'Tap the microphone orb to speak, or choose a prompt below.';
            });
          }
        }
      },
    );
  }

  void _scheduleRestartListening({
    int delayMs = 300,
    bool playChimeTone = false,
  }) {
    _restartListenTimer?.cancel();
    if (!mounted || !_continuousListening || _isSpeaking) return;

    _restartListenTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted && _continuousListening && !_isSpeaking && !_isListening) {
        _startMicrophoneListening(
          playChimeTone: playChimeTone,
          isRestart: true,
        );
      }
    });
  }

  void _stopMicrophoneListening() {
    _continuousListening = false;
    _restartListenTimer?.cancel();
    unawaited(_releaseAndroidVoiceTurn());
    _audioEngine.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
        _liveTranscription = 'Microphone paused. Tap to speak.';
      });
    }
  }

  /// Android spoken turn: streams microphone PCM into the live session for as
  /// long as the turn is open, and hands the passenger back to the text box on
  /// any failure.
  ///
  /// Nothing is transcribed locally and nothing is submitted as a text turn: the
  /// session's voice-activity detection decides when the question ended, and the
  /// reply arrives through the normal speak-exactly-once path.
  Future<void> _startAndroidVoiceTurn({bool playChimeTone = false}) async {
    await _releaseAndroidVoiceTurn();
    if (!mounted) return;

    if (mounted) {
      setState(() {
        _isPermissionBlocked = false;
        _isListening = false;
        _isSpeaking = false;
        _liveTranscription = 'Preparing the microphone...';
      });
    }

    // Never open the microphone on a socket that is still handshaking: its first
    // frames would be dropped and the turn would end the moment it started.
    if (!await _awaitLiveReady()) {
      // Name the real reason. "Still connecting" is a guess, and a wrong one when
      // no key is configured at all — which is the common first-run case, and the
      // passenger can fix it in seconds from the banner above.
      final noKey = AppSettingsController.instance.geminiApiKey.isEmpty;
      _releaseAndroidVoiceTurnUi(
        noKey
            ? 'BusBuddy needs a Gemini Live key before it can listen, so the '
                  'microphone stayed off. Please type your question, or tap Connect '
                  'to add your key.'
            : 'BusBuddy is still connecting, so the microphone stayed off. Please '
                  'type your question, or tap the microphone orb again in a moment.',
        false,
      );
      return;
    }
    if (!mounted) return;

    final turn = AndroidVoiceTurn(
      openMicrophone: _audioEngine.openLiveMicrophone,
      closeMicrophone: _audioEngine.closeLiveMicrophone,
      microphonePcm: () => _audioEngine.liveMicrophonePcm,
      microphoneErrors: () => _audioEngine.liveMicrophoneErrors,
      sendAudio: _liveSession.sendRealtimeAudio,
      onTurnLost: _releaseAndroidVoiceTurnUi,
    );
    _voiceTurn = turn;
    await turn.start();
    if (!mounted || !identical(_voiceTurn, turn)) return;
    if (!turn.isActive) {
      // start() failed and the loss was already reported through onTurnLost.
      _voiceTurn = null;
      return;
    }

    // Capture is genuinely open now, so only now may the UI say so — the chime
    // that marks the passenger's turn comes here too, not at the request.
    if (playChimeTone) _audioEngine.playChime(isListening: true);
    setState(() {
      _isPermissionBlocked = false;
      _isListening = true;
      _isSpeaking = false;
      _liveTranscription = 'Listening... speak your question.';
    });
  }

  /// Waits briefly for the Live handshake so a spoken question is never lost to a
  /// connecting socket.
  Future<bool> _awaitLiveReady({int timeoutMs = 4000}) async {
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    while (mounted) {
      if (_liveSession.isReady) return true;
      if (AppSettingsController.instance.geminiApiKey.isEmpty) return false;
      if (!DateTime.now().isBefore(deadline)) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return mounted && _liveSession.isReady;
  }

  /// Speaks failure honestly and in proportion: a microphone the passenger has to
  /// fix (permission, device) raises the blocking panel with its Try Again
  /// control, while a connection problem only shows the reason next to the text
  /// box that still works.
  void _releaseAndroidVoiceTurnUi(String reason, bool microphoneUnavailable) {
    if (!mounted) return;
    unawaited(_releaseAndroidVoiceTurn());
    _restartListenTimer?.cancel();
    if (microphoneUnavailable) _continuousListening = false;
    setState(() {
      _isListening = false;
      _isPermissionBlocked = microphoneUnavailable;
      _liveTranscription = reason;
    });
  }

  /// Closes the open spoken turn and releases the microphone handle.
  Future<void> _releaseAndroidVoiceTurn() async {
    final turn = _voiceTurn;
    _voiceTurn = null;
    await turn?.stop();
  }

  /// Stops feeding the microphone while the assistant speaks, so its own voice
  /// can never be picked up as the next question.
  void _pauseVoiceTurn() => _voiceTurn?.pause();

  void _resumeVoiceTurn() => _voiceTurn?.resume();

  /// Echo-of-self guard: the mic can pick up the AI's own speaker output
  /// (room reverb, Bluetooth tail) and transcribe it as a new query, which
  /// would start a second voice over the first. Long transcripts that closely
  /// match the last spoken reply are dropped. Short answers ("UPI", "yes")
  /// always pass so genuine replies are never ignored.
  bool _isEchoOfSelf(String transcript) {
    final heard = _normalizeForEcho(transcript);
    final spoken = _normalizeForEcho(_spokenOutput);
    if (heard.length < 8 || spoken.length < 8) return false;
    if (spoken.contains(heard) || heard.contains(spoken)) return true;
    final heardTokens = heard.split(' ').toSet();
    final spokenTokens = spoken.split(' ').toSet();
    if (heardTokens.isEmpty) return false;
    final overlap =
        heardTokens.intersection(spokenTokens).length / heardTokens.length;
    return overlap >= 0.6;
  }

  String _normalizeForEcho(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _handleVoiceInput(String query, {bool isUserTap = false}) {
    final clean = query.trim();
    if (clean.isEmpty) return;

    // Debounce duplicate queries within 1.5s to prevent feedback loops
    final now = DateTime.now();
    if (_lastVoiceInputTime != null &&
        now.difference(_lastVoiceInputTime!) <
            const Duration(milliseconds: 1500) &&
        _lastProcessedQuery.toLowerCase() == clean.toLowerCase()) {
      return;
    }
    // Drop mic echo of our own voice (not user taps / typed text).
    if (!isUserTap && _isEchoOfSelf(clean)) {
      debugPrint('[GeminiLive] Dropped echo-of-self transcript: "$clean"');
      if (_continuousListening && !_isListening && !_isSpeaking) {
        _scheduleRestartListening(delayMs: 350, playChimeTone: false);
      }
      return;
    }
    _lastVoiceInputTime = now;
    _lastProcessedQuery = clean;

    _turnCounter++;
    _actionExecutedThisTurn = false;
    _speechTimer?.cancel();
    _restartListenTimer?.cancel();
    // A typed/tapped question replaces the spoken one: close the Android
    // microphone turn so it cannot race this text turn as a second request.
    unawaited(_releaseAndroidVoiceTurn());
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
      const msg =
          'Please connect your Google AI Studio API key to chat with Gemini Live.';
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
    // New turn: clear the previous turn's "the model spoke" marker so TTS is
    // only skipped when THIS turn actually carried model audio.
    _modelVoice.beginTurn();
    unawaited(_liveSession.sendQuery(clean));
  }

  /// The single choke point for opening the socket: validates the key first so
  /// a bad key (or no network) is reported as exactly that, then connects.
  /// Every entry reaches here — first open, dialog save, settings change —
  /// so no path can open a socket on an unchecked key.
  Future<void> _connectValidated() async {
    final generation = ++_connectGeneration;
    final settings = AppSettingsController.instance;
    if (settings.geminiApiKey.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _liveStatus = 'Key Needed';
      });
      return;
    }
    if (mounted) {
      setState(() {
        _liveStatus = 'Validating API key…';
      });
    }
    final error = await GeminiLiveSession.validateApiKey(settings.geminiApiKey);
    if (!mounted || generation != _connectGeneration) return;
    if (error != null) {
      setState(() {
        _isSpeaking = false;
        _isListening = false;
        _liveStatus = 'Key Invalid';
        _liveTranscription =
            'API key check failed: $error Tap Connect to try a different key, or type your question below.';
        _spokenOutput =
            'The Gemini API key check failed. Please check the key and try again, or type your question.';
      });
      return;
    }
    _lastLiveKey = settings.geminiApiKey;
    _lastLiveModel = settings.geminiModel;
    _lastLiveVoice = settings.geminiVoice;
    _liveSession.connect();
  }

  /// Fires on every settings notification (including unrelated ones); the work
  /// is debounced and then ignored unless the connection inputs moved.
  void _onSettingsChanged() {
    _settingsDebounce?.cancel();
    _settingsDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final settings = AppSettingsController.instance;
      if (settings.geminiApiKey == _lastLiveKey &&
          settings.geminiModel == _lastLiveModel &&
          settings.geminiVoice == _lastLiveVoice) {
        return;
      }
      if (settings.geminiApiKey.trim().isEmpty) {
        _lastLiveKey = '';
        _liveSession.disconnect();
        if (mounted) {
          setState(() {
            _liveStatus = 'Key Needed';
          });
        }
        return;
      }
      unawaited(_connectValidated());
    });
  }

  void _showApiKeyDialog() {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => _GeminiSetupDialog(
          onSaved: (String newKey) {
            // The dialog State owns its TextEditingController and disposes
            // it only when the route leaves the tree, so rebuilding the
            // still-animating dialog here (settings notifications fire on
            // save) can never touch a disposed controller.
            //
            // The dialog already stored the key/model/voice in the settings
            // controller; the settings listener will see the same values and
            // stand down (its compare runs against the _lastLive* snapshot
            // taken below), so this explicit connect is the only one.
            if (newKey.isEmpty) {
              _liveSession.disconnect();
              _lastLiveKey = '';
              if (mounted) {
                setState(() {
                  _liveStatus = 'Key Needed';
                });
              }
            } else {
              unawaited(_connectValidated());
            }
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  void _executeAction(String actionType, [Map<String, dynamic>? args]) {
    if (actionType == 'set_trip' ||
        actionType == 'select_bus' ||
        actionType == 'set_passenger' ||
        actionType == 'set_payment') {
      // Slot setters never navigate alone; they pre-fill the draft and the
      // spoken turn tells the user what is still missing.
      _automation.handleToolCall(actionType, args);
      return;
    }
    if (actionType == 'confirm_booking') {
      final readiness = _automation.handleToolCall('confirm_booking', args);
      if (!readiness.isComplete) {
        if (mounted) {
          setState(() {
            _spokenOutput = readiness.spokenHint;
          });
        }
        return;
      }
      if (_actionExecutedThisTurn) return;
      _actionExecutedThisTurn = true;
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TicketBookingSuitePage(
              ticketController: _ticketController,
              journeyController: widget.journeyController,
              initialOrigin: _automation.origin,
              initialDestination: _automation.destination,
              initialBusId: _automation.hasCustomBus ? _automation.busId : null,
              initialPassengerType: _automation.passengerType,
              initialPaymentMethod: _automation.paymentMethod,
              initialPassengerName: _automation.passengerName == 'Passenger'
                  ? null
                  : _automation.passengerName,
              autoOpenCheckout: true,
            ),
          ),
        ),
      );
      return;
    }
    if (_actionExecutedThisTurn) return;
    _actionExecutedThisTurn = true;
    if (actionType == 'book_ticket') {
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TicketBookingSuitePage(
              ticketController: _ticketController,
              initialStepIndex: 0,
            ),
          ),
        ),
      );
    } else if (actionType == 'track_bus') {
      final ticket = _activeTicket;
      if (ticket != null) {
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  LiveLocationScreen(ticket: ticket, repository: _repository),
            ),
          ),
        );
      } else {
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TicketBookingSuitePage(
                ticketController: _ticketController,
                initialStepIndex: 0,
              ),
            ),
          ),
        );
      }
    } else if (actionType == 'search_route') {
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TicketBookingSuitePage(
              ticketController: _ticketController,
              initialStepIndex: 1,
            ),
          ),
        ),
      );
    } else if (actionType == 'share_location') {
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SafetySharingPage(activeTicket: _activeTicket),
          ),
        ),
      );
    } else if (actionType == 'customize_home') {
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const HomeScreenCustomizationPage(),
          ),
        ),
      );
    } else if (actionType == 'reset_home') {
      AppSettingsController.instance.resetHomeScreenLayout();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Home screen layout reset to defaults.'),
          backgroundColor: AppTheme.colors(context).statusSuccess,
        ),
      );
    }
  }

  /// True while [_liveTranscription] is a display-only voice transcript
  /// ('"…"'). Those render with a small voice-over icon before the quoted
  /// text instead of the old 🗣️ emoji prefix.
  bool get _isVoiceTranscript =>
      _liveTranscription.startsWith('"') && _liveTranscription.endsWith('"');

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.textPrimary, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Horizontal scroll keeps the badge row reflow-safe at large text
        // scales (real text, no FittedBox, no clamping).
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const BusBuddyLogo(fontSize: 18),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.actionPrimary, colors.actionSecondary],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: colors.onActionPrimary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'GEMINI LIVE',
                      style: TextStyle(
                        color: colors.onActionPrimary,
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
                      ? colors.statusSuccess.withValues(alpha: 0.2)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(
                    color: _liveService.isLiveApiKeyConfigured
                        ? colors.statusSuccess
                        : colors.textSecondary,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (AppSettingsController
                        .instance
                        .geminiApiKey
                        .isNotEmpty) ...[
                      Icon(Icons.bolt, size: 16, color: colors.statusSuccess),
                      const SizedBox(width: 2),
                    ],
                    Text(
                      AppSettingsController.instance.geminiApiKey.isNotEmpty
                          ? 'GEMINI LIVE'
                          : 'NOT CONNECTED',
                      style: TextStyle(
                        color:
                            AppSettingsController
                                .instance
                                .geminiApiKey
                                .isNotEmpty
                            ? colors.statusSuccess
                            : colors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.vpn_key, color: colors.actionSecondary, size: 22),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: InkWell(
                  onTap: _showApiKeyDialog,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppSettingsController.instance.geminiApiKey.isEmpty
                          ? colors.surface
                          : colors.statusSuccess.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color:
                            AppSettingsController.instance.geminiApiKey.isEmpty
                            ? colors.actionSecondary.withValues(alpha: 0.3)
                            : colors.statusSuccess.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          AppSettingsController.instance.geminiApiKey.isEmpty
                              ? Icons.vpn_key
                              : Icons.check_circle_outline,
                          color:
                              AppSettingsController
                                  .instance
                                  .geminiApiKey
                                  .isEmpty
                              ? colors.actionSecondary
                              : colors.statusSuccess,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppSettingsController.instance.geminiApiKey.isEmpty
                                ? 'Gemini Live key not set. Tap to connect your API key (aistudio.google.com/live-api)'
                                : 'Gemini Live Active (${AppSettingsController.instance.geminiModel.replaceAll('models/', '')}) • $_liveStatus',
                            style: TextStyle(
                              color:
                                  AppSettingsController
                                      .instance
                                      .geminiApiKey
                                      .isEmpty
                                  ? colors.textSecondary
                                  : colors.statusSuccess,
                              fontSize: 12,
                              fontWeight:
                                  AppSettingsController
                                      .instance
                                      .geminiApiKey
                                      .isEmpty
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          AppSettingsController.instance.geminiApiKey.isEmpty
                              ? 'Connect'
                              : 'Change',
                          style: TextStyle(
                            color: colors.actionSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right,
                          color: colors.actionSecondary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Top Status & Spoken Output Box with TalkBack LiveRegion.
              // Single-voice: the live region must NEVER carry the reply
              // sentence. The reply is already spoken by our own PCM/TTS
              // voice; a screen reader (TalkBack/ChromeVox) announcing the
              // same sentence through its own voice produces exactly the
              // "two voices saying the same words" double-audio report.
              // Announce only the state transition; the full text stays a
              // regular semantics node the user can navigate to on demand.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Semantics(
                  liveRegion: true,
                  label: _isSpeaking
                      ? 'Gemini is speaking'
                      : 'Gemini Live response ready',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(
                        color: colors.actionPrimary.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.actionPrimary.withValues(alpha: 0.15),
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
                              color: colors.actionSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isSpeaking
                                    ? 'GEMINI SPEAKING'
                                    : 'AUDIO RESPONSE',
                                style: TextStyle(
                                  color: colors.actionSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.volume_up,
                                color: colors.actionSecondary,
                                size: 20,
                              ),
                              tooltip: 'Voice response powered by Gemini Live',
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Voice is streamed in real-time by Gemini Live.',
                                    ),
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
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (_lastResponse?.displayText != null) ...[
                          Divider(color: colors.surface, height: 20),
                          ExcludeSemantics(
                            child: Text(
                              _lastResponse!.displayText,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                        if (_lastResponse?.actionType != null) ...[
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: double.infinity,
                              minHeight: 48,
                            ),
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: colors.actionPrimary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMd,
                                  ),
                                ),
                              ),
                              onPressed: () =>
                                  _executeAction(_lastResponse!.actionType!),
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
                            colors.actionPrimary,
                            colors.actionSecondary.withValues(alpha: alpha),
                            Colors.transparent,
                          ],
                          stops: const [0.4, 0.8, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.actionPrimary.withValues(alpha: 0.6),
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
                          child: Semantics(
                            button: true,
                            label:
                                'Microphone orb. Double tap to start or pause continuous voice.',
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
                                      ? colors.actionPrimary
                                      : colors.textMuted,
                                  size: 32,
                                ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: colors.statusSuccess.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                          border: Border.all(
                            color: colors.statusSuccess.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mic,
                              size: 13,
                              color: colors.statusSuccess,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Continuous Mic Active',
                              style: TextStyle(
                                color: colors.statusSuccess,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_isPermissionBlocked) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colors.statusError.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                          border: Border.all(
                            color: colors.statusError,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.mic_off,
                                  color: colors.statusError,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Microphone Permission Blocked',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Microphone access is blocked. Allow microphone access in your browser or device settings, then tap Try Again.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: 48,
                                minWidth: 48,
                              ),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.actionPrimary,
                                  foregroundColor: colors.onActionPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSm,
                                    ),
                                  ),
                                ),
                                onPressed: () {
                                  _startMicrophoneListening(
                                    playChimeTone: true,
                                  );
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text(
                                  'Try Again',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      if (_isVoiceTranscript)
                        // Voice transcript marker: a real icon instead of the
                        // 🗣️ emoji, so the marker renders identically at every
                        // text scale. The quote marks stay around the text.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.record_voice_over,
                                size: 16,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _liveTranscription,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          _liveTranscription,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
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
                        style: TextStyle(color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Or type your question...',
                          hintStyle: TextStyle(color: colors.textSecondary),
                          filled: true,
                          fillColor: colors.surfaceSubtle,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: colors.surface),
                          ),
                        ),
                        onSubmitted: (val) {
                          _audioEngine.unlockAudio();
                          _handleVoiceInput(val, isUserTap: true);
                          _textController.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: colors.actionPrimary,
                        padding: const EdgeInsets.all(14),
                      ),
                      icon: Icon(Icons.send, color: colors.onActionPrimary),
                      onPressed: () {
                        _audioEngine.unlockAudio();
                        _handleVoiceInput(
                          _textController.text,
                          isUserTap: true,
                        );
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
    final colors = AppTheme.colors(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      // 48dp tap-target floor (the default ActionChip renders ~32dp).
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: AppSpacing.minTouchTarget,
          minHeight: AppSpacing.minTouchTarget,
        ),
        child: ActionChip(
          backgroundColor: colors.surfaceSubtle,
          side: BorderSide(color: colors.surface),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          avatar: Icon(Icons.mic, color: colors.actionSecondary, size: 16),
          label: Text(
            prompt,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () {
            _audioEngine.unlockAudio();
            _audioEngine.playChime(isListening: false);
            _handleVoiceInput(prompt, isUserTap: true);
          },
        ),
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
      case 'customize_home':
        return 'Customize Home Screen';
      case 'reset_home':
        return 'Reset Home Screen Layout';
      default:
        return 'Execute Action';
    }
  }
}

/// Gemini Live setup dialog (API key, voice, model).
///
/// Owns its [TextEditingController] and disposes it when this State is
/// disposed — i.e. when the dialog route actually leaves the tree. The
/// previous function-based dialog disposed the controller via
/// `showDialog(...).then(...)`, which fires the moment the pop begins while
/// the dialog is still animating out; a rebuild in that window (the settings
/// notifications fired on save) rebuilt the still-mounted TextField against
/// the disposed controller, cascading into the framework's
/// `_dependents.isEmpty` teardown assert.
class _GeminiSetupDialog extends StatefulWidget {
  const _GeminiSetupDialog({required this.onSaved});

  final void Function(String newKey) onSaved;

  @override
  State<_GeminiSetupDialog> createState() => _GeminiSetupDialogState();
}

class _GeminiSetupDialogState extends State<_GeminiSetupDialog> {
  static const List<Map<String, String>> _modelOptions = [
    {
      'id': 'models/gemini-3.8-live',
      'label': 'Gemini 3.8 Live (Official Live Audio - Recommended)',
    },
    {
      'id': 'models/gemini-3.8-live-extended-thinking',
      'label': 'Gemini 3.8 Live Extended Thinking (Complex Reasoning)',
    },
    {'id': 'models/gemini-2.5-flash', 'label': 'Gemini 2.5 Flash'},
  ];

  static const List<Map<String, String>> _voiceOptions = [
    {'id': 'Aoede', 'label': 'Aoede (Natural & Conversational - Recommended)'},
    {'id': 'Kore', 'label': 'Kore (Clear & Confident)'},
    {'id': 'Charon', 'label': 'Charon (Calm & Professional)'},
    {'id': 'Puck', 'label': 'Puck (Upbeat & Energetic)'},
    {'id': 'Fenrir', 'label': 'Fenrir (Passionate & Deep)'},
  ];

  static String _initialSelection(
    List<Map<String, String>> options,
    String current,
    String fallback,
  ) {
    return options.any((opt) => opt['id'] == current) ? current : fallback;
  }

  late final TextEditingController _textCtrl = TextEditingController(
    text: AppSettingsController.instance.geminiApiKey,
  );
  late String _selectedModel = _initialSelection(
    _modelOptions,
    AppSettingsController.instance.geminiModel,
    'models/gemini-3.8-live',
  );
  late String _selectedVoice = _initialSelection(
    _voiceOptions,
    AppSettingsController.instance.geminiVoice,
    'Aoede',
  );

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return AlertDialog(
      backgroundColor: colors.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: colors.actionSecondary, size: 24),
          const SizedBox(width: 10),
          Text(
            'Gemini Multimodal Live Setup',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connected to Google AI Studio Gemini Multimodal Live API (https://aistudio.google.com/live-api) for low-latency bidirectional voice and audio streaming.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Official Live Voice:',
              style: TextStyle(
                color: colors.actionSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: colors.actionSecondary.withValues(alpha: 0.4),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedVoice,
                  isExpanded: true,
                  dropdownColor: colors.surface,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: colors.actionSecondary,
                  ),
                  items: _voiceOptions.map((opt) {
                    return DropdownMenuItem<String>(
                      value: opt['id'],
                      child: Text(opt['label']!),
                    );
                  }).toList(),
                  onChanged: (newVal) {
                    if (newVal != null) {
                      setState(() {
                        _selectedVoice = newVal;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Live Model:',
              style: TextStyle(
                color: colors.actionSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: colors.actionSecondary.withValues(alpha: 0.4),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedModel,
                  isExpanded: true,
                  dropdownColor: colors.surface,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: colors.actionSecondary,
                  ),
                  items: _modelOptions.map((opt) {
                    return DropdownMenuItem<String>(
                      value: opt['id'],
                      child: Text(opt['label']!),
                    );
                  }).toList(),
                  onChanged: (newVal) {
                    if (newVal != null) {
                      setState(() {
                        _selectedModel = newVal;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textCtrl,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Google AI Studio API Key',
                labelStyle: TextStyle(color: colors.actionSecondary),
                hintText: 'Paste key from AI Studio',
                hintStyle: TextStyle(color: colors.textSecondary),
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
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
              Navigator.pop(context);
              widget.onSaved('');
            },
            child: Text(
              'Clear Key',
              style: TextStyle(color: colors.statusError),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            final newKey = _textCtrl.text
                .replaceAll(RegExp(r'''['"\s]'''), '')
                .trim();
            AppSettingsController.instance.updateGeminiModel(_selectedModel);
            AppSettingsController.instance.updateGeminiVoice(_selectedVoice);
            AppSettingsController.instance.updateGeminiApiKey(newKey);
            Navigator.pop(context);
            widget.onSaved(newKey);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.actionPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          ),
          child: Text(
            'Save & Connect',
            style: TextStyle(
              color: colors.onActionPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
