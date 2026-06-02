import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class _Item {
  const _Item(this.time, this.icon, this.title, this.sub,
      {this.done = false, this.action, this.route});
  final String time;
  final IconData icon;
  final String title;
  final String sub;
  final bool done;
  final String? action;
  final String? route;
}

const _sections = <String, List<_Item>>{
  'Morning': [
    _Item('07:00', Symbols.wb_sunny_rounded, 'Mood + weight check-in', '+10 XP · 2 min',
        done: true, route: Routes.checkin),
    _Item('08:30', Symbols.restaurant_rounded, 'Log breakfast', '~420 kcal · high protein',
        action: 'Log', route: Routes.meal),
  ],
  'Afternoon': [
    _Item('13:00', Symbols.lunch_dining_rounded, 'Log lunch', '~520 kcal · veggies first',
        action: 'Log', route: Routes.meal),
    _Item('16:00', Symbols.water_drop_rounded, 'Hydration', '6/8 glasses · 2 to go',
        done: true),
  ],
  'Evening': [
    _Item('19:30', Symbols.directions_run_rounded, '8,000 step walk', '8,412 steps · done',
        done: true),
    _Item('21:45', Symbols.scale_rounded, 'Evening weigh-in', '5 min before bed',
        action: 'Start', route: Routes.checkin),
  ],
};

class TodayPlanScreen extends StatelessWidget {
  const TodayPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            Row(children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Day 23', style: T.small(context)),
                  Text("Today's plan", style: T.h2(context)),
                ],
              ),
              const Spacer(),
              const NeuIconButton(icon: Symbols.tune_rounded),
            ]),
            const SizedBox(height: 16),
            // day chips
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final d in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'])
                    _DayChip(label: d, today: d == 'Wed'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            NeuCard(
              color: AppColors.coralSoft,
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Progress · 6 of 8 done', style: T.title(context).copyWith(fontSize: 15)),
                      const SizedBox(height: 4),
                      Text("Finish 2 more — you'll hit your daily target.",
                          style: T.small(context)),
                    ],
                  ),
                ),
                NeuProgressRing(
                  value: 6 / 8,
                  size: 64,
                  stroke: 8,
                  center: Text('75%', style: T.small(context).copyWith(fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            for (final entry in _sections.entries) ...[
              Text(entry.key.toUpperCase(), style: T.label(context)),
              const SizedBox(height: 10),
              for (final item in entry.value) _TimelineRow(item: item),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.today});
  final String label;
  final bool today;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: today ? AppColors.coral : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: today ? null : null,
      ),
      child: Center(
        child: Text(today ? 'Today' : label,
            style: TextStyle(
                color: today ? Colors.white : AppColors.inkSoft,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item});
  final _Item item;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 46,
            child: Text(item.time, style: T.small(context).copyWith(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: NeuCard(
              onTap: item.route == null ? null : () => context.push(item.route!),
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: item.done ? AppColors.sageSoft : AppColors.bg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(item.icon,
                      color: item.done ? AppColors.sageDark : AppColors.inkMid, fill: 1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: T.title(context).copyWith(fontSize: 14)),
                      Text(item.sub, style: T.small(context).copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                if (item.done)
                  const Icon(Symbols.check_circle_rounded, color: AppColors.sage, fill: 1)
                else if (item.action != null)
                  NeuPill(
                    color: AppColors.coral,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    child: Text(item.action!,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
