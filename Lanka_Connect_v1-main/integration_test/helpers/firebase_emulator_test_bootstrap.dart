import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:lanka_connect/firebase_options_selector.dart';

Future<void> initializeFirebaseForIntegrationTests() async {
  await Firebase.initializeApp(options: currentOptionsForEnv());
}

Future<void> connectToEmulators() async {
  const useEmulators = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
    defaultValue: true,
  );
  if (!useEmulators) return;

  final host = resolveEmulatorHost();
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
}

String resolveEmulatorHost() {
  const hostOverride = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '',
  );
  if (hostOverride.trim().isNotEmpty) return hostOverride.trim();
  if (kIsWeb) return 'localhost';
  if (defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
  return 'localhost';
}
