import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/providers/daily_stats_provider.dart';
import '../../core/providers/lessons_provider.dart';
import '../../core/providers/meal_stats_provider.dart';
import '../../core/providers/notifications_provider.dart';
import '../../core/providers/tasks_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../features/group/leaderboard_provider.dart';
import '../../core/router.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/neu.dart';
import '../../core/widgets/neu_card.dart';

// Maps icon string from backend to Flutter IconData.
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

// Returns the route to push when a task is tapped (null = mark done inline).
String? _routeFor(String icon) {
  if (icon == 'wb_sunny') return Routes.checkin;
  if (icon == 'scale') return Routes.weighin;
  if (icon == 'restaurant' || icon == 'lunch_dining') return Routes.meal;
  if (icon == 'water_drop') return Routes.hydration;
  if (icon == 'directions_run' || icon == 'directions_walk') return Routes.movement;
  return null;
}

// No locked meal type — user picks in the screen.
String? _mealTypeFor(String _icon) => null;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionName = ref.watch(sessionProvider).name ?? '';
    final name = ref.watch(userProvider).maybeWhen(
          data: (u) => u.name.isNotEmpty ? u.name : sessionName,
          orElse: () => sessionName,
        );
    final tasksState = ref.watch(tasksProvider);
    final stats = ref.watch(dailyStatsProvider);
    final unreadCount = ref.watch(notificationsProvider).unreadCount;

    final leaderboard = ref.watch(leaderboardProvider);
    final myRank = leaderboard.whenOrNull(
      data: (members) {
        final me = members.where((m) => m.you).firstOrNull;
        return me?.rank;
      },
    );

    final meals = ref.watch(mealStatsProvider);
    final done = tasksState.tasks.where((t) {
      if (t.done) return true;
      if (t.icon == 'water_drop') return stats.water >= 8;
      if (t.icon == 'directions_run' || t.icon == 'directions_walk') return stats.steps >= 8000;
      if ((t.icon == 'restaurant' || t.icon == 'lunch_dining') && !meals.loading) return meals.mainCount >= 3;
      return false;
    }).length;
    final total = tasksState.total;
    final progress = total > 0 ? done / total : 0.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: Column(children: [
                // ── Top bar ──
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        'Hi, ${name.isNotEmpty ? name : 'there'}',
                        style: T.h2(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Day ${tasksState.day} of 84',
                        style: T.small(context),
                      ),
                    ]),
                  ),
                  GestureDetector(
                    onTap: () => context.push(Routes.notifications),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            boxShadow: Neu.small(),
                          ),
                          child: const Icon(Symbols.notifications_rounded,
                              color: AppColors.inkMid, size: 22),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: -2, right: -2,
                            child: Container(
                              width: 18, height: 18,
                              decoration: const BoxDecoration(
                                  color: AppColors.coral, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text(
                                unreadCount > 9 ? '9+' : '$unreadCount',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 9,
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 22),

                // ── Hero progress card ──
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.coral, Color(0xFFFF9A8B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.coral.withValues(alpha: 0.3),
                        offset: const Offset(0, 8),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TODAY'S PROGRESS",
                            style: T.section(context).copyWith(
                                color: Colors.white.withValues(alpha: 0.8)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            total == 0
                                ? 'Loading...'
                                : done == total
                                    ? 'All done!'
                                    : '$done of $total tasks',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                height: 1.1),
                          ),
                          const SizedBox(height: 10),
                          // Thin progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: Colors.white.withValues(alpha: 0.25),
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            done == total && total > 0
                                ? 'Amazing work today!'
                                : 'Keep going, you\'re doing great!',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    // Progress ring
                    SizedBox(
                      width: 80, height: 80,
                      child: Stack(alignment: Alignment.center, children: [
                        SizedBox(
                          width: 80, height: 80,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 7,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900),
                          ),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // ── Stats row ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('DAILY STATS', style: T.section(context)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _StatTile(
                    icon: Symbols.directions_walk_rounded,
                    value: stats.stepsLabel,
                    label: 'Steps',
                    accent: AppColors.coral,
                    onTap: () => _showStepsDialog(context, ref, stats.steps),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _StatTile(
                    icon: Symbols.water_drop_rounded,
                    value: stats.waterLabel,
                    label: 'Water',
                    accent: AppColors.coral,
                    onTap: () => _showWaterSheet(context, ref, stats.water),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _StatTile(
                    icon: Symbols.bedtime_rounded,
                    value: stats.sleepLabel,
                    label: 'Sleep',
                    accent: AppColors.coral,
                    onTap: () => _showSleepDialog(context, ref, stats.sleep),
                  )),
                ]),
              ]),
            ),
            const SizedBox(height: 24),

            // ── Quick actions ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('QUICK ACTIONS', style: T.section(context)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _QuickAction(
                    icon: Symbols.wb_sunny_rounded,
                    label: 'Check-in',
                    accent: AppColors.coral,
                    onTap: () async {
                      await context.push(Routes.checkin);
                      ref.read(tasksProvider.notifier).fetch();
                    },
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _QuickAction(
                    icon: Symbols.restaurant_rounded,
                    label: 'Log Meal',
                    accent: AppColors.coral,
                    onTap: () async {
                      await context.push(Routes.meal);
                      ref.read(tasksProvider.notifier).fetch();
                    },
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _QuickAction(
                    icon: Symbols.menu_book_rounded,
                    label: 'Diet Plan',
                    accent: AppColors.coral,
                    onTap: () => context.push(Routes.dietPlan),
                  )),
                ]),
              ]),
            ),
            const SizedBox(height: 24),

            // ── Today's tasks ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Text('DO THIS NOW', style: T.section(context)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.go(Routes.today),
                  child: Text('See all',
                      style: T.small(context).copyWith(
                          color: AppColors.coral, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: tasksState.loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : NeuCard(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Column(
                        children: List.generate(tasksState.tasks.length, (i) {
                          final task = tasksState.tasks[i];
                          // Check local progress to determine done state,
                          // same as today plan screen — prevents flicker on scroll.
                          bool isDone = task.done;
                          if (!isDone) {
                            if (task.icon == 'water_drop') {
                              isDone = stats.water >= 8;
                            } else if (task.icon == 'directions_run' || task.icon == 'directions_walk') {
                              isDone = stats.steps >= 8000;
                            } else if ((task.icon == 'restaurant' || task.icon == 'lunch_dining') && !meals.loading) {
                              isDone = meals.mainCount >= 3;
                            }
                          }
                          return _TaskRow(
                            icon: _iconFor(task.icon),
                            title: task.title,
                            sub: task.subtitle,
                            done: isDone,
                            action: isDone
                                ? null
                                : (_routeFor(task.icon) != null ? 'Start' : 'Done'),
                            showDivider: i < tasksState.tasks.length - 1,
                            onTap: _routeFor(task.icon) != null
                                ? () async {
                                    await context.push(_routeFor(task.icon)!,
                                        extra: _mealTypeFor(task.icon));
                                    ref.read(tasksProvider.notifier).fetch();
                                  }
                                : null,
                            onAction: isDone
                                ? null
                                : (_routeFor(task.icon) != null
                                    ? () async {
                                        await context.push(_routeFor(task.icon)!,
                                            extra: _mealTypeFor(task.icon));
                                        ref.read(tasksProvider.notifier).fetch();
                                      }
                                    : null),
                          );
                        }),
                      ),
                    ),
            ),
            const SizedBox(height: 24),

            // ── Rank + Weekly progress ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Expanded(
                  child: NeuCard(
                    onTap: () => context.go(Routes.group),
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.coralSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Symbols.emoji_events_rounded,
                            color: AppColors.coral, size: 22, fill: 1),
                      ),
                      const SizedBox(height: 12),
                      Text('YOUR RANK', style: T.section(context)),
                      const SizedBox(height: 4),
                      Text(myRank != null ? '#$myRank' : '#--',
                          style: const TextStyle(
                              color: AppColors.coral, fontSize: 28,
                              fontWeight: FontWeight.w900)),
                    ]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeuCard(
                    onTap: () => context.push(Routes.weeklyProgress),
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.coralSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Symbols.trending_up_rounded,
                            color: AppColors.coral, size: 22),
                      ),
                      const SizedBox(height: 12),
                      Text('THIS WEEK', style: T.section(context)),
                      const SizedBox(height: 4),
                      const Text('Progress',
                          style: TextStyle(
                              color: AppColors.ink, fontSize: 20,
                              fontWeight: FontWeight.w900)),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Coach card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: NeuCard(
                onTap: () => context.go(Routes.chat),
                child: Row(children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                        gradient: AppColors.orangeGrad,
                        borderRadius: BorderRadius.circular(14)),
                    alignment: Alignment.center,
                    child: const Text('P',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('AI Coach Priya',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15,
                              color: AppColors.ink)),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to chat with your coach',
                        style: T.small(context),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  ),
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.coralSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Symbols.arrow_forward_rounded,
                        color: AppColors.coral, size: 18),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // ── Health tip of the day ──
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: _HealthTipCard(),
            ),
            const SizedBox(height: 16),

            // ── Quick links row ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Expanded(child: _LinkTile(
                  icon: Symbols.timer_rounded,
                  label: 'Fasting',
                  accent: AppColors.coral,
                  onTap: () => context.push(Routes.fasting),
                )),
                const SizedBox(width: 10),
                Expanded(child: _LinkTile(
                  icon: Symbols.flag_rounded,
                  label: 'Challenge',
                  accent: AppColors.coral,
                  onTap: () => context.push(Routes.challenge),
                )),
                const SizedBox(width: 10),
                Expanded(child: _LinkTile(
                  icon: Symbols.menu_book_rounded,
                  label: 'Learn',
                  accent: AppColors.coral,
                  onTap: () => context.push(Routes.learning),
                )),
              ]),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ── Steps dialog ──
  void _showStepsDialog(
      BuildContext context, WidgetRef ref, int current) async {
    final controller = TextEditingController(
        text: current > 0 ? current.toString() : '');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Log steps'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'e.g. 8412', suffixText: 'steps'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                final v = int.tryParse(controller.text.trim()) ?? 0;
                Navigator.pop(ctx, v);
              },
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result >= 0) {
      await ref.read(dailyStatsProvider.notifier).updateSteps(result);
      ref.read(tasksProvider.notifier).fetch();
    }
    controller.dispose();
  }

  // ── Water bottom sheet ──
  void _showWaterSheet(
      BuildContext context, WidgetRef ref, int current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _WaterSheet(current: current, ref: ref),
    );
  }

  // ── Sleep dialog ──
  void _showSleepDialog(
      BuildContext context, WidgetRef ref, double current) async {
    final controller = TextEditingController(
        text: current > 0 ? current.toStringAsFixed(1) : '');
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Log sleep'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'e.g. 7.5', suffixText: 'hours'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                final v = double.tryParse(controller.text.trim()) ?? 0;
                Navigator.pop(ctx, v);
              },
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result >= 0) {
      ref.read(dailyStatsProvider.notifier).updateSleep(result);
    }
    controller.dispose();
  }
}

