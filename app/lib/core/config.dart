/// App-wide configuration.
///
/// Override the API base at build/run time with:
///   flutter run --dart-define=API_BASE=http://10.0.2.2:4000
/// (10.0.2.2 is the Android emulator's alias for the host machine's localhost.)
class AppConfig {
  AppConfig._();

  static const _apiBaseEnv = String.fromEnvironment('API_BASE', defaultValue: '');

  // 10.0.2.2 is the Android emulator alias for host localhost.
  // On web (browser) use localhost directly.
  static String get apiBase {
    if (_apiBaseEnv.isNotEmpty) return _apiBaseEnv;
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
