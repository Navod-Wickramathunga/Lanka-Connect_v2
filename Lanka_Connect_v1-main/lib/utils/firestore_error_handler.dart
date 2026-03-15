import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'app_logger.dart';
import 'app_feedback.dart';

class FirestoreErrorHandler {
  static String toUserMessageForOperation(Object error, {String? operation}) {
    if (operation == 'seed_demo_data') {
      if (error is FirebaseException && error.code == 'permission-denied') {
        return 'Demo seed blocked by rules for existing demo docs. Seed now runs in safe mode; retry once. If it still fails, use fresh demo IDs.';
      }
      if (error is FirebaseException && error.message != null) {
        return 'Demo seed failed: ${error.message}';
      }
      return 'Demo seed failed: $error';
    }
    return toUserMessage(error);
  }

  static String toUserMessage(Object error) {
    if (error is FirebaseAuthException) {
      return error.message ?? 'Authentication failed. Please try again.';
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'not-found':
          return 'Requested record was not found.';
        case 'permission-denied':
          return 'Permission denied. Your account does not have access for this action.';
        case 'unauthenticated':
          return 'Please sign in to continue.';
        case 'unavailable':
          return 'Service is temporarily unavailable. Check your connection.';
        case 'deadline-exceeded':
          return 'Request timed out. Please try again.';
        case 'failed-precondition':
          return 'A required Firestore index/config is missing.';
        default:
          return error.message ?? 'Request failed. Please try again.';
      }
    }

    return 'Something went wrong. Please try again.';
  }

  static void showError(BuildContext context, String message) {
    TigerFeedback.show(
      context,
      message,
      tone: TigerFeedbackTone.error,
    );
  }

  static void showSignInRequired(BuildContext context) {
    showError(context, 'Please sign in to continue.');
  }

  static void logWriteError({
    required String operation,
    required Object error,
    StackTrace? stackTrace,
    Map<String, Object?> details = const {},
  }) {
    AppLogger.logOperation(
      operation: operation,
      error: error,
      stackTrace: stackTrace,
      details: details,
    );
  }
}
