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

const _moodIcons = [
  Symbols.sentiment_very_dissatisfied_rounded,
  Symbols.sentiment_neutral_rounded,
  Symbols.sentiment_satisfied_rounded,
  Symbols.sentiment_very_satisfied_rounded,
  Symbols.mood_rounded,
];
const _moodLabels = ['Rough day', 'Okay', 'Good', 'Great', 'Amazing!'];
const _moodColors = [
  Color(0xFFE57373),
  Color(0xFFFFB74D),
  AppColors.coral,
  AppColors.coral,
  AppColors.coral,
];

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
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeuCard(
                depth: 0.5,
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
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: isEvening
                          ? AppColors.coral.withValues(alpha: 0.12)
                          : AppColors.coral.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEvening ? Symbols.dark_mode_rounded : Symbols.bar_chart_rounded,
                      color: isEvening ? AppColors.coral : AppColors.coral,
                      size: 20, fill: 1,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              if (_xpEarned != null) ...[
                Center(
                  child: NeuCard(
                    depth: 0.5,
                    color: AppColors.coralSoft,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Symbols.star_rounded,
                            color: AppColors.coral, size: 20, fill: 1),
                      ),
                      const SizedBox(height: 12),
                      Text('+$_xpEarned XP earned!', style: T.h2(context).copyWith(color: AppColors.coral)),
                      Text('Reflection saved', style: T.small(context)),
                    ]),
                  ),
                ),
              ] else ...[
                Text(
                  isEvening ? 'HOW WAS YOUR DAY?' : 'HOW WAS YOUR WEEK?',
                  style: T.section(context),
                ),
                const SizedBox(height: 14),
                Text(isEvening ? 'How was your day?' : 'How was your week?',
                  style: T.h2(context).copyWith(fontSize: 20)),
                const SizedBox(height: 24),

                // Mood picker
                Text('YOUR MOOD', style: T.section(context)),
                const SizedBox(height: 12),
                Row(children: List.generate(5, (i) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _mood = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: NeuCard(
                        depth: 0.5,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: _mood == i ? _moodColors[i].withValues(alpha: 0.12) : null,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_moodIcons[i],
                              size: 28,
                              color: _mood == i ? _moodColors[i] : AppColors.inkSoft,
                              fill: 1),
                          const SizedBox(height: 4),
                          Text(_moodLabels[i], style: T.small(context).copyWith(fontSize: 10),
                            textAlign: TextAlign.center),
                        ]),
                      ),
                    ),
                  ),
                ))),
                const SizedBox(height: 24),

                Text(
                  isEvening ? 'ANYTHING TO NOTE?' : 'YOUR REFLECTION THIS WEEK',
                  style: T.section(context),
                ),
                const SizedBox(height: 8),
                NeuCard(
                  depth: 0.5,
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
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.coral.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Symbols.stars_rounded,
                        color: AppColors.coral, size: 20, fill: 1),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('+10 XP for reflecting · bonus XP for perfect day!',
                      style: T.small(context).copyWith(fontSize: 11, color: AppColors.coral)),
                  ),
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
