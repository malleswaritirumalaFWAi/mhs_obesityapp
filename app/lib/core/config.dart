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
    // Release builds always hit Vercel production.
    if (kReleaseMode) return 'https://mhs-backend.vercel.app';
    // Debug/local: Android emulator uses 10.0.2.2, web uses localhost.
    // ignore: do_not_use_environment
    const isWeb = bool.fromEnvironment('dart.library.html', defaultValue: false);
    return isWeb ? 'http://localhost:4000' : 'http://10.0.2.2:4000';
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
