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

class GamificationScreen extends ConsumerWidget {
  const GamificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gamificationProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.orangeGrad,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Symbols.arrow_back_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Progress',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                      Text('XP, levels & achievements',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const Text('🏆', style: TextStyle(fontSize: 26)),
              ]),
            ),
            const SizedBox(height: 20),

            // Level card
            NeuCard(
              color: AppColors.goldSoft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(g.level.emoji, style: const TextStyle(fontSize: 40)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(g.level.label, style: T.h2(context).copyWith(color: AppColors.goldDark)),
                    Text('${g.totalXp} total XP', style: T.body(context).copyWith(color: AppColors.goldDark)),
                  ])),
                  if (g.royalRank != null)
                    NeuPill(
                      color: AppColors.coralSoft,
                      child: Text('🏅 Royal #${g.royalRank}',
                        style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                ]),
                if (g.level.nextThreshold != null) ...[
                  const SizedBox(height: 16),
                  Text('Progress to next level', style: T.small(context)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: g.level.progressToNext != null && g.level.nextThreshold != null
                        ? (g.level.progressToNext! / (g.level.nextThreshold! - g.totalXp + g.level.progressToNext!)).clamp(0.0, 1.0)
                        : 0,
                      minHeight: 10,
                      backgroundColor: Colors.white,
                      valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${g.level.progressToNext ?? 0} / ${g.level.nextThreshold} XP',
                    style: T.small(context).copyWith(fontSize: 11)),
                ],
              ]),
            ),
            const SizedBox(height: 16),

            // Stats row
            Row(children: [
              Expanded(child: _StatCard(emoji: '🔥', label: 'Streak', value: '${g.streak}d')),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(emoji: '❄️', label: 'Freezes', value: '${g.streakFreezes}')),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(emoji: '⚡', label: 'Weekly XP', value: '${g.xp}')),
            ]),
            const SizedBox(height: 20),

            // Streak freeze actions
            Text('Streak Protection', style: T.title(context)),
            const SizedBox(height: 12),
            NeuCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('❄️', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${g.streakFreezes} freeze${g.streakFreezes != 1 ? 's' : ''} available',
                      style: T.title(context).copyWith(fontSize: 15)),
                    Text('Earn 1 per 7-day streak, or buy with XP', style: T.small(context)),
                  ])),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _ActionButton(
                    label: 'Use Freeze',
                    color: g.streakFreezes > 0 ? AppColors.berry : AppColors.inkSoft,
                    onTap: g.streakFreezes > 0 ? () async {
                      final ok = await ref.read(gamificationProvider.notifier).useFreeze();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? '❄️ Streak freeze used!' : 'No freezes available'),
                          backgroundColor: ok ? AppColors.berry : AppColors.coral,
                        ));
                      }
                    } : null,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _ActionButton(
                    label: 'Buy (500 XP)',
                    color: g.xp >= 500 ? AppColors.coral : AppColors.inkSoft,
                    onTap: g.xp >= 500 ? () async {
                      final ok = await ref.read(gamificationProvider.notifier).buyFreeze();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? '❄️ Freeze purchased! -500 XP' : 'Not enough XP'),
                          backgroundColor: ok ? AppColors.coral : AppColors.inkMid,
                        ));
                      }
                    } : null,
                  )),
                ]),
              ]),
            ),
            const SizedBox(height: 20),

            // Points store
            Text('Points Store', style: T.title(context)),
            const SizedBox(height: 12),
            NeuCard(
              onTap: () => context.push(Routes.pointsStore),
              child: Row(children: [
                const Text('🛍️', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Redeem your XP', style: T.title(context).copyWith(fontSize: 15)),
                  Text('Streak freezes, double XP, cheat meal passes', style: T.small(context)),
                ])),
                const Icon(Symbols.chevron_right_rounded, color: AppColors.inkSoft),
              ]),
            ),
            const SizedBox(height: 20),

            // Level tiers
            Text('Level tiers', style: T.title(context)),
            const SizedBox(height: 12),
            for (final tier in [
              ('🥉', 'Bronze',   '0 XP',      '0+'),
              ('🥈', 'Silver',   '1,000 XP',  '1K+'),
              ('🥇', 'Gold',     '3,000 XP',  '3K+'),
              ('💎', 'Platinum', '6,000 XP',  '6K+'),
              ('👑', 'Diamond',  '10,000 XP', '10K+'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NeuCard(
                  color: g.level.label == tier.$2 ? AppColors.goldSoft : null,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Text(tier.$1, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 14),
                    Expanded(child: Text(tier.$2, style: T.title(context).copyWith(fontSize: 15))),
                    Text(tier.$3, style: T.small(context).copyWith(color: AppColors.goldDark)),
                    if (g.level.label == tier.$2) ...[
                      const SizedBox(width: 8),
                      const NeuPill(color: AppColors.goldSoft, child: Text('YOU',
                        style: TextStyle(color: AppColors.goldDark, fontWeight: FontWeight.w800, fontSize: 10))),
                    ],
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.emoji, required this.label, required this.value});
  final String emoji, label, value;
  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(14),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 6),
        Text(value, style: T.h2(context).copyWith(fontSize: 20)),
        Text(label, style: T.small(context).copyWith(fontSize: 11)),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.color, this.onTap});
  final String label;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(child: Text(label, style: T.title(context).copyWith(fontSize: 13, color: color))),
      ),
    );
  }
}
