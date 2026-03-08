import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';

import '../../ui/theme/design_tokens.dart';
import '../../utils/firestore_refs.dart';

/// Admin panel for managing homepage banners.
/// Banners are stored in the `banners` Firestore collection with fields:
///   title, subtitle, ctaText, colorHex, imageUrl, active, order,
///   scheduledStart, scheduledEnd, createdAt
class AdminBannersPanel extends StatefulWidget {
  const AdminBannersPanel({super.key});

  @override
  State<AdminBannersPanel> createState() => _AdminBannersPanelState();
}

class _AdminBannersPanelState extends State<AdminBannersPanel> {
  String _search = '';

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Color _colorFromHex(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return DesignTokens.brandPrimary;
    }
  }

  String _colorToHex(Color c) {
    return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  // â”€â”€ Image upload â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<String?> _uploadBannerImage(XFile picked) async {
    final bytes = await picked.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image must be under 5 MB.')),
        );
      }
      return null;
    }

    final mimeType = lookupMimeType(
      picked.name,
      headerBytes: bytes.take(12).toList(),
    );
    if (mimeType == null || !mimeType.startsWith('image/')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid image file.')),
        );
      }
      return null;
    }

    final ext = picked.name.split('.').last;
    final ref = FirebaseStorage.instance
        .ref()
        .child('banner_images')
        .child('${DateTime.now().millisecondsSinceEpoch}.$ext');

    final metadata = SettableMetadata(contentType: mimeType);
    if (kIsWeb) {
      await ref.putData(bytes, metadata);
    } else {
      await ref.putFile(File(picked.path), metadata);
    }
    return ref.getDownloadURL();
  }

  // â”€â”€ CRUD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _showBannerDialog({
    String? docId,
    Map<String, dynamic>? existing,
  }) async {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final subtitleCtrl = TextEditingController(
      text: existing?['subtitle'] ?? '',
    );
    final ctaCtrl = TextEditingController(text: existing?['ctaText'] ?? '');
    final orderCtrl = TextEditingController(
      text: (existing?['order'] ?? 0).toString(),
    );
    Color selectedColor = existing != null
        ? _colorFromHex(existing['colorHex'] ?? '#2563EB')
        : const Color(0xFF2563EB);
    bool active = existing?['active'] ?? true;
    String imageUrl = existing?['imageUrl'] ?? '';
    bool uploading = false;

    // Scheduling
    DateTime? scheduledStart;
    DateTime? scheduledEnd;
    if (existing?['scheduledStart'] != null) {
      scheduledStart = (existing!['scheduledStart'] as Timestamp).toDate();
    }
    if (existing?['scheduledEnd'] != null) {
      scheduledEnd = (existing!['scheduledEnd'] as Timestamp).toDate();
    }

    final isEdit = docId != null;
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> pickImage() async {
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 1200,
                maxHeight: 600,
                imageQuality: 85,
              );
              if (picked == null) return;
              setDialogState(() => uploading = true);
              try {
                final url = await _uploadBannerImage(picked);
                if (url != null) {
                  setDialogState(() => imageUrl = url);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
                }
              } finally {
                setDialogState(() => uploading = false);
              }
            }

            Future<DateTime?> pickDateTime(DateTime? initial) async {
              final date = await showDatePicker(
                context: ctx,
                initialDate: initial ?? DateTime.now(),
                firstDate: DateTime(2024),
                lastDate: DateTime(2030),
              );
              if (date == null) return null;
              if (!ctx.mounted) return null;
              final time = await showTimePicker(
                context: ctx,
                initialTime: initial != null
                    ? TimeOfDay.fromDateTime(initial)
                    : TimeOfDay.now(),
              );
              if (time == null) return null;
              return DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
            }

            return AlertDialog(
              title: Text(isEdit ? 'Edit Banner' : 'New Banner'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Title *',
                          hintText: 'e.g. Spring Cleaning Sale',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: subtitleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Subtitle *',
                          hintText: 'Get 20% off all cleaning services!',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ctaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'CTA Button Text',
                          hintText: 'e.g. Book Now',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // â”€â”€ Image upload â”€â”€
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Banner Image:',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (imageUrl.isNotEmpty)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, e, st) => Container(
                                  height: 120,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton.filled(
                                onPressed: () =>
                                    setDialogState(() => imageUrl = ''),
                                icon: const Icon(Icons.close, size: 16),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(28, 28),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        InkWell(
                          onTap: uploading ? null : pickImage,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 100,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(ctx).colorScheme.outlineVariant,
                                style: BorderStyle.solid,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: uploading
                                ? const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cloud_upload_outlined,
                                        size: 32,
                                        color: Theme.of(
                                          ctx,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Click to upload image',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            ctx,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      if (imageUrl.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: OutlinedButton.icon(
                            onPressed: uploading ? null : pickImage,
                            icon: const Icon(Icons.swap_horiz, size: 16),
                            label: const Text('Replace Image'),
                          ),
                        ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: orderCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Display Order',
                          hintText: '0 = first',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // â”€â”€ Scheduling â”€â”€
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Schedule (optional):',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await pickDateTime(
                                  scheduledStart,
                                );
                                if (picked != null) {
                                  setDialogState(() => scheduledStart = picked);
                                }
                              },
                              icon: const Icon(Icons.play_arrow, size: 16),
                              label: Text(
                                scheduledStart != null
                                    ? dateFmt.format(scheduledStart!)
                                    : 'Start Date',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await pickDateTime(scheduledEnd);
                                if (picked != null) {
                                  setDialogState(() => scheduledEnd = picked);
                                }
                              },
                              icon: const Icon(Icons.stop, size: 16),
                              label: Text(
                                scheduledEnd != null
                                    ? dateFmt.format(scheduledEnd!)
                                    : 'End Date',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (scheduledStart != null || scheduledEnd != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => setDialogState(() {
                                scheduledStart = null;
                                scheduledEnd = null;
                              }),
                              child: const Text(
                                'Clear schedule',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Color picker row
                      Row(
                        children: [
                          const Text('Banner Color: '),
                          const SizedBox(width: 8),
                          ..._presetColors.map((c) {
                            final isSelected = selectedColor == c;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: GestureDetector(
                                onTap: () =>
                                    setDialogState(() => selectedColor = c),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          )
                                        : null,
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: c.withValues(alpha: 0.5),
                                              blurRadius: 6,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Active'),
                        subtitle: const Text(
                          'Only active banners appear on the home screen',
                        ),
                        value: active,
                        onChanged: (v) => setDialogState(() => active = v),
                      ),
                      const SizedBox(height: 8),
                      // Preview
                      Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              selectedColor,
                              selectedColor.withValues(alpha: 0.7),
                            ],
                          ),
                          image: imageUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(imageUrl),
                                  fit: BoxFit.cover,
                                  colorFilter: ColorFilter.mode(
                                    selectedColor.withValues(alpha: 0.55),
                                    BlendMode.darken,
                                  ),
                                )
                              : null,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              titleCtrl.text.isEmpty
                                  ? 'Banner Title'
                                  : titleCtrl.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitleCtrl.text.isEmpty
                                  ? 'Subtitle text here'
                                  : subtitleCtrl.text,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(isEdit ? 'Update' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;
    if (titleCtrl.text.trim().isEmpty || subtitleCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and subtitle are required.')),
      );
      return;
    }

    final data = <String, dynamic>{
      'title': titleCtrl.text.trim(),
      'subtitle': subtitleCtrl.text.trim(),
      'ctaText': ctaCtrl.text.trim().isEmpty
          ? 'Learn More'
          : ctaCtrl.text.trim(),
      'imageUrl': imageUrl,
      'colorHex': _colorToHex(selectedColor),
      'active': active,
      'order': int.tryParse(orderCtrl.text) ?? 0,
      'scheduledStart': scheduledStart != null
          ? Timestamp.fromDate(scheduledStart!)
          : null,
      'scheduledEnd': scheduledEnd != null
          ? Timestamp.fromDate(scheduledEnd!)
          : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isEdit) {
      await FirestoreRefs.banners().doc(docId).update(data);
    } else {
      data['createdAt'] = FieldValue.serverTimestamp();
      await FirestoreRefs.banners().add(data);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isEdit ? 'Banner updated' : 'Banner created')),
    );
  }

  Future<void> _deleteBanner(String docId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Banner'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FirestoreRefs.banners().doc(docId).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Banner deleted')));
  }

  Future<void> _toggleActive(String docId, bool current) async {
    await FirestoreRefs.banners().doc(docId).update({'active': !current});
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  String _scheduleLabel(Map<String, dynamic> data) {
    final start = data['scheduledStart'];
    final end = data['scheduledEnd'];
    if (start == null && end == null) return '';
    final fmt = DateFormat('MMM d');
    if (start != null && end != null) {
      return '${fmt.format((start as Timestamp).toDate())} â€“ ${fmt.format((end as Timestamp).toDate())}';
    }
    if (start != null) {
      return 'From ${fmt.format((start as Timestamp).toDate())}';
    }
    return 'Until ${fmt.format((end as Timestamp).toDate())}';
  }

  static const _presetColors = [
    Color(0xFF2563EB),
    Color(0xFF0891B2),
    Color(0xFF0D9488),
    Color(0xFFF43F5E),
    Color(0xFF7C3AED),
    Color(0xFFF59E0B),
    Color(0xFF22C55E),
    Color(0xFFDC2626),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(Icons.view_carousel, color: DesignTokens.brandPrimary),
              const SizedBox(width: 8),
              Text(
                'Banner Management',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              SizedBox(
                width: 220,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search bannersâ€¦',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _showBannerDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Banner'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // List
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreRefs.banners().orderBy('order').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              final filtered = docs.where((d) {
                if (_search.isEmpty) return true;
                final data = d.data();
                final title = (data['title'] ?? '').toString().toLowerCase();
                final subtitle = (data['subtitle'] ?? '')
                    .toString()
                    .toLowerCase();
                return title.contains(_search.toLowerCase()) ||
                    subtitle.contains(_search.toLowerCase());
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.view_carousel_outlined,
                        size: 48,
                        color: scheme.outlineVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        docs.isEmpty
                            ? 'No banners yet â€” create your first one!'
                            : 'No banners match your search',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = filtered[index];
                  final data = doc.data();
                  final color = _colorFromHex(data['colorHex'] ?? '#2563EB');
                  final active = data['active'] == true;

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () =>
                          _showBannerDialog(docId: doc.id, existing: data),
                      child: Row(
                        children: [
                          // Color preview strip
                          Container(
                            width: 8,
                            height: 90,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                          ),
                          // Banner preview thumbnail (image or gradient)
                          Container(
                            width: 140,
                            height: 90,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color, color.withValues(alpha: 0.7)],
                              ),
                              image:
                                  (data['imageUrl'] ?? '').toString().isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(data['imageUrl']),
                                      fit: BoxFit.cover,
                                      colorFilter: ColorFilter.mode(
                                        color.withValues(alpha: 0.45),
                                        BlendMode.darken,
                                      ),
                                    )
                                  : null,
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  data['title'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  data['subtitle'] ?? '',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 9,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Details
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['title'] ?? 'Untitled',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    data['subtitle'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      _InfoChip(
                                        label:
                                            'CTA: ${data['ctaText'] ?? 'n/a'}',
                                        icon: Icons.touch_app,
                                      ),
                                      _InfoChip(
                                        label: 'Order: ${data['order'] ?? 0}',
                                        icon: Icons.sort,
                                      ),
                                      if (_scheduleLabel(data).isNotEmpty)
                                        _InfoChip(
                                          label: _scheduleLabel(data),
                                          icon: Icons.schedule,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Status & actions
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Column(
                              children: [
                                Switch(
                                  value: active,
                                  onChanged: (_) =>
                                      _toggleActive(doc.id, active),
                                  activeThumbColor: DesignTokens.brandPrimary,
                                ),
                                Text(
                                  active ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: active
                                        ? DesignTokens.brandPrimary
                                        : scheme.outlineVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                _deleteBanner(doc.id, data['title'] ?? ''),
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: Colors.red,
                            tooltip: 'Delete',
                          ),
                          const SizedBox(width: 4),
                        ],
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
  }
}

// â”€â”€ Reusable info chip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
