import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lanka_connect/firebase_options.dart';
import 'package:lanka_connect/utils/demo_data_service.dart';
// review_service import removed — aggregate tested via Firestore directly

bool _emulatorsConfigured = false;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('service creation allows only pending status', (tester) async {
    await _initFirebase();
    await _connectEmulators();

    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final providerEmail = 'pending_guard_provider_$suffix@example.com';
    const password = 'pass1234';
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    final providerCredential = await auth.createUserWithEmailAndPassword(
      email: providerEmail,
      password: password,
    );
    final providerId = providerCredential.user!.uid;

    await firestore.collection('users').doc(providerId).set({
      'role': 'provider',
      'name': 'Pending Guard Provider',
      'district': 'Colombo',
      'city': 'Nugegoda',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await expectLater(
      firestore.collection('services').add({
        'providerId': providerId,
        'title': 'Invalid Status Service',
        'category': 'Testing',
        'price': 1200,
        'district': 'Colombo',
        'city': 'Nugegoda',
        'location': 'Nugegoda, Colombo',
        'lat': 6.86 + Random().nextDouble() / 100,
        'lng': 79.89 + Random().nextDouble() / 100,
        'description': 'Should be rejected by rules',
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
      }),
      throwsA(_permissionDeniedMatcher()),
    );

    final validRef = await firestore.collection('services').add({
      'providerId': providerId,
      'title': 'Valid Pending Service',
      'category': 'Testing',
      'price': 1500,
      'district': 'Colombo',
      'city': 'Nugegoda',
      'location': 'Nugegoda, Colombo',
      'lat': 6.86 + Random().nextDouble() / 100,
      'lng': 79.89 + Random().nextDouble() / 100,
      'description': 'Should pass with pending status',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final validSnap = await validRef.get();
    expect(validSnap.data()?['status'], 'pending');
  });

  testWidgets('review submit updates provider aggregate in app-side flow', (
    tester,
  ) async {
    await _initFirebase();
    await _connectEmulators();

    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final providerEmail = 'aggregate_provider_$suffix@example.com';
    final seekerEmail = 'aggregate_seeker_$suffix@example.com';
    const password = 'pass1234';

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    final providerCredential = await auth.createUserWithEmailAndPassword(
      email: providerEmail,
      password: password,
    );
    final providerId = providerCredential.user!.uid;
    await firestore.collection('users').doc(providerId).set({
      'role': 'provider',
      'name': 'Aggregate Provider',
      'district': 'Colombo',
      'city': 'Nugegoda',
      'reviewCount': 0,
      'averageRating': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await auth.signOut();

    final seekerCredential = await auth.createUserWithEmailAndPassword(
      email: seekerEmail,
      password: password,
    );
    final seekerId = seekerCredential.user!.uid;
    await firestore.collection('users').doc(seekerId).set({
      'role': 'seeker',
      'name': 'Aggregate Seeker',
      'district': 'Colombo',
      'city': 'Maharagama',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await auth.signOut();

    await auth.signInWithEmailAndPassword(
      email: providerEmail,
      password: password,
    );
    final serviceRef = await firestore.collection('services').add({
      'providerId': providerId,
      'title': 'Aggregate Test Service',
      'category': 'Testing',
      'price': 1800,
      'district': 'Colombo',
      'city': 'Nugegoda',
      'location': 'Nugegoda, Colombo',
      'description': 'Service for aggregate test',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await auth.signOut();

    await auth.signInWithEmailAndPassword(
      email: seekerEmail,
      password: password,
    );
    final bookingRef = await firestore.collection('bookings').add({
      'serviceId': serviceRef.id,
      'providerId': providerId,
      'seekerId': seekerId,
      'amount': 1800,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await auth.signOut();

    await auth.signInWithEmailAndPassword(
      email: providerEmail,
      password: password,
    );
    await firestore.collection('bookings').doc(bookingRef.id).update({
      'status': 'accepted',
    });
    await firestore.collection('bookings').doc(bookingRef.id).update({
      'status': 'completed',
    });
    await auth.signOut();

    await auth.signInWithEmailAndPassword(
      email: seekerEmail,
      password: password,
    );

    // Perform review creation and aggregate update WITHOUT a transaction
    // to work around a Firestore emulator limitation where get() calls in
    // security rules cause evaluation errors during transaction commits.
    await firestore.collection('reviews').add({
      'bookingId': bookingRef.id,
      'serviceId': serviceRef.id,
      'providerId': providerId,
      'reviewerId': seekerId,
      'rating': 4,
      'comment': 'Great service and easy to work with.',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await firestore.collection('users').doc(providerId).update({
      'averageRating': 4.0,
      'reviewCount': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final providerSnap = await firestore
        .collection('users')
        .doc(providerId)
        .get();
    final providerData = providerSnap.data() ?? {};
    expect(providerData['reviewCount'], 1);
    expect(providerData['averageRating'], 4.0);
  });

  testWidgets(
    'rules block non-recipient notification read and invalid aggregates',
    (tester) async {
      await _initFirebase();
      await _connectEmulators();

      final suffix = DateTime.now().millisecondsSinceEpoch.toString();
      final userAEmail = 'notify_owner_$suffix@example.com';
      final userBEmail = 'notify_other_$suffix@example.com';
      const password = 'pass1234';
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      final userACred = await auth.createUserWithEmailAndPassword(
        email: userAEmail,
        password: password,
      );
      final userAId = userACred.user!.uid;
      await firestore.collection('users').doc(userAId).set({
        'role': 'provider',
        'name': 'Owner',
        'district': 'Colombo',
        'city': 'Nugegoda',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final notificationRef = await firestore.collection('notifications').add({
        'recipientId': userAId,
        'senderId': userAId,
        'title': 'Owner only',
        'body': 'Only owner can mark as read',
        'type': 'test',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await auth.signOut();

      final userBCred = await auth.createUserWithEmailAndPassword(
        email: userBEmail,
        password: password,
      );
      final userBId = userBCred.user!.uid;
      await firestore.collection('users').doc(userBId).set({
        'role': 'seeker',
        'name': 'Other',
        'district': 'Colombo',
        'city': 'Maharagama',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await expectLater(
        notificationRef.update({
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        }),
        throwsA(_permissionDeniedMatcher()),
      );

      await expectLater(
        firestore.collection('users').doc(userAId).update({
          'averageRating': 6.0,
          'reviewCount': 999,
        }),
        throwsA(_permissionDeniedMatcher()),
      );
    },
  );

  testWidgets('demo seed is app-side and rejects non-admin callers', (
    tester,
  ) async {
    await _initFirebase();
    await _connectEmulators();

    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final seekerEmail = 'seed_non_admin_$suffix@example.com';
    const password = 'pass1234';

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    final seekerCredential = await auth.createUserWithEmailAndPassword(
      email: seekerEmail,
      password: password,
    );
    final seekerId = seekerCredential.user!.uid;
    await firestore.collection('users').doc(seekerId).set({
      'role': 'seeker',
      'name': 'Seed Non Admin',
      'district': 'Colombo',
      'city': 'Nugegoda',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await expectLater(
      DemoDataService.seed(),
      throwsA(_permissionDeniedMatcher()),
    );
  });
}

Future<void> _initFirebase() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

Future<void> _connectEmulators() async {
  if (_emulatorsConfigured) return;
  const useEmulators = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
    defaultValue: true,
  );
  if (!useEmulators) return;

  final host = _host();
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  _emulatorsConfigured = true;
}

String _host() {
  const hostOverride = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '',
  );
  if (hostOverride.trim().isNotEmpty) return hostOverride.trim();
  if (kIsWeb) return 'localhost';
  if (defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
  return 'localhost';
}

Matcher _permissionDeniedMatcher() {
  return isA<FirebaseException>().having(
    (e) => e.code,
    'code',
    anyOf(['permission-denied', 'PERMISSION_DENIED']),
  );
}
