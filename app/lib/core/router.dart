import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/splash/splash_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/auth/login_otp_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/signin_screen.dart';
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
import '../features/checkin/weighin_screen.dart';
import '../features/meal/log_meal_screen.dart';
import '../features/badge/badge_unlock_screen.dart';
import '../features/hydration/hydration_screen.dart';
import '../features/movement/movement_screen.dart';
import '../features/feed/posts_feed_screen.dart';
import '../features/learning/learning_hub_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/fasting/fasting_screen.dart';
import '../features/checkin/reflection_screen.dart';
import '../features/tracking/measurements_screen.dart';
import '../features/gamification/gamification_screen.dart';
import '../features/gamification/points_store_screen.dart';
import '../features/challenge/weekly_challenge_screen.dart';
import '../features/meal/diet_plan_screen.dart';
import '../features/learning/recipe_library_screen.dart';
import '../features/movement/exercise_library_screen.dart';
import '../features/referral/referral_screen.dart';
import '../features/group/group_chat_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/progress/progress_photos_screen.dart';
import '../features/badge/badge_gallery_screen.dart';
import '../features/learning/lesson_viewer_screen.dart';
import '../features/home/weekly_progress_screen.dart';
import '../features/gamification/gamification_tutorial_screen.dart';

class Routes {
  Routes._();
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const signup = '/signup';
  static const signin = '/signin';
  static const quiz = '/quiz';
  static const coach = '/coach';
  static const payment = '/payment';
  static const home = '/home';
  static const today = '/today';
  static const group = '/group';
  static const chat = '/chat';
  static const profile = '/profile';
  static const checkin = '/checkin';
  static const weighin = '/weighin';
  static const meal = '/meal';
  static const badge = '/badge';
  static const hydration = '/hydration';
  static const movement = '/movement';
  static const feed = '/feed';
  static const learning = '/learning';
  static const settings = '/settings';
  static const fasting = '/fasting';
  static const reflection = '/reflection';
  static const measurements = '/measurements';
  static const gamification = '/gamification';
  static const pointsStore = '/points-store';
  static const challenge = '/challenge';
  static const dietPlan = '/diet-plan';
  static const recipes = '/recipes';
  static const exercises = '/exercises';
  static const referral = '/referral';
  static const groupChat = '/group-chat';
  static const notifications = '/notifications';
  static const progressPhotos = '/progress-photos';
  static const badgeGallery = '/badge-gallery';
  static const lessonViewer = '/lesson/:id';
  static const weeklyProgress = '/weekly-progress';
  static const gamificationTutorial = '/how-to-play';
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
    GoRoute(path: Routes.signup, builder: (_, __) => const SignUpScreen()),
    GoRoute(path: Routes.signin, builder: (_, __) => const SignInScreen()),
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
        path: Routes.weighin,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const WeighInScreen()),
    GoRoute(
        path: Routes.meal,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            LogMealScreen(mealType: state.extra as String?)),
    GoRoute(
        path: Routes.badge,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const BadgeUnlockScreen()),
    GoRoute(
        path: Routes.hydration,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const HydrationScreen()),
    GoRoute(
        path: Routes.movement,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const MovementScreen()),
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
    GoRoute(
        path: Routes.fasting,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const FastingScreen()),
    GoRoute(
        path: Routes.reflection,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            ReflectionScreen(type: state.extra as String? ?? 'evening')),
    GoRoute(
        path: Routes.measurements,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const MeasurementsScreen()),
    GoRoute(
        path: Routes.gamification,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const GamificationScreen()),
    GoRoute(
        path: Routes.pointsStore,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const PointsStoreScreen()),
    GoRoute(
        path: Routes.challenge,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const WeeklyChallengeScreen()),
    GoRoute(
        path: Routes.dietPlan,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const DietPlanScreen()),
    GoRoute(
        path: Routes.recipes,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const RecipeLibraryScreen()),
    GoRoute(
        path: Routes.exercises,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const ExerciseLibraryScreen()),
    GoRoute(
        path: Routes.referral,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const ReferralScreen()),
    GoRoute(
        path: Routes.groupChat,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const GroupChatScreen()),
    GoRoute(
        path: Routes.notifications,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const NotificationsScreen()),
    GoRoute(
        path: Routes.progressPhotos,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const ProgressPhotosScreen()),
    GoRoute(
        path: Routes.badgeGallery,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const BadgeGalleryScreen()),
    GoRoute(
        path: Routes.lessonViewer,
        parentNavigatorKey: _rootKey,
        builder: (_, state) => LessonViewerScreen(
            lessonId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0)),
    GoRoute(
        path: Routes.weeklyProgress,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const WeeklyProgressScreen()),
    GoRoute(
        path: Routes.gamificationTutorial,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const GamificationTutorialScreen()),
  ],
);
