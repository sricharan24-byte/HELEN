import 'dart:async';
import 'package:flutter/material.dart';

import '../ai_assistant/gemini_live_screen.dart';
import '../../data/repositories/transport_repository.dart';
import '../tickets/ticket_controller.dart';

import '../../core/settings/app_settings_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_semantic_colors.dart';

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
  bool get _voiceConfirmations => _settings.voiceConfirmations;

  void _showLanguagePicker() {
    final colors = AppTheme.colors(context);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
    final colors = AppTheme.colors(context);
    final textCtrl = TextEditingController(text: _settings.geminiApiKey);
    String selectedModel = _settings.geminiModel;
    String selectedVoice = _settings.geminiVoice;

    final modelOptions = const [
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
    if (!modelOptions.any((opt) => opt['id'] == selectedModel)) {
      selectedModel = 'models/gemini-3.8-live';
    }

    final voiceOptions = const [
      {
        'id': 'Aoede',
        'label': 'Aoede (Natural & Conversational - Recommended)',
      },
      {'id': 'Kore', 'label': 'Kore (Clear & Confident)'},
      {'id': 'Charon', 'label': 'Charon (Calm & Professional)'},
      {'id': 'Puck', 'label': 'Puck (Upbeat & Energetic)'},
      {'id': 'Fenrir', 'label': 'Fenrir (Passionate & Deep)'},
    ];
    if (!voiceOptions.any((opt) => opt['id'] == selectedVoice)) {
      selectedVoice = 'Aoede';
    }

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: colors.surfaceSubtle,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: colors.actionSecondary,
                  size: 24,
                ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.actionSecondary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedVoice,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.actionSecondary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedModel,
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
                    style: TextStyle(color: colors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Google AI Studio API Key',
                      labelStyle: TextStyle(color: colors.actionSecondary),
                      hintText: 'Paste key from AI Studio',
                      hintStyle: TextStyle(color: colors.textMuted),
                      filled: true,
                      fillColor: colors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (_settings.geminiApiKey.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _settings.updateGeminiApiKey('');
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    'Clear Key',
                    style: TextStyle(color: colors.statusError),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final newKey = textCtrl.text.trim();
                  _settings.updateGeminiModel(selectedModel);
                  _settings.updateGeminiVoice(selectedVoice);
                  _settings.updateGeminiApiKey(newKey);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.actionPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
          ),
        ),
      ).then((_) => textCtrl.dispose()),
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
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bus',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                Text(
                  'Buddy',
                  style: TextStyle(
                    color: colors.actionSecondary,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            Text(
              'Voice Assistant',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        // Brand voice badge: constant saturated purple keeps the
                        // white mic icon at passing contrast in every theme.
                        decoration: const BoxDecoration(
                          color: Color(0xFF7C3AED),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mic,
                          color: Colors.white,
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
                _buildLightCard(
                  colors: colors,
                  icon: Icons.graphic_eq,
                  title: 'Wake Phrase',
                  subtitle: 'Say "Hey BusBuddy"',
                  trailing: Switch(
                    value: _wakePhrase,
                    activeThumbColor: colors.onActionPrimary,
                    activeTrackColor: colors.statusSuccess,
                    onChanged: _settings.updateWakePhrase,
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

                // ── Light Card 5: Floating AI Assistant Bubble ───────────
                _buildLightCard(
                  colors: colors,
                  icon: Icons.bubble_chart_outlined,
                  title: 'Floating AI Assistant Bubble',
                  subtitle:
                      'Movable assistant bubble across all screens with mic & chat window',
                  trailing: Switch(
                    value: _settings.floatingAssistantEnabled,
                    activeThumbColor: colors.onActionPrimary,
                    activeTrackColor: colors.statusSuccess,
                    onChanged: _settings.updateFloatingAssistantEnabled,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Light Card 6: Gemini Live Voice Selection ────────────
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

                // ── Light Card 7: Google AI Studio Live API Key ──────────
                _buildLightCard(
                  colors: colors,
                  icon: Icons.vpn_key_outlined,
                  title: 'Gemini Live API',
                  subtitle: _settings.geminiApiKey.isEmpty
                      ? 'Tap to connect key from aistudio.google.com/live-api'
                      : 'Connected (${_settings.geminiModel.replaceAll('models/', '')}) • Live streaming active',
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
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _settings.geminiApiKey.isNotEmpty
                              ? '⚡ GEMINI LIVE'
                              : 'NOT CONNECTED',
                          style: TextStyle(
                            color: _settings.geminiApiKey.isNotEmpty
                                ? colors.statusSuccess
                                : colors.textSecondary,
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
                        borderRadius: BorderRadius.circular(16),
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
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Semantics(
                button: true,
                label: 'Ask BusBuddy. Test the voice assistant.',
                excludeSemantics: true,
                child: InkWell(
                  onTap: _openAskBusBuddy,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      // Brand CTA red kept constant: white text on #DC2626
                      // measures 4.83:1 (WCAG AA) in every theme.
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Ask BusBuddy',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Test the voice assistant.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
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
