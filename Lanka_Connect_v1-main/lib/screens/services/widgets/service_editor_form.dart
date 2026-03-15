import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../../utils/firestore_error_handler.dart';
import '../../../utils/firestore_refs.dart';
import '../../../utils/validators.dart';

class ServiceEditorForm extends StatefulWidget {
  const ServiceEditorForm({
    super.key,
    this.serviceId,
    this.initialData,
    this.submitLabel,
    this.onSaved,
    this.enableImagePicking = true,
  });

  final String? serviceId;
  final Map<String, dynamic>? initialData;
  final String? submitLabel;
  final VoidCallback? onSaved;
  final bool enableImagePicking;

  @override
  State<ServiceEditorForm> createState() => _ServiceEditorFormState();
}

class _ServiceEditorFormState extends State<ServiceEditorForm> {
  static const List<String> _categories = [
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

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String? _selectedCategory;
  final _priceController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _saving = false;
  bool _fillingLocation = false;
  final List<XFile> _selectedImages = [];
  final List<String> _existingImageUrls = [];
  static const int _maxImages = 5;

  bool get _isEditMode => widget.serviceId != null;

  @override
  void initState() {
    super.initState();
    _prefillFromInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _prefillFromInitialData() {
    final data = widget.initialData ?? const <String, dynamic>{};
    _titleController.text = (data['title'] ?? '').toString();
    final cat = (data['category'] ?? '').toString();
    _selectedCategory = _categories.contains(cat) ? cat : null;
    final rawPrice = data['price'];
    if (rawPrice is num) {
      _priceController.text = rawPrice.toString();
    } else {
      _priceController.text = (rawPrice ?? '').toString();
    }
    _districtController.text = (data['district'] ?? '').toString();
    _cityController.text = (data['city'] ?? '').toString();

    final rawLat = data['lat'];
    if (rawLat is num) {
      _latController.text = rawLat.toString();
    } else {
      _latController.text = (rawLat ?? '').toString();
    }

    final rawLng = data['lng'];
    if (rawLng is num) {
      _lngController.text = rawLng.toString();
    } else {
      _lngController.text = (rawLng ?? '').toString();
    }
    _descriptionController.text = (data['description'] ?? '').toString();

    final rawImages = data['imageUrls'];
    if (rawImages is List) {
      _existingImageUrls.addAll(rawImages.map((e) => e.toString()));
    }
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final usedSlots = _existingImageUrls.length + _selectedImages.length;
      final remaining = _maxImages - usedSlots;
      if (remaining <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 5 images allowed.')),
          );
        }
        return;
      }

      final images = await picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.take(remaining));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to pick images.')));
    }
  }

  Future<List<String>> _uploadImages(String serviceId) async {
    final urls = <String>[];
    for (var i = 0; i < _selectedImages.length; i++) {
      final file = _selectedImages[i];
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final mimeType = lookupMimeType(file.name) ?? 'image/jpeg';
      final ref = FirebaseStorage.instance.ref(
        'service_images/$serviceId/${DateTime.now().millisecondsSinceEpoch}_$i.$ext',
      );

      UploadTask task;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        task = ref.putData(bytes, SettableMetadata(contentType: mimeType));
      } else {
        task = ref.putFile(
          File(file.path),
          SettableMetadata(contentType: mimeType),
        );
      }
      final snapshot = await task;
      urls.add(await snapshot.ref.getDownloadURL());
    }
    return urls;
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      FirestoreErrorHandler.showSignInRequired(context);
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final district = _districtController.text.trim();
      final city = _cityController.text.trim();
      final lat = double.tryParse(_latController.text.trim());
      final lng = double.tryParse(_lngController.text.trim());
      final payload = <String, dynamic>{
        'providerId': user.uid,
        'title': _titleController.text.trim(),
        'category': _selectedCategory ?? '',
        'price': double.tryParse(_priceController.text.trim()) ?? 0,
        'district': district,
        'city': city,
        'location': '$city, $district',
        'lat': lat,
        'lng': lng,
        'description': _descriptionController.text.trim(),
        'status': 'pending',
      };

      if (_isEditMode) {
        final docRef = FirestoreRefs.services().doc(widget.serviceId);
        final uploaded = await _uploadImages(widget.serviceId!);
        payload['imageUrls'] = [..._existingImageUrls, ...uploaded];
        payload['updatedAt'] = FieldValue.serverTimestamp();
        await docRef.update(payload);
      } else {
        payload['imageUrls'] = <String>[];
        payload['createdAt'] = FieldValue.serverTimestamp();
        final docRef = await FirestoreRefs.services().add(payload);
        if (_selectedImages.isNotEmpty) {
          final uploaded = await _uploadImages(docRef.id);
          await docRef.update({'imageUrls': uploaded});
        }
      }

      if (mounted) {
        widget.onSaved?.call();
      }
    } on FirebaseException catch (e, st) {
      FirestoreErrorHandler.logWriteError(
        operation: _isEditMode ? 'services_update' : 'services_add',
        error: e,
        stackTrace: st,
        details: {'uid': user.uid, 'serviceId': widget.serviceId},
      );
      if (mounted) {
        FirestoreErrorHandler.showError(
          context,
          FirestoreErrorHandler.toUserMessage(e),
        );
      }
    } catch (e, st) {
      FirestoreErrorHandler.logWriteError(
        operation: _isEditMode
            ? 'services_update_unknown'
            : 'services_add_unknown',
        error: e,
        stackTrace: st,
        details: {'uid': user.uid, 'serviceId': widget.serviceId},
      );
      if (mounted) {
        FirestoreErrorHandler.showError(
          context,
          FirestoreErrorHandler.toUserMessage(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _fillFromCurrentLocation() async {
    setState(() => _fillingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services.')),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied for current position.'),
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _latController.text = pos.latitude.toStringAsFixed(6);
      _lngController.text = pos.longitude.toStringAsFixed(6);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location coordinates filled.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _fillingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLabel =
        widget.submitLabel ?? (_isEditMode ? 'Update Service' : 'Post Service');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              key: const Key('service_editor_field_title'),
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) =>
                  Validators.requiredField(value, 'Title required'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('service_editor_field_category'),
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedCategory = value),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Category required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('service_editor_field_price'),
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Price (LKR)'),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  Validators.priceField(value, 'Price required'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('service_editor_field_district'),
              controller: _districtController,
              decoration: const InputDecoration(labelText: 'District'),
              validator: (value) =>
                  Validators.requiredField(value, 'District required'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('service_editor_field_city'),
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'City'),
              validator: (value) =>
                  Validators.requiredField(value, 'City required'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude (optional)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: Validators.optionalLatitude,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lngController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude (optional)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: Validators.optionalLongitude,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _saving || _fillingLocation
                    ? null
                    : _fillFromCurrentLocation,
                icon: _fillingLocation
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _fillingLocation ? 'Locating...' : 'Use current location',
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'If latitude/longitude are empty, map uses approximate city/district location.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Service Images (${_existingImageUrls.length + _selectedImages.length}/$_maxImages)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            if (_existingImageUrls.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingImageUrls.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _existingImageUrls[index],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox(width: 100, height: 100),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _existingImageUrls.removeAt(index);
                                });
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (_selectedImages.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb
                                ? FutureBuilder<Uint8List>(
                                    future: _selectedImages[index]
                                        .readAsBytes(),
                                    builder: (context, snap) {
                                      if (!snap.hasData) {
                                        return const SizedBox(
                                          width: 100,
                                          height: 100,
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      }
                                      return Image.memory(
                                        snap.data!,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  )
                                : Image.file(
                                    File(_selectedImages[index].path),
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImages.removeAt(index);
                                });
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving || !widget.enableImagePicking
                  ? null
                  : _pickImages,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add Images'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('service_editor_field_description'),
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
              validator: (value) =>
                  Validators.requiredField(value, 'Description required'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('service_editor_submit'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : effectiveLabel),
            ),
          ],
        ),
      ),
    );
  }
}
