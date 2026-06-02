import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class CoachScreen extends StatelessWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeuTopBar(onBack: () => context.go(Routes.quiz)),
              const SizedBox(height: 18),
              Text("You're in! 🎉", style: T.label(context).copyWith(color: AppColors.sageDark)),
              const SizedBox(height: 8),
              Text('Meet your coach', style: T.h1(context)),
              const SizedBox(height: 22),
              NeuCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                              color: AppColors.berrySoft, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text('P',
                              style: T.h2(context).copyWith(color: AppColors.berry)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text('Priya Sharma', style: T.title(context)),
                                const SizedBox(width: 6),
                                const Icon(Symbols.verified_rounded,
                                    size: 18, color: AppColors.sage, fill: 1),
                              ]),
                              const SizedBox(height: 2),
                              Row(children: [
                                const Icon(Symbols.star_rounded,
                                    size: 16, color: AppColors.gold, fill: 1),
                                const SizedBox(width: 4),
                                Text('4.8 · Certified Dietitian', style: T.small(context)),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '"Hi! I\'m your coach for the next 12 weeks. We\'ve got this — let\'s make it happen 💪"',
                      style: T.body(context).copyWith(color: AppColors.ink),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(children: [
                        const Icon(Symbols.play_circle_rounded,
                            color: AppColors.coral, fill: 1),
                        const SizedBox(width: 10),
                        Text('Audio intro · 0:45', style: T.small(context)),
                        const Spacer(),
                        const Icon(Symbols.graphic_eq_rounded, color: AppColors.inkSoft),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: _InfoTile(
                    icon: Symbols.calendar_today_rounded,
                    title: 'Batch starts',
                    value: 'Mon, Mar 3',
                    sub: 'Batch #47 · 49 joined',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    icon: Symbols.schedule_rounded,
                    title: '12-week program',
                    value: '~15 min/day',
                    sub: 'daily check-ins',
                  ),
                ),
              ]),
              const Spacer(),
              NeuButton.primary(
                'Continue to your plan',
                trailing: const Icon(Symbols.arrow_forward_rounded, size: 20),
                onPressed: () => context.go(Routes.payment),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.go(Routes.payment),
                  child: Text('Skip for now', style: T.small(context)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.sub,
  });
  final IconData icon;
  final String title;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.coral),
          const SizedBox(height: 10),
          Text(title, style: T.small(context)),
          const SizedBox(height: 2),
          Text(value, style: T.title(context).copyWith(fontSize: 16)),
          Text(sub, style: T.small(context).copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}
