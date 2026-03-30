import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:app_links/app_links.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/permissions/required_permissions_screen.dart';
import 'screens/splash/startup_splash_screen.dart';
import 'ui/mobile/mobile_theme.dart';
import 'ui/theme/app_theme_controller.dart';
import 'firebase_options_selector.dart';
import 'utils/firebase_env.dart';
import 'utils/fcm_service.dart';
import 'utils/app_logger.dart';

class AppNavigationContract {
  const AppNavigationContract._();

  static const String authLoginPath = '/auth';
  static const String authSignupPath = '/auth/signup';
  static const String resetPasswordPath = '/reset-password';
}

/// Top-level background message handler for FCM.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: currentOptionsForEnv());
  debugPrint('FCM background message: ${message.notification?.title}');
}

Future<void>? _bootstrapFuture;

Future<void> _bootstrapApplication() async {
  if (!kIsWeb) {
    // Initialize Google Maps with latest renderer on Android for proper tile loading.
    final mapsImplementation = GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      mapsImplementation.useAndroidViewSurface = true;
      try {
        await mapsImplementation.initializeWithRenderer(
          AndroidMapRenderer.latest,
        );
      } catch (error) {
        debugPrint('Google Maps renderer init failed: $error');
      }
    }
  }

  await Firebase.initializeApp(options: currentOptionsForEnv());
  await FirebaseEnv.configure();
  await AppLogger.initialize();
  debugPrint(
    'Firebase boot: env=${FirebaseEnv.appEnvRaw} projectId=${currentOptionsForEnv().projectId}',
  );
  debugPrint(
    'Firebase boot: useEmulators=${FirebaseEnv.useEmulators} backend=${FirebaseEnv.backendLabel().isEmpty ? 'PRODUCTION' : FirebaseEnv.backendLabel()}',
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

Future<void> _ensureBootstrapStarted() {
  return _bootstrapFuture ??= _bootstrapApplication();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    _ensureBootstrapStarted();
    runApp(const MyApp());
    return;
  }

  await _ensureBootstrapStarted();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Lanka Connect',
          debugShowCheckedModeBanner: false,
          theme: MobileTheme.build(),
          darkTheme: MobileTheme.buildDark(),
          themeMode: mode,
          navigatorKey: navigatorKey,
          home: const _AppEntryPoint(),
        );
      },
    );
  }
}

class _AppEntryPoint extends StatefulWidget {
  const _AppEntryPoint();

  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initDeepLinks();
    }
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();

    // Handle the initial link that launched the app.
    final initial = await appLinks.getInitialLink();
    if (initial != null) {
      _handleDeepLink(initial);
    }

    // Listen for links while the app is already running.
    _linkSub = appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  Uri? _extractResetUri(Uri uri) {
    final visited = <String>{};
    Uri? current = uri;

    while (current != null && visited.add(current.toString())) {
      final path = current.path.toLowerCase();
      final mode = (current.queryParameters['mode'] ?? '').toLowerCase();
      final hasResetPath =
          path == AppNavigationContract.resetPasswordPath ||
          path.endsWith(AppNavigationContract.resetPasswordPath) ||
          path.endsWith('/__/auth/action');
      final hasResetMode = mode == 'resetpassword';
      if (hasResetPath || hasResetMode) {
        return current;
      }

      final nested =
          current.queryParameters['link'] ??
          current.queryParameters['continueUrl'] ??
          current.queryParameters['deep_link_id'];
      if (nested == null || nested.trim().isEmpty) {
        current = null;
      } else {
        current = Uri.tryParse(Uri.decodeFull(nested.trim()));
      }
    }

    return null;
  }

  void _handleDeepLink(Uri uri) {
    final resetUri = _extractResetUri(uri);
    if (resetUri == null) return;

    final oobCode = (resetUri.queryParameters['oobCode'] ?? '').trim();
    final nav = MyApp.navigatorKey.currentState;
    if (nav != null) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(initialOobCode: oobCode),
        ),
      );
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final resetUri = _extractResetUri(Uri.base);
      if (resetUri != null) {
        return ResetPasswordScreen(
          initialOobCode: resetUri.queryParameters['oobCode'] ?? '',
        );
      }
    }
    return const StartupFlowGate();
  }
}

class StartupFlowGate extends StatefulWidget {
  const StartupFlowGate({super.key});

  @override
  State<StartupFlowGate> createState() => _StartupFlowGateState();
}

class _StartupFlowGateState extends State<StartupFlowGate> {
  // Skip splash on web for instant access to the login page.
  bool _showSplash = !kIsWeb;
  late final Future<void> _bootstrapFuture = _ensureBootstrapStarted();

  void _finishSplash() {
    if (!mounted) return;
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapLoadingScreen();
        }

        if (_showSplash) {
          return StartupSplashScreen(onFinished: _finishSplash);
        }
        return const RequiredPermissionsScreen(child: AuthGate());
      },
    );
  }
}

class _BootstrapLoadingScreen extends StatelessWidget {
  const _BootstrapLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF033B42),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            SizedBox(height: 18),
            Text(
              'Starting Lanka Connect',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // Initialize FCM after successful authentication
          FcmService.initialize();
          return const HomeScreen();
        }

        return const AuthScreen();
      },
    );
  }
}
