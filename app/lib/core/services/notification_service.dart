import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api_client.dart';

/// Handles background FCM messages (must be top-level, not a class method).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // System tray display is handled automatically by FCM on Android when the
  // app is in background/terminated. No action needed here.
}

/// The notification channel used for all FitQuest alerts on Android.
const _channel = AndroidNotificationChannel(
  'fitquest_channel',
  'FitQuest Notifications',
  description: 'Reminders and updates from FitQuest',
  importance: Importance.high,
);

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // Do NOT initialise FirebaseMessaging.instance eagerly — on web it throws if
  // Firebase was not configured. Access it lazily inside initialize() only.
  final _localNotifications = FlutterLocalNotificationsPlugin();

  /// Call once after the user is authenticated (has a valid JWT token).
  /// Silently skips if Firebase was not initialised (no google-services.json).
  Future<void> initialize(ApiClient api) async {
    // Firebase.apps is empty when initializeApp() was never called or failed.
    // Accessing FirebaseMessaging.instance without an initialised app crashes on web.
    if (Firebase.apps.isEmpty) return;

    try {
    final _messaging = FirebaseMessaging.instance;
    // 1. Request permission (iOS always prompts; Android 13+ prompts).
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // 2. Set up local notifications plugin (needed to show in-foreground alerts).
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // 3. Create the Android notification channel.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 4. Register background message handler.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 5. Show a local notification when a message arrives while the app is open.
    FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n == null) return;
      _localNotifications.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    });

    // 6. Get the FCM device token and register it with the backend.
    final token = await _messaging.getToken();
    if (token != null) await _registerToken(api, token);

    // 7. Re-register whenever the token rotates.
    _messaging.onTokenRefresh.listen((token) => _registerToken(api, token));
    } catch (_) {
      // Any other Firebase/platform error — notifications won't work but app continues.
    }
  }

  Future<void> _registerToken(ApiClient api, String token) async {
    try {
      await api.postJson('/notifications/fcm-token', {'token': token});
    } catch (_) {
      // Non-fatal — token will be re-registered on the next launch.
    }
  }
}
