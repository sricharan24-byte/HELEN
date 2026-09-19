import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../data/datasources/local_transport_data_source.dart';
import '../../data/models/ticket_model.dart';
import '../../data/repositories/ticket_repository.dart';
import '../../data/repositories/transport_repository.dart';
import '../safety/safety_sharing_page.dart';
import '../tickets/booking_page.dart';
import '../tickets/live_location_screen.dart';
import '../tickets/ticket_controller.dart';
import 'ai_assistant_service.dart';
import 'gemini_live_screen.dart';

class AiAssistantDialog extends StatefulWidget {
  const AiAssistantDialog({
    super.key,
    this.ticketController,
    this.repository,
  });

  final TicketController? ticketController;
  final TransportRepository? repository;

  @override
  State<AiAssistantDialog> createState() => _AiAssistantDialogState();
}

class _AiAssistantDialogState extends State<AiAssistantDialog> {
  final AiAssistantService _aiService = AiAssistantService();
  final TextEditingController _inputController = TextEditingController();
  final List<Map<String, String>> _chatMessages = [];

  late final TicketController _ticketController;
  late final TransportRepository _repository;

  bool _isListening = false;
  Ticket? get _activeTicket => _ticketController.activeTicket;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AppServiceLocator.instance.transportRepository;
    _ticketController = widget.ticketController ?? AppServiceLocator.instance.ticketController;
    _chatMessages.add({
      'sender': 'ai',
      'text': 'Hello! I am BusBuddy AI Assistant. Ask me about bus timings, live bus tracking, fares, or emergency sharing.',
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _sendQuery(String query) {
    if (query.trim().isEmpty) return;

    setState(() {
      _chatMessages.add({'sender': 'user', 'text': query});
      _inputController.clear();
      _isListening = false;
    });

    final response = _aiService.processQuery(query, activeTicket: _activeTicket);

    setState(() {
      _chatMessages.add({
        'sender': 'ai',
        'text': response.text,
        if (response.actionLabel != null) 'actionLabel': response.actionLabel!,
        if (response.actionType != null) 'actionType': response.actionType!,
      });
    });
  }

  void _handleAction(String actionType) {
    Navigator.of(context).pop(); // Close dialog first

    if (actionType == 'book_ticket') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookingPage(ticketController: _ticketController),
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
      }
    } else if (actionType == 'share_location') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SafetySharingPage(
            activeTicket: _activeTicket,
          ),
        ),
      );
    }
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
    });
    if (_isListening) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isListening) {
          _sendQuery('When is the next bus to Katpadi Railway Station?');
        }
      });
    }
  }

  void _openGeminiLiveScreen() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GeminiLiveScreen(
          ticketController: _ticketController,
          repository: _repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 560, maxWidth: 420),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF002B7F),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Talk to BusBuddy AI',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0A2540),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Voice & Natural Language Assistant',
                        style: textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Gemini Live Voice Mode',
                  icon: const Icon(Icons.auto_awesome, color: Color(0xFF007AFF)),
                  onPressed: _openGeminiLiveScreen,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Quick Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip('Next bus to Katpadi'),
                  const SizedBox(width: 8),
                  _buildChip('Student fare price'),
                  const SizedBox(width: 8),
                  _buildChip('Where is my bus?'),
                  const SizedBox(width: 8),
                  _buildChip('Share location'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Chat Messages Thread
            Expanded(
              child: ListView.builder(
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final msg = _chatMessages[index];
                  final isUser = msg['sender'] == 'user';
                  final actionLabel = msg['actionLabel'];
                  final actionType = msg['actionType'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xFF002B7F) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            msg['text']!,
                            style: textTheme.bodyMedium?.copyWith(
                              color: isUser ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (actionLabel != null && actionType != null) ...[
                          const SizedBox(height: 6),
                          ElevatedButton.icon(
                            onPressed: () => _handleAction(actionType),
                            icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                            label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF002B7F),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Input Row & Voice Mic Action
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    onSubmitted: _sendQuery,
                    decoration: InputDecoration(
                      hintText: _isListening ? 'Listening...' : 'Type or speak your question...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _sendQuery(_inputController.text),
                  icon: const Icon(Icons.send, color: Color(0xFF002B7F)),
                ),
                GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isListening ? const Color(0xFFE11D48) : const Color(0xFF002B7F),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isListening ? Icons.graphic_eq : Icons.mic,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: () => _sendQuery(label),
    );
  }
}