// ── Health tip of the day ──
class _HealthTipCard extends ConsumerWidget {
  const _HealthTipCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipAsync = ref.watch(healthTipProvider);
    return tipAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (tip) {
        if (tip['tip']?.isEmpty ?? true) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.coralSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.coral.withValues(alpha: 0.2)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.coral.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(Symbols.lightbulb_rounded,
                  color: AppColors.coral, size: 20, fill: 1),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TIP OF THE DAY',
                    style: T.section(context).copyWith(color: AppColors.coral)),
                const SizedBox(height: 4),
                Text(tip['tip'] ?? '',
                    style: T.body(context).copyWith(fontSize: 13)),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ── Water bottom sheet widget ──
class _WaterSheet extends ConsumerStatefulWidget {
  const _WaterSheet({required this.current, required this.ref});
  final int current;
  final WidgetRef ref;

  @override
  ConsumerState<_WaterSheet> createState() => _WaterSheetState();
}

class _WaterSheetState extends ConsumerState<_WaterSheet> {
  late int _glasses;

  @override
  void initState() {
    super.initState();
    _glasses = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Water intake', style: T.title(context)),
        const SizedBox(height: 6),
        Text('Tap glasses to update', style: T.small(context)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(8, (i) {
            final filled = i < _glasses;
            return GestureDetector(
              onTap: () => setState(() => _glasses = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Symbols.water_drop_rounded,
                  size: 34,
                  fill: filled ? 1 : 0,
                  color: filled ? AppColors.coral : AppColors.inkSoft,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text('$_glasses of 8 glasses',
            style: T.body(context)
                .copyWith(fontWeight: FontWeight.w700, color: AppColors.coral)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: () async {
              await ref.read(dailyStatsProvider.notifier).updateWater(_glasses);
              ref.read(tasksProvider.notifier).fetch();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      ]),
    );
  }
}

// ── Stat tile (Steps / Water / Sleep) ──
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    this.onTap,
  });
  final IconData icon;
  final String value, label;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: Neu.card(radius: 20, depth: 0.5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20, fill: 1),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: T.small(context).copyWith(fontSize: 11)),
        ]),
      ),
    );
  }
}

