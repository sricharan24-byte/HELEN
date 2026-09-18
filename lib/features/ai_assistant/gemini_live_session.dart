import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/settings/app_settings_controller.dart';
import 'gemini_live_transport.dart';

/// Client for the real Google AI Studio Gemini Multimodal Live API (BidiGenerateContent).
/// Endpoint: wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent
class GeminiLiveSession {
  GeminiLiveSession({
    this.onTextChunk,
    this.onAudioPcmChunk,
    this.onTurnComplete,
    this.onAction,
    this.onError,
    this.onStatusChanged,
    this.onInterrupted,
  });

  final void Function(String text)? onTextChunk;
  final void Function(String pcmBase64)? onAudioPcmChunk;
  final void Function(String fullText, String? actionType)? onTurnComplete;
  final void Function(String actionType, Map<String, dynamic>? args)? onAction;
  final void Function(String error)? onError;
  final void Function(String status, bool isConnected)? onStatusChanged;
  final VoidCallback? onInterrupted;

  GeminiLiveTransport? _transport;
  bool _isConnected = false;
  bool _isSetupDone = false;
  Completer<void>? _setupCompleter;
  String _currentTurnText = '';
  String? _currentTurnAction;

  bool get isConnected => _isConnected && (_transport?.isConnected ?? false);

  String get effectiveApiKey => AppSettingsController.instance.geminiApiKey;
  String get effectiveModel => AppSettingsController.instance.geminiModel;
  String get effectiveVoice => AppSettingsController.instance.geminiVoice.isNotEmpty
      ? AppSettingsController.instance.geminiVoice
      : 'Aoede';

  static const String naturalTransitInstruction = '''You are BusBuddy, a warm, natural, human transit assistant for bus passengers in Vellore, India (VIT Main Gate to Katpadi Railway Station corridor).

CRITICAL CONVERSATIONAL RULES:
1. Speak in a warm, relaxed, human tone like a friendly local transit companion.
2. NEVER mention or say aloud technical function, tool, or code names (NEVER say "track_bus", "book_ticket", "search_route", "emergency_sos", "open_saved", "function_call", "toolResponse", or "executing").
3. When triggering or confirming an action, phrase your response in natural, conversational English (e.g., "I've pulled up the live bus tracker for you!", "Here is the ticket booking screen.", "Let me check the buses to Katpadi for you.").
4. Keep spoken responses concise and natural (1 to 2 sentences). Do NOT output markdown, bullet points, asterisks, or system logs.
5. Key transit facts: General bus fare is ₹20. Student and senior citizen concession fare is ₹12 (40% discount). Main stops: VIT Main Gate, Green Circle, New Bus Stand, Katpadi Railway Station. Frequent buses: Bus 18B, Bus 12A.''';

  static String _resolveLiveModel(String requested) {
    var model = requested.trim();
    if (model.isEmpty) {
      return 'models/gemini-3.8-live';
    }
    if (!model.startsWith('models/')) {
      model = 'models/$model';
    }
    // Google AI Studio Live API (BidiGenerateContent) currently supports:
    // - models/gemini-3.8-live (primary official low-latency Live API model)
    // - models/gemini-3.8-live-extended-thinking (reasoning Live model)
    // - models/gemini-2.5-flash
    // Redirect deprecated 2.0-flash-exp and rejected preview model strings:
    if (model.contains('2.0-flash-exp') ||
        model.contains('gemini-2.5-flash-preview-native-audio-dialog') ||
        model.contains('gemini-2.5-flash-native-audio-preview')) {
      return 'models/gemini-3.8-live';
    }
    return model;
  }

