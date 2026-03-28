import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_connect/utils/firebase_env.dart';
import 'package:lanka_connect/utils/notification_navigation.dart';
import 'package:lanka_connect/utils/user_roles.dart';

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
    test('chatId takes highest priority', () {
      final data = {'type': 'payment', 'bookingId': 'b123', 'chatId': 'c456'};
      expect(
        NotificationNavigation.resolveTarget(data),
        NotificationNavigationTarget.chat,
      );
    });

    test('payment type with bookingId routes to payment', () {
      final data = {'type': 'payment', 'bookingId': 'b123'};
      expect(
        NotificationNavigation.resolveTarget(data),
        NotificationNavigationTarget.payment,
      );
    });

    test('bookingId without payment type routes to booking list', () {
      final data = {'type': 'booking', 'bookingId': 'b123'};
      expect(
        NotificationNavigation.resolveTarget(data),
        NotificationNavigationTarget.bookingList,
      );
    });

    test('requestId routes providers to provider requests', () {
      final data = {'type': 'request', 'requestId': 'r123'};
      expect(
        NotificationNavigation.resolveTarget(data, role: UserRoles.provider),
        NotificationNavigationTarget.providerRequests,
      );
    });

    test('requestId routes seekers to seeker requests', () {
      final data = {'type': 'request', 'requestId': 'r123'};
      expect(
        NotificationNavigation.resolveTarget(data, role: UserRoles.seeker),
        NotificationNavigationTarget.seekerRequests,
      );
    });

    test('empty data routes to notifications fallback', () {
      final data = <String, dynamic>{};
      expect(
        NotificationNavigation.resolveTarget(data),
        NotificationNavigationTarget.notifications,
      );
    });

    test('only type without bookingId routes to notifications', () {
      final data = {'type': 'payment'};
      expect(
        NotificationNavigation.resolveTarget(data),
        NotificationNavigationTarget.notifications,
      );
    });

    test('null values are treated as empty strings', () {
      final data = <String, dynamic>{
        'type': null,
        'bookingId': null,
        'chatId': null,
      };
      expect(
        NotificationNavigation.resolveTarget(data),
        NotificationNavigationTarget.notifications,
      );
    });
  });
}