// ── Quick action button ──
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: Neu.card(radius: 18, depth: 0.5),
        child: Column(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 24, fill: 1),
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent)),
        ]),
      ),
    );
  }
}

// ── Link tile (Fasting / Challenge / Learn) ──
class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: Neu.card(radius: 18, depth: 0.5),
        child: Column(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 22, fill: 1),
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkMid)),
        ]),
      ),
    );
  }
}

// ── Task row (inside shared card) ──
class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.icon,
    required this.title,
    required this.sub,
    this.done = false,
    this.action,
    this.showDivider = true,
    this.onTap,
    this.onAction,
  });
  final IconData icon;
  final String title, sub;
  final bool done, showDivider;
  final String? action;
  final VoidCallback? onTap, onAction;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: done
                    ? AppColors.coralSoft
                    : AppColors.coralSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: done ? AppColors.coral : AppColors.coral,
                  size: 20, fill: 1),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: done ? AppColors.inkSoft : AppColors.ink,
                          decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
                          decorationColor: done ? AppColors.inkSoft : null,
                          decorationThickness: 2)),
                  Text(sub, style: T.small(context).copyWith(fontSize: 12)),
                ],
              ),
            ),
            if (done)
              const Icon(Symbols.check_circle_rounded,
                  color: AppColors.coral, fill: 1, size: 22)
            else if (action != null)
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.coral,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(action!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ),
          ]),
        ),
      ),
      if (showDivider)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1, color: AppColors.line.withValues(alpha: 0.6)),
        ),
    ]);
  }
}