  /// Connects to Google AI Studio's Gemini Live API WebSocket endpoint.
  void connect({String? customApiKey}) {
    final apiKey = (customApiKey ?? effectiveApiKey).trim();
    if (apiKey.isEmpty) {
      onStatusChanged?.call('API Key Needed', false);
      return;
    }

    disconnect();

    _setupCompleter = Completer<void>();
    // Prevent unhandled zone error if closed before sendQuery awaits it
    _setupCompleter!.future.catchError((_) {});

    final modelToUse = _resolveLiveModel(effectiveModel);
    onStatusChanged?.call('Connecting to Gemini Live...', false);

    final url =
        'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=$apiKey';

    _transport = createGeminiLiveTransport();

    _transport!.connect(
      url,
      onOpen: () {
        debugPrint('[GeminiLive] Connected to AI Studio Live WebSocket ($modelToUse, voice: $effectiveVoice)');
        _isConnected = true;
        _isSetupDone = false;
        onStatusChanged?.call('Live Connected', true);
        _sendSetupHandshake();
      },
      onMessage: (message) {
        _handleServerMessage(message);
      },
      onError: (err) {
        debugPrint('[GeminiLive] WebSocket error: $err');
        _isConnected = false;
        _isSetupDone = false;
        if (_setupCompleter != null && !_setupCompleter!.isCompleted) {
          _setupCompleter!.completeError(err);
        }
        onStatusChanged?.call('Connection Error', false);
        onError?.call('WebSocket error: $err');
      },
      onClose: (code, reason) {
        debugPrint('[GeminiLive] WebSocket closed: code=$code, reason=$reason');
        _isConnected = false;
        _isSetupDone = false;
        if (_setupCompleter != null && !_setupCompleter!.isCompleted) {
          _setupCompleter!.completeError('Closed: $code $reason');
        }
        onStatusChanged?.call('Disconnected', false);
      },
    );
  }

  void disconnect() {
    _isConnected = false;
    _isSetupDone = false;
    if (_setupCompleter != null && !_setupCompleter!.isCompleted) {
      _setupCompleter!.completeError('Disconnected');
    }
    _setupCompleter = null;
    _transport?.close();
    _transport = null;
  }

