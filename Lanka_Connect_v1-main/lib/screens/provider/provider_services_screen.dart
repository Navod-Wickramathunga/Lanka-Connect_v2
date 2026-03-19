import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../ui/mobile/mobile_components.dart';
import '../../ui/mobile/mobile_page_scaffold.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/theme/design_tokens.dart';
import '../../ui/web/web_page_scaffold.dart';
import '../../utils/firestore_refs.dart';
import '../services/widgets/service_editor_form.dart';

class ProviderServicesScreen extends StatefulWidget {
  const ProviderServicesScreen({super.key});

  @override
  State<ProviderServicesScreen> createState() => _ProviderServicesScreenState();
}

class _ProviderServicesScreenState extends State<ProviderServicesScreen> {
  final Set<String> _deletingIds = <String>{};

  Stream<QuerySnapshot<Map<String, dynamic>>> _servicesStream({
    required String uid,
    required bool ordered,
  }) {
    final base = FirestoreRefs.services().where('providerId', isEqualTo: uid);
    if (!ordered) return base.snapshots();
    return base.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> _openEditor({
    String? serviceId,
    Map<String, dynamic>? initialData,
  }) async {
    final isEdit = serviceId != null;
    final title = isEdit ? 'Edit Service' : 'Add New Service';

    if (kIsWeb) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return Dialog(
            child: SizedBox(
              width: 640,
              height: 760,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 10, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ServiceEditorForm(
                      serviceId: serviceId,
                      initialData: initialData,
                      submitLabel: isEdit ? 'Update Service' : 'Create Service',
                      onSaved: () {
                        Navigator.of(context).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEdit
                                    ? 'Service updated successfully.'
                                    : 'Service created successfully.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.95,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ServiceEditorForm(
                  serviceId: serviceId,
                  initialData: initialData,
                  submitLabel: isEdit ? 'Update Service' : 'Create Service',
                  onSaved: () {
                    Navigator.of(context).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEdit
                                ? 'Service updated successfully.'
                                : 'Service created successfully.',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteService(
    String serviceId,
    Map<String, dynamic> serviceData,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Service'),
          content: const Text(
            'This will permanently remove the service listing. Continue?',
          ),
          actions: [
            TextButton(
              key: const Key('provider_services_delete_cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('provider_services_delete_confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: DesignTokens.danger,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _deletingIds.add(serviceId);
    });

    try {
      final imageUrls = ((serviceData['imageUrls'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();

      for (final url in imageUrls) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(url);
          await ref.delete();
        } catch (_) {
          // Best-effort cleanup; deletion of Firestore doc should not fail on this.
        }
      }

      await FirestoreRefs.services().doc(serviceId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service deleted successfully.')),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete service: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete service.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingIds.remove(serviceId);
        });
      }
    }
  }

  Future<void> _showServiceDetails({
    required String serviceId,
    required Map<String, dynamic> data,
  }) async {
    final title = (data['title'] ?? 'Service').toString();
    final category = (data['category'] ?? '').toString().trim();
    final city = (data['city'] ?? '').toString().trim();
    final district = (data['district'] ?? '').toString().trim();
    final location = (data['location'] ?? '').toString().trim();
    final description = (data['description'] ?? '').toString().trim();
    final status = (data['status'] ?? 'pending').toString();
    final price = (data['price'] is num)
        ? (data['price'] as num).toDouble()
        : 0.0;
    final displayLocation = city.isNotEmpty || district.isNotEmpty
        ? '$city, $district'
        : location;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (category.isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.category_outlined, size: 16),
                        label: Text(category),
                      ),
                    Chip(
                      avatar: const Icon(Icons.payments_outlined, size: 16),
                      label: Text(
                        'LKR ${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}',
                      ),
                    ),
                    Chip(
                      avatar: const Icon(Icons.flag_outlined, size: 16),
                      label: Text(status),
                    ),
                  ],
                ),
                if (displayLocation.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(displayLocation)),
                    ],
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _deletingIds.contains(serviceId)
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                _openEditor(
                                  serviceId: serviceId,
                                  initialData: data,
                                );
                              },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _deletingIds.contains(serviceId)
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                _deleteService(serviceId, data);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: DesignTokens.danger,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildList({required String uid, required bool ordered}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _servicesStream(uid: uid, ordered: ordered),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          if (ordered &&
              error is FirebaseException &&
              error.code == 'failed-precondition') {
            return _buildList(uid: uid, ordered: false);
          }
          return _errorPanel();
        }

        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return _emptyPanel();
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
            itemCount: docs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FilledButton.icon(
                    onPressed: _openEditor,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Service'),
                  ),
                );
              }

              final doc = docs[index - 1];
              final data = doc.data();
              return _ProviderServiceCard(
                serviceId: doc.id,
                data: data,
                deleting: _deletingIds.contains(doc.id),
                onTap: () => _showServiceDetails(serviceId: doc.id, data: data),
              );
            },
          ),
        );
      },
    );
  }

  Widget _errorPanel() {
    if (kIsWeb) {
      return WebStatePanel(
        icon: Icons.error_outline,
        title: 'Could not load your services',
        subtitle: 'Please retry in a moment.',
        tone: WebStateTone.error,
        action: OutlinedButton(
          onPressed: () => setState(() {}),
          child: const Text('Retry'),
        ),
      );
    }
    return MobileStatePanel(
      icon: Icons.error_outline,
      title: 'Could not load your services',
      subtitle: 'Please retry in a moment.',
      tone: MobileStateTone.error,
      action: OutlinedButton(
        onPressed: () => setState(() {}),
        child: const Text('Retry'),
      ),
    );
  }

  Widget _emptyPanel() {
    final cta = FilledButton.icon(
      key: const Key('provider_services_empty_cta'),
      onPressed: () => _openEditor(),
      icon: const Icon(Icons.add),
      label: const Text('Create your first service'),
    );
    if (kIsWeb) {
      return WebStatePanel(
        icon: Icons.store_outlined,
        title: 'No services yet',
        subtitle: 'Start listing your services for seekers.',
        tone: WebStateTone.info,
        action: cta,
      );
    }
    return MobileStatePanel(
      icon: Icons.store_outlined,
      title: 'No services yet',
      subtitle: 'Start listing your services for seekers.',
      tone: MobileStateTone.info,
      action: cta,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not signed in'));
    }

    final list = Stack(
      children: [
        Positioned.fill(child: _buildList(uid: user.uid, ordered: true)),
        Positioned(
          right: 18,
          bottom: 18,
          child: FloatingActionButton.extended(
            key: const Key('provider_services_fab_add'),
            onPressed: _openEditor,
            backgroundColor: DesignTokens.brandPrimary,
            icon: const Icon(Icons.add),
            label: const Text('Create Service'),
          ),
        ),
      ],
    );

    if (kIsWeb) {
      return WebPageScaffold(
        title: 'My Services',
        subtitle: 'Manage your listings and offerings',
        useScaffold: false,
        child: list,
      );
    }

    return MobilePageScaffold(
      title: 'My Services',
      subtitle: 'Manage your listings and offerings',
      accentColor: MobileTokens.primary,
      body: list,
    );
  }
}

