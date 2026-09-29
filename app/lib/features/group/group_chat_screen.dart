import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/providers/group_chat_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key});
  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    await ref.read(groupChatProvider.notifier).send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupChatProvider);
    _scrollToBottom();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: NeuCard(
                depth: 0.5,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Symbols.arrow_back_rounded,
                        color: AppColors.inkMid, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.coralSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Symbols.groups_rounded,
                        color: AppColors.coral, size: 20, fill: 1),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cohort Chat',
                            style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        Text('CHAT WITH YOUR BATCH MEMBERS',
                            style: T.section(context)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: state.loading ? null : () => ref.read(groupChatProvider.notifier).load(),
                    child: state.loading && state.messages.isNotEmpty
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkMid),
                        )
                      : Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.coralSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Symbols.refresh_rounded,
                              color: AppColors.coral, size: 20, fill: 1),
                        ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: state.loading && state.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.coralSoft,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Symbols.waving_hand_rounded,
                                size: 28, color: AppColors.coral, fill: 1),
                          ),
                          const SizedBox(height: 16),
                          Text('No messages yet. Say hi!', style: T.body(context)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: state.messages.length,
                      itemBuilder: (_, i) => _Bubble(msg: state.messages[i]),
                    ),
            ),
            _InputBar(ctrl: _ctrl, onSend: _send, sending: state.sending),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});
  final ChatMessage msg;

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isMe;
    final isCoach = msg.type == 'coach';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: isCoach ? AppColors.coral : AppColors.coralSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                msg.authorName.isNotEmpty ? msg.authorName[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isCoach ? Colors.white : AppColors.coral,
                  fontWeight: FontWeight.w700, fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCoach)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Symbols.verified_rounded,
                                size: 14, color: AppColors.coral, fill: 1),
                          ),
                        Text(
                          msg.authorName,
                          style: T.small(context).copyWith(fontSize: 11,
                            color: isCoach ? AppColors.coral : AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.coral : (isCoach ? AppColors.coralSoft : AppColors.surface),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Text(
                    msg.text,
                    style: T.body(context).copyWith(
                      color: isMe ? Colors.white : AppColors.ink,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.ctrl, required this.onSend, required this.sending});
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final bool sending;

  static const _quickEmojis = ['👍', '❤️', '🔥', '💪', '🎉', '😊'];

  void _showEmojiPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _quickEmojis.map((e) => GestureDetector(
            onTap: () {
              ctrl.text = ctrl.text + e;
              ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
              Navigator.pop(context);
            },
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              alignment: Alignment.center,
              child: Text(e, style: const TextStyle(fontSize: 24)),
            ),
          )).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 8, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => _showEmojiPicker(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.coralSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Symbols.emoji_emotions_rounded,
                color: AppColors.coral, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.line),
            ),
            child: TextField(
              controller: ctrl,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Message your cohort...',
                hintStyle: T.small(context),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: sending ? null : onSend,
          child: Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(color: AppColors.coral, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: sending
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Symbols.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}
