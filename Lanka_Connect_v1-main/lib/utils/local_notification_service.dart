import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  const LocalNotificationService._();

  static const String channelId = 'lanka_connect_notifications_soft';
  static const String channelName = 'Lanka Connect Notifications';
  static const String channelDescription =
      'General alerts, bookings, requests, and account notifications.';
  static const String androidSoundResource = 'soft_notification';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static Future<bool> Function(Map<String, dynamic> payload)? _tapHandler;
  static bool _initialized = false;

  static Future<void> initialize({
    required Future<bool> Function(Map<String, dynamic> payload) onTapPayload,
  }) async {
    if (kIsWeb || _initialized) {
      _tapHandler = onTapPayload;
      return;
    }

    _tapHandler = onTapPayload;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: darwin);

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) async {
        final payload = _decodePayload(response.payload);
        if (payload == null) return;
        await _tapHandler?.call(payload);
      },
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      const channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(androidSoundResource),
      );
      await androidPlugin.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  static Future<void> showRemoteMessage(RemoteMessage message) async {
    if (kIsWeb || !_initialized) return;

    final title = (message.notification?.title ?? message.data['title'] ?? '')
        .toString()
        .trim();
    final body = (message.notification?.body ?? message.data['body'] ?? '')
        .toString()
        .trim();
    if (title.isEmpty && body.isEmpty) return;

    await show(
      title: title.isEmpty ? 'Lanka Connect' : title,
      body: body,
      payload: message.data,
      notificationId: _notificationIdFor(message.data),
    );
  }

  static Future<void> show({
    required String title,
    required String body,
    Map<String, dynamic> payload = const {},
    int? notificationId,
  }) async {
    if (kIsWeb || !_initialized) return;

    final details = NotificationDetails(
      android: const AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(androidSoundResource),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      id:
          notificationId ??
          DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      notificationDetails: details,
      payload: jsonEncode(payload),
    );
  }

  static int _notificationIdFor(Map<String, dynamic> data) {
    final notificationId = (data['notificationId'] ?? '').toString().trim();
    if (notificationId.isNotEmpty) {
      return notificationId.hashCode & 0x7fffffff;
    }
    return DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
  }

  static Map<String, dynamic>? _decodePayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
