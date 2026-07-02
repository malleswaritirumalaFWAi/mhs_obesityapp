import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/neu.dart';

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
    // Check immediately after first frame in case bootstrap already completed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(sessionProvider);
      if (s.status != AuthStatus.unknown) _route(s);
    });
  }

  void _route(SessionState s) {
    if (!mounted) return;
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
    // Route as soon as bootstrap finishes (status leaves unknown).
    ref.listen<SessionState>(sessionProvider, (_, s) {
      if (s.status != AuthStatus.unknown) _route(s);
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
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
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: Neu.raised(depth: 0.8),
                  ),
                  child: const Center(
                    child: Text('🏆', style: TextStyle(fontSize: 56)),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'FitQuest',
                  style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your 12-Week Weight Loss Game',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkMid),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.coral),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
