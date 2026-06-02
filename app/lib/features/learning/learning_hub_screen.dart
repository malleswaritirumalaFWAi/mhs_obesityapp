import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class _Journey {
  const _Journey(this.week, this.title, this.status);
  final String week;
  final String title;
  final String status; // completed, active, locked
}

const _journey = [
  _Journey('Week 1', 'Foundation', 'completed'),
  _Journey('Week 2', 'Nutrition basics', 'completed'),
  _Journey('Week 3', 'Power of walking', 'active'),
  _Journey('Week 4', 'Sleep & recovery', 'locked'),
  _Journey('Week 5', 'Strength habits', 'locked'),
];

class LearningHubScreen extends StatelessWidget {
  const LearningHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            NeuTopBar(
              title: 'Learn 📚',
              onBack: () => context.pop(),
              trailing: const NeuIconButton(icon: Symbols.notifications_rounded),
            ),
            const SizedBox(height: 18),
            NeuCard(
              color: AppColors.berrySoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NeuPill(
                    color: AppColors.berry,
                    child: Text('Week 3 · +50 XP',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                  const SizedBox(height: 14),
                  Text('Why 8K steps changes everything', style: T.h2(context).copyWith(fontSize: 20)),
                  const SizedBox(height: 6),
                  Text('Lesson 2 of 3 · 66% complete', style: T.small(context)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: 0.66,
                      minHeight: 8,
                      backgroundColor: Colors.white,
                      valueColor: const AlwaysStoppedAnimation(AppColors.berry),
                    ),
                  ),
                  const SizedBox(height: 16),
                  NeuButton.primary('Continue lesson',
                      trailing: const Icon(Symbols.arrow_forward_rounded, size: 18),
                      onPressed: () {}),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Up next', style: T.title(context)),
            const SizedBox(height: 12),
            _UpNext(
              icon: Symbols.play_circle_rounded,
              color: AppColors.coral,
              title: 'Why sleep matters',
              sub: 'Dr. Roy · 5 min · +30 XP',
            ),
            _UpNext(
              icon: Symbols.psychology_rounded,
              color: AppColors.gold,
              title: 'Quick quiz',
              sub: 'Test week 2 · earn big +100 XP',
            ),
            const SizedBox(height: 20),
            Text('Your journey', style: T.title(context)),
            const SizedBox(height: 12),
            for (final j in _journey) _JourneyRow(item: j),
          ],
        ),
      ),
    );
  }
}

class _UpNext extends StatelessWidget {
  const _UpNext({required this.icon, required this.color, required this.title, required this.sub});
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeuCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, fill: 1),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.title(context).copyWith(fontSize: 15)),
                Text(sub, style: T.small(context)),
              ],
            ),
          ),
          const Icon(Symbols.chevron_right_rounded, color: AppColors.inkSoft),
        ]),
      ),
    );
  }
}

class _JourneyRow extends StatelessWidget {
  const _JourneyRow({required this.item});
  final _Journey item;
  @override
  Widget build(BuildContext context) {
    final completed = item.status == 'completed';
    final active = item.status == 'active';
    final icon = completed
        ? Symbols.verified_rounded
        : active
            ? Symbols.lock_open_rounded
            : Symbols.lock_rounded;
    final color = completed
        ? AppColors.sage
        : active
            ? AppColors.coral
            : AppColors.inkSoft;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeuCard(
        color: active ? AppColors.coralSoft : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, color: color, fill: completed || active ? 1 : 0),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.week} · ${item.title}', style: T.title(context).copyWith(fontSize: 14)),
                Text(
                    completed
                        ? 'Completed'
                        : active
                            ? 'Active now'
                            : 'Unlocks soon',
                    style: T.small(context).copyWith(color: color)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
