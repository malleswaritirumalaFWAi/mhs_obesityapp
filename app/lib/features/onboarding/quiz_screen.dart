import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class _Q {
  const _Q(this.label, this.subtitle, this.options);
  final String label;
  final String subtitle;
  final List<({IconData icon, String title, String sub})> options;
}

const _questions = <_Q>[
  _Q('Your gender?', 'Helps us tailor calorie targets.', [
    (icon: Symbols.man_rounded, title: 'Male', sub: ''),
    (icon: Symbols.woman_rounded, title: 'Female', sub: ''),
    (icon: Symbols.transgender_rounded, title: 'Other', sub: ''),
  ]),
  _Q('Your activity level?', 'Be honest — we adjust the plan.', [
    (icon: Symbols.chair_rounded, title: 'Mostly sitting', sub: 'Desk job, little movement'),
    (icon: Symbols.directions_walk_rounded, title: 'Lightly active', sub: 'Some walking daily'),
    (icon: Symbols.fitness_center_rounded, title: 'Very active', sub: 'Workout 4+ days/week'),
  ]),
  _Q("What's your main goal?", "We'll personalize the plan around it.", [
    (icon: Symbols.monitor_weight_rounded, title: 'Lose weight', sub: '8–15 kg in 12 weeks'),
    (icon: Symbols.fitness_center_rounded, title: 'Build muscle', sub: 'Strength + lean gains'),
    (icon: Symbols.favorite_rounded, title: 'Better health markers', sub: 'Blood sugar, BP, sleep'),
    (icon: Symbols.bolt_rounded, title: 'More energy', sub: 'Feel sharper through the day'),
  ]),
  _Q('Food preference?', 'We build your meal plan from this.', [
    (icon: Symbols.eco_rounded, title: 'Vegetarian', sub: 'No meat, eggs ok'),
    (icon: Symbols.egg_rounded, title: 'Eggetarian', sub: 'Veg + eggs'),
    (icon: Symbols.lunch_dining_rounded, title: 'Non-vegetarian', sub: 'Everything'),
  ]),
  _Q('Biggest challenge?', 'Your coach will focus here first.', [
    (icon: Symbols.cookie_rounded, title: 'Cravings & snacking', sub: ''),
    (icon: Symbols.bedtime_rounded, title: 'Poor sleep', sub: ''),
    (icon: Symbols.schedule_rounded, title: 'No time', sub: ''),
    (icon: Symbols.sentiment_stressed_rounded, title: 'Stress eating', sub: ''),
  ]),
];

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});
  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _step = 0;
  final _answers = <int, int>{};

  Future<void> _submitAndContinue() async {
    // Map selected option titles into the quiz payload, then persist.
    String pick(int i) =>
        _answers.containsKey(i) ? _questions[i].options[_answers[i]!].title : '';
    try {
      await ref.read(apiClientProvider).postJson('/profile/quiz', {
        'gender': pick(0),
        'activity': pick(1),
        'goal': pick(2),
        'food_pref': pick(3),
        'challenge': pick(4),
      });
    } catch (_) {/* demo mode — backend optional */}
    if (mounted) context.go(Routes.coach);
  }

  void _next() {
    if (_step < _questions.length - 1) {
      setState(() => _step++);
    } else {
      _submitAndContinue();
    }
  }

  void _back() {
    if (_step == 0) {
      context.go(Routes.login);
    } else {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_step];
    final selected = _answers[_step];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeuTopBar(
                onBack: _back,
                trailing: Text('${_step + 1} of ${_questions.length}',
                    style: T.small(context)),
              ),
              const SizedBox(height: 18),
              // progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (_step + 1) / _questions.length,
                  minHeight: 8,
                  backgroundColor: AppColors.line,
                  valueColor: const AlwaysStoppedAnimation(AppColors.coral),
                ),
              ),
              const SizedBox(height: 28),
              Text('ABOUT YOU', style: T.label(context).copyWith(color: AppColors.coral)),
              const SizedBox(height: 10),
              Text(q.label, style: T.h1(context).copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              Text(q.subtitle, style: T.body(context)),
              const SizedBox(height: 22),
              Expanded(
                child: ListView.separated(
                  itemCount: q.options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final o = q.options[i];
                    final on = selected == i;
                    return NeuCard(
                      onTap: () => setState(() => _answers[_step] = i),
                      padding: const EdgeInsets.all(16),
                      color: on ? AppColors.coralSoft : null,
                      child: Row(
                        children: [
                          Icon(o.icon,
                              color: on ? AppColors.coral : AppColors.inkMid, fill: on ? 1 : 0),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(o.title, style: T.title(context).copyWith(fontSize: 15)),
                                if (o.sub.isNotEmpty)
                                  Text(o.sub, style: T.small(context)),
                              ],
                            ),
                          ),
                          Icon(
                            on
                                ? Symbols.check_circle_rounded
                                : Symbols.radio_button_unchecked_rounded,
                            color: on ? AppColors.coral : AppColors.line,
                            fill: on ? 1 : 0,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              NeuButton.primary(
                _step == _questions.length - 1 ? 'See my plan' : 'Continue',
                trailing: const Icon(Symbols.arrow_forward_rounded, size: 20),
                onPressed: selected == null ? null : _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
