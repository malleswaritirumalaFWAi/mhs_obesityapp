import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/router.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), _route);
  }

  void _route() {
    if (!mounted) return;
    final s = ref.read(sessionProvider);
    if (s.status == AuthStatus.signedIn) {
      context.go(s.onboarded ? Routes.home : Routes.quiz);
    } else {
      context.go(Routes.welcome);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _c,
          child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NeuCard(
                  padding: const EdgeInsets.all(28),
                  radius: 34,
                  child: const Icon(Symbols.eco_rounded,
                      size: 64, color: AppColors.sage, fill: 1),
                ),
                const SizedBox(height: 28),
                Text('FitQuest', style: T.h1(context).copyWith(fontSize: 34)),
                const SizedBox(height: 8),
                Text('Real coach. Real results.', style: T.body(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
