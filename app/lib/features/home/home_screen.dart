import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/providers/daily_stats_provider.dart';
import '../../core/providers/lessons_provider.dart';
import '../../core/providers/notifications_provider.dart';
import '../../core/providers/tasks_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/router.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

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

    final done = tasksState.done;
    final total = tasksState.total;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Gradient header ──
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.orangeGrad,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  // Top bar
                  Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        'Hi, ${name.isNotEmpty ? name : 'there'} 👋',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Day ${tasksState.day} / 84',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ]),
                    const Spacer(),
                    // Notification bell
                    GestureDetector(
                      onTap: () => context.push(Routes.notifications),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Symbols.notifications_rounded,
                                color: Colors.white, size: 22),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              top: -2, right: -2,
                              child: Container(
                                width: 16, height: 16,
                                decoration: const BoxDecoration(
                                    color: Colors.white, shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: Text(
                                  unreadCount > 9 ? '9+' : '$unreadCount',
                                  style: const TextStyle(
                                      color: AppColors.orange, fontSize: 9,
                                      fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  // Hero progress card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.35), width: 1.5),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Today's Progress",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              total == 0
                                  ? 'Loading…'
                                  : done == total
                                      ? 'All done! 🎉'
                                      : '$done of $total tasks done',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 10),
                            if (done == total && total > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('🔥 On a roll!',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12)),
                              )
                            else
                              Text(
                                'Keep going, you\'re doing great!',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Big progress ring
                      SizedBox(
                        width: 90, height: 90,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 90, height: 90,
                              child: CircularProgressIndicator(
                                value: total > 0 ? done / total : 0,
                                strokeWidth: 8,
                                backgroundColor: Colors.white.withOpacity(0.25),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$done/$total',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900),
                                ),
                                const Text('DONE',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Quick action tiles ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Quick Actions', style: T.title(context)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _QuickAction(
                      emoji: '☀️',
                      label: 'Check-in',
                      color: AppColors.orange,
                      soft: AppColors.orangeSoft,
                      onTap: () async {
                        await context.push(Routes.checkin);
                        ref.read(tasksProvider.notifier).fetch();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                      emoji: '🍽️',
                      label: 'Log Meal',
                      color: AppColors.sage,
                      soft: AppColors.sageSoft,
                      onTap: () async {
                        await context.push(Routes.meal);
                        ref.read(tasksProvider.notifier).fetch();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                      emoji: '⚖️',
                      label: 'Weigh-in',
                      color: AppColors.teal,
                      soft: const Color(0xFFE8F4F8),
                      onTap: () async {
                        await context.push(Routes.weighin);
                        ref.read(tasksProvider.notifier).fetch();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                      emoji: '🥗',
                      label: 'Diet Plan',
                      color: AppColors.goldDark,
                      soft: AppColors.goldSoft,
                      onTap: () => context.push(Routes.dietPlan),
                    ),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Stats row ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(
                  child: _Stat(
                    icon: Symbols.directions_walk_rounded,
                    color: AppColors.orange,
                    label: 'Steps',
                    value: stats.stepsLabel,
                    sub: stats.stepsSub,
                    onTap: () => _showStepsDialog(context, ref, stats.steps),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Stat(
                    icon: Symbols.water_drop_rounded,
                    color: AppColors.teal,
                    label: 'Water',
                    value: stats.waterLabel,
                    sub: stats.waterSub,
                    onTap: () => _showWaterSheet(context, ref, stats.water),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Stat(
                    icon: Symbols.bedtime_rounded,
                    color: AppColors.berry,
                    label: 'Sleep',
                    value: stats.sleepLabel,
                    sub: stats.sleepSub,
                    onTap: () => _showSleepDialog(context, ref, stats.sleep),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 22),

            // ── Today's plan ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Text("Today's Plan", style: T.title(context)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.go(Routes.today),
                  child: Text('See all →',
                      style: T.small(context).copyWith(
                          color: AppColors.orange,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: tasksState.loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      children: tasksState.tasks.map((task) => _Task(
                            icon: _iconFor(task.icon),
                            title: task.title,
                            sub: task.subtitle,
                            done: task.done,
                            action: task.done
                                ? null
                                : (_routeFor(task.icon) != null ? 'Start' : 'Done'),
                            onTap: _routeFor(task.icon) != null
                                ? () async {
                                    await context.push(_routeFor(task.icon)!,
                                        extra: _mealTypeFor(task.icon));
                                    ref.read(tasksProvider.notifier).fetch();
                                  }
                                : null,
                            onAction: task.done
                                ? null
                                : () async {
                                    ref.read(tasksProvider.notifier).complete(task.id);
                                    final route = _routeFor(task.icon);
                                    if (route != null) {
                                      await context.push(route,
                                          extra: _mealTypeFor(task.icon));
                                      ref.read(tasksProvider.notifier).fetch();
                                    }
                                  },
                          )).toList(),
                    ),
            ),

            const SizedBox(height: 20),

            // ── Rank + Weekly progress ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.go(Routes.group),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: AppColors.orangeGrad,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.orange.withOpacity(0.3),
                              blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('🏆', style: TextStyle(fontSize: 28)),
                        const SizedBox(height: 8),
                        const Text('Your Rank',
                            style: TextStyle(
                                color: Colors.white, fontSize: 12,
                                fontWeight: FontWeight.w500)),
                        const Text('#12',
                            style: TextStyle(
                                color: Colors.white, fontSize: 28,
                                fontWeight: FontWeight.w900)),
                        const Text('Top 5% this week',
                            style: TextStyle(
                                color: Colors.white, fontSize: 11,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push(Routes.weeklyProgress),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: AppColors.tealGrad,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.teal.withOpacity(0.3),
                              blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('📈', style: TextStyle(fontSize: 28)),
                        const SizedBox(height: 8),
                        const Text('This Week',
                            style: TextStyle(
                                color: Colors.white, fontSize: 12,
                                fontWeight: FontWeight.w500)),
                        const Text('Progress',
                            style: TextStyle(
                                color: Colors.white, fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        const Text('Tap to see summary',
                            style: TextStyle(
                                color: Colors.white, fontSize: 11,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Coach card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => context.go(Routes.chat),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: const BoxDecoration(
                          gradient: AppColors.orangeGrad, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Text('M',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Coach Mira',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15,
                                color: Color(0xFF1A1A2E))),
                        Text(
                          'You crushed steps today. Try a 10-min stretch before bed 🌙',
                          style: T.small(context),
                        ),
                      ]),
                    ),
                    const Icon(Symbols.arrow_forward_rounded,
                        color: AppColors.orange),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Health tip of the day ──
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _HealthTipCard(),
            ),
            const SizedBox(height: 16),

            // ── Quick links row ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(
                  child: _LinkCard(
                    emoji: '⏱️',
                    label: 'Fasting',
                    sub: 'Start window',
                    color: AppColors.berry,
                    soft: AppColors.berrySoft,
                    onTap: () => context.push(Routes.fasting),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LinkCard(
                    emoji: '🎯',
                    label: 'Challenge',
                    sub: 'This week',
                    color: AppColors.gold,
                    soft: AppColors.goldSoft,
                    onTap: () => context.push(Routes.challenge),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LinkCard(
                    emoji: '📚',
                    label: 'Learn',
                    sub: 'Lessons',
                    color: AppColors.teal,
                    soft: const Color(0xFFE8F4F8),
                    onTap: () => context.push(Routes.learning),
                  ),
                ),
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
      ref.read(dailyStatsProvider.notifier).updateSteps(result);
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
  const _HealthTipCard({super.key});

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
            color: AppColors.sageSoft,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(children: [
            const Text('💡', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Tip of the day · ${tip['category']}',
                    style: T.small(context).copyWith(
                        color: AppColors.sageDark, fontSize: 11)),
                const SizedBox(height: 4),
                Text(tip['tip'] ?? '',
                    style: T.body(context)
                        .copyWith(color: AppColors.sageDark)),
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
        Text('Tap glasses to update · target 8/day',
            style: T.small(context)),
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
                  color: filled ? AppColors.sage : AppColors.inkSoft,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text('$_glasses of 8 glasses',
            style: T.body(context)
                .copyWith(fontWeight: FontWeight.w700, color: AppColors.sage)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: () {
              ref.read(dailyStatsProvider.notifier).updateWater(_glasses);
              Navigator.pop(context);
            },
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      ]),
    );
  }
}

// ── Stat card ──
class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20, fill: 1),
            ),
            const SizedBox(height: 10),
            Text(label, style: T.small(context).copyWith(fontSize: 11)),
            Text(value, style: T.title(context).copyWith(fontSize: 18)),
            Text(sub, style: T.small(context).copyWith(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Quick action tile ──
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.emoji,
    required this.label,
    required this.color,
    required this.soft,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final Color color;
  final Color soft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
            child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ]),
      ),
    );
  }
}

// ── Small link card ──
class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.emoji,
    required this.label,
    required this.sub,
    required this.color,
    required this.soft,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final String sub;
  final Color color;
  final Color soft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(label, style: T.small(context).copyWith(fontSize: 11)),
          Text(sub,
              style: T.title(context)
                  .copyWith(fontSize: 13, color: color)),
        ]),
      ),
    );
  }
}

// ── Task card ──
class _Task extends StatelessWidget {
  const _Task({
    required this.icon,
    required this.title,
    required this.sub,
    this.done = false,
    this.action,
    this.onTap,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String sub;
  final bool done;
  final String? action;
  final VoidCallback? onTap;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.sageSoft
                      : AppColors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon,
                    color: done ? AppColors.sageDark : AppColors.orange,
                    fill: 1),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: T.title(context).copyWith(fontSize: 15,
                            color: const Color(0xFF1A1A2E))),
                    Text(sub, style: T.small(context)),
                  ],
                ),
              ),
              if (done)
                const Icon(Symbols.check_circle_rounded,
                    color: AppColors.sage, fill: 1)
              else if (action != null)
                GestureDetector(
                  onTap: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: AppColors.orangeGrad,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(action!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
