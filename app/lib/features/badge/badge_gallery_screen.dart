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
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
              children: [
                NeuCard(
                  depth: 0.5,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Symbols.arrow_back_rounded,
                          color: AppColors.inkMid, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Badge Collection',
                              style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900)),
                          Text('Your earned achievements',
                              style: TextStyle(
                                  color: AppColors.inkSoft, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.coralSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Symbols.military_tech_rounded, color: AppColors.coral, size: 20, fill: 1),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                // Summary pill row
                Row(children: [
                  NeuPill(
                    color: AppColors.coralSoft,
                    child: Text('${earned.length} earned',
                        style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  NeuPill(
                    color: AppColors.bg,
                    child: Text('${locked.length} locked',
                        style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 24),

                if (earned.isNotEmpty) ...[
                  Text('EARNED', style: T.section(context)),
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
                  Text('LOCKED', style: T.section(context)),
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

  static const _earnedColors = [AppColors.coral, AppColors.coral, AppColors.coral, AppColors.coral];
  static const _earnedSoftColors = [AppColors.coralSoft, AppColors.coralSoft, AppColors.coralSoft, AppColors.coralSoft];

  @override
  Widget build(BuildContext context) {
    final colorIdx = badge.name.length % _earnedColors.length;
    final accent = _earnedColors[colorIdx];
    final softAccent = _earnedSoftColors[colorIdx];

    return GestureDetector(
      onTap: () => _showDetail(context, accent, softAccent),
      child: NeuCard(
        depth: 0.5,
        padding: const EdgeInsets.all(12),
        color: locked ? null : softAccent,
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
                  color: locked ? AppColors.inkSoft : accent),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, Color accent, Color softAccent) {
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
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Symbols.lock_rounded, size: 13, color: AppColors.inkSoft),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      badge.description.isNotEmpty
                          ? badge.description
                          : 'Keep going to unlock!',
                      style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ),
                ]),
              ),
            ] else ...[
              NeuPill(
                color: softAccent,
                child: Text('+${badge.xpReward} XP earned',
                    style: TextStyle(
                        color: accent,
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
