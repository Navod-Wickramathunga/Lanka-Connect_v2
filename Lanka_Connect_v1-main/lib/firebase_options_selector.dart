import 'package:firebase_core/firebase_core.dart';
import 'firebase_options_production.dart';
import 'firebase_options_staging.dart';
import 'utils/firebase_env.dart';

FirebaseOptions currentOptionsForEnv() {
  if (FirebaseEnv.isProduction) {
    return DefaultFirebaseOptionsProduction.currentPlatform;
  }
  return DefaultFirebaseOptionsStaging.currentPlatform;
}
