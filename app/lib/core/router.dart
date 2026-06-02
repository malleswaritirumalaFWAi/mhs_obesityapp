import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/splash/splash_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/auth/login_otp_screen.dart';
import '../features/onboarding/quiz_screen.dart';
import '../features/onboarding/coach_screen.dart';
import '../features/payment/plan_payment_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/home/home_screen.dart';
import '../features/plan/today_plan_screen.dart';
import '../features/group/group_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/checkin/checkin_screen.dart';
import '../features/meal/log_meal_screen.dart';
import '../features/badge/badge_unlock_screen.dart';
import '../features/feed/posts_feed_screen.dart';
import '../features/learning/learning_hub_screen.dart';
import '../features/settings/settings_screen.dart';

class Routes {
  Routes._();
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const quiz = '/quiz';
  static const coach = '/coach';
  static const payment = '/payment';
  static const home = '/home';
  static const today = '/today';
  static const group = '/group';
  static const chat = '/chat';
  static const profile = '/profile';
  static const checkin = '/checkin';
  static const meal = '/meal';
  static const badge = '/badge';
  static const feed = '/feed';
  static const learning = '/learning';
  static const settings = '/settings';
}

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: Routes.splash,
  routes: [
    GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
    GoRoute(path: Routes.welcome, builder: (_, __) => const WelcomeScreen()),
    GoRoute(path: Routes.login, builder: (_, __) => const LoginOtpScreen()),
    GoRoute(path: Routes.quiz, builder: (_, __) => const QuizScreen()),
    GoRoute(path: Routes.coach, builder: (_, __) => const CoachScreen()),
    GoRoute(path: Routes.payment, builder: (_, __) => const PlanPaymentScreen()),

    // Bottom-nav shell
    ShellRoute(
      navigatorKey: _shellKey,
      builder: (_, __, child) => AppShell(child: child),
      routes: [
        GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
        GoRoute(path: Routes.today, builder: (_, __) => const TodayPlanScreen()),
        GoRoute(path: Routes.group, builder: (_, __) => const GroupScreen()),
        GoRoute(path: Routes.chat, builder: (_, __) => const ChatScreen()),
        GoRoute(path: Routes.profile, builder: (_, __) => const ProfileScreen()),
      ],
    ),

    // Pushed (full-screen) routes
    GoRoute(
        path: Routes.checkin,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const CheckinScreen()),
    GoRoute(
        path: Routes.meal,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const LogMealScreen()),
    GoRoute(
        path: Routes.badge,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const BadgeUnlockScreen()),
    GoRoute(
        path: Routes.feed,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const PostsFeedScreen()),
    GoRoute(
        path: Routes.learning,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const LearningHubScreen()),
    GoRoute(
        path: Routes.settings,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const SettingsScreen()),
  ],
);
