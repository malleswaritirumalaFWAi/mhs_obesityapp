import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/providers/daily_stats_provider.dart';
import '../../core/providers/meal_stats_provider.dart';
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

({Color accent, Color soft, LinearGradient grad}) _taskColors(String icon) =>
    switch (icon) {
  'wb_sunny' => (
    accent: const Color(0xFFF7971E),
    soft: AppColors.goldSoft,
    grad: const LinearGradient(
        colors: [Color(0xFFF7971E), Color(0xFFFFD200)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
  ),
  'restaurant' || 'lunch_dining' => (
    accent: const Color(0xFFFF416C),
    soft: AppColors.coralSoft,
    grad: const LinearGradient(
        colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
  ),
  'water_drop' => (
    accent: AppColors.tealLight,
    soft: const Color(0xFFD6EFF8),
    grad: const LinearGradient(
        colors: [Color(0xFF1B4F72), Color(0xFF00B4DB)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
  ),
  'directions_run' || 'directions_walk' => (
    accent: AppColors.orange,
    soft: AppColors.orangeSoft,
    grad: const LinearGradient(
        colors: [Color(0xFFFF6B35), Color(0xFFF7971E)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
  ),
  'fitness_center' => (
    accent: AppColors.orange,
    soft: AppColors.orangeSoft,
    grad: const LinearGradient(
        colors: [Color(0xFFFF6B35), Color(0xFFF7971E)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
  ),
  'scale' => (
    accent: const Color(0xFF11998E),
    soft: AppColors.sageSoft,
    grad: const LinearGradient(
        colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
  ),
  'bedtime' => (
    accent: const Color(0xFF6A11CB),
    soft: AppColors.berrySoft,
    grad: const LinearGradient(
        colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
  ),
  _ => (
    accent: AppColors.inkMid,
    soft: AppColors.bg,
    grad: const LinearGradient(
        colors: [AppColors.inkMid, AppColors.inkSoft],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
  ),
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
      backgroundColor: const Color(0xFFF5F5F5),
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
                                // Goal-based tasks are NEVER manually completable.
                                // They complete automatically via markTasksDoneByIcon
                                // on the backend when the real goal is met.
                                onComplete: null,
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
    final gradient = name == 'Morning'
        ? const LinearGradient(
            colors: [Color(0xFFF7971E), Color(0xFFFFD200)],
            begin: Alignment.centerLeft, end: Alignment.centerRight)
        : name == 'Afternoon'
            ? const LinearGradient(
                colors: [Color(0xFF1B4F72), Color(0xFF00B4DB)],
                begin: Alignment.centerLeft, end: Alignment.centerRight)
            : const LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                begin: Alignment.centerLeft, end: Alignment.centerRight);

    final icon = name == 'Morning'
        ? Symbols.wb_sunny_rounded
        : name == 'Afternoon'
            ? Symbols.wb_cloudy_rounded
            : Symbols.bedtime_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (name == 'Morning'
                      ? const Color(0xFFF7971E)
                      : name == 'Afternoon'
                          ? AppColors.tealLight
                          : const Color(0xFF6A11CB))
                  .withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 16, fill: 1),
          const SizedBox(width: 8),
          Text(name.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.2)),
        ]),
      ),
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

// ── Meal chip (B / L / D indicator) ───────────────────────────────────────────

class _MealChip extends StatelessWidget {
  const _MealChip({required this.label, required this.done});
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: done
            ? Colors.white.withOpacity(0.35)
            : Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(done ? 0.6 : 0.25),
          width: 1,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white.withOpacity(done ? 1.0 : 0.5))),
        if (done) ...[
          const SizedBox(width: 3),
          Icon(Symbols.check_rounded,
              color: Colors.white, size: 10),
        ],
      ]),
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
    final meals = ref.watch(mealStatsProvider);
    final c = _taskColors(task.icon);

    // Progress tracking for hydration, movement, and meals
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
    } else if (task.icon == 'restaurant' || task.icon == 'lunch_dining') {
      if (!meals.loading) {
        progress = meals.mainCount;
        target = 3;
        progressLabel = '${meals.mainCount}/3 meals';
      }
    }
    final progressPct =
        (target != null && target > 0) ? (progress! / target).clamp(0.0, 1.0) : null;

    // Only show Start (navigate). Goal tasks are never manually completable.
    final action = task.done ? null : (onTap != null ? 'Start' : null);

    final isDone = task.done;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: isDone ? null : (onTap != null ? onTap : null),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // ── 3D gradient card ──
              Container(
                decoration: BoxDecoration(
                  gradient: c.grad,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: c.accent.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      // White semi-transparent icon circle
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.35), width: 1.5),
                        ),
                        child: Icon(_iconFor(task.icon),
                            color: Colors.white, fill: 1, size: 26),
                      ),
                      const SizedBox(width: 14),
                      // Title + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(task.title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Text(task.displayTime,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withOpacity(0.8))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                child: Text('·',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.6))),
                              ),
                              Expanded(
                                child: Text(task.subtitle,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.75)),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Action / done
                      if (isDone)
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.5), width: 1.5),
                          ),
                          child: const Icon(Symbols.check_rounded,
                              color: Colors.white, size: 22),
                        )
                      else if (action != null)
                        GestureDetector(
                          onTap: () {
                            if (onTap != null) {
                              onTap!();
                            } else {
                              onComplete?.call();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(action,
                                style: TextStyle(
                                    color: c.accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12)),
                          ),
                        ),
                    ]),

                    // ── Progress bar ──
                    if (progressPct != null) ...[
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progressPct,
                              minHeight: 7,
                              backgroundColor: Colors.white.withOpacity(0.25),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(progressLabel!,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withOpacity(0.9))),
                      ]),
                      // B / L / D chips for the meal task
                      if ((task.icon == 'restaurant' || task.icon == 'lunch_dining') &&
                          !meals.loading) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          _MealChip(label: 'B', done: meals.has('Breakfast')),
                          const SizedBox(width: 6),
                          _MealChip(label: 'L', done: meals.has('Lunch')),
                          const SizedBox(width: 6),
                          _MealChip(label: 'D', done: meals.has('Dinner')),
                          const SizedBox(width: 10),
                          Text(
                            meals.has('Snacks') ? '+ Snack' : 'Snack optional',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.6)),
                          ),
                        ]),
                      ],
                      if (progressPct >= 1.0) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Symbols.check_circle_rounded,
                              color: Colors.white, size: 13, fill: 1),
                          const SizedBox(width: 4),
                          Text('Goal reached!',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withOpacity(0.9))),
                        ]),
                      ],
                    ],
                  ],
                ),
              ),

              // ── Top shine highlight (3D convex effect) ──
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.18),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
