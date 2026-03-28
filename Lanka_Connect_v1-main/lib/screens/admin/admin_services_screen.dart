import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../ui/web/web_page_scaffold.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/service_moderation_service.dart';

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  String _statusFilter = 'pending';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(
    BuildContext context,
    String serviceId,
    String status,
  ) async {
    try {
      await ServiceModerationService.updateStatus(
        serviceId: serviceId,
        status: status,
      );
    } on FirebaseException catch (e, st) {
      FirestoreErrorHandler.logWriteError(
        operation: 'services_update_status',
        error: e,
        stackTrace: st,
        details: {'serviceId': serviceId, 'status': status},
      );
      if (context.mounted) {
        FirestoreErrorHandler.showError(
          context,
          FirestoreErrorHandler.toUserMessage(e),
        );
      }
    } catch (e, st) {
      FirestoreErrorHandler.logWriteError(
        operation: 'services_update_status_unknown',
        error: e,
        stackTrace: st,
        details: {'serviceId': serviceId, 'status': status},
      );
      if (context.mounted) {
        FirestoreErrorHandler.showError(
          context,
          FirestoreErrorHandler.toUserMessage(e),
        );
      }
    }
  }

  /// Returns a human-readable SLA label from a Firestore Timestamp.
  String _slaLabel(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _slaColor(Timestamp? ts) {
    if (ts == null) return Colors.grey;
    final hours = DateTime.now().difference(ts.toDate()).inHours;
    if (hours < 12) return Colors.green;
    if (hours < 48) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirestoreRefs.services();
    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    final body = Column(
      children: [
        // ── Filter bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by title or category…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  DropdownMenuItem(value: 'all', child: Text('All')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _statusFilter = v);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Service list ──
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var docs = snapshot.data?.docs ?? [];

              // Client-side search filter
              if (_searchQuery.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data();
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final cat = (data['category'] ?? '').toString().toLowerCase();
                  return title.contains(_searchQuery) ||
                      cat.contains(_searchQuery);
                }).toList();
              }

              if (docs.isEmpty) {
                return const Center(
                  child: Text('No services match the current filters.'),
                );
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final status = (data['status'] ?? 'pending').toString();
                  final createdAt = data['createdAt'] as Timestamp?;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      title: Text(data['title'] ?? 'Service'),
                      subtitle: Row(
                        children: [
                          Text(data['category'] ?? ''),
                          if (status == 'pending' && createdAt != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: _slaColor(createdAt),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _slaLabel(createdAt),
                              style: TextStyle(
                                color: _slaColor(createdAt),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: status == 'pending'
                          ? Wrap(
                              spacing: 8,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('Approve'),
                                  onPressed: () => _updateStatus(
                                    context,
                                    doc.id,
                                    'approved',
                                  ),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.close, size: 18),
                                  label: const Text('Reject'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  onPressed: () => _updateStatus(
                                    context,
                                    doc.id,
                                    'rejected',
                                  ),
                                ),
                              ],
                            )
                          : Builder(
                              builder: (context) {
                                final isApproved = status == 'approved';
                                final chipColor = isApproved
                                    ? Colors.green
                                    : Colors.red;
                                return Chip(
                                  label: Text(
                                    status[0].toUpperCase() +
                                        status.substring(1),
                                    style: TextStyle(
                                      color: chipColor.shade700,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  side: BorderSide(
                                    color: chipColor.withValues(alpha: 0.28),
                                  ),
                                  backgroundColor: chipColor.withValues(
                                    alpha: 0.14,
                                  ),
                                );
                              },
                            ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    if (!kIsWeb) return body;

    return WebPageScaffold(
      title: 'Moderation',
      subtitle: 'Review and moderate pending service postings.',
      useScaffold: false,
      child: body,
    );
  }
}
