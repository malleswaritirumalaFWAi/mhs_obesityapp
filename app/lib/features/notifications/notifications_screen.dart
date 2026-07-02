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
  'badge': AppColors.gold,
  'streak_risk': AppColors.coral,
  'combo_bonus': AppColors.sage,
  'perfect_day': AppColors.gold,
  'weekly_winner': AppColors.gold,
  'challenge_complete': AppColors.berry,
  'diet_plan': AppColors.berry,
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: NeuCard(
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
                    const Text('🔔', style: TextStyle(fontSize: 26)),
                ]),
              ),
            ),
            Expanded(
              child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : state.items.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Symbols.notifications_off_rounded, size: 48, color: AppColors.inkSoft),
                      const SizedBox(height: 12),
                      Text('All caught up!', style: T.body(context)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      itemCount: state.items.length,
                      itemBuilder: (_, i) {
                        final n = state.items[i];
                        final icon = _typeIcons[n.type] ?? Symbols.info_rounded;
                        final color = _typeColors[n.type] ?? AppColors.coral;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: NeuCard(
                            padding: const EdgeInsets.all(14),
                            color: n.read ? null : color.withValues(alpha: 0.05),
                            child: Row(children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(icon, color: color, fill: 1),
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
