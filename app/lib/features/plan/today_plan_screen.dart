import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/providers/tasks_provider.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

IconData _iconFor(String name) {
  const map = <String, IconData>{
    'wb_sunny': Symbols.wb_sunny_rounded,
    'restaurant': Symbols.restaurant_rounded,
    'lunch_dining': Symbols.lunch_dining_rounded,
    'water_drop': Symbols.water_drop_rounded,
    'directions_run': Symbols.directions_run_rounded,
    'directions_walk': Symbols.directions_walk_rounded,
    'scale': Symbols.scale_rounded,
    'fitness_center': Symbols.fitness_center_rounded,
    'bedtime': Symbols.bedtime_rounded,
  };
  return map[name] ?? Symbols.task_alt_rounded;
}

String? _routeFor(String icon) {
  if (icon == 'wb_sunny') return Routes.checkin;
  if (icon == 'scale') return Routes.weighin;
  if (icon == 'restaurant' || icon == 'lunch_dining') return Routes.meal;
  if (icon == 'water_drop') return Routes.hydration;
  if (icon == 'directions_run' || icon == 'directions_walk') return Routes.movement;
  if (icon == 'bedtime') return Routes.reflection;
  return null;
}

// No locked meal type — user picks in the screen.
String? _mealTypeFor(String _icon) => null;

class TodayPlanScreen extends ConsumerWidget {
  const TodayPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(tasksProvider);

    final Map<String, List<TaskItem>> sections = {};
    for (final t in s.tasks) {
      final slot = t.slot.isEmpty
          ? 'Other'
          : t.slot[0].toUpperCase() + t.slot.substring(1);
      sections.putIfAbsent(slot, () => []).add(t);
    }

    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayLabel = dayLabels[DateTime.now().weekday - 1];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: s.loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                children: [
                  Row(children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Day ${s.day}', style: T.small(context)),
                        Text("Today's plan", style: T.h2(context)),
                      ],
                    ),
                    const Spacer(),
                    const NeuIconButton(icon: Symbols.tune_rounded),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 64,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final d in dayLabels)
                          _DayChip(label: d, today: d == todayLabel),
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
                            Text(
                              'Progress · ${s.done} of ${s.total} done',
                              style: T.title(context).copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.done == s.total && s.total > 0
                                  ? 'All done — amazing work today!'
                                  : "Finish ${s.total - s.done} more — you'll hit your target.",
                              style: T.small(context),
                            ),
                          ],
                        ),
                      ),
                      NeuProgressRing(
                        value: s.total > 0 ? s.done / s.total : 0,
                        size: 64,
                        stroke: 8,
                        center: Text(
                          s.total > 0
                              ? '${((s.done / s.total) * 100).round()}%'
                              : '0%',
                          style: T.small(context)
                              .copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  if (s.tasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    for (final entry in sections.entries) ...[
                      Text(entry.key.toUpperCase(),
                          style: T.label(context)),
                      const SizedBox(height: 10),
                      for (final task in entry.value)
                        _TimelineRow(
                          task: task,
                          onTap: _routeFor(task.icon) != null
                              ? () async {
                                  await context.push(_routeFor(task.icon)!,
                                      extra: task.icon == 'bedtime'
                                          ? 'evening'
                                          : _mealTypeFor(task.icon));
                                  ref.read(tasksProvider.notifier).fetch();
                                }
                              : null,
                          onComplete: task.done
                              ? null
                              : () => ref
                                  .read(tasksProvider.notifier)
                                  .complete(task.id),
                        ),
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
      ),
      child: Center(
        child: Text(
          today ? 'Today' : label,
          style: TextStyle(
              color: today ? Colors.white : AppColors.inkSoft,
              fontWeight: FontWeight.w700,
              fontSize: 13),
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.task, this.onTap, this.onComplete});
  final TaskItem task;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final action = task.done ? null : (onTap != null ? 'Start' : 'Done');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(task.displayTime,
                    style: T.small(context).copyWith(
                        fontSize: 12,
                        fontWeight: task.done
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: task.done
                            ? AppColors.sageDark
                            : null)),
                if (task.done && task.completedAt != null)
                  Text('done',
                      style: T.small(context).copyWith(
                          fontSize: 9,
                          color: AppColors.sage,
                          fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: NeuCard(
              onTap: onTap,
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: task.done ? AppColors.sageSoft : AppColors.bg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(_iconFor(task.icon),
                      color:
                          task.done ? AppColors.sageDark : AppColors.inkMid,
                      fill: 1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title,
                          style: T.title(context).copyWith(fontSize: 14)),
                      Text(task.subtitle,
                          style: T.small(context).copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                if (task.done)
                  const Icon(Symbols.check_circle_rounded,
                      color: AppColors.sage, fill: 1)
                else if (action != null)
                  GestureDetector(
                    onTap: () {
                      onComplete?.call();
                      onTap?.call();
                    },
                    child: NeuPill(
                      color: AppColors.coral,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      child: Text(action,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
