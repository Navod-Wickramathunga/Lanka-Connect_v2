import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../ui/mobile/mobile_components.dart';
import '../../ui/mobile/mobile_page_scaffold.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/web/web_page_scaffold.dart';
import '../../utils/geo_utils.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/notification_service.dart';
import '../../utils/user_roles.dart';
import '../../widgets/service_map_preview.dart';
import 'service_map_screen.dart';

class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  /// Deletes a service if it has no active bookings (pending/accepted).
  static Future<void> _confirmDeleteService(
    BuildContext context,
    String serviceId,
  ) async {
    // Check for active bookings first
    final activeBookings = await FirestoreRefs.bookings()
        .where('serviceId', isEqualTo: serviceId)
        .where('status', whereIn: ['pending', 'accepted'])
        .limit(1)
        .get();

    if (activeBookings.docs.isNotEmpty) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cannot Delete'),
            content: const Text(
              'This service has active bookings (pending or accepted). '
              'Complete or cancel them before deleting the service.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service'),
        content: const Text(
          'Are you sure you want to permanently delete this service?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirestoreRefs.services().doc(serviceId).delete();
      if (context.mounted) {
        Navigator.of(context).pop(); // Go back after deletion
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Service deleted.')));
      }
    } catch (e) {
      if (context.mounted) {
        FirestoreErrorHandler.showError(
          context,
          'Failed to delete service: $e',
        );
      }
    }
  }

  static void _showFullImage(
    BuildContext context,
    List<String> urls,
    int initial,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('${initial + 1} / ${urls.length}'),
          ),
          body: PageView.builder(
            controller: PageController(initialPage: initial),
            itemCount: urls.length,
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    urls[index],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) => const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _servicePage({
    required BuildContext context,
    required String title,
    required Widget body,
    Color accentColor = MobileTokens.primary,
  }) {
    if (kIsWeb) {
      return WebPageScaffold(
        title: title,
        subtitle: 'Detailed service information and actions.',
        useScaffold: true,
        child: body,
      );
    }
    return MobilePageScaffold(
      title: title,
      subtitle: 'Detailed service information and actions.',
      accentColor: accentColor,
      useScaffold: true,
      body: body,
    );
  }

  Future<void> _createBooking(
    BuildContext context,
    String serviceId,
    String providerId,
    double amount,
    String serviceTitle,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      FirestoreErrorHandler.showSignInRequired(context);
      return;
    }

    try {
      final bookingRef = await FirestoreRefs.bookings().add({
        'serviceId': serviceId,
        'providerId': providerId,
        'seekerId': user.uid,
        'amount': amount,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await NotificationService.createMany(
        recipientIds: [providerId, user.uid],
        title: 'Booking request created',
        body: 'Booking request for "$serviceTitle" is pending provider action.',
        type: 'booking',
        data: {
          'bookingId': bookingRef.id,
          'serviceId': serviceId,
          'providerId': providerId,
          'seekerId': user.uid,
          'status': 'pending',
        },
      );
      await NotificationService.notifyAdmins(
        title: 'New booking request',
        body: 'A new booking request was created for "$serviceTitle".',
        data: {
          'bookingId': bookingRef.id,
          'serviceId': serviceId,
          'providerId': providerId,
          'seekerId': user.uid,
          'status': 'pending',
        },
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Booking request sent.')));
    } on FirebaseException catch (e, st) {
      FirestoreErrorHandler.logWriteError(
        operation: 'bookings_add',
        error: e,
        stackTrace: st,
        details: {
          'uid': user.uid,
          'serviceId': serviceId,
          'providerId': providerId,
        },
      );
      if (context.mounted) {
        FirestoreErrorHandler.showError(
          context,
          FirestoreErrorHandler.toUserMessage(e),
        );
      }
    } catch (e, st) {
      FirestoreErrorHandler.logWriteError(
        operation: 'bookings_add_unknown',
        error: e,
        stackTrace: st,
        details: {
          'uid': user.uid,
          'serviceId': serviceId,
          'providerId': providerId,
        },
      );
      if (context.mounted) {
        FirestoreErrorHandler.showError(
          context,
          FirestoreErrorHandler.toUserMessage(e),
        );
      }
    }
  }

  Future<void> _createRequest(
    BuildContext context,
    String serviceId,
    String providerId,
    String serviceTitle,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      FirestoreErrorHandler.showSignInRequired(context);
      return;
    }

    try {
      final requestRef = await FirestoreRefs.requests().add({
        'serviceId': serviceId,
        'providerId': providerId,
        'seekerId': user.uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await NotificationService.createMany(
        recipientIds: [providerId, user.uid],
        title: 'Service request created',
        body: 'A request for "$serviceTitle" is now pending provider action.',
        type: 'request',
        data: {
          'requestId': requestRef.id,
          'serviceId': serviceId,
          'providerId': providerId,
          'seekerId': user.uid,
          'status': 'pending',
        },
      );
      await NotificationService.notifyAdmins(
        title: 'New service request',
        body: 'A new service request was created for "$serviceTitle".',
        data: {
          'requestId': requestRef.id,
          'serviceId': serviceId,
          'providerId': providerId,
          'seekerId': user.uid,
          'status': 'pending',
        },
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Service request created.')));
    } on FirebaseException catch (e, st) {
      FirestoreErrorHandler.logWriteError(
        operation: 'requests_add',
        error: e,
        stackTrace: st,
        details: {
          'uid': user.uid,
          'serviceId': serviceId,
          'providerId': providerId,
        },
      );
      if (context.mounted) {
        FirestoreErrorHandler.showError(
          context,
          FirestoreErrorHandler.toUserMessage(e),
        );
      }
    } catch (e, st) {
      FirestoreErrorHandler.logWriteError(
        operation: 'requests_add_unknown',
        error: e,
        stackTrace: st,
        details: {
          'uid': user.uid,
          'serviceId': serviceId,
          'providerId': providerId,
        },
      );
      if (context.mounted) {
        FirestoreErrorHandler.showError(
          context,
          FirestoreErrorHandler.toUserMessage(e),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kIsWeb) {
        return const WebPageScaffold(
          title: 'Service',
          subtitle: 'Detailed service information and actions.',
          useScaffold: true,
          child: Center(child: Text('Not signed in')),
        );
      }
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.services().doc(serviceId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _servicePage(
            context: context,
            title: 'Service',
            body: Center(
              child: Text(FirestoreErrorHandler.toUserMessage(snapshot.error!)),
            ),
          );
        }
        if (!snapshot.hasData) {
          return _servicePage(
            context: context,
            title: 'Service',
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data();
        if (data == null) {
          return _servicePage(
            context: context,
            title: 'Service',
            body: const Center(child: Text('Service not found.')),
          );
        }
        final providerId = (data['providerId'] ?? '').toString();
        final city = (data['city'] ?? '').toString().trim();
        final district = (data['district'] ?? '').toString().trim();
        final location = (city.isNotEmpty || district.isNotEmpty)
            ? '$city, $district'
            : (data['location'] ?? '').toString();
        final point = GeoUtils.extractPoint(data);
        final rawImages = data['imageUrls'];
        final imageUrls = rawImages is List
            ? rawImages
                  .map((e) => e.toString())
                  .where((u) => u.isNotEmpty)
                  .toList()
            : <String>[];

        return _servicePage(
          context: context,
          title: (data['title'] ?? 'Service').toString(),
          accentColor: MobileTokens.accent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MobileSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          MobileStatusChip(
                            label: (data['status'] ?? 'pending').toString(),
                            color: (data['status'] ?? '') == 'approved'
                                ? MobileTokens.secondary
                                : MobileTokens.accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['category'] ?? '',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Location: $location'),
                      Text('Price: LKR ${data['price'] ?? ''}'),
                    ],
                  ),
                ),
                if (imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: PageView.builder(
                      itemCount: imageUrls.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () =>
                              _showFullImage(context, imageUrls, index),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                imageUrls[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                                errorBuilder: (context, error, stack) =>
                                    const Center(
                                      child: Icon(Icons.broken_image, size: 48),
                                    ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (imageUrls.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${imageUrls.length} photos — swipe to browse',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
                if (point != null) ...[
                  const SizedBox(height: 12),
                  ServiceMapPreview(
                    point: point,
                    title: (data['title'] ?? 'Service').toString(),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ServiceMapScreen(
                            items: [
                              ServiceMapItem(
                                serviceId: serviceId,
                                title: (data['title'] ?? 'Service').toString(),
                                locationLabel: location,
                                priceLabel: 'LKR ${data['price'] ?? ''}',
                                point: point,
                              ),
                            ],
                            initialCenter: point,
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 12),
                MobileSectionCard(child: Text(data['description'] ?? '')),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirestoreRefs.reviews()
                      .where('serviceId', isEqualTo: serviceId)
                      .snapshots(),
                  builder: (context, reviewSnapshot) {
                    if (reviewSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const SizedBox(
                        height: 24,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (reviewSnapshot.hasError) {
                      return const Text('Could not load reviews right now.');
                    }
                    final reviews = reviewSnapshot.data?.docs ?? [];
                    if (reviews.isEmpty) {
                      return const Text('No reviews yet.');
                    }
                    final avg =
                        reviews
                            .map((doc) => (doc.data()['rating'] ?? 0) as int)
                            .fold<int>(0, (total, item) => total + item) /
                        reviews.length;
                    return Text('Average rating: ${avg.toStringAsFixed(1)}');
                  },
                ),
                const SizedBox(height: 16),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirestoreRefs.users().doc(user.uid).snapshots(),
                  builder: (context, roleSnapshot) {
                    final role = user.isAnonymous
                        ? UserRoles.guest
                        : UserRoles.normalize(roleSnapshot.data?.data()?['role']);
                    final isOwner = providerId == user.uid;

                    // Provider who owns this service — can delete it
                    if (role == UserRoles.provider && isOwner) {
                      return OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete Service'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () =>
                            _confirmDeleteService(context, serviceId),
                      );
                    }

                    // Provider viewing someone else's service — no actions
                    if (role == UserRoles.provider) {
                      return const SizedBox.shrink();
                    }

                    // Admin — can approve/reject services
                    if (role == UserRoles.admin) {
                      final serviceStatus = (data['status'] ?? 'pending')
                          .toString();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (serviceStatus != 'approved')
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Approve Service'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                try {
                                  await FirestoreRefs.services()
                                      .doc(serviceId)
                                      .update({
                                        'status': 'approved',
                                        'updatedAt':
                                            FieldValue.serverTimestamp(),
                                      });
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Service approved.'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    FirestoreErrorHandler.showError(
                                      context,
                                      'Failed to approve: $e',
                                    );
                                  }
                                }
                              },
                            ),
                          if (serviceStatus != 'rejected') ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.block),
                              label: const Text('Reject Service'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              onPressed: () async {
                                try {
                                  await FirestoreRefs.services()
                                      .doc(serviceId)
                                      .update({
                                        'status': 'rejected',
                                        'updatedAt':
                                            FieldValue.serverTimestamp(),
                                      });
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Service rejected.'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    FirestoreErrorHandler.showError(
                                      context,
                                      'Failed to reject: $e',
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete Service'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            onPressed: () =>
                                _confirmDeleteService(context, serviceId),
                          ),
                        ],
                      );
                    }

                    // Seeker — can book or create request
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (role == UserRoles.guest)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Guest mode: Create an account to keep booking history and access chat later.',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ElevatedButton(
                          onPressed: () => _createBooking(
                            context,
                            serviceId,
                            providerId,
                            (data['price'] is num)
                                ? (data['price'] as num).toDouble()
                                : 0.0,
                            (data['title'] ?? 'service').toString(),
                          ),
                          child: const Text('Book Service'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => _createRequest(
                            context,
                            serviceId,
                            providerId,
                            (data['title'] ?? 'service').toString(),
                          ),
                          child: const Text('Create Request'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
