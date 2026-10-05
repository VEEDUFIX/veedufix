import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../providers/chat_providers.dart';

class WorkerChatPage extends ConsumerStatefulWidget {
  final String bookingId;

  const WorkerChatPage({super.key, required this.bookingId});

  @override
  ConsumerState<WorkerChatPage> createState() => _WorkerChatPageState();
}

class _WorkerChatPageState extends ConsumerState<WorkerChatPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final List<ChatAttachment> _draftAttachments = [];
  final Set<String> _markedReadMessageIds = <String>{};
  Timer? _draftSaveTimer;
  Future<void> _draftPersistence = Future<void>.value();
  String? _draftOwnerId;
  bool _draftWasEdited = false;
  bool _isTyping = false;
  bool _isSending = false;
  bool _isChoosingAttachment = false;
  bool _isUploadingAttachment = false;

  late final AnimationController _quickReplyAnimController;
  late final Animation<double> _quickReplyFadeAnim;

  final List<String> _quickReplies = [
    'On my way',
    'Running 10 mins late',
    'Need access code',
    'Job completed',
    'Need more time',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreDraft());
    });
    _quickReplyAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _quickReplyFadeAnim = CurvedAnimation(
      parent: _quickReplyAnimController,
      curve: Curves.easeIn,
    );
    _quickReplyAnimController.forward();
  }

  Future<void> _restoreDraft() async {
    final userId = ref.read(authControllerProvider).valueOrNull?.user.id;
    if (userId == null) return;
    _draftOwnerId = userId;
    final message = await ChatDraftStore.read(
      mode: AppMode.worker,
      userId: userId,
      bookingId: widget.bookingId,
    );
    if (!mounted ||
        message == null ||
        _messageController.text.isNotEmpty ||
        _draftAttachments.isNotEmpty ||
        ref.read(authControllerProvider).valueOrNull?.user.id != userId) {
      return;
    }
    setState(() {
      _messageController.value = TextEditingValue(
        text: message,
        selection: TextSelection.collapsed(offset: message.length),
      );
      _isTyping = message.trim().isNotEmpty;
    });
  }

  void _scheduleDraftSave(String message) {
    final userId = ref.read(authControllerProvider).valueOrNull?.user.id;
    if (userId == null) return;
    _draftOwnerId = userId;
    _draftWasEdited = true;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 400), () {
      _draftSaveTimer = null;
      _queueDraftPersistence(
        () => ChatDraftStore.write(
          mode: AppMode.worker,
          userId: userId,
          bookingId: widget.bookingId,
          message: message,
        ),
      );
    });
  }

  void _queueDraftPersistence(Future<void> Function() operation) {
    _draftPersistence = _draftPersistence.then((_) => operation());
  }

  void _clearSavedDraft(String userId) {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = null;
    _draftWasEdited = false;
    _queueDraftPersistence(
      () => ChatDraftStore.clear(
        mode: AppMode.worker,
        userId: userId,
        bookingId: widget.bookingId,
      ),
    );
  }

  void _saveDraftBeforeExit() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = null;
    final userId = _draftOwnerId;
    if (userId == null || !_draftWasEdited) return;
    final message = _messageController.text;
    _draftWasEdited = false;
    _queueDraftPersistence(
      () => ChatDraftStore.write(
        mode: AppMode.worker,
        userId: userId,
        bookingId: widget.bookingId,
        message: message,
      ),
    );
  }

  @override
  void dispose() {
    _saveDraftBeforeExit();
    _messageController.dispose();
    _scrollController.dispose();
    _quickReplyAnimController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    if (_isSending || _isChoosingAttachment || _isUploadingAttachment) return;
    setState(() => _isChoosingAttachment = true);
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _isChoosingAttachment = false;
        _isUploadingAttachment = true;
      });
      final attachment =
          await ref.read(chatControllerProvider).uploadAttachment(
                bookingId: widget.bookingId,
                bytes: bytes,
                filename: picked.name,
              );
      if (!mounted) return;
      setState(() {
        _draftAttachments.add(attachment);
        _isTyping = _messageController.text.trim().isNotEmpty ||
            _draftAttachments.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not attach the photo. Check camera or photo access and try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChoosingAttachment = false;
          _isUploadingAttachment = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage([String? quickText]) async {
    if (_isSending || _isUploadingAttachment) return;
    final isQuickMessage = quickText != null;
    final text = quickText ?? _messageController.text.trim();
    if (text.isEmpty && (isQuickMessage || _draftAttachments.isEmpty)) return;

    final auth = ref.read(authControllerProvider).valueOrNull;
    if (auth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again to send messages.')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await ref.read(chatControllerProvider).sendMessage(
            bookingId: widget.bookingId,
            text: text,
            senderId: auth.user.id,
            attachments: isQuickMessage ? const [] : [..._draftAttachments],
          );
      if (!isQuickMessage) _clearSavedDraft(auth.user.id);
      if (!mounted) return;
      setState(() {
        if (!isQuickMessage) {
          _messageController.clear();
          _draftAttachments.clear();
        }
        _isTyping = _messageController.text.trim().isNotEmpty ||
            _draftAttachments.isNotEmpty;
      });
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Message not sent. Check your connection and try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    final h = localTime.hour.toString().padLeft(2, '0');
    final m = localTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool _isDifferentDay(DateTime d1, DateTime d2) {
    final first = d1.toLocal();
    final second = d2.toLocal();
    return first.year != second.year ||
        first.month != second.month ||
        first.day != second.day;
  }

  String _formatDateSeparator(DateTime date) {
    date = date.toLocal();
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final shortId = widget.bookingId.length >= 8
        ? widget.bookingId.substring(0, 8)
        : widget.bookingId;
    final customerName = 'Customer #$shortId';

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
              backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.15),
              child: Text(
                customerName[0].toUpperCase(),
                style: tt.titleMedium?.copyWith(
                  color: const Color(0xFF3B82F6),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        'Booking conversation',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TapScale(
            onTap: () => context.push(
              '/support?autoFocusForm=true&category=app&subject=${Uri.encodeComponent('Help with booking ${widget.bookingId}')}&message=${Uri.encodeComponent('I need help with booking ${widget.bookingId}. Please review this conversation and the booking details.')}',
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.support_agent_rounded,
                    color: cs.primary, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ref.watch(chatProvider(widget.bookingId)).when(
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
                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.chat_bubble_outline_rounded,
                                  size: 48, color: cs.primary),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Start the conversation',
                              style: tt.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Say hi to the customer to let them know you\'re ready.',
                              style: tt.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      );
                    }

                    final shouldFollowLatest = !_scrollController.hasClients ||
                        _scrollController.position.maxScrollExtent -
                                _scrollController.position.pixels <=
                            120;
                    if (shouldFollowLatest) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _scrollToBottom();
                      });
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == auth?.user.id;

                        bool showDateSeparator = false;
                        if (index == 0) {
                          showDateSeparator = true;
                        } else {
                          final prevMessage = messages[index - 1];
                          showDateSeparator = _isDifferentDay(
                              prevMessage.timestamp, message.timestamp);
                        }

                        return Column(
                          children: [
                            if (showDateSeparator)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatDateSeparator(message.timestamp),
                                    style: tt.labelSmall
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ),
                              ),
                            _buildMessageBubble(
                              text: message.text,
                              isMe: isMe,
                              time: _formatTime(message.timestamp),
                              cs: cs,
                              tt: tt,
                              attachments: message.attachments,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
          ),
          FadeTransition(
            opacity: _quickReplyFadeAnim,
            child: SizedBox(
              height: 44,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: _quickReplies
                    .map((reply) => _QuickReply(
                          label: reply,
                          onTap: _isSending || _isUploadingAttachment
                              ? null
                              : () => _sendMessage(reply),
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_draftAttachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _draftAttachments.map((attachment) {
                  return PendingChatAttachmentTile(
                    imageUrl: attachment.url,
                    name: attachment.name,
                    onRemove: () {
                      setState(() {
                        _draftAttachments.remove(attachment);
                        _isTyping = _messageController.text.trim().isNotEmpty ||
                            _draftAttachments.isNotEmpty;
                      });
                    },
                  );
                }).toList(growable: false),
              ),
            ),
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
                    onTap: _isSending ||
                            _isChoosingAttachment ||
                            _isUploadingAttachment
                        ? null
                        : _pickAttachment,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: _isUploadingAttachment
                          ? Padding(
                              padding: const EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.primary,
                              ),
                            )
                          : Icon(Icons.attach_file_rounded,
                              color: cs.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius:
                            BorderRadius.circular(AbzioTheme.cardRadius),
                      ),
                      child: TextField(
                        controller: _messageController,
                        onChanged: (v) {
                          _scheduleDraftSave(v);
                          setState(() => _isTyping = v.trim().isNotEmpty ||
                              _draftAttachments.isNotEmpty);
                        },
                        readOnly: _isSending,
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
                    onTap: _isSending || _isUploadingAttachment
                        ? null
                        : _sendMessage,
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

  Widget _buildMessageBubble({
    required String text,
    required bool isMe,
    required String time,
    required ColorScheme cs,
    required TextTheme tt,
    required List<ChatAttachment> attachments,
  }) {
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
              backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.15),
              child: const Text('C',
                  style: TextStyle(
                      color: Color(0xFF3B82F6),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    text,
                    style: tt.bodyMedium?.copyWith(
                      color: isMe ? cs.onPrimary : cs.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...attachments.map((attachment) => _AttachmentPreview(
                        attachment: attachment,
                        isMe: isMe,
                      )),
                ],
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style:
                          tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.done_all_rounded, size: 14, color: cs.primary),
                    ],
                  ],
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
                  Icon(Icons.broken_image_rounded,
                      color: isMe ? cs.onPrimary : cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    attachment.name ?? 'Image',
                    style: tt.labelMedium?.copyWith(
                        color: isMe ? cs.onPrimary : cs.onSurfaceVariant),
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
          Icon(Icons.insert_drive_file_rounded,
              size: 18, color: isMe ? cs.onPrimary : cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            attachment.name ?? 'File',
            style: tt.labelMedium
                ?.copyWith(color: isMe ? cs.onPrimary : cs.onSurfaceVariant),
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
      child: IgnorePointer(
        ignoring: onTap == null,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: TapScale(
            onTap: onTap ?? () {},
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
        ),
      ),
    );
  }
}
