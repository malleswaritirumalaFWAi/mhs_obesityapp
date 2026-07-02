import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

const _moods = ['😔', '😐', '🙂', '😊', '🤩'];
const _moodLabels = ['Rough day', 'Okay', 'Good', 'Great', 'Amazing!'];

class ReflectionScreen extends ConsumerStatefulWidget {
  const ReflectionScreen({super.key, this.type = 'evening'});
  final String type;
  @override
  ConsumerState<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends ConsumerState<ReflectionScreen> {
  int? _mood;
  final _textCtrl = TextEditingController();
  bool _saving = false;
  int? _xpEarned;

  @override
  void dispose() { _textCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_mood == null && _textCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a mood or text to save')));
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await ref.read(apiClientProvider).postJson('/reflection', {
        'type': widget.type,
        'mood': _mood,
        'text': _textCtrl.text.trim().isEmpty ? null : _textCtrl.text.trim(),
      });
      final xp = (res['xp_awarded'] as num?)?.toInt() ?? 0;
      if (mounted) {
        setState(() { _xpEarned = xp; _saving = false; });
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) context.pop();
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEvening = widget.type == 'evening';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeuCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Symbols.arrow_back_rounded,
                        color: AppColors.inkMid, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEvening ? 'Evening Reflection' : 'Weekly Review',
                          style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w900),
                        ),
                        Text(
                          isEvening
                              ? 'How did your day go?'
                              : 'Reflect on your week',
                          style: const TextStyle(
                              color: AppColors.inkSoft, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(isEvening ? '🌙' : '📊',
                      style: const TextStyle(fontSize: 26)),
                ]),
              ),
              const SizedBox(height: 24),

              if (_xpEarned != null) ...[
                Center(
                  child: NeuCard(
                    color: AppColors.sageSoft,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('✨', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      Text('+$_xpEarned XP earned!', style: T.h2(context).copyWith(color: AppColors.sageDark)),
                      Text('Reflection saved', style: T.small(context)),
                    ]),
                  ),
                ),
              ] else ...[
                Text(isEvening ? 'How was your day?' : 'How was your week?',
                  style: T.h2(context).copyWith(fontSize: 20)),
                const SizedBox(height: 20),

                // Mood picker
                Row(children: List.generate(5, (i) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _mood = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: NeuCard(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: _mood == i ? AppColors.goldSoft : null,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_moods[i], style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 4),
                          Text(_moodLabels[i], style: T.small(context).copyWith(fontSize: 10),
                            textAlign: TextAlign.center),
                        ]),
                      ),
                    ),
                  ),
                ))),
                const SizedBox(height: 20),

                Text(isEvening ? 'Anything to note?' : 'Your reflection this week',
                  style: T.title(context)),
                const SizedBox(height: 8),
                NeuCard(
                  padding: EdgeInsets.zero,
                  child: TextField(
                    controller: _textCtrl,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: isEvening
                        ? 'What went well? What was hard? What are you grateful for?'
                        : 'Wins this week, challenges, what you\'ll do differently...',
                      hintStyle: T.small(context),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Row(children: [
                  const Icon(Symbols.stars_rounded, color: AppColors.gold, size: 16),
                  const SizedBox(width: 6),
                  Text('+10 XP for reflecting • bonus XP for perfect day!',
                    style: T.small(context).copyWith(fontSize: 11, color: AppColors.goldDark)),
                ]),
                const Spacer(),

                NeuButton.primary(
                  'Save reflection',
                  trailing: _saving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Symbols.check_rounded, size: 20),
                  onPressed: _saving ? null : _save,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
