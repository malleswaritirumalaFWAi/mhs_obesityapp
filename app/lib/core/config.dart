import 'package:flutter/foundation.dart';

/// App-wide configuration.
///
/// Debug builds (flutter run) → local backend automatically.
/// Release builds (flutter build apk / web) → Vercel production automatically.
/// Override at any time with: flutter run --dart-define=API_BASE=http://...
class AppConfig {
  AppConfig._();

  static const _apiBaseEnv = String.fromEnvironment('API_BASE', defaultValue: '');

  static String get apiBase {
    if (_apiBaseEnv.isNotEmpty) return _apiBaseEnv;
    // Use Vercel production for release builds AND debug on real devices.
    // 10.0.2.2 only works inside the Android emulator — real phones can't
    // reach it, which causes silent 404s. Developers targeting a local
    // backend should pass --dart-define=API_BASE=http://10.0.2.2:4000
    if (kReleaseMode) return 'https://mhs-backend.vercel.app';
    // ignore: do_not_use_environment
    const isWeb = bool.fromEnvironment('dart.library.html', defaultValue: false);
    if (isWeb) return 'http://localhost:4000';
    // Default to production even in debug — works on both emulators and
    // real devices. Override with API_BASE for local backend testing.
    return 'https://mhs-backend.vercel.app';
  }

  /// Razorpay public key id (test mode). Safe to ship in the app.
  static const razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_xxxxxxxx',
  );

  /// When true the app tolerates a missing backend and falls back to seeded
  /// demo data so every screen renders during development.
  static const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);
}
