import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/daily_stats_provider.dart';
import '../../core/providers/meal_stats_provider.dart';
import '../../core/providers/tasks_provider.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/neu.dart';
import '../../core/widgets/neu_card.dart';

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

class TodayPlanScreen extends ConsumerStatefulWidget {
  const TodayPlanScreen({super.key});

  @override
  ConsumerState<TodayPlanScreen> createState() => _TodayPlanScreenState();
}

class _TodayPlanScreenState extends ConsumerState<TodayPlanScreen> {
  // null = viewing today; positive = offset into the past (1 = yesterday, etc.)
  int _dayOffset = 0;
  List<TaskItem>? _historyTasks;
  bool _historyLoading = false;

  Future<void> _loadDay(int offset, int todayProgramDay, ApiClient api) async {
    if (offset == 0) {
      setState(() { _dayOffset = 0; _historyTasks = null; });
      return;
    }
    setState(() { _dayOffset = offset; _historyLoading = true; });
    try {
      final targetDay = (todayProgramDay - offset).clamp(1, 84);
      final res = await api.getJson('/today?day=$targetDay');
      final rawTasks = (res['tasks'] as List?) ?? [];
      final tasks = rawTasks
          .map((t) => TaskItem.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList();
      if (mounted) setState(() { _historyTasks = tasks; _historyLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _historyTasks = []; _historyLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(tasksProvider);
    final api = ref.read(apiClientProvider);

    final displayTasks = _dayOffset == 0 ? s.tasks : (_historyTasks ?? []);
    final Map<String, List<TaskItem>> sections = {};
    for (final t in displayTasks) {
      final slot = t.slot.isEmpty
          ? 'Other'
          : t.slot[0].toUpperCase() + t.slot.substring(1);
      sections.putIfAbsent(slot, () => []).add(t);
    }

    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayWeekday = DateTime.now().weekday - 1; // 0=Mon … 6=Sun
    final todayLabel = dayLabels[todayWeekday];

    // Days up to and including today are selectable; future days are not.
    // offset 0 = today, 1 = yesterday, etc.
    int offsetFor(String label) {
      final idx = dayLabels.indexOf(label);
      return todayWeekday - idx; // positive for past, negative for future
    }

    final isLoading = s.loading || (_dayOffset != 0 && _historyLoading);
    final headerDone = _dayOffset == 0 ? s.done : displayTasks.where((t) => t.done).length;
    final headerTotal = _dayOffset == 0 ? s.total : displayTasks.length;
    final allDone = headerTotal > 0 && headerDone >= headerTotal;
    final dayNum = _dayOffset == 0 ? s.day : (s.day - _dayOffset).clamp(1, 84);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ── Neumorphic header ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(children: [
                      Row(children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Day $dayNum / 84',
                              style: const TextStyle(
                                  color: AppColors.inkMid,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          Text(_dayOffset == 0 ? "Today's Plan" : 'Past Day',
                              style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900)),
                        ]),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _dayOffset == 0 ? AppColors.coralSoft : AppColors.bg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(todayLabel,
                              style: TextStyle(
                                  color: _dayOffset == 0 ? AppColors.coral : AppColors.inkSoft,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: Neu.card(radius: 20),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  allDone
                                      ? 'All done — amazing!'
                                      : '$headerDone of $headerTotal tasks done',
                                  style: TextStyle(
                                      color: allDone ? AppColors.sageDark : AppColors.ink,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: headerTotal > 0
                                        ? (headerDone / headerTotal).clamp(0.0, 1.0)
                                        : 0,
                                    minHeight: 6,
                                    backgroundColor: AppColors.line,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        allDone ? AppColors.sage : AppColors.coral),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // At 100%: solid checkmark circle to avoid stroke-cap overlap
                          if (allDone)
                            Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                color: AppColors.sageSoft,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Symbols.check_rounded,
                                  color: AppColors.sageDark, size: 30, fill: 1),
                            )
                          else
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: headerTotal > 0
                                        ? (headerDone / headerTotal).clamp(0.0, 1.0)
                                        : 0,
                                    strokeWidth: 6,
                                    backgroundColor: AppColors.line,
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                        AppColors.coral),
                                    strokeCap: StrokeCap.round,
                                  ),
                                  Text(
                                    headerTotal > 0
                                        ? '${((headerDone / headerTotal) * 100).round()}%'
                                        : '0%',
                                    style: const TextStyle(
                                        color: AppColors.ink,
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
                      height: 60,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final d in dayLabels)
                            _DayChip(
                              label: d,
                              isToday: d == todayLabel,
                              isSelected: offsetFor(d) == _dayOffset,
                              isFuture: offsetFor(d) < 0,
                              onTap: offsetFor(d) < 0
                                  ? null
                                  : () => _loadDay(offsetFor(d), s.day, api),
                            ),
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
                        if (displayTasks.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text('No tasks for this day.',
                                  style: TextStyle(color: AppColors.inkSoft)),
                            ),
                          )
                        else
                          for (final entry in sections.entries) ...[
                            _SectionHeader(name: entry.key),
                            for (final task in entry.value)
                              _TaskCard(
                                task: task,
                                // Past-day tasks are read-only
                                onTap: _dayOffset != 0 || _routeFor(task.icon) == null
                                    ? null
                                    : () async {
                                        await context.push(_routeFor(task.icon)!,
                                            extra: task.icon == 'bedtime'
                                                ? 'evening'
                                                : _mealTypeFor(task.icon));
                                        ref.read(tasksProvider.notifier).fetch();
                                      },
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
    final color = name == 'Morning'
        ? AppColors.gold
        : name == 'Afternoon'
            ? AppColors.coral
            : AppColors.berry;
    final softColor = name == 'Morning'
        ? AppColors.goldSoft
        : name == 'Afternoon'
            ? AppColors.coralSoft
            : AppColors.berrySoft;

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
          color: softColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 16, fill: 1),
          const SizedBox(width: 8),
          Text(name.toUpperCase(),
              style: TextStyle(
                  color: color,
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
  const _DayChip({
    required this.label,
    required this.isToday,
    required this.isSelected,
    required this.isFuture,
    this.onTap,
  });
  final String label;
  final bool isToday;
  final bool isSelected;
  final bool isFuture;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = isSelected
        ? (isToday ? AppColors.coral : AppColors.berry)
        : isFuture
            ? AppColors.bg
            : AppColors.surface;
    final Color textColor = isSelected
        ? Colors.white
        : isFuture
            ? AppColors.line
            : AppColors.inkSoft;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isToday ? 70 : 46,
        margin: const EdgeInsets.only(right: 10, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected ? Neu.raised(depth: 0.5) : Neu.small(),
        ),
        child: Center(
          child: Text(
            isToday ? 'Today' : label,
            style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 12),
          ),
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
        color: done ? AppColors.sageSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: done ? AppColors.sage : AppColors.line,
          width: 1,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: done ? AppColors.sageDark : AppColors.inkSoft)),
        if (done) ...[
          const SizedBox(width: 3),
          const Icon(Symbols.check_rounded,
              color: AppColors.sageDark, size: 10),
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

    // Hide Start if task is done OR if the local progress already meets the goal
    // (backend may not have marked it done yet due to async lag).
    final goalReached = progressPct != null && progressPct >= 1.0;
    final action = (task.done || goalReached) ? null : (onTap != null ? 'Start' : null);

    final isDone = task.done || goalReached;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: isDone ? null : (onTap != null ? onTap : null),
        child: NeuCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Accent icon circle
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDone ? AppColors.sageSoft : c.soft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_iconFor(task.icon),
                      color: isDone ? AppColors.sageDark : c.accent,
                      fill: 1, size: 26),
                ),
                const SizedBox(width: 14),
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title,
                          style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text(task.displayTime,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkSoft)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: Text('·',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.inkSoft)),
                        ),
                        Expanded(
                          child: Text(task.subtitle,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.inkSoft),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action / done
                if (isDone)
                  const Icon(Symbols.check_circle_rounded,
                      color: AppColors.sage, fill: 1, size: 28)
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
                        color: AppColors.coral,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(action,
                          style: const TextStyle(
                              color: Colors.white,
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
                        backgroundColor: AppColors.line,
                        valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(progressLabel!,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSoft)),
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
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.inkSoft),
                    ),
                  ]),
                ],
                if (progressPct >= 1.0) ...[
                  const SizedBox(height: 6),
                  const Row(children: [
                    Icon(Symbols.check_circle_rounded,
                        color: AppColors.sage, size: 13, fill: 1),
                    SizedBox(width: 4),
                    Text('Goal reached!',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.sage)),
                  ]),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
