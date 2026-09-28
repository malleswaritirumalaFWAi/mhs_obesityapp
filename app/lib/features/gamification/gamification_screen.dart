import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/providers/gamification_provider.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class GamificationScreen extends ConsumerStatefulWidget {
  const GamificationScreen({super.key});
  @override
  ConsumerState<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends ConsumerState<GamificationScreen> {
  @override
  void initState() {
    super.initState();
    // Always reload fresh XP/freeze data when this screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gamificationProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gamificationProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            // ── Top bar ──
            Row(
              children: [
                NeuIconButton(
                  icon: Symbols.arrow_back_rounded,
                  onTap: () => context.pop(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Progress', style: T.h2(context)),
                      const SizedBox(height: 2),
                      Text('XP, levels & achievements',
                          style: T.small(context)),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Symbols.emoji_events_rounded,
                      color: AppColors.coral, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Level card ──
            NeuCard(
              depth: 0.5,
              color: AppColors.coralSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(g.level.emoji,
                              style: const TextStyle(fontSize: 30)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.level.label,
                                style: T.h2(context)
                                    .copyWith(color: AppColors.coral)),
                            const SizedBox(height: 2),
                            Text('${g.totalXp} total XP',
                                style: T.body(context)
                                    .copyWith(color: AppColors.coral)),
                          ],
                        ),
                      ),
                      if (g.royalRank != null)
                        NeuPill(
                          color: Colors.white.withValues(alpha: 0.7),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Symbols.military_tech_rounded,
                                  color: AppColors.coral, size: 16),
                              const SizedBox(width: 4),
                              Text('Royal #${g.royalRank}',
                                  style: const TextStyle(
                                      color: AppColors.coral,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (g.level.nextThreshold != null) ...[
                    const SizedBox(height: 18),
                    Text('NEXT LEVEL',
                        style: T.section(context)
                            .copyWith(color: AppColors.coral)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: g.level.progressToNext != null &&
                                g.level.nextThreshold != null
                            ? (g.level.progressToNext! /
                                    (g.level.nextThreshold! -
                                        g.totalXp +
                                        g.level.progressToNext!))
                                .clamp(0.0, 1.0)
                            : 0,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.6),
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.coral),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                        '${g.level.progressToNext ?? 0} / ${g.level.nextThreshold} XP',
                        style: T.small(context)
                            .copyWith(fontSize: 12, color: AppColors.coral)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Stats row ──
            Text('STATS', style: T.section(context)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _StatTile(
                  icon: Symbols.bolt_rounded,
                  iconColor: AppColors.coral,
                  iconBg: AppColors.coral.withValues(alpha: 0.12),
                  label: 'Weekly XP',
                  value: '${g.xp}',
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatTile(
                  icon: Symbols.local_fire_department_rounded,
                  iconColor: AppColors.coral,
                  iconBg: AppColors.coral.withValues(alpha: 0.12),
                  label: 'Streak',
                  value: '${g.streak}d',
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatTile(
                  icon: Symbols.trophy_rounded,
                  iconColor: AppColors.coral,
                  iconBg: AppColors.coral.withValues(alpha: 0.12),
                  label: 'Rank',
                  value: g.royalRank != null ? '#${g.royalRank}' : '--',
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatTile(
                  icon: Symbols.ac_unit_rounded,
                  iconColor: AppColors.coral,
                  iconBg: AppColors.coral.withValues(alpha: 0.12),
                  label: 'Freezes',
                  value: '${g.streakFreezes}',
                )),
              ],
            ),
            const SizedBox(height: 24),

            // ── Streak protection ──
            Text('STREAK PROTECTION', style: T.section(context)),
            const SizedBox(height: 12),
            NeuCard(
              depth: 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Symbols.ac_unit_rounded,
                            color: AppColors.coral, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${g.streakFreezes} freeze${g.streakFreezes != 1 ? 's' : ''} available',
                                style:
                                    T.title(context).copyWith(fontSize: 15)),
                            const SizedBox(height: 2),
                            Text('Earn 1 per 7-day streak, or buy with XP',
                                style: T.small(context)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: _ActionButton(
                        label: 'Use Freeze',
                        icon: Symbols.shield_rounded,
                        color: g.streakFreezes > 0
                            ? AppColors.coral
                            : AppColors.inkSoft,
                        onTap: g.streakFreezes > 0
                            ? () async {
                                final ok = await ref
                                    .read(gamificationProvider.notifier)
                                    .useFreeze();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(ok
                                        ? 'Streak freeze used!'
                                        : 'No freezes available'),
                                    backgroundColor:
                                        ok ? AppColors.coral : AppColors.coral,
                                  ));
                                }
                              }
                            : null,
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _ActionButton(
                        label: 'Buy (500 XP)',
                        icon: Symbols.shopping_cart_rounded,
                        color: g.totalXp >= 500
                            ? AppColors.coral
                            : AppColors.inkSoft,
                        onTap: g.totalXp >= 500
                            ? () async {
                                final ok = await ref
                                    .read(gamificationProvider.notifier)
                                    .buyFreeze();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(ok
                                        ? 'Freeze purchased! -500 XP'
                                        : 'Not enough XP'),
                                    backgroundColor:
                                        ok ? AppColors.coral : AppColors.inkMid,
                                  ));
                                }
                              }
                            : null,
                      )),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Points store ──
            Text('POINTS STORE', style: T.section(context)),
            const SizedBox(height: 12),
            NeuCard(
              depth: 0.5,
              onTap: () => context.push(Routes.pointsStore),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.coral.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Symbols.storefront_rounded,
                        color: AppColors.coral, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Redeem your XP',
                            style: T.title(context).copyWith(fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('Streak freezes, double XP, cheat meal passes',
                            style: T.small(context)),
                      ],
                    ),
                  ),
                  const Icon(Symbols.chevron_right_rounded,
                      color: AppColors.inkSoft),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Level tiers ──
            Text('LEVEL TIERS', style: T.section(context)),
            const SizedBox(height: 12),
            for (final tier in [
              (Symbols.hexagon_rounded, 'Bronze', '0 XP', AppColors.coral),
              (Symbols.hexagon_rounded, 'Silver', '1,000 XP', AppColors.inkSoft),
              (Symbols.hexagon_rounded, 'Gold', '3,000 XP', AppColors.coral),
              (Symbols.diamond_rounded, 'Platinum', '6,000 XP', AppColors.coral),
              (Symbols.diamond_rounded, 'Diamond', '10,000 XP', AppColors.coral),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NeuCard(
                  depth: 0.5,
                  color: g.level.label == tier.$2 ? AppColors.coralSoft : null,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: tier.$4.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(tier.$1, color: tier.$4, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Text(tier.$2,
                              style:
                                  T.title(context).copyWith(fontSize: 15))),
                      Text(tier.$3,
                          style:
                              T.small(context).copyWith(color: tier.$4)),
                      if (g.level.label == tier.$2) ...[
                        const SizedBox(width: 10),
                        NeuPill(
                          color: AppColors.coral.withValues(alpha: 0.15),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          child: const Text('YOU',
                              style: TextStyle(
                                  color: AppColors.coral,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.8)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Stat tile with icon background ──
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      depth: 0.5,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: T.h2(context).copyWith(fontSize: 18, color: iconColor)),
          const SizedBox(height: 2),
          Text(label,
              style: T.small(context).copyWith(fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Action button with icon ──
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    this.icon,
    this.onTap,
  });
  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: T.title(context).copyWith(fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }
}
