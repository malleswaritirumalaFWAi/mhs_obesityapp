import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's quest", style: T.small(context)),
                    Text('Hi, Aarav 👋', style: T.h2(context)),
                  ],
                ),
                const Spacer(),
                const NeuIconButton(icon: Symbols.notifications_rounded),
              ],
            ),
            const SizedBox(height: 18),
            // Hero quest card
            NeuCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('2 small things', style: T.h2(context)),
                        Text('to finish strong', style: T.h2(context)),
                        const SizedBox(height: 12),
                        const NeuPill(
                          color: AppColors.sageSoft,
                          child: Text('Day 23 / 84 · on track',
                              style: TextStyle(
                                  color: AppColors.sageDark,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  NeuProgressRing(
                    value: 6 / 8,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('6/8', style: T.title(context)),
                        Text('DONE', style: T.label(context).copyWith(fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Stats
            Row(children: const [
              Expanded(
                  child: _Stat(
                      icon: Symbols.directions_walk_rounded,
                      color: AppColors.coral,
                      label: 'Steps',
                      value: '8,412',
                      sub: '+412 ✓')),
              SizedBox(width: 12),
              Expanded(
                  child: _Stat(
                      icon: Symbols.water_drop_rounded,
                      color: AppColors.sage,
                      label: 'Water',
                      value: '6/8',
                      sub: '2 more')),
              SizedBox(width: 12),
              Expanded(
                  child: _Stat(
                      icon: Symbols.bedtime_rounded,
                      color: AppColors.berry,
                      label: 'Sleep',
                      value: '7.4h',
                      sub: 'restful')),
            ]),
            const SizedBox(height: 22),
            Row(children: [
              Text("Today's plan", style: T.title(context)),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go(Routes.today),
                child: Text('See all →',
                    style: T.small(context).copyWith(
                        color: AppColors.coral, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 12),
            _Task(
              icon: Symbols.wb_sunny_rounded,
              title: 'Morning check-in',
              sub: 'Logged at 7:14 AM',
              done: true,
              onTap: () => context.push(Routes.checkin),
            ),
            _Task(
              icon: Symbols.restaurant_rounded,
              title: 'Log breakfast',
              sub: 'Target 420 kcal · high protein',
              action: 'Log',
              onTap: () => context.push(Routes.meal),
            ),
            _Task(
              icon: Symbols.directions_walk_rounded,
              title: '8,000 step walk',
              sub: '8,412 steps · +412 over',
              done: true,
            ),
            _Task(
              icon: Symbols.scale_rounded,
              title: 'Evening weigh-in',
              sub: '5 min before bed · 9:45 PM',
              action: 'Start',
              onTap: () => context.push(Routes.checkin),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: NeuCard(
                  onTap: () => context.go(Routes.group),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Symbols.emoji_events_rounded,
                          color: AppColors.gold, fill: 1),
                      const SizedBox(height: 8),
                      Text('Your rank', style: T.small(context)),
                      Text('#12', style: T.h2(context)),
                      Text('Top 5% week', style: T.small(context)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeuCard(
                  onTap: () => context.push(Routes.learning),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Symbols.school_rounded, color: AppColors.berry, fill: 1),
                      const SizedBox(height: 8),
                      Text('This week', style: T.small(context)),
                      Text('Why 8,000 steps matter',
                          style: T.title(context).copyWith(fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('Lesson 2/3 · 66%', style: T.small(context)),
                    ],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            NeuCard(
              onTap: () => context.go(Routes.chat),
              color: AppColors.coralSoft,
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      color: AppColors.coral, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Text('M',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Coach Mira', style: T.title(context).copyWith(fontSize: 14)),
                      Text('You crushed steps today. Try a 10-min stretch before bed 🌙',
                          style: T.small(context)),
                    ],
                  ),
                ),
                const Icon(Symbols.arrow_forward_rounded, color: AppColors.coral),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22, fill: 1),
          const SizedBox(height: 10),
          Text(label, style: T.small(context).copyWith(fontSize: 11)),
          Text(value, style: T.title(context).copyWith(fontSize: 18)),
          Text(sub, style: T.small(context).copyWith(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

class _Task extends StatelessWidget {
  const _Task({
    required this.icon,
    required this.title,
    required this.sub,
    this.done = false,
    this.action,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String sub;
  final bool done;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: done ? AppColors.sageSoft : AppColors.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon,
                  color: done ? AppColors.sageDark : AppColors.inkMid, fill: 1),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.title(context).copyWith(fontSize: 15)),
                  Text(sub, style: T.small(context)),
                ],
              ),
            ),
            if (done)
              const Icon(Symbols.check_circle_rounded, color: AppColors.sage, fill: 1)
            else if (action != null)
              NeuPill(
                color: AppColors.coral,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(action!,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }
}
