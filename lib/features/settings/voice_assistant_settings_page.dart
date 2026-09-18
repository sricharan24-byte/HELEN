import 'package:flutter/material.dart';

import '../ai_assistant/ai_assistant_dialog.dart';
import '../ai_assistant/gemini_live_screen.dart';
import '../../data/repositories/transport_repository.dart';
import '../tickets/ticket_controller.dart';

import '../../core/settings/app_settings_controller.dart';

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
  State<VoiceAssistantSettingsPage> createState() => _VoiceAssistantSettingsPageState();
}

class _VoiceAssistantSettingsPageState extends State<VoiceAssistantSettingsPage> {
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
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
              const Text(
                'Preferred Language',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ...['English', 'Tamil', 'Hindi', 'Telugu'].map((lang) {
                final isSelected = _language == lang;
                return ListTile(
                  title: Text(
                    lang,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF38BDF8)) : null,
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
    );
  }

  void _showVoiceSpeedPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
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
              const Text(
                'Voice Speed',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
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
                      color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF38BDF8)) : null,
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
    );
  }

  void _showVoicePicker() {
    final voices = const [
      {'id': 'Aoede', 'name': 'Aoede', 'desc': 'Natural, breezy & conversational (Recommended)'},
      {'id': 'Kore', 'name': 'Kore', 'desc': 'Clear, firm & articulate'},
      {'id': 'Charon', 'name': 'Charon', 'desc': 'Calm, steady & professional'},
      {'id': 'Puck', 'name': 'Puck', 'desc': 'Upbeat, friendly & energetic'},
      {'id': 'Fenrir', 'name': 'Fenrir', 'desc': 'Passionate, deep & expressive'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
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
              const Text(
                'Gemini Live Voice',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select the official Google Multimodal Live voice for natural spoken audio responses.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...voices.map((v) {
                final isSelected = _settings.geminiVoice == v['id'];
                return ListTile(
                  title: Text(
                    v['name']!,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    v['desc']!,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF7DD3FC) : const Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF38BDF8)) : null,
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
    );
  }

  void _showApiKeyDialog() {
    final textCtrl = TextEditingController(text: _settings.geminiApiKey);
    String selectedModel = _settings.geminiModel;
    String selectedVoice = _settings.geminiVoice;

    final modelOptions = const [
      {'id': 'models/gemini-3.8-live', 'label': 'Gemini 3.8 Live (Official Live Audio - Recommended)'},
      {'id': 'models/gemini-3.8-live-extended-thinking', 'label': 'Gemini 3.8 Live Extended Thinking (Complex Reasoning)'},
      {'id': 'models/gemini-2.5-flash', 'label': 'Gemini 2.5 Flash'},
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
                'Gemini Live API Setup',
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
                  'Connected to Google AI Studio Gemini Multimodal Live API (https://aistudio.google.com/live-api) for low-latency bidirectional voice interaction.',
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
                    hintStyle: const TextStyle(color: Color(0xFF475569)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                child: const Text('Clear Key', style: TextStyle(color: Color(0xFFEF4444))),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
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
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    ).then((_) => textCtrl.dispose());
  }

  void _openAskBusBuddy() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GeminiLiveScreen(
          repository: widget.repository,
          ticketController: widget.ticketController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B101D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B101D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('Bus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                Text('Buddy', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 20)),
              ],
            ),
            const Text(
              'Voice Assistant',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
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
                    color: const Color(0xFF111C33),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFF7C3AED),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mic, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Voice Assistant',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Set up how you interact with BusBuddy using voice.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
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
                  icon: Icons.language,
                  title: 'Preferred Language',
                  subtitle: 'Choose the assistant language',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_language, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: Color(0xFF2563EB), size: 20),
                    ],
                  ),
                  onTap: _showLanguagePicker,
                ),
                const SizedBox(height: 12),

                // ── Light Card 2: Voice Speed ────────────────────────────
                _buildLightCard(
                  icon: Icons.speed,
                  title: 'Voice Speed',
                  subtitle: 'Adjust how fast the assistant speaks',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_voiceSpeed, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: Color(0xFF2563EB), size: 20),
                    ],
                  ),
                  onTap: _showVoiceSpeedPicker,
                ),
                const SizedBox(height: 12),

                // ── Light Card 3: Wake Phrase ────────────────────────────
                _buildLightCard(
                  icon: Icons.graphic_eq,
                  title: 'Wake Phrase',
                  subtitle: 'Say "Hey BusBuddy"',
                  trailing: Switch(
                    value: _wakePhrase,
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF22C55E),
                    onChanged: (val) => _settings.updateWakePhrase(val),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Light Card 4: Voice Confirmations ────────────────────
                _buildLightCard(
                  icon: Icons.verified_user_outlined,
                  title: 'Voice Confirmations',
                  subtitle: 'Ask for confirmation before important actions (e.g. booking)',
                  trailing: Switch(
                    value: _voiceConfirmations,
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF22C55E),
                    onChanged: (val) => _settings.updateVoiceConfirmations(val),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Light Card 5: Floating AI Assistant Bubble ───────────
                _buildLightCard(
                  icon: Icons.bubble_chart_outlined,
                  title: 'Floating AI Assistant Bubble',
                  subtitle: 'Movable assistant bubble across all screens with mic & chat window',
                  trailing: Switch(
                    value: _settings.floatingAssistantEnabled,
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF22C55E),
                    onChanged: (val) => _settings.updateFloatingAssistantEnabled(val),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Light Card 6: Gemini Live Voice Selection ────────────
                _buildLightCard(
                  icon: Icons.record_voice_over_outlined,
                  title: 'Gemini Live Voice',
                  subtitle: 'Official Google voice: ${_settings.geminiVoice}',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_settings.geminiVoice, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: Color(0xFF2563EB), size: 20),
                    ],
                  ),
                  onTap: _showVoicePicker,
                ),
                const SizedBox(height: 12),

                // ── Light Card 7: Google AI Studio Live API Key ──────────
                _buildLightCard(
                  icon: Icons.vpn_key_outlined,
                  title: 'Gemini Live API',
                  subtitle: _settings.geminiApiKey.isEmpty
                      ? 'Tap to connect key from aistudio.google.com/live-api'
                      : 'Connected (${_settings.geminiModel.replaceAll('models/', '')}) • Live streaming active',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _settings.geminiApiKey.isNotEmpty
                              ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _settings.geminiApiKey.isNotEmpty ? '⚡ GEMINI LIVE' : 'NOT CONNECTED',
                          style: TextStyle(
                            color: _settings.geminiApiKey.isNotEmpty
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: Color(0xFF2563EB), size: 20),
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
                      side: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GeminiLiveScreen(
                            ticketController: widget.ticketController,
                            repository: widget.repository,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome, color: Color(0xFF007AFF)),
                    label: const Text(
                      'Launch Gemini Live Voice Interface',
                      style: TextStyle(
                        color: Color(0xFF007AFF),
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
                    color: const Color(0xFF111C33),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.info, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Example',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                            SizedBox(height: 8),
                            Text('"Find a bus to Katpadi"', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5)),
                            Text('"Show my current ticket"', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5)),
                            Text('"What\'s my next stop?"', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5)),
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
                child: InkWell(
                  onTap: _openAskBusBuddy,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
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
                          child: const Icon(Icons.mic, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Ask BusBuddy',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Test the voice assistant.',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
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
            color: const Color(0xFFEBF3FF), // Light blue-tinted card background
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF0F172A), size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w500),
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
