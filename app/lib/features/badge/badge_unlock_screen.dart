import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';

class BadgeUnlockScreen extends StatefulWidget {
  const BadgeUnlockScreen({super.key});
  @override
  State<BadgeUnlockScreen> createState() => _BadgeUnlockScreenState();
}

class _BadgeUnlockScreenState extends State<BadgeUnlockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Badge data passed via GoRouter extra from CheckinScreen.
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final emoji = extra?['emoji'] as String? ?? '🏅';
    final name = extra?['name'] as String? ?? 'Badge Unlocked';
    final xp = extra?['xp'] as int? ?? 0;
    final streak = extra?['streak'] as int? ?? 0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Symbols.close_rounded, color: AppColors.inkSoft),
                  onPressed: () => context.go(Routes.home),
                ),
              ),
              const Spacer(),
              ScaleTransition(
                scale: Tween(begin: 0.6, end: 1.0)
                    .animate(CurvedAnimation(parent: _c, curve: Curves.elasticOut)),
                child: NeuCard(
                  padding: const EdgeInsets.all(36),
                  radius: 40,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                            color: AppColors.goldSoft, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(emoji, style: const TextStyle(fontSize: 56)),
                      ),
                      const SizedBox(height: 16),
                      if (streak > 0)
                        Text('$streak day streak',
                            style: T.label(context).copyWith(color: AppColors.goldDark)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text('Badge unlocked', style: T.small(context)),
              const SizedBox(height: 8),
              Text(name, style: T.h1(context)),
              const SizedBox(height: 10),
              Text(
                streak >= 30
                    ? "$streak days in a row. You're officially unstoppable."
                    : "$streak days straight — keep the momentum going!",
                textAlign: TextAlign.center,
                style: T.body(context),
              ),
              const SizedBox(height: 18),
              NeuCard(
                color: AppColors.goldSoft,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Symbols.military_tech_rounded,
                      color: AppColors.goldDark, fill: 1),
                  const SizedBox(width: 10),
                  Text(
                    xp > 0 ? 'Reward earned · +$xp XP' : 'Badge earned!',
                    style: T.title(context)
                        .copyWith(color: AppColors.goldDark, fontSize: 15),
                  ),
                ]),
              ),
              const Spacer(),
              Row(children: [
                Expanded(
                  child: NeuButton(
                    onPressed: () {},
                    filled: false,
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Symbols.share_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Share'),
                    ]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: NeuButton.primary('Continue',
                      onPressed: () => context.go(Routes.home)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