  /// Sends the required BidiGenerateContentSetup JSON payload upon connecting.
  void _sendSetupHandshake() {
    final modelToUse = _resolveLiveModel(effectiveModel);
    final voiceToUse = effectiveVoice;
    final setup = {
      'setup': {
        'model': modelToUse,
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': voiceToUse,
              }
            }
          }
        },
        'systemInstruction': {
          'parts': [
            {
              'text': naturalTransitInstruction,
            }
          ]
        },
        'tools': [
          {
            'functionDeclarations': [
              {
                'name': 'track_bus',
                'description': 'Opens the live GPS map tracker for the active bus route.'
              },
              {
                'name': 'book_ticket',
                'description': 'Opens ticket booking and payment checkout flow.'
              },
              {
                'name': 'search_route',
                'description': 'Finds available buses and shows route options between origin and destination.'
              },
              {
                'name': 'emergency_sos',
                'description': 'Triggers emergency safety broadcast and shares live location.'
              },
              {
                'name': 'open_saved',
                'description': 'Opens saved places like Home, College, or Hostel.'
              }
            ]
          }
        ]
      }
    };

    _transport?.send(jsonEncode(setup));
    // NOTE: Handshake sent; wait for server setupComplete before setting _isSetupDone
    debugPrint('[GeminiLive] Setup handshake frame sent for $modelToUse with voice $voiceToUse');
  }

  /// Streams a user query to the Gemini Multimodal Live API.
  Future<void> sendQuery(String query) async {
    _currentTurnText = '';
    _currentTurnAction = null;

    // If connected but setupComplete hasn't arrived yet, wait up to 3 seconds for handshake
    if (isConnected && !_isSetupDone && _setupCompleter != null) {
      debugPrint('[GeminiLive] Awaiting setupComplete before transmitting query...');
      try {
        await _setupCompleter!.future.timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('[GeminiLive] Setup wait timed out or failed: $e');
      }
    }

    if (isConnected && _isSetupDone) {
      final message = {
        'clientContent': {
          'turns': [
            {
              'role': 'user',
              'parts': [
                {'text': query}
              ]
            }
          ],
          'turnComplete': true
        }
      };

      _transport?.send(jsonEncode(message));
      debugPrint('[GeminiLive] Sent client turn: "$query"');
    } else {
      // Fall back to real Google AI Studio Gemini 2.5 Flash REST API
      debugPrint('[GeminiLive] Live session not ready (_isConnected=$_isConnected, _isSetupDone=$_isSetupDone); falling back to REST');
      await _sendRestQuery(query);
    }
  }

  void _handleServerMessage(String raw) {
    try {
      final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;

      // 0. Check for setupComplete
      if (data.containsKey('setupComplete')) {
        _isSetupDone = true;
        if (_setupCompleter != null && !_setupCompleter!.isCompleted) {
          _setupCompleter!.complete();
        }
        debugPrint('[GeminiLive] setupComplete received: session ready');
        onStatusChanged?.call('Live Ready', true);
        return;
      }

      // 1. Check for serverContent
      if (data.containsKey('serverContent')) {
        final serverContent = data['serverContent'] as Map<String, dynamic>;

        // Interrupted by user speaking
        if (serverContent['interrupted'] == true) {
          debugPrint('[GeminiLive] Model audio playback interrupted by user');
          onInterrupted?.call();
        }

        // Output transcription (text stream of spoken response)
        final trans = serverContent['outputTranscription'] ?? serverContent['outputAudioTranscription'];
        if (trans != null) {
          if (trans is Map<String, dynamic> && trans.containsKey('text')) {
            final text = trans['text'] as String;
            _currentTurnText += text;
            onTextChunk?.call(text);
          } else if (trans is String) {
            _currentTurnText += trans;
            onTextChunk?.call(trans);
          }
        }

        // Model turn parts (text / audio)
        if (serverContent.containsKey('modelTurn')) {
          final modelTurn = serverContent['modelTurn'] as Map<String, dynamic>;
          final parts = modelTurn['parts'] as List<dynamic>?;
          if (parts != null) {
            for (final part in parts) {
              if (part is Map<String, dynamic>) {
                // Text streaming
                if (part.containsKey('text')) {
                  final text = part['text'] as String;
                  _currentTurnText += text;
                  onTextChunk?.call(text);
                }
                // Audio streaming (24kHz PCM linear 16-bit)
                String? base64Pcm;
                if (part.containsKey('inlineData') && part['inlineData'] is Map) {
                  final inline = part['inlineData'] as Map<String, dynamic>;
                  base64Pcm = inline['data']?.toString();
                } else if (part.containsKey('data') && part['data'] is String) {
                  base64Pcm = part['data'] as String?;
                } else if (part.containsKey('audio') && part['audio'] is String) {
                  base64Pcm = part['audio'] as String?;
                }

                if (base64Pcm != null && base64Pcm.isNotEmpty) {
                  onAudioPcmChunk?.call(base64Pcm);
                }
              }
            }
          }
        }

        // Turn complete
        if (serverContent['turnComplete'] == true) {
          debugPrint('[GeminiLive] Turn complete: "$_currentTurnText"');
          onTurnComplete?.call(_currentTurnText, _currentTurnAction);
        }
      }

      // 2. Check for toolCall
      if (data.containsKey('toolCall')) {
        final toolCall = data['toolCall'] as Map<String, dynamic>;
        final functionCalls = toolCall['functionCalls'] as List<dynamic>?;
        if (functionCalls != null) {
          final functionResponses = <Map<String, dynamic>>[];
          for (final call in functionCalls) {
            if (call is Map<String, dynamic>) {
              final name = call['name'] as String;
              final callId = call['id']?.toString() ?? 'call_1';
              final args = call['args'] as Map<String, dynamic>?;
              _currentTurnAction = name;
              debugPrint('[GeminiLive] Tool call received: $name (id: $callId)');
              onAction?.call(name, args);

              Map<String, dynamic> outputContext;
              switch (name) {
                case 'track_bus':
                  outputContext = {
                    'status': 'success',
                    'result': 'Live GPS bus map tracker is now open on the passenger\'s screen.',
                  };
                  break;
                case 'book_ticket':
                  outputContext = {
                    'status': 'success',
                    'result': 'Ticket booking and payment checkout is now open on the screen.',
                  };
                  break;
                case 'search_route':
                  outputContext = {
                    'status': 'success',
                    'result': 'Available buses and route timetable between VIT Main Gate and Katpadi are displayed on the screen.',
                  };
                  break;
                case 'emergency_sos':
                  outputContext = {
                    'status': 'success',
                    'result': 'Emergency SOS broadcast activated and live location shared with emergency contacts.',
                  };
                  break;
                case 'open_saved':
                  outputContext = {
                    'status': 'success',
                    'result': 'Saved places and favorite routes are open on the passenger\'s screen.',
                  };
                  break;
                default:
                  outputContext = {
                    'status': 'success',
                    'result': 'Action completed successfully on the passenger screen.',
                  };
              }

              functionResponses.add({
                'id': callId,
                'response': {
                  'output': outputContext,
                }
              });
            }
          }

          // Return toolResponse to Gemini server
          if (functionResponses.isNotEmpty && isConnected) {
            final toolResponse = {
              'toolResponse': {
                'functionResponses': functionResponses,
              }
            };
            _transport?.send(jsonEncode(toolResponse));
            debugPrint('[GeminiLive] Sent toolResponse frame');
          }
        }
      }

      // 3. Error
      if (data.containsKey('error')) {
        final errObj = data['error'];
        final msg = errObj is Map ? (errObj['message']?.toString() ?? 'Server error') : errObj.toString();
        debugPrint('[GeminiLive] Server error: $msg');
        onError?.call(msg);
      }
    } catch (e) {
      debugPrint('[GeminiLive] Message parse error: $e');
    }
  }

  /// REST fallback to Google AI Studio Gemini 2.5 Flash endpoint
  Future<void> _sendRestQuery(String query) async {
    final apiKey = effectiveApiKey.trim();
    if (apiKey.isEmpty) {
      onError?.call('Please set your Google AI Studio API key (from https://aistudio.google.com/live-api)');
      return;
    }

    try {
      const restModel = 'gemini-2.5-flash';
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$restModel:generateContent?key=$apiKey',
      );

      final payload = {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': query}
            ]
          }
        ],
        'systemInstruction': {
          'parts': [
            {
              'text': naturalTransitInstruction,
            }
          ]
        },
        'tools': [
          {
            'functionDeclarations': [
              {
                'name': 'track_bus',
                'description': 'Opens the live GPS map tracker for the active bus.'
              },
              {
                'name': 'book_ticket',
                'description': 'Opens ticket booking and checkout.'
              },
              {
                'name': 'search_route',
                'description': 'Searches for available buses on the corridor.'
              },
              {
                'name': 'emergency_sos',
                'description': 'Triggers emergency safety location broadcast.'
              },
              {
                'name': 'open_saved',
                'description': 'Opens saved places.'
              }
            ]
          }
        ]
      };

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final first = candidates.first as Map<String, dynamic>;
          final content = first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;

          String responseText = '';
          String? actionName;

          if (parts != null) {
            for (final part in parts) {
              if (part is Map<String, dynamic>) {
                if (part.containsKey('text')) {
                  responseText += part['text'] as String;
                }
                if (part.containsKey('functionCall')) {
                  final fn = part['functionCall'] as Map<String, dynamic>;
                  actionName = fn['name'] as String?;
                  if (actionName != null) {
                    onAction?.call(actionName, fn['args'] as Map<String, dynamic>?);
                  }
                }
              }
            }
          }

          if (actionName != null) {
            final trimmed = responseText.trim();
            if (trimmed.isEmpty ||
                trimmed.toLowerCase().contains('executing') ||
                trimmed.toLowerCase().contains(actionName.toLowerCase())) {
              switch (actionName) {
                case 'track_bus':
                  responseText = 'I\'ve opened the live bus tracker for you.';
                  break;
                case 'book_ticket':
                  responseText = 'Opening ticket booking for you now.';
                  break;
                case 'search_route':
                  responseText = 'Here are the available buses for your route.';
                  break;
                case 'emergency_sos':
                  responseText = 'Emergency safety broadcast has been activated.';
                  break;
                case 'open_saved':
                  responseText = 'Here are your saved places and routes.';
                  break;
                default:
                  responseText = 'Sure, right away.';
              }
            }
          }

          onTextChunk?.call(responseText);
          onTurnComplete?.call(responseText, actionName);
        }
      } else {
        onError?.call('Gemini API error (${res.statusCode}): ${res.body}');
      }
    } catch (e) {
      debugPrint('[GeminiLive] REST fallback error: $e');
      onError?.call('Could not connect to Gemini API: $e');
    }
  }
}
