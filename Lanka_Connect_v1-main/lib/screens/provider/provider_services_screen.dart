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
import '../../widgets/animated_icon.dart';
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

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 880;
            final crossAxisCount = constraints.maxWidth >= 1200
                ? 3
                : constraints.maxWidth >= 880
                ? 2
                : 1;
            final grid = GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isWide ? 0.95 : 1.15,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                return _ProviderServiceCard(
                  serviceId: doc.id,
                  data: data,
                  deleting: _deletingIds.contains(doc.id),
                  onEdit: () =>
                      _openEditor(serviceId: doc.id, initialData: data),
                  onDelete: () => _deleteService(doc.id, data),
                );
              },
            );
            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: grid,
            );
          },
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
          child: FloatingActionButton(
            key: const Key('provider_services_fab_add'),
            onPressed: _openEditor,
            backgroundColor: DesignTokens.brandPrimary,
            child: const Icon(Icons.add, size: 30),
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
    required this.onEdit,
    required this.onDelete,
  });

  final String serviceId;
  final Map<String, dynamic> data;
  final bool deleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 140,
            width: double.infinity,
            child: images.isNotEmpty
                ? Image.network(
                    images.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      return const ColoredBox(
                        color: Color(0xFFF1F5F9),
                        child: Center(child: Icon(Icons.broken_image)),
                      );
                    },
                  )
                : const ColoredBox(
                    color: Color(0xFFF1F5F9),
                    child: Center(child: Icon(Icons.image_not_supported)),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
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
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayLocation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        'LKR ${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        key: Key('provider_services_action_edit_$serviceId'),
                        onPressed: deleting ? null : onEdit,
                        tooltip: 'Edit',
                        icon: const AnimatedIconWidget(
                          icon: Icons.edit_outlined,
                          animation: IconAnimation.wiggle,
                          triggerOnTap: true,
                        ),
                      ),
                      IconButton(
                        key: Key('provider_services_action_delete_$serviceId'),
                        onPressed: deleting ? null : onDelete,
                        tooltip: 'Delete',
                        icon: const AnimatedIconWidget(
                          icon: Icons.delete_outline,
                          animation: IconAnimation.shake,
                          triggerOnTap: true,
                          color: DesignTokens.danger,
                        ),
                      ),
                      if (deleting)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
