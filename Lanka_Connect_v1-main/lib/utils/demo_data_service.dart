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
    final serviceCatalog = _demoServices(
      providerId: providerId,
      approvedServiceOneId: approvedServiceOneId,
      approvedServiceTwoId: approvedServiceTwoId,
      pendingServiceId: pendingServiceId,
    );
    final serviceIds = serviceCatalog.map((entry) => entry.id).toList();

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
      for (final entry in serviceCatalog) {
        await _seedService(
          ref: db.collection('services').doc(entry.id),
          payload: entry.payload,
          desiredStatus: entry.desiredStatus,
          result: result,
        );
      }
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
        'serviceId': 'demo_service_electrical_main',
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
          'services': serviceIds,
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
      'services': serviceIds,
      'bookings': [acceptedBookingId, completedBookingId],
      'reviewId': reviewId,
    };
  }

  static List<({String id, Map<String, dynamic> payload, String desiredStatus})>
  _demoServices({
    required String providerId,
    required String approvedServiceOneId,
    required String approvedServiceTwoId,
    required String pendingServiceId,
  }) {
    final timestamp = {
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    Map<String, dynamic> buildService({
      required String title,
      required String category,
      required num price,
      required String district,
      required String city,
      required double lat,
      required double lng,
      required String description,
      required String status,
    }) {
      return {
        'providerId': providerId,
        'title': title,
        'category': category,
        'price': price,
        'district': district,
        'city': city,
        'location': '$city, $district',
        'lat': lat,
        'lng': lng,
        'description': description,
        'status': status,
        ...timestamp,
      };
    }

    return [
      (
        id: approvedServiceOneId,
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Home Deep Cleaning',
          category: 'Cleaning',
          price: 3500,
          district: 'Colombo',
          city: 'Nugegoda',
          lat: 6.8721,
          lng: 79.8883,
          description: 'Apartment and house deep cleaning service.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_cleaning_office',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Office Sanitizing Crew',
          category: 'Cleaning',
          price: 5200,
          district: 'Colombo',
          city: 'Battaramulla',
          lat: 6.9022,
          lng: 79.9187,
          description: 'Deep office cleaning with disinfecting and glass care.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_cleaning_moveout',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Move-Out Cleaning Team',
          category: 'Cleaning',
          price: 4100,
          district: 'Gampaha',
          city: 'Wattala',
          lat: 6.9902,
          lng: 79.8885,
          description: 'Fast end-of-tenancy cleaning for apartments and homes.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_cleaning_sofa',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Sofa and Mattress Shampooing',
          category: 'Cleaning',
          price: 4800,
          district: 'Kalutara',
          city: 'Panadura',
          lat: 6.7132,
          lng: 79.9026,
          description: 'Fabric-safe shampooing for sofas, chairs, and beds.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_cleaning_postreno',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Post-Renovation Cleanup',
          category: 'Cleaning',
          price: 6200,
          district: 'Galle',
          city: 'Galle',
          lat: 6.0535,
          lng: 80.2210,
          description: 'Dust and debris removal after painting or renovation.',
          status: 'approved',
        ),
      ),
      (
        id: approvedServiceTwoId,
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Quick Plumbing Fix',
          category: 'Plumbing',
          price: 2500,
          district: 'Gampaha',
          city: 'Kadawatha',
          lat: 7.0013,
          lng: 79.9528,
          description: 'Leak repairs and basic plumbing maintenance.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_plumbing_sink',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Kitchen Sink Unclogging',
          category: 'Plumbing',
          price: 2200,
          district: 'Colombo',
          city: 'Dehiwala',
          lat: 6.8513,
          lng: 79.8653,
          description: 'Drain clearing and pipe cleanup for kitchens.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_plumbing_tank',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Water Tank Maintenance',
          category: 'Plumbing',
          price: 3900,
          district: 'Kandy',
          city: 'Kandy',
          lat: 7.2906,
          lng: 80.6337,
          description: 'Float valve checks, minor repairs, and water flow tuning.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_plumbing_bath',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Bathroom Leak Repair',
          category: 'Plumbing',
          price: 3100,
          district: 'Kalutara',
          city: 'Horana',
          lat: 6.7150,
          lng: 80.0640,
          description: 'Tap, shower, and flush leak repairs with replacement parts.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_plumbing_pipe',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Emergency Pipe Replacement',
          category: 'Plumbing',
          price: 5600,
          district: 'Matara',
          city: 'Matara',
          lat: 5.9549,
          lng: 80.5550,
          description: 'Rapid response for burst lines and urgent pipe changes.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_electrical_main',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Electrical Wiring & Repairs',
          category: 'Electrical',
          price: 4500,
          district: 'Colombo',
          city: 'Rajagiriya',
          lat: 6.9060,
          lng: 79.8980,
          description:
              'Full-house wiring inspection, switch replacements, and safety audits.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_electrical_fan',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Ceiling Fan Installation',
          category: 'Electrical',
          price: 2800,
          district: 'Gampaha',
          city: 'Negombo',
          lat: 7.2094,
          lng: 79.8358,
          description: 'Install or replace ceiling fans with secure mounting.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_electrical_db',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'DB Board Safety Inspection',
          category: 'Electrical',
          price: 5200,
          district: 'Colombo',
          city: 'Maharagama',
          lat: 6.8480,
          lng: 79.9265,
          description:
              'Distribution board checks, breaker testing, and load balancing.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_electrical_lighting',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Outdoor Lighting Setup',
          category: 'Electrical',
          price: 4700,
          district: 'Galle',
          city: 'Hikkaduwa',
          lat: 6.1404,
          lng: 80.1017,
          description: 'Garden and gate lighting layout with weather-safe fixtures.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_electrical_generator',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Generator Changeover Support',
          category: 'Electrical',
          price: 6100,
          district: 'Kurunegala',
          city: 'Kurunegala',
          lat: 7.4863,
          lng: 80.3647,
          description: 'Generator wiring checks and safe emergency backup setup.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_carpentry_main',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Custom Furniture Repair',
          category: 'Carpentry',
          price: 5500,
          district: 'Galle',
          city: 'Galle',
          lat: 6.0535,
          lng: 80.2210,
          description: 'Furniture repair, polishing, and custom shelf installation.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_carpentry_door',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Door Frame Restoration',
          category: 'Carpentry',
          price: 4300,
          district: 'Colombo',
          city: 'Kotte',
          lat: 6.8905,
          lng: 79.9023,
          description: 'Frame repairs, alignment fixes, and hinge replacement.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_carpentry_cabinet',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Kitchen Cabinet Fitting',
          category: 'Carpentry',
          price: 7900,
          district: 'Gampaha',
          city: 'Kelaniya',
          lat: 6.9553,
          lng: 79.9220,
          description: 'Cabinet alignment, handle fitting, and shelf installation.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_carpentry_wardrobe',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Wardrobe Hinge Repair',
          category: 'Carpentry',
          price: 2600,
          district: 'Kalutara',
          city: 'Kalutara',
          lat: 6.5854,
          lng: 79.9607,
          description: 'Door alignment, hinge replacement, and sliding door fixes.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_carpentry_shelves',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Floating Shelves Installation',
          category: 'Carpentry',
          price: 3400,
          district: 'Kandy',
          city: 'Peradeniya',
          lat: 7.2661,
          lng: 80.5937,
          description: 'Minimal wall shelves fitted cleanly and securely.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_painting_main',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Interior Wall Painting',
          category: 'Painting',
          price: 8000,
          district: 'Gampaha',
          city: 'Negombo',
          lat: 7.2094,
          lng: 79.8358,
          description: 'Professional interior painting with premium emulsion paint.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_painting_exterior',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Exterior Weather Shield Painting',
          category: 'Painting',
          price: 12500,
          district: 'Galle',
          city: 'Ambalangoda',
          lat: 6.2358,
          lng: 80.0548,
          description: 'Exterior wall coating with weather-resistant finishes.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_painting_flat',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Apartment Repaint Package',
          category: 'Painting',
          price: 9800,
          district: 'Colombo',
          city: 'Colombo 03',
          lat: 6.9047,
          lng: 79.8538,
          description: 'Fast repainting for apartments with prep and cleanup.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_painting_office',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Office Accent Painting',
          category: 'Painting',
          price: 7400,
          district: 'Colombo',
          city: 'Battaramulla',
          lat: 6.9022,
          lng: 79.9187,
          description: 'Brand-color accent walls and neat edge finishing.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_painting_gate',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Gate and Grill Repaint',
          category: 'Painting',
          price: 3600,
          district: 'Matara',
          city: 'Weligama',
          lat: 5.9746,
          lng: 80.4298,
          description: 'Anti-rust sanding and enamel recoating for metal work.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_gardening_main',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Garden Maintenance',
          category: 'Gardening',
          price: 3000,
          district: 'Kandy',
          city: 'Peradeniya',
          lat: 7.2590,
          lng: 80.5970,
          description: 'Lawn mowing, hedge trimming, and seasonal planting.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_gardening_lawn',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Lawn Restoration Visit',
          category: 'Gardening',
          price: 4200,
          district: 'Colombo',
          city: 'Maharagama',
          lat: 6.8480,
          lng: 79.9265,
          description: 'Weed clearing, patch recovery, and lawn feeding.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_gardening_balcony',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Balcony Plant Care',
          category: 'Gardening',
          price: 2400,
          district: 'Colombo',
          city: 'Colombo 07',
          lat: 6.9147,
          lng: 79.8624,
          description: 'Balcony planter cleanup and maintenance for city homes.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_gardening_hedge',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Hedge Shaping Service',
          category: 'Gardening',
          price: 2800,
          district: 'Gampaha',
          city: 'Ja-Ela',
          lat: 7.0745,
          lng: 79.8919,
          description: 'Precise hedge trimming and pathway edge cleanup.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_gardening_landscape',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Seasonal Landscaping Refresh',
          category: 'Gardening',
          price: 6500,
          district: 'Galle',
          city: 'Karapitiya',
          lat: 6.0559,
          lng: 80.2147,
          description: 'Plant bed redesign and color-balanced seasonal planting.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_moving_house',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'House Shifting Assistance',
          category: 'Moving',
          price: 9800,
          district: 'Colombo',
          city: 'Nugegoda',
          lat: 6.8721,
          lng: 79.8883,
          description: 'Packing, loading, transport coordination, and unloading.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_moving_office',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Office Relocation Crew',
          category: 'Moving',
          price: 15500,
          district: 'Colombo',
          city: 'Battaramulla',
          lat: 6.9022,
          lng: 79.9187,
          description: 'Weekend office moves with furniture handling support.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_moving_van',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Furniture Moving Van',
          category: 'Moving',
          price: 7200,
          district: 'Gampaha',
          city: 'Wattala',
          lat: 6.9890,
          lng: 79.8912,
          description: 'Van and crew service for medium-size furniture moves.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_moving_pack',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Packing and Unpacking Help',
          category: 'Moving',
          price: 5400,
          district: 'Kalutara',
          city: 'Panadura',
          lat: 6.7132,
          lng: 79.9026,
          description: 'Boxes, wrapping, and organized room-by-room unpacking.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_moving_small',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Same-Day Small Moves',
          category: 'Moving',
          price: 4600,
          district: 'Kandy',
          city: 'Katugastota',
          lat: 7.3300,
          lng: 80.6159,
          description: 'Quick transport for studio apartments and urgent moves.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_beauty_main',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Bridal Makeup Package',
          category: 'Beauty',
          price: 15000,
          district: 'Colombo',
          city: 'Colombo 07',
          lat: 6.9147,
          lng: 79.8624,
          description:
              'Complete bridal makeup with air-brush finish and trial session.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_beauty_party',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Party Makeup Session',
          category: 'Beauty',
          price: 6800,
          district: 'Gampaha',
          city: 'Negombo',
          lat: 7.2094,
          lng: 79.8358,
          description: 'Event makeup with hairstyling support at your location.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_beauty_hair',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Haircut at Home',
          category: 'Beauty',
          price: 2500,
          district: 'Colombo',
          city: 'Dehiwala',
          lat: 6.8513,
          lng: 79.8653,
          description: 'Convenient home haircut service for women and men.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_beauty_nails',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Nail Care Set',
          category: 'Beauty',
          price: 3900,
          district: 'Colombo',
          city: 'Maharagama',
          lat: 6.8480,
          lng: 79.9265,
          description: 'Basic manicure and gel polish service at home.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_beauty_facial',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Facial Treatment Visit',
          category: 'Beauty',
          price: 5200,
          district: 'Galle',
          city: 'Galle',
          lat: 6.0535,
          lng: 80.2210,
          description: 'Hydrating facial care with cleanup and skin prep advice.',
          status: 'approved',
        ),
      ),
      (
        id: pendingServiceId,
        desiredStatus: 'pending',
        payload: buildService(
          title: 'Math Tutoring (O/L)',
          category: 'Tutoring',
          price: 2000,
          district: 'Colombo',
          city: 'Dehiwala',
          lat: 6.8560,
          lng: 79.8650,
          description: 'One-to-one O/L maths support sessions.',
          status: 'pending',
        ),
      ),
      (
        id: 'demo_service_tutoring_math',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Advanced Math Home Tutoring',
          category: 'Tutoring',
          price: 2600,
          district: 'Colombo',
          city: 'Nugegoda',
          lat: 6.8721,
          lng: 79.8883,
          description: 'Targeted maths tutoring for local and Cambridge exams.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_tutoring_english',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'English Exam Prep Classes',
          category: 'Tutoring',
          price: 2300,
          district: 'Gampaha',
          city: 'Kadawatha',
          lat: 7.0013,
          lng: 79.9528,
          description: 'Writing, grammar, and speaking support for school exams.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_tutoring_science',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Science Home Tutoring',
          category: 'Tutoring',
          price: 2800,
          district: 'Kandy',
          city: 'Kandy',
          lat: 7.2906,
          lng: 80.6337,
          description: 'Practical science guidance with revision-focused sessions.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_tutoring_grade5',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'Grade 5 Scholarship Coaching',
          category: 'Tutoring',
          price: 2400,
          district: 'Kurunegala',
          city: 'Kuliyapitiya',
          lat: 7.4688,
          lng: 80.0401,
          description: 'Structured scholarship preparation with weekly drills.',
          status: 'approved',
        ),
      ),
      (
        id: 'demo_service_tutoring_ict',
        desiredStatus: 'approved',
        payload: buildService(
          title: 'ICT Basics Coaching',
          category: 'Tutoring',
          price: 2200,
          district: 'Matara',
          city: 'Weligama',
          lat: 5.9746,
          lng: 80.4298,
          description: 'Computer basics, Office apps, and beginner internet skills.',
          status: 'approved',
        ),
      ),
    ];
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
