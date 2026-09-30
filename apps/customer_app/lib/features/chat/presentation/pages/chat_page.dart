import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _picker = ImagePicker();
  final List<ChatAttachment> _draftAttachments = [];
  final Set<String> _markedReadMessageIds = <String>{};
  bool _isTyping = false;
  bool _isSending = false;
  bool _isUploadingAttachment = false;

  Future<void> _pickAttachment() async {
    if (_isUploadingAttachment || _isSending) return;
    setState(() => _isUploadingAttachment = true);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null || !mounted) return;
      final attachment = await ref
          .read(chatControllerProvider)
          .uploadAttachment(
            bookingId: widget.bookingId,
            bytes: await picked.readAsBytes(),
            filename: picked.name,
          );
      if (!mounted) return;
      setState(() {
        _draftAttachments.add(attachment);
        _isTyping =
            _controller.text.trim().isNotEmpty || _draftAttachments.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not attach the selected image.')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAttachment = false);
    }
  }

  Future<void> _send() async {
    if (_isSending || _isUploadingAttachment) return;
    final text = _controller.text.trim();
    if (text.isEmpty && _draftAttachments.isEmpty) return;

    final auth = ref.read(authControllerProvider).valueOrNull;
    if (auth == null) return;

    setState(() => _isSending = true);
    try {
      await ref
          .read(chatControllerProvider)
          .sendMessage(
            bookingId: widget.bookingId,
            text: text,
            senderId: auth.user.id,
            attachments: [..._draftAttachments],
          );

      if (!mounted) return;
      setState(() {
        _controller.clear();
        _draftAttachments.clear();
        _isTyping = false;
      });

      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message not sent. Check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
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

  void _setQuickReply(String text) {
    setState(() {
      _controller.text = text;
      _controller.selection = TextSelection.collapsed(offset: text.length);
      _isTyping = true;
    });
  }

  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    final h = localTime.hour.toString().padLeft(2, '0');
    final m = localTime.minute.toString().padLeft(2, '0');
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
    final workerInitial = workerName.trim().isNotEmpty
        ? workerName.trim()[0].toUpperCase()
        : 'P';

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
                boxShadow: AbzioTheme.eliteShadow,
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
              backgroundColor: const Color(0xFFC2A15E).withValues(alpha: 0.15),
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
                Text(
                  workerName,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Booking professional',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TapScale(
            onTap: () => context.push(
              '/support?autoCompose=true&bookingId=${Uri.encodeComponent(widget.bookingId)}&category=booking&subject=${Uri.encodeComponent('Issue with booking ${widget.bookingId}')}&message=${Uri.encodeComponent('I need help with booking ${widget.bookingId}. Please review this conversation and the booking details.')}',
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: cs.primary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Message list ─────────────────────────────────────────────────
          Expanded(
            child: ref
                .watch(chatProvider(widget.bookingId))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => PremiumRetryState(
                    title: 'Could not load messages',
                    subtitle: 'Check your connection and try again.',
                    icon: Icons.chat_bubble_outline_rounded,
                    onRetry: () =>
                        ref.invalidate(chatProvider(widget.bookingId)),
                    onRefresh: () async {
                      await ref
                          .refresh(chatProvider(widget.bookingId).future)
                          .then<void>((_) {});
                    },
                  ),
                  data: (messages) {
                    final auth = ref.read(authControllerProvider).valueOrNull;
                    final shouldFollowLatest =
                        !_scrollController.hasClients ||
                        _scrollController.position.maxScrollExtent -
                                _scrollController.position.pixels <=
                            120;
                    if (auth != null) {
                      final pendingReadIds = messages
                          .where(
                            (message) =>
                                !message.isRead &&
                                message.senderId != auth.user.id &&
                                message.id.isNotEmpty &&
                                !_markedReadMessageIds.contains(message.id),
                          )
                          .map((message) => message.id)
                          .toSet();
                      if (pendingReadIds.isNotEmpty) {
                        _markedReadMessageIds.addAll(pendingReadIds);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          ref
                              .read(chatControllerProvider)
                              .markAsRead(
                                bookingId: widget.bookingId,
                                userId: auth.user.id,
                              )
                              .catchError((_) {
                                _markedReadMessageIds.removeAll(pendingReadIds);
                              });
                        });
                      }
                    }
                    if (shouldFollowLatest) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToBottom();
                      });
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      itemCount: messages.isEmpty ? 1 : messages.length,
                      itemBuilder: (context, index) {
                        if (messages.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 100),
                            child: Center(
                              child: Text(
                                'No messages yet. Start the conversation about your booking.',
                                textAlign: TextAlign.center,
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          );
                        }
                        final message = messages[index];
                        final isMe = message.senderId == auth?.user.id;
                        return _BubbleTile(
                          message: _ChatMessage(
                            text: message.text,
                            isMe: isMe,
                            time: _formatTime(message.timestamp),
                            workerInitial: workerInitial,
                            attachments: message.attachments,
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
                  label: 'I’m at the address',
                  onTap: _isSending
                      ? null
                      : () {
                          _setQuickReply('I’m at the service address.');
                          _send();
                        },
                ),
                _QuickReply(
                  label: 'Please call me',
                  onTap: _isSending
                      ? null
                      : () {
                          _setQuickReply('Please call me when you can.');
                          _send();
                        },
                ),
                _QuickReply(
                  label: 'Running late',
                  onTap: _isSending
                      ? null
                      : () {
                          _setQuickReply('I’m running about 5 minutes late.');
                          _send();
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (_draftAttachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _draftAttachments
                    .map((attachment) {
                      return Chip(
                        avatar: const Icon(Icons.image_rounded, size: 18),
                        label: Text(attachment.name ?? 'Attachment'),
                        onDeleted: () {
                          setState(() => _draftAttachments.remove(attachment));
                        },
                      );
                    })
                    .toList(growable: false),
              ),
            ),

          // ── Compose bar ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            decoration: BoxDecoration(
              color: cs.surface,
              boxShadow: AbzioTheme.eliteShadow,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  TapScale(
                    onTap: _isSending || _isUploadingAttachment
                        ? null
                        : _pickAttachment,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.attach_file_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(
                          AbzioTheme.cardRadius,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        onChanged: (v) => setState(
                          () => _isTyping =
                              v.trim().isNotEmpty ||
                              _draftAttachments.isNotEmpty,
                        ),
                        readOnly: _isSending,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Type a message…',
                          hintStyle: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TapScale(
                    onTap: _isSending || _isUploadingAttachment ? null : _send,
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
                      child: _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
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
    required this.attachments,
  });
  final String text;
  final bool isMe;
  final String time;
  final String workerInitial;
  final List<ChatAttachment> attachments;
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
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFC2A15E).withValues(alpha: 0.15),
              child: Text(
                message.workerInitial,
                style: const TextStyle(
                  color: Color(0xFFC2A15E),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? cs.primary : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: AbzioTheme.eliteShadow,
                  ),
                  child: Text(
                    message.text,
                    style: tt.bodyMedium?.copyWith(
                      color: isMe ? cs.onPrimary : cs.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
                if (message.attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...message.attachments.map(
                    (attachment) =>
                        _AttachmentPreview(attachment: attachment, isMe: isMe),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  message.time,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
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

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.attachment, required this.isMe});

  final ChatAttachment attachment;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (attachment.kind == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 240, maxHeight: 180),
          color: isMe
              ? Colors.white.withValues(alpha: 0.08)
              : cs.surfaceContainerHighest,
          child: Image.network(
            attachment.url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_rounded,
                    color: isMe ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    attachment.name ?? 'Image',
                    style: tt.labelMedium?.copyWith(
                      color: isMe ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.08)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file_rounded,
            size: 18,
            color: isMe ? cs.onPrimary : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            attachment.name ?? 'File',
            style: tt.labelMedium?.copyWith(
              color: isMe ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickReply extends StatelessWidget {
  const _QuickReply({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

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
            borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
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
