import 'dart:async';
import 'package:flutter/material.dart';

import '../ai_assistant/audio_speech_engine.dart';
import '../ai_assistant/gemini_live_screen.dart';
import '../../data/repositories/transport_repository.dart';
import '../tickets/ticket_controller.dart';

import '../../core/a11y/announcement_coordinator.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_semantic_colors.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/widgets/bus_buddy_logo.dart';

/// Voice Assistant settings page matching BusBuddy UI design screenshot 3.
class VoiceAssistantSettingsPage extends StatefulWidget {
  const VoiceAssistantSettingsPage({
    super.key,
    this.repository,
    this.ticketController,
  });

  final TransportRepository? repository;
  final TicketController? ticketController;

  @override
  State<VoiceAssistantSettingsPage> createState() =>
      _VoiceAssistantSettingsPageState();
}

class _VoiceAssistantSettingsPageState
    extends State<VoiceAssistantSettingsPage> {
  final AppSettingsController _settings = AppSettingsController.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  String get _language => _settings.preferredLanguage;
  String get _voiceSpeed => _settings.voiceSpeed;
  bool get _wakePhrase => _settings.wakePhrase;

  /// Whether this platform can transcribe ambient microphone audio at all.
  /// Gates the Wake Phrase switch, which is otherwise inert here.
  bool get _canRecognizeSpeech => AudioSpeechEngine().canRecognizeSpeech;
  bool get _voiceConfirmations => _settings.voiceConfirmations;

  void _showLanguagePicker() {
    final colors = AppTheme.colors(context);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preferred Language',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                ...['English', 'Tamil', 'Hindi', 'Telugu'].map((lang) {
                  final isSelected = _language == lang;
                  return ListTile(
                    title: Text(
                      lang,
                      style: TextStyle(
                        color: isSelected
                            ? colors.actionSecondary
                            : colors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: colors.actionSecondary)
                        : null,
                    onTap: () {
                      _settings.updatePreferredLanguage(lang);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showVoiceSpeedPicker() {
    final colors = AppTheme.colors(context);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Speed',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                ...[
                  {'label': 'Slow', 'display': 'Slow (0.8x)'},
                  {'label': 'Normal', 'display': 'Normal (1.0x)'},
                  {'label': 'Fast', 'display': 'Fast (1.2x)'},
                ].map((item) {
                  final label = item['label']!;
                  final display = item['display']!;
                  final isSelected = _voiceSpeed == label;
                  return ListTile(
                    title: Text(
                      display,
                      style: TextStyle(
                        color: isSelected
                            ? colors.actionSecondary
                            : colors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: colors.actionSecondary)
                        : null,
                    onTap: () {
                      _settings.updateVoiceSpeed(label);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showVoicePicker() {
    final voices = const [
      {
        'id': 'Aoede',
        'name': 'Aoede',
        'desc': 'Natural, breezy & conversational (Recommended)',
      },
      {'id': 'Kore', 'name': 'Kore', 'desc': 'Clear, firm & articulate'},
      {'id': 'Charon', 'name': 'Charon', 'desc': 'Calm, steady & professional'},
      {'id': 'Puck', 'name': 'Puck', 'desc': 'Upbeat, friendly & energetic'},
      {
        'id': 'Fenrir',
        'name': 'Fenrir',
        'desc': 'Passionate, deep & expressive',
      },
    ];
    final colors = AppTheme.colors(context);

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gemini Live Voice',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select the official Google Multimodal Live voice for natural spoken audio responses.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ...voices.map((v) {
                  final isSelected = _settings.geminiVoice == v['id'];
                  return ListTile(
                    title: Text(
                      v['name']!,
                      style: TextStyle(
                        color: isSelected
                            ? colors.actionSecondary
                            : colors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      v['desc']!,
                      style: TextStyle(
                        color: isSelected
                            ? colors.actionSecondary
                            : colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: colors.actionSecondary,
                          )
                        : null,
                    onTap: () {
                      _settings.updateGeminiVoice(v['id']!);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showApiKeyDialog() {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const _GeminiLiveSetupDialog(),
      ),
    );
  }

  void _openAskBusBuddy() {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GeminiLiveScreen(
            repository: widget.repository,
            ticketController: widget.ticketController,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: colors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const BusBuddyLogo(
          fontSize: 20,
          subtitle: 'Voice Assistant',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                // ── Hero Header Card (Purple Circle) ────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        // One accent per app: the mic badge uses the same
                        // actionPrimary as every other action surface.
                        decoration: BoxDecoration(
                          color: colors.actionPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.mic,
                          color: colors.onActionPrimary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voice Assistant',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Set up how you interact with BusBuddy using voice.',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Light Card 1: Preferred Language ─────────────────────
                _buildLightCard(
                  colors: colors,
                  icon: Icons.language,
                  title: 'Preferred Language',
                  subtitle: 'Choose the assistant language',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _language,
                        style: TextStyle(
                          color: colors.actionPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: colors.actionPrimary,
                        size: 20,
                      ),
                    ],
                  ),
                  onTap: _showLanguagePicker,
                ),
                const SizedBox(height: 12),

                // ── Light Card 2: Voice Speed ────────────────────────────
                _buildLightCard(
                  colors: colors,
                  icon: Icons.speed,
                  title: 'Voice Speed',
                  subtitle: 'Adjust how fast the assistant speaks',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _voiceSpeed,
                        style: TextStyle(
                          color: colors.actionPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: colors.actionPrimary,
                        size: 20,
                      ),
                    ],
                  ),
                  onTap: _showVoiceSpeedPicker,
                ),
                const SizedBox(height: 12),

                // ── Light Card 3: Wake Phrase ────────────────────────────
                // Hidden where the platform cannot transcribe ambient audio:
                // the switch would flip a setting nothing reads, which is the
                // same lie as an inert accessibility switch. Android streams
                // its microphone to Gemini Live instead of transcribing locally
                // (AudioSpeechEngine.canRecognizeSpeech).
                if (_canRecognizeSpeech)
                  _buildLightCard(
                    colors: colors,
                    icon: Icons.graphic_eq,
                    title: 'Wake Phrase',
                    subtitle: 'Say "Hey BusBuddy"',
                    trailing: Switch(
                      value: _wakePhrase,
                      activeThumbColor: colors.onActionPrimary,
                      activeTrackColor: colors.statusSuccess,
                      onChanged: (val) {
                        _settings.updateWakePhrase(val);
                        AnnouncementCoordinator.instance.announce(
                          val
                              ? 'Wake phrase "Hey BusBuddy" enabled'
                              : 'Wake phrase disabled',
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),

                // ── Light Card 4: Voice Confirmations ────────────────────
                _buildLightCard(
                  colors: colors,
                  icon: Icons.verified_user_outlined,
                  title: 'Voice Confirmations',
                  subtitle:
                      'Ask for confirmation before important actions (e.g. booking)',
                  trailing: Switch(
                    value: _voiceConfirmations,
                    activeThumbColor: colors.onActionPrimary,
                    activeTrackColor: colors.statusSuccess,
                    onChanged: _settings.updateVoiceConfirmations,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Light Card 5: Gemini Live Voice Selection ────────────
                _buildLightCard(
                  colors: colors,
                  icon: Icons.record_voice_over_outlined,
                  title: 'Gemini Live Voice',
                  subtitle: 'Official Google voice: ${_settings.geminiVoice}',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _settings.geminiVoice,
                        style: TextStyle(
                          color: colors.actionPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: colors.actionPrimary,
                        size: 20,
                      ),
                    ],
                  ),
                  onTap: _showVoicePicker,
                ),
                const SizedBox(height: 12),

                // ── Light Card 6: Google AI Studio Live API Key ──────────
                _buildLightCard(
                  colors: colors,
                  icon: Icons.vpn_key_outlined,
                  title: 'Gemini Live API',
                  subtitle: _settings.geminiApiKey.isEmpty
                      ? 'Tap to connect key from aistudio.google.com/live-api'
                      : 'Key saved (${_settings.geminiModel.replaceAll('models/', '')}) • Ready for live voice',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _settings.geminiApiKey.isNotEmpty
                              ? colors.statusSuccessBg
                              : colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: _settings.geminiApiKey.isNotEmpty
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bolt,
                                    size: 16,
                                    color: colors.statusSuccess,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'GEMINI LIVE',
                                    style: TextStyle(
                                      color: colors.statusSuccess,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'NOT CONNECTED',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: colors.actionPrimary,
                        size: 20,
                      ),
                    ],
                  ),
                  onTap: _showApiKeyDialog,
                ),
                const SizedBox(height: 14),

                // Gemini Live Launch Action Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: colors.actionPrimary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    onPressed: () {
                      unawaited(
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => GeminiLiveScreen(
                              ticketController: widget.ticketController,
                              repository: widget.repository,
                            ),
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.auto_awesome, color: colors.actionPrimary),
                    label: Text(
                      'Launch Gemini Live Voice Interface',
                      style: TextStyle(
                        color: colors.actionPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Dark Blue Example Box ────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colors.actionPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info,
                          color: colors.onActionPrimary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Example',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '"Find a bus to Katpadi"',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            Text(
                              '"Show my current ticket"',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            Text(
                              '"What\'s my next stop?"',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Sticky Bottom Ask BusBuddy Action Bar ─────────────────────
            // Single actionPrimary accent (red is reserved for Emergency SOS).
            // minHeight instead of a fixed height so two-line content reflows
            // at 300% text scale instead of overflowing.
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Semantics(
                button: true,
                label: 'Ask BusBuddy. Test the voice assistant.',
                excludeSemantics: true,
                child: Material(
                  color: colors.actionPrimary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  child: InkWell(
                    onTap: _openAskBusBuddy,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.minTouchTarget,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colors.onActionPrimary.withValues(
                                alpha: 0.2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.mic,
                              color: colors.onActionPrimary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ask BusBuddy',
                                  style: TextStyle(
                                    color: colors.onActionPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Test the voice assistant.',
                                  style: TextStyle(
                                    color: colors.onActionPrimary
                                        .withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLightCard({
    required AppSemanticColors colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: colors.textPrimary, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Gemini Live setup dialog (API key, voice, model).
///
/// Owns its [TextEditingController] and disposes it when this State is
/// disposed — when the dialog route actually leaves the tree. The previous
/// function-based dialog disposed the controller via
/// `showDialog(...).then(...)`, which fires the moment the pop begins while
/// the dialog is still animating out; a rebuild in that window (the settings
/// notifications fired on save) rebuilt the still-mounted TextField against
/// the disposed controller, cascading into the framework's
/// `_dependents.isEmpty` teardown assert.
class _GeminiLiveSetupDialog extends StatefulWidget {
  const _GeminiLiveSetupDialog();

  @override
  State<_GeminiLiveSetupDialog> createState() => _GeminiLiveSetupDialogState();
}

class _GeminiLiveSetupDialogState extends State<_GeminiLiveSetupDialog> {
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
            'Gemini Live API Setup',
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
              'Connected to Google AI Studio Gemini Multimodal Live API (https://aistudio.google.com/live-api) for low-latency bidirectional voice interaction.',
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
                  icon: Icon(Icons.arrow_drop_down, color: colors.actionSecondary),
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
                  icon: Icon(Icons.arrow_drop_down, color: colors.actionSecondary),
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
                hintStyle: TextStyle(color: colors.textMuted),
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
            },
            child: Text(
              'Clear Key',
              style: TextStyle(color: colors.statusError),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: colors.textSecondary),
          ),
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
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.actionPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          ),
          child: Text(
            'Save Settings',
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
