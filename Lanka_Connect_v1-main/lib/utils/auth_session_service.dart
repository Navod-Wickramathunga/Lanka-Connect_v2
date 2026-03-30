import 'package:firebase_auth/firebase_auth.dart';

import 'app_logger.dart';
import 'fcm_service.dart';

class AuthSessionService {
  const AuthSessionService._();

  static Future<void> signOut() async {
    try {
      await FcmService.removeToken();
    } catch (_) {
      // Sign-out should continue even if token cleanup fails.
    }

    try {
      await AppLogger.clearUserId();
    } catch (_) {
      // Crash logging cleanup should not block sign-out.
    }

    await FirebaseAuth.instance.signOut();
  }
}
