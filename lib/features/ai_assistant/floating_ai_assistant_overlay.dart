import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/settings/app_settings_controller.dart';
import '../../data/repositories/transport_repository.dart';
import '../journey/journey_controller.dart';
import '../tickets/ticket_controller.dart';
import 'floating_assistant_controller.dart';
import 'floating_chat_message.dart';

/// Global overlay widget providing a movable floating BusBuddy AI bubble and
/// an interactive compact chat/voice window accessible across all app screens.
class FloatingAiAssistantOverlay extends StatefulWidget {
  const FloatingAiAssistantOverlay({
    super.key,
    required this.navigatorKey,
    this.ticketController,
    this.repository,
    this.journeyController,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final TicketController? ticketController;
  final TransportRepository? repository;
  final JourneyController? journeyController;

  @override
  State<FloatingAiAssistantOverlay> createState() => _FloatingAiAssistantOverlayState();
}

class _FloatingAiAssistantOverlayState extends State<FloatingAiAssistantOverlay>
    with SingleTickerProviderStateMixin {
  late final FloatingAssistantController _controller;
  late final AnimationController _pulseAnimation;
  final TextEditingController _textInputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Offset _dragStartPos = Offset.zero;
  double _dragDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = FloatingAssistantController.instance;
    _controller.initialize(
      ticketCtrl: widget.ticketController,
      repo: widget.repository,
      journeyCtrl: widget.journeyController,
    );

    _pulseAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseAnimation.dispose();
    _textInputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int _lastRenderedMessageCount = 0;

  void _scrollToBottomIfNeeded(int currentCount) {
    if (currentCount > _lastRenderedMessageCount) {
      _lastRenderedMessageCount = currentCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsController.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([_controller, settings]),
      builder: (context, _) {
        // If disabled in settings or full screen Gemini Live is active, hide
        if (!settings.floatingAssistantEnabled || _controller.isFullScreenActive) {
          return const SizedBox.shrink();
        }

        final media = MediaQuery.of(context);
        final size = media.size;
        final padding = media.padding;

        // Ensure bubble remains fully within viewport boundaries during resize or orientation changes
        if (!_controller.hasCustomPosition) {
          _controller.resetPosition(size, padding);
        } else {
          _controller.clampToScreen(size, padding);
        }

        return Stack(
          children: [
            // ── The Floating Window (when open) ──────────────────────────────
            if (_controller.isWindowOpen) ...[
              // Barrier: Tap outside to minimize back to bubble
              Positioned.fill(
                child: GestureDetector(
                  onTap: _controller.closeWindow,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
              ),

              // The Compact Floating Chat & Mic Window Card
              _buildMiniWindow(size, padding),
            ],

            // ── The Draggable Floating Mascot Bubble (when closed) ───────────
            if (!_controller.isWindowOpen)
              _buildDraggableBubble(size, padding),
          ],
        );
      },
    );
  }

  // ── Floating Draggable Mascot Bubble ───────────────────────────────────────
  Widget _buildDraggableBubble(Size screenSize, EdgeInsets safeArea) {
    const double bubbleSize = 64.0;

    return Positioned(
      left: _controller.position.dx,
      top: _controller.position.dy,
      child: GestureDetector(
        onPanStart: (details) {
          _dragStartPos = details.globalPosition;
          _dragDistance = 0.0;
        },
        onPanUpdate: (details) {
          _dragDistance += (details.delta.dx.abs() + details.delta.dy.abs());
          final newPos = _controller.position + details.delta;
          _controller.updatePosition(newPos, screenSize, safeArea);
        },
        onPanEnd: (details) {
          if (_dragDistance < 8.0) {
            _controller.openWindow();
          }
        },
        onTap: () {
          _controller.openWindow();
        },
        child: Semantics(
          button: true,
          label: 'BusBuddy AI assistant. Tap to chat and voice search. Drag to move.',
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final isSpeaking = _controller.isSpeaking;
              final isListening = _controller.isListening;
              final pulseVal = _pulseAnimation.value;

              final glowAlpha = isSpeaking
                  ? 0.7 + (pulseVal * 0.3)
                  : isListening
                      ? 0.6 + (pulseVal * 0.4)
                      : 0.3 + (pulseVal * 0.25);

              final glowSpread = (isSpeaking || isListening) ? 6.0 + (pulseVal * 4.0) : 2.0;

              return Container(
                width: bubbleSize,
                height: bubbleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isListening
                        ? const [Color(0xFF059669), Color(0xFF10B981)]
                        : isSpeaking
                            ? const [Color(0xFF2563EB), Color(0xFF06B6D4)]
                            : const [Color(0xFF007AFF), Color(0xFF38BDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isListening
                          ? const Color(0xFF10B981).withValues(alpha: glowAlpha)
                          : const Color(0xFF007AFF).withValues(alpha: glowAlpha),
                      blurRadius: 18.0,
                      spreadRadius: glowSpread,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8.0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 2.2,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Dynamic Center Icon
                    Icon(
                      isListening
                          ? Icons.mic
                          : isSpeaking
                              ? Icons.graphic_eq
                              : _controller.isMuted
                                  ? Icons.volume_off
                                  : Icons.auto_awesome,
                      color: Colors.white,
                      size: 30,
                    ),

                    // Unread Notification Indicator
                    if (_controller.hasUnread)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),

                    // Mute Badge Indicator
                    if (_controller.isMuted)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 10),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── The Compact Floating Mini Window Card ──────────────────────────────────
  Widget _buildMiniWindow(Size screenSize, EdgeInsets safeArea) {
    final double windowWidth = min(390.0, screenSize.width - 32.0);
    final double windowHeight = min(540.0, screenSize.height * 0.72);
    final double left = ((screenSize.width - windowWidth) / 2).clamp(16.0, double.infinity);
    final double bottom = max(16.0, safeArea.bottom + 12.0);

    return Positioned(
      left: left,
      bottom: bottom,
      width: windowWidth,
      height: windowHeight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF007AFF).withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 32,
                spreadRadius: 4,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: const Color(0xFF007AFF).withValues(alpha: 0.18),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: [
                // 1. Header Bar
                _buildWindowHeader(),

                // 2. Chat History & Assistant Responses
                Expanded(
                  child: _buildChatFeed(),
                ),

                // 3. Mic & Voice Mute Control Center
                _buildVoiceControlBar(),

                // 4. Quick Suggestion Prompt Chips
                _buildPromptChips(),

                // 5. Text Input & Send
                _buildTextInputBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Mini Window Header ─────────────────────────────────────────────────────
  Widget _buildWindowHeader() {
    final isLiveKeySet = AppSettingsController.instance.geminiApiKey.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF111C33),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Mascot Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF007AFF), Color(0xFF38BDF8)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),

          // Title & Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'BusBuddy AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isLiveKeySet
                            ? const Color(0xFF16A34A).withValues(alpha: 0.2)
                            : const Color(0xFF007AFF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isLiveKeySet ? '⚡ Live 3.8' : '🔒 Local Engine',
                        style: TextStyle(
                          color: isLiveKeySet ? const Color(0xFF4ADE80) : const Color(0xFF38BDF8),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _controller.liveStatus,
                  style: TextStyle(
                    color: _controller.isListening
                        ? const Color(0xFF4ADE80)
                        : _controller.isSpeaking
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Mute / Unmute Voice Toggle Button
          Semantics(
            label: _controller.isMuted ? 'Unmute AI voice' : 'Mute AI voice',
            button: true,
            child: IconButton(
              icon: Icon(
                _controller.isMuted ? Icons.volume_off : Icons.volume_up,
                color: _controller.isMuted ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                size: 20,
              ),
              onPressed: _controller.toggleMute,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: 4),

          // Full Screen Expansion Button
          Semantics(
            label: 'Open Full Screen Live Assistant',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.open_in_full, color: Color(0xFF94A3B8), size: 18),
              onPressed: () {
                _controller.executeAction(context, 'full_screen', widget.navigatorKey);
              },
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: 4),

          // Minimize / Close Button
          Semantics(
            label: 'Minimize back to floating bubble',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              onPressed: _controller.closeWindow,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat Feed ──────────────────────────────────────────────────────────────
  Widget _buildChatFeed() {
    final msgs = _controller.messages;
    _scrollToBottomIfNeeded(msgs.length);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: msgs.length,
      itemBuilder: (context, index) {
        final msg = msgs[index];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildMessageBubble(FloatingChatMessage msg) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Color(0xFF007AFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF007AFF) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(color: const Color(0xFF334155).withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),

                  // Action Button (if generated by the AI response)
                  if (msg.actionType != null && msg.actionLabel != null) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        _controller.executeAction(context, msg.actionType!, widget.navigatorKey);
                      },
                      icon: const Icon(Icons.touch_app, size: 14),
                      label: Text(
                        msg.actionLabel!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Voice Control & Mute Orb Bar ───────────────────────────────────────────
  Widget _buildVoiceControlBar() {
    final isListening = _controller.isListening;
    final isSpeaking = _controller.isSpeaking;
    final isMuted = _controller.isMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF111C33),
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glowing Center Mic Orb
          GestureDetector(
            onTap: _controller.toggleListeningOrMute,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) {
                final scale = (isListening || isSpeaking)
                    ? 1.0 + (_pulseAnimation.value * 0.12)
                    : 1.0;

                final glowColor = isListening
                    ? const Color(0xFF10B981)
                    : isSpeaking
                        ? const Color(0xFF38BDF8)
                        : isMuted
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF007AFF);

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: glowColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: glowColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isListening
                              ? Icons.mic
                              : isSpeaking
                                  ? Icons.graphic_eq
                                  : isMuted
                                      ? Icons.mic_off
                                      : Icons.mic_none,
                          color: glowColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isListening
                              ? (_controller.isContinuousListening
                                  ? 'Continuous Mic (Tap to Mute)'
                                  : 'Listening (Tap to Mute)')
                              : isSpeaking
                                  ? 'Speaking (Tap to Silence)'
                                  : isMuted
                                      ? 'Muted (Tap to Speak)'
                                      : 'Tap to Speak',
                          style: TextStyle(
                            color: glowColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Prompt Chips ─────────────────────────────────────────────────────
  Widget _buildPromptChips() {
    const prompts = [
      'Where is my bus?',
      'Buses to Katpadi',
      'Book a ticket',
      'Student concession fare?',
      'Emergency SOS',
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final p = prompts[index];
          return ActionChip(
            backgroundColor: const Color(0xFF1E293B),
            side: const BorderSide(color: Color(0xFF334155)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            label: Text(
              p,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11.5),
            ),
            onPressed: () {
              _controller.sendQuery(p);
            },
          );
        },
      ),
    );
  }

  // ── Text Input Bar ─────────────────────────────────────────────────────────
  Widget _buildTextInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textInputController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ask BusBuddy anything...',
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
                ),
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  _controller.sendQuery(val);
                  _textInputController.clear();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              padding: const EdgeInsets.all(10),
              minimumSize: const Size(40, 40),
            ),
            icon: const Icon(Icons.send, color: Colors.white, size: 16),
            onPressed: () {
              final text = _textInputController.text;
              if (text.trim().isNotEmpty) {
                _controller.sendQuery(text);
                _textInputController.clear();
              }
            },
          ),
        ],
      ),
    );
  }
}
