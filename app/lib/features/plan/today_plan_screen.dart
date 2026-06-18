import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/providers/daily_stats_provider.dart';
import '../../core/providers/tasks_provider.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

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

String? _mealTypeFor(String _icon) => null;

({Color accent, Color soft}) _taskColors(String icon) => switch (icon) {
  'wb_sunny'                              => (accent: AppColors.gold,      soft: AppColors.goldSoft),
  'restaurant' || 'lunch_dining'          => (accent: AppColors.coral,     soft: AppColors.coralSoft),
  'water_drop'                            => (accent: AppColors.tealLight,  soft: const Color(0xFFD6EFF8)),
  'directions_run' || 'directions_walk'   => (accent: AppColors.berry,     soft: AppColors.berrySoft),
  'fitness_center'                        => (accent: AppColors.orange,    soft: AppColors.orangeSoft),
  'scale'                                 => (accent: AppColors.sage,      soft: AppColors.sageSoft),
  'bedtime'                               => (accent: AppColors.berry,     soft: AppColors.berrySoft),
  _                                       => (accent: AppColors.inkMid,    soft: AppColors.bg),
};

// ── Main screen ───────────────────────────────────────────────────────────────

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
      backgroundColor: const Color(0xFFF0EEE9),
      body: SafeArea(
        bottom: false,
        child: s.loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ── Gradient header ──────────────────────────────────────
                  Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.orangeGrad,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(children: [
                      Row(children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Day ${s.day} / 84',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          const Text("Today's Plan",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900)),
                        ]),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(todayLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3), width: 1),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.done == s.total && s.total > 0
                                      ? 'All done — amazing! 🎉'
                                      : '${s.done} of ${s.total} tasks done',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: s.total > 0 ? s.done / s.total : 0,
                                    minHeight: 6,
                                    backgroundColor: Colors.white.withOpacity(0.3),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: s.total > 0 ? s.done / s.total : 0,
                                  strokeWidth: 6,
                                  backgroundColor: Colors.white.withOpacity(0.25),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeCap: StrokeCap.round,
                                ),
                                Text(
                                  s.total > 0
                                      ? '${((s.done / s.total) * 100).round()}%'
                                      : '0%',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // ── Day chips ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final d in dayLabels)
                            _DayChip(label: d, today: d == todayLabel),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Task sections ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (s.tasks.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          for (final entry in sections.entries) ...[
                            _SectionHeader(name: entry.key),
                            for (final task in entry.value)
                              _TaskCard(
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
                            const SizedBox(height: 8),
                          ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final color = name == 'Morning'
        ? AppColors.gold
        : name == 'Afternoon'
            ? AppColors.tealLight
            : AppColors.berry;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 4, height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(name.toUpperCase(),
            style: T.label(context).copyWith(
                letterSpacing: 1.2,
                fontSize: 11,
                color: color)),
      ]),
    );
  }
}

// ── Day chip ───────────────────────────────────────────────────────────────────

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.today});
  final String label;
  final bool today;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: today ? 70 : 46,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        gradient: today ? AppColors.orangeGrad : null,
        color: today ? null : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: today ? null : Border.all(color: AppColors.line),
        boxShadow: today
            ? [BoxShadow(color: AppColors.orange.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))]
            : null,
      ),
      child: Center(
        child: Text(
          today ? 'Today' : label,
          style: TextStyle(
              color: today ? Colors.white : AppColors.inkSoft,
              fontWeight: FontWeight.w700,
              fontSize: 12),
        ),
      ),
    );
  }
}

// ── Task card ──────────────────────────────────────────────────────────────────

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task, this.onTap, this.onComplete});
  final TaskItem task;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dailyStatsProvider);
    final c = _taskColors(task.icon);

    // Progress tracking for hydration and movement
    int? progress;
    int? target;
    String? progressLabel;
    if (task.icon == 'water_drop') {
      progress = stats.water;
      target = 8;
      progressLabel = '$progress / 8 glasses';
    } else if (task.icon == 'directions_run' || task.icon == 'directions_walk') {
      progress = stats.steps;
      target = 8000;
      final stepsStr = progress >= 1000
          ? '${(progress / 1000).toStringAsFixed(1)}k'
          : '$progress';
      progressLabel = '$stepsStr / 8k steps';
    }
    final progressPct =
        (target != null && target > 0) ? (progress! / target).clamp(0.0, 1.0) : null;

    final action = task.done ? null : (onTap != null ? 'Start' : 'Done');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          // ── Card background ──
          GestureDetector(
            onTap: task.done ? null : (onTap != null ? onTap : null),
            child: Container(
              decoration: BoxDecoration(
                color: task.done ? c.soft : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: task.done
                        ? c.accent.withOpacity(0.25)
                        : AppColors.line),
                boxShadow: task.done
                    ? null
                    : [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ],
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    // Colored icon box
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: c.soft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_iconFor(task.icon),
                          color: c.accent, fill: 1, size: 22),
                    ),
                    const SizedBox(width: 12),
                    // Title + subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.title,
                              style: T.title(context).copyWith(
                                  fontSize: 14,
                                  color: task.done
                                      ? c.accent
                                      : AppColors.ink)),
                          const SizedBox(height: 3),
                          Row(children: [
                            Text(task.displayTime,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: task.done
                                        ? c.accent.withOpacity(0.7)
                                        : AppColors.inkSoft)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              child: Text('·',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.inkSoft)),
                            ),
                            Expanded(
                              child: Text(task.subtitle,
                                  style: T.small(context)
                                      .copyWith(fontSize: 11),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Action / done indicator
                    if (task.done)
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c.soft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Symbols.check_circle_rounded,
                            color: c.accent, fill: 1, size: 20),
                      )
                    else if (action != null)
                      GestureDetector(
                        // ✅ FIX: Start → navigate only; Done → mark complete
                        onTap: () {
                          if (onTap != null) {
                            onTap!();
                          } else {
                            onComplete?.call();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: c.accent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: c.accent.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Text(action,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ),
                      ),
                  ]),

                  // ── Progress bar (hydration + movement only) ──
                  if (progressPct != null) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: Stack(children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: c.soft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: progressPct,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    c.accent.withOpacity(0.7),
                                    c.accent,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 10),
                      Text(progressLabel!,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: c.accent)),
                    ]),
                    if (progressPct >= 1.0) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Symbols.check_circle_rounded,
                            color: c.accent, size: 14, fill: 1),
                        const SizedBox(width: 4),
                        Text('Goal reached!',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c.accent)),
                      ]),
                    ],
                  ],
                ],
              ),
            ),
          ),
          // ── Left accent bar ──
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                color:
                    task.done ? c.accent.withOpacity(0.5) : c.accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
