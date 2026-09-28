import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/providers/notifications_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

const _typeIcons = <String, IconData>{
  'badge': Symbols.emoji_events_rounded,
  'streak_risk': Symbols.local_fire_department_rounded,
  'combo_bonus': Symbols.restaurant_rounded,
  'perfect_day': Symbols.stars_rounded,
  'weekly_winner': Symbols.emoji_events_rounded,
  'challenge_complete': Symbols.military_tech_rounded,
  'diet_plan': Symbols.menu_book_rounded,
  'rank_change': Symbols.leaderboard_rounded,
};

const _typeColors = <String, Color>{
  'badge': AppColors.coral,
  'streak_risk': AppColors.coral,
  'combo_bonus': AppColors.coral,
  'perfect_day': AppColors.coral,
  'weekly_winner': AppColors.coral,
  'challenge_complete': AppColors.coral,
  'diet_plan': AppColors.coral,
  'rank_change': AppColors.coral,
};

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: NeuCard(
                depth: 0.5,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Symbols.arrow_back_rounded,
                        color: AppColors.inkMid, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notifications',
                            style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        Text('Stay updated on your progress',
                            style: TextStyle(
                                color: AppColors.inkSoft, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (state.unreadCount > 0)
                    GestureDetector(
                      onTap: () => ref.read(notificationsProvider.notifier).readAll(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.coralSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('Mark all read',
                            style: TextStyle(
                                color: AppColors.coral,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    )
                  else
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.coral.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Symbols.notifications_rounded,
                          color: AppColors.coral, size: 20, fill: 1),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('ALL NOTIFICATIONS', style: T.section(context)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : state.items.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Symbols.notifications_off_rounded,
                            color: AppColors.coral, size: 20, fill: 1),
                      ),
                      const SizedBox(height: 12),
                      Text('All caught up!', style: T.body(context)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: state.items.length,
                      itemBuilder: (_, i) {
                        final n = state.items[i];
                        final icon = _typeIcons[n.type] ?? Symbols.info_rounded;
                        final color = _typeColors[n.type] ?? AppColors.coral;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: NeuCard(
                            depth: 0.5,
                            padding: const EdgeInsets.all(14),
                            color: n.read ? null : color.withValues(alpha: 0.05),
                            child: Row(children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: color, size: 20, fill: 1),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Text(n.title,
                                    style: T.title(context).copyWith(fontSize: 14))),
                                  if (!n.read)
                                    Container(width: 8, height: 8,
                                      decoration: const BoxDecoration(color: AppColors.coral, shape: BoxShape.circle)),
                                ]),
                                const SizedBox(height: 2),
                                Text(n.body, style: T.small(context)),
                              ])),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
