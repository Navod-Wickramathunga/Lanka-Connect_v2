import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_refs.dart';
import 'notification_service.dart';

class ReviewService {
  static Future<void> submitReview({
    required String bookingId,
    required String serviceId,
    required String providerId,
    required int rating,
    required String comment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Please sign in to submit a review.',
      );
    }

    final reviewRef = FirestoreRefs.reviews().doc();
    final providerRef = FirestoreRefs.users().doc(providerId);

    // Prevent duplicate reviews for the same booking
    final existingReview = await FirestoreRefs.reviews()
        .where('bookingId', isEqualTo: bookingId)
        .where('reviewerId', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (existingReview.docs.isNotEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'already-exists',
        message: 'You have already reviewed this booking.',
      );
    }

    await FirebaseFirestore.instance.runTransaction((tx) async {
      // All reads MUST come before writes in a Firestore transaction
      final providerSnap = await tx.get(providerRef);
      final providerData = providerSnap.data() ?? {};

      final currentAverage = (providerData['averageRating'] as num?)
          ?.toDouble();
      final currentCount = (providerData['reviewCount'] as num?)?.toInt();

      final safeAverage = currentAverage != null && currentAverage.isFinite
          ? currentAverage
          : 0.0;
      final safeCount = currentCount != null && currentCount > 0
          ? currentCount
          : 0;

      final newCount = safeCount + 1;
      final newAverage = ((safeAverage * safeCount) + rating) / newCount;

      // Now perform all writes
      tx.set(reviewRef, {
        'bookingId': bookingId,
        'serviceId': serviceId,
        'providerId': providerId,
        'reviewerId': user.uid,
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(providerRef, {
        'averageRating': double.parse(newAverage.toStringAsFixed(2)),
        'reviewCount': newCount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    await NotificationService.createMany(
      recipientIds: [providerId, user.uid],
      title: 'New review submitted',
      body: 'A review was submitted with rating $rating/5.',
      type: 'review',
      excludeSender: true,
      data: {
        'bookingId': bookingId,
        'serviceId': serviceId,
        'providerId': providerId,
        'reviewerId': user.uid,
        'rating': rating,
      },
    );

    await NotificationService.notifyAdmins(
      title: 'Review submitted',
      body: 'A review was submitted with rating $rating/5.',
      type: 'review',
      data: {
        'bookingId': bookingId,
        'serviceId': serviceId,
        'providerId': providerId,
        'reviewerId': user.uid,
        'rating': rating,
      },
    );

    // Mark booking as reviewed so UI can hide the review button
    try {
      await FirestoreRefs.bookings().doc(bookingId).update({'reviewed': true});
    } catch (_) {
      // Non-critical — UI will still check reviews collection
    }
  }
}
