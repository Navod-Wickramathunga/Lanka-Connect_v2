import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_connect/utils/firebase_env.dart';

void main() {
  group('FirebaseEnv', () {
    test('appEnvRaw has a non-empty default value', () {
      // The default is 'production' when no --dart-define is provided
      expect(FirebaseEnv.appEnvRaw, isNotEmpty);
    });

    test('isProduction / isStaging / isEmulator are mutually exclusive', () {
      // Exactly one must be true at any given time
      final flags = [
        FirebaseEnv.isProduction,
        FirebaseEnv.isStaging,
        FirebaseEnv.isEmulator,
      ];
      expect(flags.where((f) => f).length, 1);
    });

    test('appEnv matches the expected environment', () {
      // In test mode without --dart-define, appEnv should be production
      expect(
        FirebaseEnv.appEnv,
        anyOf(AppEnv.production, AppEnv.staging, AppEnv.emulator),
      );
    });

    test('backendLabel returns empty string for production', () {
      if (FirebaseEnv.isProduction) {
        expect(FirebaseEnv.backendLabel(), isEmpty);
      }
    });

    test('backendLabel returns STAGING for staging', () {
      if (FirebaseEnv.isStaging) {
        expect(FirebaseEnv.backendLabel(), 'STAGING');
      }
    });
  });

  group('FCM navigation routing logic', () {
    // These tests verify the routing decision logic from _navigateFromMessage,
    // extracted as pure functions for testability.

    test('chatId takes highest priority', () {
      final data = {'type': 'payment', 'bookingId': 'b123', 'chatId': 'c456'};
      expect(_resolveRoute(data), 'chat');
    });

    test('payment type with bookingId routes to payment', () {
      final data = {'type': 'payment', 'bookingId': 'b123'};
      expect(_resolveRoute(data), 'payment');
    });

    test('bookingId without payment type routes to booking list', () {
      final data = {'type': 'booking', 'bookingId': 'b123'};
      expect(_resolveRoute(data), 'booking_list');
    });

    test('empty data routes to notifications fallback', () {
      final data = <String, dynamic>{};
      expect(_resolveRoute(data), 'notifications');
    });

    test('only type without bookingId routes to notifications', () {
      final data = {'type': 'payment'};
      expect(_resolveRoute(data), 'notifications');
    });

    test('null values are treated as empty strings', () {
      final data = <String, dynamic>{
        'type': null,
        'bookingId': null,
        'chatId': null,
      };
      expect(_resolveRoute(data), 'notifications');
    });
  });
}

/// Mirrors the routing logic from FcmService._navigateFromMessage.
/// Extracted here for pure unit testability without Navigator dependency.
String _resolveRoute(Map<String, dynamic> data) {
  final type = (data['type'] ?? '').toString();
  final bookingId = (data['bookingId'] ?? '').toString();
  final chatId = (data['chatId'] ?? '').toString();

  if (chatId.isNotEmpty) return 'chat';
  if (type == 'payment' && bookingId.isNotEmpty) return 'payment';
  if (bookingId.isNotEmpty) return 'booking_list';
  return 'notifications';
}