class _ProviderServiceCard extends StatelessWidget {
  const _ProviderServiceCard({
    required this.serviceId,
    required this.data,
    required this.deleting,
    required this.onTap,
  });

  final String serviceId;
  final Map<String, dynamic> data;
  final bool deleting;
  final VoidCallback onTap;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return DesignTokens.success;
      case 'rejected':
        return DesignTokens.danger;
      case 'pending':
      default:
        return DesignTokens.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawImages = data['imageUrls'];
    final images = rawImages is List
        ? rawImages.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    final title = (data['title'] ?? 'Service').toString();
    final category = (data['category'] ?? '').toString();
    final city = (data['city'] ?? '').toString().trim();
    final district = (data['district'] ?? '').toString().trim();
    final location = (data['location'] ?? '').toString().trim();
    final displayLocation = city.isNotEmpty || district.isNotEmpty
        ? '$city, $district'
        : location;
    final price = (data['price'] is num)
        ? (data['price'] as num).toDouble()
        : 0.0;
    final status = (data['status'] ?? 'pending').toString();
    final statusColor = _statusColor(status);

    return Card(
      key: Key('provider_services_card_$serviceId'),
      child: ListTile(
        onTap: deleting ? null : onTap,
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          backgroundImage: images.isNotEmpty
              ? NetworkImage(images.first)
              : null,
          child: images.isEmpty
              ? Icon(Icons.home_repair_service, color: statusColor)
              : null,
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (category.isNotEmpty) category,
            if (displayLocation.isNotEmpty) displayLocation,
            'LKR ${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}',
          ].join(' - '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: deleting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right),
                ],
              ),
      ),
    );
  }
}
