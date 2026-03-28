import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class DemoDataService {
  static Future<Map<String, dynamic>> seed() async {
    final callerUid = FirebaseAuth.instance.currentUser?.uid;
    if (callerUid == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Sign in before seeding demo data.',
      );
    }

    final db = FirebaseFirestore.instance;
    final callerRef = db.collection('users').doc(callerUid);
    final callerSnap = await callerRef.get();
    final role = (callerSnap.data()?['role'] ?? '').toString().toLowerCase();
    if (role != 'admin') {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Only admin can seed demo data.',
      );
    }

    final providerId = 'demo_provider';
    const approvedServiceOneId = 'demo_service_cleaning';
    const approvedServiceTwoId = 'demo_service_plumbing';
    const pendingServiceId = 'demo_service_tutoring';
    const approvedServiceElectricalId = 'demo_service_electrical';
    const approvedServicePaintingId = 'demo_service_painting';
    const approvedServiceGardeningId = 'demo_service_gardening';
    const approvedServiceBeautyId = 'demo_service_beauty';
    const approvedServiceCarpentryId = 'demo_service_carpentry';
    const demoRequestPendingId = 'demo_request_pending';
    const demoRequestRejectedId = 'demo_request_rejected';
    const demoRequestAcceptedId = 'demo_request_accepted';
    const promoWeekendId = 'demo_promo_weekend';
    const promoPlumbingId = 'demo_promo_plumbing';
    const demoOfferId = 'demo_offer_cleaning';
    final suffix = callerUid.substring(0, 6);
    final acceptedBookingId = 'demo_booking_accepted_$suffix';
    final completedBookingId = 'demo_booking_completed_$suffix';
    final result = <String, dynamic>{
      'ok': false,
      'created': 0,
      'updated': 0,
      'skipped': 0,
    };

    final providerRef = db.collection('users').doc(providerId);
    const providerBankAccountId = 'demo_provider_bank_primary';
    final providerBankRef = db
        .collection('providerBankAccounts')
        .doc(providerBankAccountId);
    final serviceOneRef = db.collection('services').doc(approvedServiceOneId);
    final serviceTwoRef = db.collection('services').doc(approvedServiceTwoId);
    final pendingServiceRef = db.collection('services').doc(pendingServiceId);
    final requestPendingRef = db
        .collection('requests')
        .doc(demoRequestPendingId);
    final requestRejectedRef = db
        .collection('requests')
        .doc(demoRequestRejectedId);
    final promoWeekendRef = db.collection('promotions').doc(promoWeekendId);
    final promoPlumbingRef = db.collection('promotions').doc(promoPlumbingId);
    final acceptedBookingRef = db.collection('bookings').doc(acceptedBookingId);
    final completedBookingRef = db
        .collection('bookings')
        .doc(completedBookingId);

    try {
      await providerRef.set({
        'role': 'provider',
        'name': 'Demo Provider',
        'email': 'demo.provider@lankaconnect.app',
        'contact': '+94770000000',
        'district': 'Colombo',
        'city': 'Maharagama',
        'skills': ['Home Cleaning', 'Plumbing'],
        'bio': 'Demo profile for presentation and testing.',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      result['updated'] = (result['updated'] as int) + 1;
    } catch (e, st) {
      _logPhaseError('seed_demo_provider', e, st);
      throw _seedPhaseException('seed_demo_provider', e);
    }

    try {
      await providerBankRef.set({
        'providerId': providerId,
        'bankName': 'Bank of Ceylon',
        'accountName': 'Demo Provider',
        'accountNumberMasked': '****5678',
        'branch': 'Maharagama',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      result['updated'] = (result['updated'] as int) + 1;
    } catch (e, st) {
      _logPhaseError('seed_demo_provider_bank_account', e, st);
      throw _seedPhaseException('seed_demo_provider_bank_account', e);
    }

    try {
      await _seedService(
        ref: serviceOneRef,
        payload: {
          'providerId': providerId,
          'title': 'Home Deep Cleaning',
          'category': 'Cleaning',
          'price': 3500,
          'district': 'Colombo',
          'city': 'Nugegoda',
          'location': 'Nugegoda, Colombo',
          'lat': 6.8721,
          'lng': 79.8883,
          'description': 'Apartment and house deep cleaning service.',
          'status': 'approved',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        desiredStatus: 'approved',
        result: result,
      );
      await _seedService(
        ref: serviceTwoRef,
        payload: {
          'providerId': providerId,
          'title': 'Quick Plumbing Fix',
          'category': 'Plumbing',
          'price': 2500,
          'district': 'Gampaha',
          'city': 'Kadawatha',
          'location': 'Kadawatha, Gampaha',
          'lat': 7.0013,
          'lng': 79.9528,
          'description': 'Leak repairs and basic plumbing maintenance.',
          'status': 'approved',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        desiredStatus: 'approved',
        result: result,
      );
      await _seedService(
        ref: pendingServiceRef,
        payload: {
          'providerId': providerId,
          'title': 'Math Tutoring (O/L)',
          'category': 'Tutoring',
          'price': 2000,
          'district': 'Colombo',
          'city': 'Dehiwala',
          'location': 'Dehiwala, Colombo',
          'lat': 6.8560,
          'lng': 79.8650,
          'description': 'One-to-one O/L maths support sessions.',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        desiredStatus: 'pending',
        result: result,
      );

      // Additional diverse services
      await _seedService(
        ref: db.collection('services').doc(approvedServiceElectricalId),
        payload: {
          'providerId': providerId,
          'title': 'Electrical Wiring & Repairs',
          'category': 'Electrical',
          'price': 4500,
          'district': 'Colombo',
          'city': 'Rajagiriya',
          'location': 'Rajagiriya, Colombo',
          'lat': 6.9060,
          'lng': 79.8980,
          'description':
              'Full-house wiring inspection, switch replacements, and safety audits.',
          'status': 'approved',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        desiredStatus: 'approved',
        result: result,
      );
      await _seedService(
        ref: db.collection('services').doc(approvedServicePaintingId),
        payload: {
          'providerId': providerId,
          'title': 'Interior Wall Painting',
          'category': 'Painting',
          'price': 8000,
          'district': 'Gampaha',
          'city': 'Negombo',
          'location': 'Negombo, Gampaha',
          'lat': 7.2094,
          'lng': 79.8358,
          'description':
              'Professional interior painting with premium emulsion paint. Includes furniture covering.',
          'status': 'approved',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        desiredStatus: 'approved',
        result: result,
      );
      await _seedService(
        ref: db.collection('services').doc(approvedServiceGardeningId),
        payload: {
          'providerId': providerId,
          'title': 'Garden Maintenance',
          'category': 'Gardening',
          'price': 3000,
          'district': 'Kandy',
          'city': 'Peradeniya',
          'location': 'Peradeniya, Kandy',
          'lat': 7.2590,
          'lng': 80.5970,
          'description':
              'Lawn mowing, hedge trimming, and seasonal planting by experienced gardeners.',
          'status': 'approved',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        desiredStatus: 'approved',
        result: result,
      );
      await _seedService(
        ref: db.collection('services').doc(approvedServiceBeautyId),
        payload: {
          'providerId': providerId,
          'title': 'Bridal Makeup Package',
          'category': 'Beauty',
          'price': 15000,
          'district': 'Colombo',
          'city': 'Colombo 07',
          'location': 'Colombo 07, Colombo',
          'lat': 6.9147,
          'lng': 79.8624,
          'description':
              'Complete bridal makeup with air-brush finish. Includes trial session.',
          'status': 'approved',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        desiredStatus: 'approved',
        result: result,
      );
      await _seedService(
        ref: db.collection('services').doc(approvedServiceCarpentryId),
        payload: {
          'providerId': providerId,
          'title': 'Custom Furniture Repair',
          'category': 'Carpentry',
          'price': 5500,
          'district': 'Galle',
          'city': 'Galle',
          'location': 'Galle, Galle',
          'lat': 6.0535,
          'lng': 80.2210,
          'description':
              'Furniture repair, polishing, and custom shelf installation.',
          'status': 'approved',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        desiredStatus: 'approved',
        result: result,
      );
    } catch (e, st) {
      _logPhaseError('seed_demo_services', e, st);
      throw _seedPhaseException('seed_demo_services', e);
    }

    try {
      await _ensureBooking(
        ref: acceptedBookingRef,
        createPayload: {
          'serviceId': approvedServiceOneId,
          'providerId': providerId,
          'seekerId': callerUid,
          'amount': 3500,
          'status': 'pending',
          'scheduledDateKey': DateTime.now()
              .add(const Duration(days: 2))
              .toIso8601String()
              .split('T')
              .first,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        desiredStatus: 'accepted',
        result: result,
      );

      await _ensureBooking(
        ref: completedBookingRef,
        createPayload: {
          'serviceId': approvedServiceTwoId,
          'providerId': providerId,
          'seekerId': callerUid,
          'amount': 2500,
          'status': 'pending',
          'scheduledDateKey': DateTime.now()
              .subtract(const Duration(days: 3))
              .toIso8601String()
              .split('T')
              .first,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        desiredStatus: 'completed',
        result: result,
      );
    } catch (e, st) {
      _logPhaseError('seed_demo_bookings', e, st);
      throw _seedPhaseException('seed_demo_bookings', e);
    }

    try {
      await requestPendingRef.set({
        'serviceId': approvedServiceOneId,
        'providerId': providerId,
        'seekerId': callerUid,
        'status': 'pending',
        'timeWindow': 'Morning',
        'notes': 'Need access from the side gate.',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await requestRejectedRef.set({
        'serviceId': pendingServiceId,
        'providerId': providerId,
        'seekerId': callerUid,
        'status': 'rejected',
        'timeWindow': 'Flexible',
        'notes': 'Need support after office hours.',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await db.collection('requests').doc(demoRequestAcceptedId).set({
        'serviceId': approvedServiceElectricalId,
        'providerId': providerId,
        'seekerId': callerUid,
        'status': 'accepted',
        'timeWindow': 'Morning',
        'scheduledDate': DateTime.now()
            .add(const Duration(days: 2))
            .toIso8601String()
            .split('T')
            .first,
        'notes': 'Please bring extra wire rolls.',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await db.collection('offers').doc(demoOfferId).set({
        'title': '20% Off Cleaning Services',
        'description': 'Book any Cleaning service this week and save 20%.',
        'discountType': 'percentage',
        'discountValue': 20,
        'linkedCategory': 'Cleaning',
        'targetCategory': 'Cleaning',
        'isActive': true,
        'active': true,
        'startsAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
        'endsAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30)),
        ),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await promoWeekendRef.set({
        'title': 'Weekend Cleaner',
        'description': 'Save on your next home cleaning booking.',
        'discount': '15% OFF',
        'linkedCategory': 'Cleaning',
        'colorHex': 'F43F5E',
        'iconName': 'cleaning_services',
        'expiry': 'Ends Sunday',
        'active': true,
        'order': 1,
      }, SetOptions(merge: true));
      await promoPlumbingRef.set({
        'title': 'Pipe Rescue',
        'description': 'Flat discount on quick plumbing fixes.',
        'discount': 'Rs. 500 OFF',
        'linkedCategory': 'Plumbing',
        'colorHex': '2563EB',
        'iconName': 'plumbing',
        'expiry': 'Limited Time',
        'active': true,
        'order': 2,
      }, SetOptions(merge: true));
      result['updated'] = (result['updated'] as int) + 6;
    } catch (e, st) {
      _logPhaseError('seed_demo_requests_promotions', e, st);
      throw _seedPhaseException('seed_demo_requests_promotions', e);
    }

    late final String reviewId;
    try {
      reviewId = await _createReviewAndAggregate(
        db: db,
        providerRef: providerRef,
        completedBookingId: completedBookingId,
        serviceId: approvedServiceTwoId,
        providerId: providerId,
        reviewerId: callerUid,
      );
      result['created'] = (result['created'] as int) + 1;
    } catch (e, st) {
      _logPhaseError('seed_demo_review', e, st);
      throw _seedPhaseException('seed_demo_review', e);
    }

    try {
      final notificationRef = db.collection('notifications').doc();
      await notificationRef.set({
        'recipientId': callerUid,
        'senderId': callerUid,
        'title': 'Demo data ready',
        'body':
            'Seed completed successfully. Refresh tabs to view sample data.',
        'type': 'system',
        'data': {
          'services': [
            approvedServiceOneId,
            approvedServiceTwoId,
            pendingServiceId,
            approvedServiceElectricalId,
            approvedServicePaintingId,
            approvedServiceGardeningId,
            approvedServiceBeautyId,
            approvedServiceCarpentryId,
          ],
          'bookings': [acceptedBookingId, completedBookingId],
          'requests': [
            demoRequestPendingId,
            demoRequestRejectedId,
            demoRequestAcceptedId,
          ],
          'promotions': [promoWeekendId, promoPlumbingId],
          'offers': [demoOfferId],
          'summary': {
            'created': result['created'],
            'updated': result['updated'],
            'skipped': result['skipped'],
          },
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      result['created'] = (result['created'] as int) + 1;
    } catch (e, st) {
      _logPhaseError('seed_demo_notification', e, st);
      throw _seedPhaseException('seed_demo_notification', e);
    }

    return {
      ...result,
      'ok': true,
      'providerId': providerId,
      'services': [
        approvedServiceOneId,
        approvedServiceTwoId,
        pendingServiceId,
        approvedServiceElectricalId,
        approvedServicePaintingId,
        approvedServiceGardeningId,
        approvedServiceBeautyId,
        approvedServiceCarpentryId,
      ],
      'bookings': [acceptedBookingId, completedBookingId],
      'reviewId': reviewId,
    };
  }

  static Future<void> _seedService({
    required DocumentReference<Map<String, dynamic>> ref,
    required Map<String, dynamic> payload,
    required String desiredStatus,
    required Map<String, dynamic> result,
  }) async {
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set(payload);
      result['created'] = (result['created'] as int) + 1;
      return;
    }

    final currentStatus = (snap.data()?['status'] ?? '').toString();
    if (currentStatus == desiredStatus) {
      result['skipped'] = (result['skipped'] as int) + 1;
      return;
    }

    await ref.update({
      'status': desiredStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    result['updated'] = (result['updated'] as int) + 1;
  }

  static Future<void> _ensureBooking({
    required DocumentReference<Map<String, dynamic>> ref,
    required Map<String, dynamic> createPayload,
    required String desiredStatus,
    required Map<String, dynamic> result,
  }) async {
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set(createPayload);
      result['created'] = (result['created'] as int) + 1;
    }

    final status =
        (snap.data()?['status'] ?? createPayload['status'] ?? 'pending')
            .toString();

    if (desiredStatus == 'accepted') {
      if (status == 'accepted' || status == 'completed') {
        result['skipped'] = (result['skipped'] as int) + 1;
        return;
      }
      await ref.update({
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      result['updated'] = (result['updated'] as int) + 1;
      return;
    }

    if (status == 'completed') {
      result['skipped'] = (result['skipped'] as int) + 1;
      return;
    }

    if (status == 'pending') {
      await ref.update({
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      result['updated'] = (result['updated'] as int) + 1;
    }

    await ref.update({
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    result['updated'] = (result['updated'] as int) + 1;
  }

  static Future<String> _createReviewAndAggregate({
    required FirebaseFirestore db,
    required DocumentReference<Map<String, dynamic>> providerRef,
    required String completedBookingId,
    required String serviceId,
    required String providerId,
    required String reviewerId,
  }) async {
    final reviewRef = db.collection('reviews').doc();
    await db.runTransaction((tx) async {
      final providerSnap = await tx.get(providerRef);
      final providerData = providerSnap.data() ?? {};
      final safeAverage = _asDouble(providerData['averageRating']) ?? 0.0;
      final safeCount = _asInt(providerData['reviewCount']) ?? 0;
      final newCount = safeCount + 1;
      final newAverage = ((safeAverage * safeCount) + 5) / newCount;

      tx.set(reviewRef, {
        'bookingId': completedBookingId,
        'serviceId': serviceId,
        'providerId': providerId,
        'reviewerId': reviewerId,
        'rating': 5,
        'comment': 'Reliable and quick service. Great for demo data.',
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(providerRef, {
        'averageRating': double.parse(newAverage.toStringAsFixed(2)),
        'reviewCount': newCount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    return reviewRef.id;
  }

  static void _logPhaseError(
    String phase,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint('Seed error [$phase]: $error');
    debugPrint(stackTrace.toString());
  }

  static FirebaseException _seedPhaseException(String phase, Object error) {
    if (error is FirebaseException) {
      return FirebaseException(
        plugin: error.plugin,
        code: error.code,
        message: 'Seed failed at $phase: ${error.message ?? error.code}',
      );
    }
    return FirebaseException(
      plugin: 'cloud_firestore',
      code: 'seed-failed',
      message: 'Seed failed at $phase: $error',
    );
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
