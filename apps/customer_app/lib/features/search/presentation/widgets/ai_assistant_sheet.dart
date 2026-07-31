import 'dart:math' show sin, pi;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

void showAiAssistantSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _AiAssistantSheet(),
  );
}

class _AiAssistantSheet extends ConsumerStatefulWidget {
  const _AiAssistantSheet();

  @override
  ConsumerState<_AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends ConsumerState<_AiAssistantSheet> with TickerProviderStateMixin {
  late final AnimationController _waveController;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _textController.text;
    if (text.isEmpty) return;
    ref.read(aiAssistantControllerProvider.notifier).sendMessage(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final aiState = ref.watch(aiAssistantControllerProvider);
    final messages = aiState.messages;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            height: 4,
            width: 48,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Veedufix AI',
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              foreground: Paint()
                ..shader = LinearGradient(
                  colors: [cs.primary, const Color(0xFF8B5CF6)],
                ).createShader(const Rect.fromLTWH(0, 0, 200, 24)),
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final isUser = messages[index].role == 'user';
                return _ChatBubble(
                  text: messages[index].text,
                  isUser: isUser,
                  animation: const AlwaysStoppedAnimation(1.0),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          // Text Input Area
          Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (aiState.isLoading)
                  SizedBox(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (index) => _WaveBar(
                          index: index,
                          controller: _waveController,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        onSubmitted: (_) => _submit(),
                        enabled: !aiState.isLoading,
                        decoration: InputDecoration(
                          hintText: 'Type your message...',
                          hintStyle: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                          filled: true,
                          fillColor: cs.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TapScale(
                      onTap: aiState.isLoading ? null : _submit,
                      child: Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [cs.primary, const Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveBar extends StatelessWidget {
  const _WaveBar({
    required this.index,
    required this.controller,
    required this.color,
  });

  final int index;
  final AnimationController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final phase = controller.value * 2 * pi;
        final offset = index * (pi / 3);
        final height = 20 + 40 * ((sin(phase + offset) + 1) / 2);
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 6,
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.7 + 0.3 * sin(phase + offset)),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.text,
    required this.isUser,
    required this.animation,
  });

  final String text;
  final bool isUser;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isUser ? cs.primary : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AbzioTheme.cardRadius).copyWith(
                bottomRight: Radius.circular(isUser ? 4 : 24),
                bottomLeft: Radius.circular(!isUser ? 4 : 24),
              ),
            ),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isUser ? cs.onPrimary : cs.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
