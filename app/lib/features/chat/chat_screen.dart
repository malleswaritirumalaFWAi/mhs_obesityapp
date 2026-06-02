import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/neu.dart';
import '../../core/widgets/neu_misc.dart';

class _Msg {
  _Msg(this.text, this.fromCoach, {this.card = false});
  final String text;
  final bool fromCoach;
  final bool card;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Msg>[
    _Msg('Good morning Aarav! How did you sleep? 😊', true),
    _Msg('7.4 hours, felt restful 💤', false),
    _Msg('Love it. For breakfast today, try this:', true),
    _Msg('🍳 Veggie egg bhurji\n~380 kcal · 26g protein', true, card: true),
    _Msg("Sounds great, I'll log it 👍", false),
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _messages.add(_Msg(t, false));
      _input.clear();
    });
    _scrollDown();
    // demo coach reply (replace with POST /chat -> Claude)
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _messages.add(_Msg(
          'Great work staying consistent! Keep it up and hydrate well today 💪', true)));
      _scrollDown();
    });
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      color: AppColors.berrySoft, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('P', style: T.title(context).copyWith(color: AppColors.berry)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Coach Priya', style: T.title(context).copyWith(fontSize: 16)),
                    Row(children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: AppColors.sage, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('Online', style: T.small(context)),
                    ]),
                  ],
                ),
                const Spacer(),
                const NeuIconButton(icon: Symbols.call_rounded),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _Bubble(msg: _messages[i]),
              ),
            ),
            _InputBar(controller: _input, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});
  final _Msg msg;
  @override
  Widget build(BuildContext context) {
    final coach = msg.fromCoach;
    return Align(
      alignment: coach ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
        decoration: BoxDecoration(
          color: msg.card
              ? AppColors.goldSoft
              : coach
                  ? AppColors.surface
                  : AppColors.coral,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(coach ? 4 : 20),
            bottomRight: Radius.circular(coach ? 20 : 4),
          ),
          boxShadow: coach ? Neu.small() : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.text,
                style: TextStyle(
                    color: coach ? AppColors.ink : Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.35)),
            if (msg.card) ...[
              const SizedBox(height: 10),
              Row(children: [
                _MiniBtn('Log meal', AppColors.coral),
                const SizedBox(width: 8),
                _MiniBtn('Recipe?', AppColors.surface, dark: true),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn(this.label, this.color, {this.dark = false});
  final String label;
  final Color color;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              color: dark ? AppColors.ink : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12)),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 10 + MediaQuery.of(context).viewInsets.bottom),
      color: AppColors.bg,
      child: Row(children: [
        const NeuIconButton(icon: Symbols.add_rounded, size: 44),
        const SizedBox(width: 10),
        Expanded(
          child: NeuTextField(controller: controller, hint: 'Message your coach…'),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onSend,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.coral,
              shape: BoxShape.circle,
              boxShadow: Neu.small(),
            ),
            child: const Icon(Symbols.send_rounded, color: Colors.white, fill: 1),
          ),
        ),
      ]),
    );
  }
}
