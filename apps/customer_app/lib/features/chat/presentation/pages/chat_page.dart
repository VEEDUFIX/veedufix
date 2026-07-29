import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../providers/chat_providers.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    final auth = ref.read(authControllerProvider).valueOrNull;
    if (auth == null) return;

    ref.read(chatControllerProvider).sendMessage(
      bookingId: widget.bookingId,
      text: text,
      senderId: auth.user.id,
    );
    
    setState(() {
      _controller.clear();
      _isTyping = false;
    });
    
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));
    final workerName = bookingAsync.valueOrNull?.worker?.name ?? 'Professional';
    final workerInitial = workerName.isNotEmpty ? workerName[0].toUpperCase() : 'P';

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: TapScale(
            onTap: () => context.pop(),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  const Color(0xFFC2A15E).withValues(alpha: 0.15),
              child: Text(
                workerInitial,
                style: tt.titleMedium?.copyWith(
                  color: const Color(0xFFC2A15E),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(workerName,
                    style: tt.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text('Online · Arriving soon',
                    style: tt.labelSmall
                        ?.copyWith(color: const Color(0xFF10B981))),
              ],
            ),
          ],
        ),
        actions: [
          TapScale(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call_rounded,
                    color: Color(0xFF10B981), size: 20),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Message list ─────────────────────────────────────────────────
          Expanded(
            child: ref.watch(chatProvider(widget.bookingId)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (messages) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final auth = ref.read(authControllerProvider).valueOrNull;
                    final isMe = message.senderId == auth?.user.id;
                    return _BubbleTile(
                      message: _ChatMessage(
                        text: message.text,
                        isMe: isMe,
                        time: _formatTime(message.timestamp),
                        workerInitial: workerInitial,
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ── Quick replies ─────────────────────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _QuickReply(
                    label: 'On my way',
                    onTap: () {
                      _controller.text = 'On my way!';
                      _send();
                    }),
                _QuickReply(
                    label: 'Running 5 mins late',
                    onTap: () {
                      _controller.text = 'Running 5 mins late, sorry!';
                      _send();
                    }),
                _QuickReply(
                    label: 'Please hurry',
                    onTap: () {
                      _controller.text = 'Please hurry up!';
                      _send();
                    }),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Compose bar ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            decoration: BoxDecoration(
              color: cs.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        onChanged: (v) =>
                            setState(() => _isTyping = v.trim().isNotEmpty),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Type a message…',
                          hintStyle: tt.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TapScale(
                    onTap: _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isTyping ? cs.primary : cs.outlineVariant,
                        shape: BoxShape.circle,
                        boxShadow: _isTyping
                            ? [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        color: _isTyping
                            ? cs.onPrimary
                            : cs.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isMe,
    required this.time,
    required this.workerInitial,
  });
  final String text;
  final bool isMe;
  final String time;
  final String workerInitial;
}

class _BubbleTile extends StatelessWidget {
  const _BubbleTile({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isMe = message.isMe;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFC2A15E).withValues(alpha: 0.15),
              child: Text(message.workerInitial,
                  style: const TextStyle(
                      color: Color(0xFFC2A15E),
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMe
                        ? cs.primary
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: tt.bodyMedium?.copyWith(
                      color: isMe ? cs.onPrimary : cs.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.time,
                  style: tt.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _QuickReply extends StatelessWidget {
  const _QuickReply({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TapScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
