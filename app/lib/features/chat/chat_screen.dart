import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/neu.dart';
import '../../core/widgets/neu_misc.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _Msg {
  _Msg({
    required this.text,
    required this.fromCoach,
    required this.createdAt,
    this.sending = false,
  });
  final String text;
  final bool fromCoach;
  final DateTime createdAt;
  final bool sending; // true = optimistic "typing…" indicator

  String get timeLabel {
    final h = createdAt.hour.toString().padLeft(2, '0');
    final m = createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get dateLabel {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(createdAt.year, createdAt.month, createdAt.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Msg>[];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final res = await ref.read(apiClientProvider).getJson('/chat');
      final raw = (res['messages'] as List?) ?? [];
      final msgs = raw.map((m) {
        final map = Map<String, dynamic>.from(m as Map);
        return _Msg(
          text: map['text'] as String? ?? '',
          fromCoach: map['from_coach'] == true,
          createdAt: (DateTime.tryParse(map['created_at'] as String? ?? '') ??
              DateTime.now()).toLocal(),
        );
      }).toList();
      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(msgs);
          _loading = false;
        });
        _scrollDown();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final now = DateTime.now();
    setState(() {
      _input.clear();
      _sending = true;
      _messages.add(_Msg(text: text, fromCoach: false, createdAt: now));
      _messages.add(
          _Msg(text: '…', fromCoach: true, createdAt: now, sending: true));
    });
    _scrollDown();
    try {
      final res = await ref
          .read(apiClientProvider)
          .postJson('/chat', {'text': text});
      final reply = res['reply'] as String? ??
          'Great work staying consistent! Keep it up 💪';
      if (mounted) {
        setState(() {
          _messages.removeLast();
          _messages.add(_Msg(
              text: reply, fromCoach: true, createdAt: DateTime.now()));
          _sending = false;
        });
        _scrollDown();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.removeLast();
          _messages.add(_Msg(
              text: 'Great work staying consistent! Keep it up 💪',
              fromCoach: true,
              createdAt: DateTime.now()));
          _sending = false;
        });
        _scrollDown();
      }
    }
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.tealGrad,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text('P',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Coach Priya',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                  Row(children: [
                    const CircleAvatar(
                        radius: 4,
                        backgroundColor: Color(0xFF80FFD4)),
                    const SizedBox(width: 6),
                    const Text('Online',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ]),
                ]),
                const Spacer(),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Symbols.call_rounded,
                      color: Colors.white, size: 20),
                ),
              ]),
            ),

            // ── Messages ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                  Symbols.chat_bubble_outline_rounded,
                                  size: 48,
                                  color: AppColors.inkSoft),
                              const SizedBox(height: 12),
                              Text('No messages yet',
                                  style: T.small(context)),
                              Text('Say hi to your coach!',
                                  style: T.small(context)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding:
                              const EdgeInsets.fromLTRB(20, 12, 20, 12),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) {
                            final msg = _messages[i];
                            final showDate = i == 0 ||
                                _messages[i - 1].dateLabel != msg.dateLabel;
                            return Column(children: [
                              if (showDate) _DateDivider(msg.dateLabel),
                              _Bubble(msg: msg),
                            ]);
                          },
                        ),
            ),

            _InputBar(
                controller: _input, onSend: _send, sending: _sending),
          ],
        ),
      ),
    );
  }
}

// ── Date divider ──────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  const _DateDivider(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          const Expanded(child: Divider(color: AppColors.line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
                style: T.small(context)
                    .copyWith(fontSize: 11, color: AppColors.inkSoft)),
          ),
          const Expanded(child: Divider(color: AppColors.line)),
        ]),
      );
}

// ── Chat bubble ───────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});
  final _Msg msg;

  @override
  Widget build(BuildContext context) {
    final coach = msg.fromCoach;
    return Align(
      alignment: coach ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        crossAxisAlignment:
            coach ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.74),
            decoration: BoxDecoration(
              color: coach ? AppColors.surface : AppColors.coral,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(coach ? 4 : 20),
                bottomRight: Radius.circular(coach ? 20 : 4),
              ),
              boxShadow: coach ? Neu.small() : null,
            ),
            child: msg.sending
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < 3; i++) ...[
                      Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: AppColors.inkSoft,
                              shape: BoxShape.circle)),
                      if (i < 2) const SizedBox(width: 4),
                    ],
                  ])
                : Text(msg.text,
                    style: TextStyle(
                        color: coach ? AppColors.ink : Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.35)),
          ),
          // ── Actual timestamp ──
          Padding(
            padding:
                const EdgeInsets.only(bottom: 10, left: 4, right: 4),
            child: Text(msg.timeLabel,
                style: T.small(context)
                    .copyWith(fontSize: 10, color: AppColors.inkSoft)),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.sending,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 10 + MediaQuery.of(context).viewInsets.bottom),
      color: AppColors.bg,
      child: Row(children: [
        Expanded(
          child: NeuTextField(
              controller: controller, hint: 'Message your coach…'),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: sending ? null : onSend,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: sending ? AppColors.inkSoft : AppColors.coral,
              shape: BoxShape.circle,
              boxShadow: sending ? null : Neu.small(),
            ),
            child: sending
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Symbols.send_rounded,
                    color: Colors.white, fill: 1),
          ),
        ),
      ]),
    );
  }
}
