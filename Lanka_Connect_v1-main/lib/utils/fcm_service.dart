import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firestore_refs.dart';
import '../main.dart';
import '../screens/bookings/booking_list_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/payments/payment_screen.dart';

/// Handles FCM token lifecycle and push notification setup.
class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Request permission and save the FCM token to Firestore.
  /// Call this after the user signs in.
  static Future<void> initialize() async {
    try {
      // On Android 13+ request POST_NOTIFICATIONS runtime permission
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          final result = await Permission.notification.request();
          if (!result.isGranted) {
            debugPrint('FCM: Android notification permission denied.');
          }
        }
      }
      // Request permission (iOS/macOS/web require explicit permission)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM: User denied notification permission.');
        return;
      }

      debugPrint('FCM: Permission status = ${settings.authorizationStatus}');

      // Get and save the token
      await _saveToken();

      // Listen for token refreshes
      _messaging.onTokenRefresh.listen((newToken) {
        _saveTokenValue(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Check if app was opened from terminated state via notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      // Remove stale tokens (non-blocking)
      cleanupStaleTokens();
    } catch (e, st) {
      debugPrint('FCM initialization error: $e');
      debugPrint(st.toString());
    }
  }

  /// Save current FCM token to the user's Firestore document.
  static Future<void> _saveToken() async {
    try {
      final token = await _messaging.getToken(
        vapidKey: kIsWeb
            ? null // Set your VAPID key here for web push
            : null,
      );

      if (token != null) {
        await _saveTokenValue(token);
      }
    } catch (e) {
      debugPrint('FCM: Failed to get token: $e');
    }
  }

  /// Persist an FCM token in the user's Firestore doc and fcm_tokens subcollection.
  static Future<void> _saveTokenValue(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    debugPrint(
      'FCM: Saving token for ${user.uid} (${token.substring(0, 10)}...)',
    );

    try {
      // Store latest token on user doc for simple single-device lookup
      await FirestoreRefs.users().doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also store in subcollection for multi-device support
      await FirestoreRefs.users()
          .doc(user.uid)
          .collection('fcm_tokens')
          .doc(token.hashCode.toString())
          .set({
            'token': token,
            'platform': _currentPlatform(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('FCM: Failed to save token: $e');
    }
  }

  /// Remove the FCM token on sign-out.
  static Future<void> removeToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        // Remove from subcollection
        await FirestoreRefs.users()
            .doc(user.uid)
            .collection('fcm_tokens')
            .doc(token.hashCode.toString())
            .delete();

        // Clear from user doc
        await FirestoreRefs.users().doc(user.uid).set({
          'fcmToken': FieldValue.delete(),
          'fcmTokenUpdatedAt': FieldValue.delete(),
        }, SetOptions(merge: true));
      }

      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('FCM: Failed to remove token: $e');
    }
  }

  /// Handle messages received while the app is in the foreground.
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('FCM foreground message: ${message.notification?.title}');
    // Foreground messages are handled by the in-app Firestore listeners.
    // Show a brief SnackBar so the user knows a notification arrived.
    final nav = MyApp.navigatorKey.currentState;
    final ctx = nav?.context;
    if (ctx != null && message.notification != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(message.notification!.title ?? 'New notification'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => _navigateFromMessage(message.data),
          ),
        ),
      );
    }
  }

  /// Handle when a user taps a notification while app is in background/terminated.
  static void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('FCM message opened app: ${message.data}');
    _navigateFromMessage(message.data);
  }

  /// Navigate to the appropriate screen based on notification payload data.
  static void _navigateFromMessage(Map<String, dynamic> data) {
    final nav = MyApp.navigatorKey.currentState;
    if (nav == null) return;

    final type = (data['type'] ?? '').toString();
    final bookingId = (data['bookingId'] ?? '').toString();
    final chatId = (data['chatId'] ?? '').toString();

    if (chatId.isNotEmpty) {
      nav.push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)));
    } else if (type == 'payment' && bookingId.isNotEmpty) {
      nav.push(
        MaterialPageRoute(builder: (_) => PaymentScreen(bookingId: bookingId)),
      );
    } else if (bookingId.isNotEmpty) {
      nav.push(MaterialPageRoute(builder: (_) => const BookingListScreen()));
    } else {
      nav.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    }
  }

  /// Clean up stale FCM tokens older than [maxAge] from the user's subcollection.
  static Future<void> cleanupStaleTokens({
    Duration maxAge = const Duration(days: 30),
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(maxAge));
      final stale = await FirestoreRefs.users()
          .doc(user.uid)
          .collection('fcm_tokens')
          .where('updatedAt', isLessThan: cutoff)
          .get();

      for (final doc in stale.docs) {
        await doc.reference.delete();
      }

      if (stale.docs.isNotEmpty) {
        debugPrint('FCM: Cleaned up ${stale.docs.length} stale token(s).');
      }
    } catch (e) {
      debugPrint('FCM: Failed to cleanup stale tokens: $e');
    }
  }

  static String _currentPlatform() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.macOS) return 'macos';
    if (defaultTargetPlatform == TargetPlatform.windows) return 'windows';
    if (defaultTargetPlatform == TargetPlatform.linux) return 'linux';
    return 'unknown';
  }
}
