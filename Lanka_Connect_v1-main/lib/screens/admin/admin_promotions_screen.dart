import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../ui/theme/design_tokens.dart';
import '../../utils/firestore_refs.dart';

/// Admin panel for managing exclusive offers / promotions.
/// Promotions are stored in the `promotions` Firestore collection with fields:
///   title, description, discount, expiry, colorHex, iconName,
///   linkedCategory, active, order, createdAt
class AdminPromotionsPanel extends StatefulWidget {
  const AdminPromotionsPanel({super.key});

  @override
  State<AdminPromotionsPanel> createState() => _AdminPromotionsPanelState();
}

class _AdminPromotionsPanelState extends State<AdminPromotionsPanel> {
  String _search = '';

  // ── Helpers ──────────────────────────────────────────────────────────────

  Color _colorFromHex(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return const Color(0xFFF43F5E);
    }
  }

  String _colorToHex(Color c) {
    return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  static const _iconOptions = <String, IconData>{
    'cleaning_services': Icons.cleaning_services,
    'plumbing': Icons.plumbing,
    'electrical_services': Icons.electrical_services,
    'carpenter': Icons.carpenter,
    'format_paint': Icons.format_paint,
    'grass': Icons.grass,
    'local_shipping': Icons.local_shipping,
    'spa': Icons.spa,
    'school': Icons.school,
    'ac_unit': Icons.ac_unit,
    'yard': Icons.yard,
    'handyman': Icons.handyman,
    'home_repair_service': Icons.home_repair_service,
    'local_offer': Icons.local_offer,
    'star': Icons.star,
  };

  IconData _iconFromName(String? name) {
    return _iconOptions[name] ?? Icons.local_offer;
  }

  static const _presetColors = [
    Color(0xFFF43F5E),
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
    Color(0xFF7C3AED),
    Color(0xFFF59E0B),
    Color(0xFF0891B2),
    Color(0xFFDC2626),
    Color(0xFF0D9488),
  ];

  static const _categoryOptions = [
    '',
    'Cleaning',
    'Plumbing',
    'Electrical',
    'Carpentry',
    'Painting',
    'Gardening',
    'Moving',
    'Beauty',
    'Tutoring',
  ];

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> _showPromoDialog({
    String? docId,
    Map<String, dynamic>? existing,
  }) async {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final descCtrl = TextEditingController(
      text: existing?['description'] ?? '',
    );
    final discountCtrl = TextEditingController(
      text: existing?['discount'] ?? '',
    );
    final expiryCtrl = TextEditingController(text: existing?['expiry'] ?? '');
    final orderCtrl = TextEditingController(
      text: (existing?['order'] ?? 0).toString(),
    );
    Color selectedColor = existing != null
        ? _colorFromHex(existing['colorHex'] ?? '#F43F5E')
        : const Color(0xFFF43F5E);
    String selectedIcon = existing?['iconName'] ?? 'local_offer';
    String linkedCategory = existing?['linkedCategory'] ?? '';
    bool active = existing?['active'] ?? true;

    final isEdit = docId != null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Promotion' : 'New Promotion'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Title *',
                          hintText: 'e.g. Weekend Cleaner',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          hintText:
                              'Get your house sparkling clean for the weekend.',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: discountCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Discount Label *',
                                hintText: 'e.g. 15% OFF or Rs. 500 OFF',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: expiryCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Expiry Text',
                                hintText: 'e.g. Ends Sunday',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: linkedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Linked Category',
                              ),
                              items: _categoryOptions.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(c.isEmpty ? '— None —' : c),
                                );
                              }).toList(),
                              onChanged: (v) => setDialogState(
                                () => linkedCategory = v ?? '',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: orderCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Display Order',
                                hintText: '0 = first',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Icon picker
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Icon:',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _iconOptions.entries.map((e) {
                          final isSelected = selectedIcon == e.key;
                          return GestureDetector(
                            onTap: () =>
                                setDialogState(() => selectedIcon = e.key),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? selectedColor.withValues(alpha: 0.15)
                                    : Theme.of(
                                        ctx,
                                      ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(color: selectedColor, width: 2)
                                    : null,
                              ),
                              child: Icon(
                                e.value,
                                size: 20,
                                color: isSelected
                                    ? selectedColor
                                    : Theme.of(
                                        ctx,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Color picker
                      Row(
                        children: [
                          const Text('Color: '),
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
                          'Only active promotions appear on the home screen',
                        ),
                        value: active,
                        onChanged: (v) => setDialogState(() => active = v),
                      ),
                      const SizedBox(height: 8),
                      // Preview card
                      Container(
                        height: 80,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(ctx).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              decoration: BoxDecoration(
                                color: selectedColor.withValues(alpha: 0.1),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(11),
                                  bottomLeft: Radius.circular(11),
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  _iconFromName(selectedIcon),
                                  color: selectedColor,
                                  size: 28,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (discountCtrl.text.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selectedColor,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          discountCtrl.text,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      titleCtrl.text.isEmpty
                                          ? 'Promotion Title'
                                          : titleCtrl.text,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
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
    if (titleCtrl.text.trim().isEmpty ||
        descCtrl.text.trim().isEmpty ||
        discountCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title, description and discount are required.'),
        ),
      );
      return;
    }

    final data = {
      'title': titleCtrl.text.trim(),
      'description': descCtrl.text.trim(),
      'discount': discountCtrl.text.trim(),
      'expiry': expiryCtrl.text.trim().isEmpty
          ? 'Limited Time'
          : expiryCtrl.text.trim(),
      'colorHex': _colorToHex(selectedColor),
      'iconName': selectedIcon,
      'linkedCategory': linkedCategory,
      'active': active,
      'order': int.tryParse(orderCtrl.text) ?? 0,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isEdit) {
      await FirestoreRefs.promotions().doc(docId).update(data);
    } else {
      data['createdAt'] = FieldValue.serverTimestamp();
      await FirestoreRefs.promotions().add(data);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEdit ? 'Promotion updated' : 'Promotion created'),
      ),
    );
  }

  Future<void> _deletePromo(String docId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Promotion'),
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
    await FirestoreRefs.promotions().doc(docId).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Promotion deleted')));
  }

  Future<void> _toggleActive(String docId, bool current) async {
    await FirestoreRefs.promotions().doc(docId).update({'active': !current});
  }

  // ── Build ────────────────────────────────────────────────────────────────

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
              Icon(Icons.local_offer, color: DesignTokens.brandPrimary),
              const SizedBox(width: 8),
              Text(
                'Promotions Management',
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
                    hintText: 'Search promotions…',
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
                onPressed: () => _showPromoDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Promotion'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // List
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreRefs.promotions().orderBy('order').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              final filtered = docs.where((d) {
                if (_search.isEmpty) return true;
                final data = d.data();
                final title = (data['title'] ?? '').toString().toLowerCase();
                final desc = (data['description'] ?? '')
                    .toString()
                    .toLowerCase();
                return title.contains(_search.toLowerCase()) ||
                    desc.contains(_search.toLowerCase());
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_offer_outlined,
                        size: 48,
                        color: scheme.outlineVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        docs.isEmpty
                            ? 'No promotions yet — create your first one!'
                            : 'No promotions match your search',
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
                  final color = _colorFromHex(data['colorHex'] ?? '#F43F5E');
                  final icon = _iconFromName(data['iconName']);
                  final active = data['active'] == true;
                  final category = (data['linkedCategory'] ?? '').toString();

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () =>
                          _showPromoDialog(docId: doc.id, existing: data),
                      child: Row(
                        children: [
                          // Icon section
                          Container(
                            width: 70,
                            height: 90,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                            child: Center(
                              child: Icon(icon, color: color, size: 32),
                            ),
                          ),
                          // Content
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          data['discount'] ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (category.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                scheme.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            category,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: scheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    data['title'] ?? 'Untitled',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    data['description'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        data['expiry'] ?? '',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Status & actions
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
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
                                _deletePromo(doc.id, data['title'] ?? ''),
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
