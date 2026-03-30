import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../ui/mobile/mobile_components.dart';
import '../../ui/mobile/mobile_page_scaffold.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/web/web_page_scaffold.dart';
import '../../utils/app_feedback.dart';
import '../../utils/geo_utils.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/notification_service.dart';
import '../../utils/presence_service.dart';
import '../../utils/profile_identity.dart';
import '../../utils/service_image_defaults.dart';
import '../../utils/user_roles.dart';
import '../../widgets/service_map_preview.dart';
import '../../widgets/service_visual.dart';
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
        TigerFeedback.show(
          context,
          'Service deleted',
          tone: TigerFeedbackTone.success,
        );
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

  Future<Map<String, dynamic>> _loadServiceActionData(String serviceId) async {
    final serviceSnap = await FirestoreRefs.services().doc(serviceId).get();
    final serviceData = serviceSnap.data();
    if (serviceData == null) {
      throw StateError('This service is no longer available.');
    }

    final providerId = (serviceData['providerId'] ?? '').toString().trim();
    if (providerId.isEmpty) {
      throw StateError('This service is missing its provider link.');
    }

    return serviceData;
  }

  Future<void> _createBooking(
    BuildContext context,
    String serviceId,
    String providerId,
    double amount,
    String serviceTitle,
    DateTime? scheduledDate,
    String timeWindow,
    String notes,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      FirestoreErrorHandler.showSignInRequired(context);
      return;
    }
    if (serviceId.trim().isEmpty || providerId.trim().isEmpty) {
      FirestoreErrorHandler.showError(
        context,
        'This service is missing its provider link. Refresh and try again.',
      );
      return;
    }
    if (providerId == user.uid) {
      FirestoreErrorHandler.showError(
        context,
        'You cannot create a booking for your own service.',
      );
      return;
    }

    try {
      final serviceData = await _loadServiceActionData(serviceId);
      final resolvedProviderId = (serviceData['providerId'] ?? '')
          .toString()
          .trim();
      final resolvedAmount = serviceData['price'] is num
          ? (serviceData['price'] as num).toDouble()
          : amount;

      if (resolvedProviderId == user.uid) {
        if (context.mounted) {
          FirestoreErrorHandler.showError(
            context,
            'You cannot create a booking for your own service.',
          );
        }
        return;
      }

      final bookingRef = await FirestoreRefs.bookings().add({
        'serviceId': serviceId,
        'providerId': resolvedProviderId,
        'seekerId': user.uid,
        'amount': resolvedAmount,
        'notes': notes,
        'status': 'pending',
        if (scheduledDate != null)
          'scheduledDate': Timestamp.fromDate(scheduledDate),
        if (scheduledDate != null)
          'scheduledDateKey': DateFormat('yyyy-MM-dd').format(scheduledDate),
        if (timeWindow.trim().isNotEmpty) 'timeWindow': timeWindow,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await NotificationService.createManySafe(
        recipientIds: [resolvedProviderId, user.uid],
        title: 'Booking request created',
        body: 'Booking request for "$serviceTitle" is pending provider action.',
        type: 'booking',
        excludeSender: true,
        data: {
          'bookingId': bookingRef.id,
          'serviceId': serviceId,
          'providerId': resolvedProviderId,
          'seekerId': user.uid,
          'status': 'pending',
        },
      );
      await NotificationService.notifyAdminsSafe(
        title: 'New booking request',
        body: 'A new booking request was created for "$serviceTitle".',
        data: {
          'bookingId': bookingRef.id,
          'serviceId': serviceId,
          'providerId': resolvedProviderId,
          'seekerId': user.uid,
          'status': 'pending',
        },
      );

      if (!context.mounted) return;
      TigerFeedback.show(
        context,
        'Tiger sent your booking request.',
        tone: TigerFeedbackTone.success,
      );
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
    DateTime? scheduledDate,
    String timeWindow,
    String? requestedTimeLabel,
    String notes,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      FirestoreErrorHandler.showSignInRequired(context);
      return;
    }
    if (serviceId.trim().isEmpty || providerId.trim().isEmpty) {
      FirestoreErrorHandler.showError(
        context,
        'This service is missing its provider link. Refresh and try again.',
      );
      return;
    }
    if (providerId == user.uid) {
      FirestoreErrorHandler.showError(
        context,
        'You cannot create a request for your own service.',
      );
      return;
    }

    try {
      final serviceData = await _loadServiceActionData(serviceId);
      final resolvedProviderId = (serviceData['providerId'] ?? '')
          .toString()
          .trim();

      if (resolvedProviderId == user.uid) {
        if (context.mounted) {
          FirestoreErrorHandler.showError(
            context,
            'You cannot create a request for your own service.',
          );
        }
        return;
      }

      final requestRef = await FirestoreRefs.requests().add({
        'serviceId': serviceId,
        'providerId': resolvedProviderId,
        'seekerId': user.uid,
        'notes': notes,
        'status': 'pending',
        if (scheduledDate != null)
          'scheduledDate': Timestamp.fromDate(scheduledDate),
        if (scheduledDate != null)
          'scheduledDateKey': DateFormat('yyyy-MM-dd').format(scheduledDate),
        if (timeWindow.trim().isNotEmpty) 'timeWindow': timeWindow,
        if ((requestedTimeLabel ?? '').trim().isNotEmpty)
          'requestedTimeLabel': requestedTimeLabel,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await NotificationService.createManySafe(
        recipientIds: [resolvedProviderId, user.uid],
        title: 'Service request created',
        body: 'A request for "$serviceTitle" is now pending provider action.',
        type: 'request',
        excludeSender: true,
        data: {
          'requestId': requestRef.id,
          'serviceId': serviceId,
          'providerId': resolvedProviderId,
          'seekerId': user.uid,
          'status': 'pending',
        },
      );
      await NotificationService.notifyAdminsSafe(
        title: 'New service request',
        body: 'A new service request was created for "$serviceTitle".',
        data: {
          'requestId': requestRef.id,
          'serviceId': serviceId,
          'providerId': resolvedProviderId,
          'seekerId': user.uid,
          'status': 'pending',
        },
      );

      if (!context.mounted) return;
      TigerFeedback.show(
        context,
        'Tiger sent your request to the provider.',
        tone: TigerFeedbackTone.success,
      );
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
          'Failed to create request: ${FirestoreErrorHandler.toUserMessage(e)}',
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
          'Failed to create request: $e',
        );
      }
    }
  }

  Future<void> _showServiceActionSheet({
    required BuildContext context,
    required bool isBooking,
    required String serviceId,
    required String providerId,
    required String serviceTitle,
    required double amount,
  }) async {
    final notesController = TextEditingController();
    DateTime? selectedDate;
    String selectedWindow = 'Flexible';
    TimeOfDay? selectedTime;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (innerCtx, setModalState) {
              final selectedDateKey = selectedDate == null
                  ? null
                  : DateFormat('yyyy-MM-dd').format(selectedDate!);

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.of(innerCtx).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isBooking ? 'Book Service' : 'Create Request',
                        style: Theme.of(innerCtx).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isBooking
                            ? 'Book the service now and share the day plus your preferred time window.'
                            : 'Send a request with the exact date and time you want, then wait for provider approval.',
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: innerCtx,
                            initialDate: selectedDate ?? now,
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 90)),
                          );
                          if (picked == null) return;
                          setModalState(() => selectedDate = picked);
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          selectedDate == null
                              ? (isBooking
                                    ? 'Select preferred date'
                                    : 'Select requested date')
                              : DateFormat(
                                  'EEE, dd MMM yyyy',
                                ).format(selectedDate!),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isBooking)
                        DropdownButtonFormField<String>(
                          initialValue: selectedWindow,
                          decoration: const InputDecoration(
                            labelText: 'Preferred time window',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Morning',
                              child: Text('Morning'),
                            ),
                            DropdownMenuItem(
                              value: 'Afternoon',
                              child: Text('Afternoon'),
                            ),
                            DropdownMenuItem(
                              value: 'Evening',
                              child: Text('Evening'),
                            ),
                            DropdownMenuItem(
                              value: 'Flexible',
                              child: Text('Flexible'),
                            ),
                          ],
                          onChanged: (value) {
                            setModalState(
                              () => selectedWindow = value ?? 'Flexible',
                            );
                          },
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: innerCtx,
                              initialTime: selectedTime ?? TimeOfDay.now(),
                            );
                            if (picked == null) return;
                            setModalState(() => selectedTime = picked);
                          },
                          icon: const Icon(Icons.schedule),
                          label: Text(
                            selectedTime == null
                                ? 'Select requested time'
                                : MaterialLocalizations.of(
                                    innerCtx,
                                  ).formatTimeOfDay(selectedTime!),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: isBooking
                              ? 'Booking notes'
                              : 'Explain your request',
                          hintText: isBooking
                              ? 'Gate number, materials, special instructions...'
                              : 'Tell the provider what you need done before they approve.',
                        ),
                      ),
                      if (selectedDateKey != null) ...[
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            final scheme = Theme.of(context).colorScheme;
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final background = isDark
                                ? const Color(0xFF0F2230)
                                : const Color(0xFFEFF6FF);
                            final border = isDark
                                ? const Color(0xFF2E4C66)
                                : const Color(0xFF93C5FD);
                            final foreground = isDark
                                ? const Color(0xFFBFDBFE)
                                : const Color(0xFF1D4ED8);
                            final message = isBooking
                                ? 'Availability is confirmed after you send the booking request. The provider will review the selected date and time window.'
                                : 'Your requested date and time will be sent to the provider for confirmation.';

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: background,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: border),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: foreground),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      message,
                                      style: TextStyle(
                                        color: scheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final notes = notesController.text.trim();
                            final date = selectedDate;
                            final requestedTimeLabel = selectedTime == null
                                ? null
                                : MaterialLocalizations.of(
                                    innerCtx,
                                  ).formatTimeOfDay(selectedTime!);
                            Navigator.of(innerCtx).pop();
                            if (isBooking) {
                              await _createBooking(
                                context,
                                serviceId,
                                providerId,
                                amount,
                                serviceTitle,
                                date,
                                selectedWindow,
                                notes,
                              );
                            } else {
                              await _createRequest(
                                context,
                                serviceId,
                                providerId,
                                serviceTitle,
                                date,
                                selectedWindow,
                                requestedTimeLabel,
                                notes,
                              );
                            }
                          },
                          icon: Icon(
                            isBooking ? Icons.event_available : Icons.send,
                          ),
                          label: Text(
                            isBooking ? 'Confirm Booking' : 'Send Request',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      notesController.dispose();
    }
  }

  Widget _buildFlowGuideCard(BuildContext context) {
    return MobileSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How This Works',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _flowLine(
            context,
            icon: Icons.event_available,
            title: 'Book Service',
            body:
                'Price and scope are clear — pick a date and the provider confirms.',
            color: const Color(0xFF0F766E),
          ),
          const SizedBox(height: 8),
          _flowLine(
            context,
            icon: Icons.question_answer_outlined,
            title: 'Create Request',
            body:
                'Need to explain the job first — the provider reviews before a booking is made.',
            color: const Color(0xFFB45309),
          ),
        ],
      ),
    );
  }

  Widget _flowLine(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
              const SizedBox(height: 2),
              Text(body, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _providerSummaryCard(BuildContext context, String providerId) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.users().doc(providerId).snapshots(),
      builder: (context, providerSnapshot) {
        final providerData = providerSnapshot.data?.data();
        final providerName = ProfileIdentity.displayNameFrom(
          providerData,
          fallback: 'Provider',
        );
        final online = PresenceService.isOnline(providerData);
        final statusLabel = PresenceService.statusLabel(providerData);
        final rating = (providerData?['averageRating'] is num)
            ? (providerData!['averageRating'] as num).toDouble()
            : 0.0;
        final reviewCount = (providerData?['reviewCount'] is num)
            ? (providerData!['reviewCount'] as num).toInt()
            : 0;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreRefs.bookings()
              .where('providerId', isEqualTo: providerId)
              .snapshots(),
          builder: (context, bookingSnapshot) {
            final bookings = bookingSnapshot.data?.docs ?? const [];
            final completedJobs = bookings
                .where((doc) => (doc.data()['status'] ?? '') == 'completed')
                .length;
            final pendingJobs = bookings.where((doc) {
              final status = (doc.data()['status'] ?? '').toString();
              return status == 'pending' || status == 'accepted';
            }).length;

            return MobileSectionCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: online
                        ? const Color(0xFFECFDF5)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text(
                      providerName.isNotEmpty
                          ? providerName[0].toUpperCase()
                          : 'P',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: online
                            ? const Color(0xFF047857)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                providerName,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: online
                                  ? const Color(0xFF22C55E)
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: online
                                    ? const Color(0xFF047857)
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 13,
                              color: const Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${rating.toStringAsFixed(1)} ($reviewCount)',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.task_alt,
                              size: 13,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$completedJobs done',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.timelapse,
                              size: 13,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$pendingJobs active',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
        final imageUrls = resolveServiceImageUrls(data: data);

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
                const SizedBox(height: 12),
                if (imageUrls.isNotEmpty) ...[
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
                            child: ServiceVisual(
                              title: (data['title'] ?? 'Service').toString(),
                              category: (data['category'] ?? '').toString(),
                              imageUrl: imageUrls[index],
                              height: 220,
                              borderRadius: BorderRadius.circular(12),
                              showOverlay: true,
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
                        '${imageUrls.length} photos - swipe to browse',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ] else
                  ServiceVisual(
                    title: (data['title'] ?? 'Service').toString(),
                    category: (data['category'] ?? '').toString(),
                    height: 220,
                    borderRadius: BorderRadius.circular(12),
                    showOverlay: true,
                  ),
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
                _providerSummaryCard(context, providerId),
                const SizedBox(height: 12),
                MobileSectionCard(
                  child: Text(
                    data['description'] ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFlowGuideCard(context),
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
                        : UserRoles.normalize(
                            roleSnapshot.data?.data()?['role'],
                          );
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
                                    TigerFeedback.show(
                                      context,
                                      'Service approved',
                                      tone: TigerFeedbackTone.success,
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
                                    TigerFeedback.show(
                                      context,
                                      'Service rejected',
                                      tone: TigerFeedbackTone.warning,
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
                        ElevatedButton.icon(
                          onPressed: () => _showServiceActionSheet(
                            context: context,
                            isBooking: true,
                            serviceId: serviceId,
                            providerId: providerId,
                            amount: (data['price'] is num)
                                ? (data['price'] as num).toDouble()
                                : 0.0,
                            serviceTitle: (data['title'] ?? 'service')
                                .toString(),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.event_available),
                          label: const Text('Book Service'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showServiceActionSheet(
                            context: context,
                            isBooking: false,
                            serviceId: serviceId,
                            providerId: providerId,
                            amount: (data['price'] is num)
                                ? (data['price'] as num).toDouble()
                                : 0.0,
                            serviceTitle: (data['title'] ?? 'service')
                                .toString(),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB45309),
                            side: const BorderSide(color: Color(0xFFB45309)),
                          ),
                          icon: const Icon(Icons.question_answer_outlined),
                          label: const Text('Create Request'),
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
