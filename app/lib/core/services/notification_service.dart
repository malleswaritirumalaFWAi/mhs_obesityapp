import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;

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

  bool _tzInitialized = false;

  void _ensureTzInit() {
    if (!_tzInitialized) {
      tz.initializeTimeZones();
      _tzInitialized = true;
    }
  }

  /// Call once after the user is authenticated (has a valid JWT token).
  /// Silently skips if Firebase was not initialised (no google-services.json).
  Future<void> initialize(ApiClient api) async {
    _ensureTzInit();

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

  // ── Fasting progress notifications ──────────────────────────────────────

  static const _fastingChannelId = 'fitquest_fasting';
  static const _fastingNotifBase = 9000; // notification ID range

  /// Schedule hourly fasting progress notifications.
  Future<void> scheduleFastingReminders({
    required DateTime startedAt,
    required int targetHours,
  }) async {
    _ensureTzInit();
    // Cancel any existing fasting notifications first
    await cancelFastingReminders();

    for (int hour = 1; hour <= targetHours; hour++) {
      final scheduledTime = startedAt.add(Duration(hours: hour));
      if (scheduledTime.isBefore(DateTime.now())) continue; // skip past hours

      final remaining = targetHours - hour;
      String title;
      String body;

      if (hour == targetHours) {
        title = 'Fasting goal reached!';
        body = 'Congratulations! You completed your $targetHours-hour fast!';
      } else if (hour == targetHours ~/ 2) {
        title = 'Halfway there!';
        body = "You've completed $hour of $targetHours hours. Keep it up!";
      } else if (remaining == 1) {
        title = 'Almost done!';
        body = '$hour hours completed! Just 1 hour left until your goal!';
      } else {
        title = 'Fasting progress';
        body = "You've fasted for $hour hours. $remaining hours to go!";
      }

      try {
        await _localNotifications.zonedSchedule(
          _fastingNotifBase + hour,
          title,
          body,
          TZDateTime.from(scheduledTime, local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              _fastingChannelId,
              'Fasting Reminders',
              channelDescription: 'Hourly fasting progress updates',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: null,
        );
      } catch (_) {
        // Scheduling failed for this hour — non-fatal.
      }
    }
  }

  /// Cancel all pending fasting notifications.
  Future<void> cancelFastingReminders() async {
    for (int i = 1; i <= 24; i++) {
      await _localNotifications.cancel(_fastingNotifBase + i);
    }
  }
}
