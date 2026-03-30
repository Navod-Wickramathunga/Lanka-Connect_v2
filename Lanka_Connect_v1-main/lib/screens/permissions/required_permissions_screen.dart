import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class RequiredPermissionsScreen extends StatefulWidget {
  const RequiredPermissionsScreen({super.key, required this.child});

  final Widget child;

  @override
  State<RequiredPermissionsScreen> createState() =>
      _RequiredPermissionsScreenState();
}

class _RequiredPermissionsScreenState extends State<RequiredPermissionsScreen>
    with WidgetsBindingObserver {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  bool _loading = true;
  bool _ready = false;
  bool _showSettingsAction = false;
  List<Permission> _requiredPermissions = const [];

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_ready) {
      _ensurePermissions();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ensurePermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _ensurePermissions() async {
    if (!_requiresRuntimePermissions()) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _loading = false;
      });
      return;
    }

    final permissions = await _resolveRequiredPermissions();
    final statuses = await _requestPermissions(permissions);
    if (!mounted) return;

    final allGranted = statuses.every((status) => status.isGranted);
    final anyPermanent = statuses.any((status) => status.isPermanentlyDenied);

    setState(() {
      _ready = allGranted;
      _showSettingsAction = anyPermanent;
      _requiredPermissions = permissions;
      _loading = false;
    });
  }

  bool _requiresRuntimePermissions() {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<List<Permission>> _resolveRequiredPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return const [];

    if (Platform.isIOS) {
      return const [Permission.photos];
    }

    final android = await _deviceInfo.androidInfo;
    if (android.version.sdkInt >= 33) {
      return const [Permission.photos];
    }
    return const [Permission.storage];
  }

  Future<List<PermissionStatus>> _requestPermissions(
    List<Permission> permissions,
  ) async {
    final statuses = await permissions.request();
    return permissions
        .map((permission) => statuses[permission] ?? PermissionStatus.denied)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return widget.child;
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 48,
                      color: Color(0xFF1769AA),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Permissions Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Media access is required for profile and service images. Location is now requested only when you use nearby or current-position features.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    if (_loading)
                      const CircularProgressIndicator()
                    else ...[
                      if (_requiredPermissions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Required: ${_requiredPermissions.map((p) => p.toString().split(".").last).join(", ")}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _ensurePermissions,
                          child: const Text('Grant Permissions'),
                        ),
                      ),
                      if (_showSettingsAction) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: openAppSettings,
                            child: const Text('Open App Settings'),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
