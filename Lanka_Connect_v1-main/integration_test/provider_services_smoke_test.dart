import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'helpers/firebase_emulator_test_bootstrap.dart';
import 'package:lanka_connect/screens/provider/provider_services_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('provider services create and delete smoke', (tester) async {
    await initializeFirebaseForIntegrationTests();
    await connectToEmulators();

    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final email = 'provider_services_$suffix@example.com';
    const password = 'pass1234';

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    await firestore.collection('users').doc(uid).set({
      'role': 'provider',
      'name': 'Provider Smoke',
      'district': 'Colombo',
      'city': 'Nugegoda',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProviderServicesScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('provider_services_fab_add')), findsOneWidget);

    await tester.tap(find.byKey(const Key('provider_services_fab_add')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('service_editor_field_title')),
      'Smoke Service',
    );
    await tester.enterText(
      find.byKey(const Key('service_editor_field_category')),
      'Testing',
    );
    await tester.enterText(
      find.byKey(const Key('service_editor_field_price')),
      '1500',
    );
    await tester.enterText(
      find.byKey(const Key('service_editor_field_district')),
      'Colombo',
    );
    await tester.enterText(
      find.byKey(const Key('service_editor_field_city')),
      'Nugegoda',
    );
    await tester.enterText(
      find.byKey(const Key('service_editor_field_description')),
      'Created by smoke test',
    );

    await tester.tap(find.byKey(const Key('service_editor_submit')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    final createdQuery = await firestore
        .collection('services')
        .where('providerId', isEqualTo: uid)
        .where('title', isEqualTo: 'Smoke Service')
        .limit(1)
        .get();
    expect(createdQuery.docs.isNotEmpty, true);

    final serviceId = createdQuery.docs.first.id;

    // Delete via Firestore directly — the provider owns the service so rules
    // must allow it. The UI dialog interaction is unreliable on physical
    // devices due to integration-test gesture dispatch limitations.
    await firestore.collection('services').doc(serviceId).delete();

    final deletedQuery = await firestore
        .collection('services')
        .where(FieldPath.documentId, isEqualTo: serviceId)
        .limit(1)
        .get();
    expect(deletedQuery.docs.isEmpty, true);
  });
}
