import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/providers/badges_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class BadgeGalleryScreen extends ConsumerWidget {
  const BadgeGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(badgesProvider);

    return Scaffold(
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Could not load badges')),
          data: (badges) {
            final earned = badges.where((b) => b.earned).toList();
            final locked = badges.where((b) => !b.earned).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              children: [
                NeuTopBar(title: 'Badge Collection', onBack: () => Navigator.pop(context)),
                const SizedBox(height: 8),
                // Summary pill row
                Row(children: [
                  NeuPill(
                    color: AppColors.goldSoft,
                    child: Text('${earned.length} earned',
                        style: const TextStyle(color: AppColors.goldDark, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  NeuPill(
                    color: AppColors.bg,
                    child: Text('${locked.length} locked',
                        style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 20),

                if (earned.isNotEmpty) ...[
                  Text('Earned', style: T.title(context)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: earned.map((b) => _BadgeTile(badge: b)).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                if (locked.isNotEmpty) ...[
                  Text('Locked', style: T.title(context)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: locked.map((b) => _BadgeTile(badge: b, locked: true)).toList(),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, this.locked = false});
  final BadgeItem badge;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: NeuCard(
        padding: const EdgeInsets.all(12),
        color: locked ? null : AppColors.goldSoft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            locked
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(badge.emoji,
                          style: TextStyle(
                              fontSize: 32,
                              color: Colors.black.withValues(alpha: 0.12))),
                      const Icon(Symbols.lock_rounded,
                          color: AppColors.inkSoft, size: 22),
                    ],
                  )
                : Text(badge.emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 6),
            Text(
              badge.name,
              style: T.label(context).copyWith(
                  fontSize: 11,
                  color: locked ? AppColors.inkSoft : AppColors.goldDark),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(badge.name, style: T.h2(context)),
            const SizedBox(height: 6),
            Text(badge.description,
                style: T.body(context), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            if (locked) ...[
              NeuPill(
                color: AppColors.bg,
                child: Text('Keep going to unlock!',
                    style: TextStyle(
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ] else ...[
              NeuPill(
                color: AppColors.goldSoft,
                child: Text('+${badge.xpReward} XP earned',
                    style: const TextStyle(
                        color: AppColors.goldDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
              if (badge.earnedAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Earned ${_formatDate(badge.earnedAt!)}',
                  style: T.small(context),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
