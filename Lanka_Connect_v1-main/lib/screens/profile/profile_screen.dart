import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import '../../ui/mobile/mobile_components.dart';
import '../../ui/mobile/mobile_page_scaffold.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/web/web_page_scaffold.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/app_feedback.dart';
import '../../utils/user_roles.dart';
import '../../utils/validators.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _skillsController = TextEditingController();
  final _bioController = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  String _role = UserRoles.seeker;
  String _imageUrl = '';

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _skillsController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      FirestoreErrorHandler.showSignInRequired(context);
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _saving = true;
    });

    try {
      final skills = _skillsController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

      await FirestoreRefs.users().doc(user.uid).set({
        'name': _nameController.text.trim(),
        'contact': _contactController.text.trim(),
        'district': _districtController.text.trim(),
        'city': _cityController.text.trim(),
        'skills': skills,
        'bio': _bioController.text.trim(),
        'imageUrl': _imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _saving = false;
        });
        TigerFeedback.show(
          context,
          'Tiger saved your profile.',
          tone: TigerFeedbackTone.success,
        );
      }
    } on FirebaseException catch (e, st) {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
      FirestoreErrorHandler.logWriteError(
        operation: 'users_set_profile',
        error: e,
        stackTrace: st,
        details: {'uid': user.uid},
      );
      if (mounted) {
        FirestoreErrorHandler.showError(
          context,
          FirestoreErrorHandler.toUserMessage(e),
        );
      }
    } catch (e, st) {
      FirestoreErrorHandler.logWriteError(
        operation: 'users_set_profile_unknown',
        error: e,
        stackTrace: st,
        details: {'uid': user.uid},
      );
      if (mounted) {
        setState(() {
          _saving = false;
        });
        FirestoreErrorHandler.showError(
          context,
          FirestoreErrorHandler.toUserMessage(e),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        FirestoreErrorHandler.showSignInRequired(context);
        return;
      }

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(user.uid)
          .child('avatar.jpg');

      final bytes = await picked.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          FirestoreErrorHandler.showError(
            context,
            'Image is too large. Please choose an image under 5 MB.',
          );
        }
        return;
      }

      final mimeType = lookupMimeType(
        picked.name,
        headerBytes: bytes.take(12).toList(),
      );
      if (mimeType == null || !mimeType.startsWith('image/')) {
        if (mounted) {
          FirestoreErrorHandler.showError(
            context,
            'Please select a valid image file.',
          );
        }
        return;
      }

      final metadata = SettableMetadata(contentType: mimeType);

      if (kIsWeb) {
        await ref.putData(bytes, metadata);
      } else {
        await ref.putFile(File(picked.path), metadata);
      }

      final url = await ref.getDownloadURL();
      await FirestoreRefs.users().doc(user.uid).set({
        'imageUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await user.updatePhotoURL(url);

      setState(() {
        _imageUrl = url;
      });

      if (mounted) {
        TigerFeedback.show(
          context,
          'Tiger updated your profile photo.',
          tone: TigerFeedbackTone.success,
        );
      }
    } on FirebaseException catch (e, st) {
      FirestoreErrorHandler.logWriteError(
        operation: 'profile_image_upload',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        final isStorageAuthIssue =
            e.code == 'unauthorized' || e.code == 'permission-denied';
        FirestoreErrorHandler.showError(
          context,
          isStorageAuthIssue
              ? 'Image upload is blocked by storage rules. Ensure storage rules are deployed and your account is signed in.'
              : FirestoreErrorHandler.toUserMessage(e),
        );
      }
    } catch (e, st) {
      FirestoreErrorHandler.logWriteError(
        operation: 'profile_image_upload_unknown',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        FirestoreErrorHandler.showError(
          context,
          FirestoreErrorHandler.toUserMessage(e),
        );
      }
    }
  }

  void _hydrateFields(Map<String, dynamic> data) {
    _role = UserRoles.normalize(data['role']);
    _imageUrl = (data['imageUrl'] ?? '').toString();
    _nameController.text = (data['name'] ?? '').toString();
    _contactController.text = (data['contact'] ?? '').toString();
    _districtController.text = (data['district'] ?? '').toString();
    _cityController.text = (data['city'] ?? '').toString();
    _bioController.text = (data['bio'] ?? '').toString();

    final skills = List<String>.from(data['skills'] ?? const []);
    _skillsController.text = skills.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not signed in'));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.users().doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.data() ?? {};
        if (!_initialized) {
          _hydrateFields(data);
          _initialized = true;
        }
        // Keep profile image in sync with Firestore (e.g. uploaded from another device)
        final latestImageUrl = (data['imageUrl'] ?? '').toString();
        if (latestImageUrl.isNotEmpty && latestImageUrl != _imageUrl) {
          _imageUrl = latestImageUrl;
        }

        final content = SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundImage: _imageUrl.isNotEmpty
                          ? NetworkImage(_imageUrl)
                          : null,
                      onBackgroundImageError: _imageUrl.isNotEmpty
                          ? (_, __) {}
                          : null,
                      child: _imageUrl.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Upload image'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                MobileSectionCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) =>
                            Validators.requiredField(value, 'Name required'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _contactController,
                        decoration: const InputDecoration(labelText: 'Contact'),
                        validator: (value) => Validators.phoneField(value),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _districtController,
                        decoration: const InputDecoration(
                          labelText: 'District',
                        ),
                        validator: (value) => Validators.requiredField(
                          value,
                          'District required',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'City'),
                        validator: (value) =>
                            Validators.requiredField(value, 'City required'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_role == UserRoles.provider) ...[
                  MobileSectionCard(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _skillsController,
                          decoration: const InputDecoration(
                            labelText: 'Skills / categories (comma separated)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _bioController,
                          decoration: const InputDecoration(
                            labelText: 'Short bio',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  child: Text(_saving ? 'Saving...' : 'Save Profile'),
                ),
              ],
            ),
          ),
        );

        if (!kIsWeb) {
          return MobilePageScaffold(
            title: 'Profile',
            subtitle: 'Manage your identity and account details',
            accentColor: RoleVisuals.forRole(_role).accent,
            body: content,
          );
        }

        return WebPageScaffold(
          title: 'Profile',
          subtitle: 'Manage your identity and account information.',
          useScaffold: false,
          child: content,
        );
      },
    );
  }
}
