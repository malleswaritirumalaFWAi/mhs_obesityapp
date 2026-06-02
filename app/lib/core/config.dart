/// App-wide configuration.
///
/// Override the API base at build/run time with:
///   flutter run --dart-define=API_BASE=http://10.0.2.2:4000
/// (10.0.2.2 is the Android emulator's alias for the host machine's localhost.)
class AppConfig {
  AppConfig._();

  static const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://10.0.2.2:4000',
  );

  /// Razorpay public key id (test mode). Safe to ship in the app.
  static const razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_xxxxxxxx',
  );

  /// When true the app tolerates a missing backend and falls back to seeded
  /// demo data so every screen renders during development.
  static const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);
}
