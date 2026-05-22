import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../features/auth/services/auth_service.dart';

import '../../features/auth/services/auth_service.dart';

class NotificationService {
  final Ref _ref;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  static const String _appId = "8d2d2357-e051-4e81-8f92-dc5e4dbeff4b";
  static const String _serverUrl = "https://parametra-notification-server.onrender.com";
  static const String _restApiKey = "os_v2_app_ruwsgv7akfhidd4s3rpe3px7jphude5dj7duateq4y63ufqkc6pxeez4el75xgqxihsvh4v6t6eum2iiwjoxwpbyzshup666lqjgsky";

  NotificationService(this._ref);

  Future<void> init() async {
    // 1. Local Notifications Init
    tz_data.initializeTimeZones();
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(const InitializationSettings(android: androidSettings, iOS: iosSettings));

    // 2. OneSignal Init
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(_appId);
    await OneSignal.Notifications.requestPermission(true);

    _ref.listen(authStateProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        OneSignal.login(user.uid);
      } else {
        OneSignal.logout();
      }
    });
  }

  // --- LOCAL NOTIFICATIONS ---

  Future<void> scheduleLocal({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'parametra_main',
          'Parametra Bildirimleri',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleRepeatingLocal({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required DateTimeComponents matchComponents,
  }) async {
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'parametra_main',
          'Parametra Bildirimleri',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchComponents,
    );
  }

  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }

  Future<void> cancelLocal(int id) async {
    await _localNotifications.cancel(id);
  }

  // --- PUSH NOTIFICATIONS (SERVER) ---

  Future<void> sendPushNotification({
    required String title,
    required String message,
  }) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      await http.post(
        Uri.parse("$_serverUrl/send-notification"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": user.uid,
          "title": title,
          "message": message,
          "appId": _appId,
          "apiKey": _restApiKey,
        }),
      );
    } catch (e) {
      print("Push Notification Error: $e");
    }
  }

  Future<void> sendTag(String key, dynamic value) async {
    OneSignal.User.addTagWithKey(key, value.toString());
  }
}
