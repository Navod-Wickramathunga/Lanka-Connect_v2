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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Google Maps with latest renderer on Android for proper tile loading
  if (!kIsWeb) {
    final mapsImplementation = GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      mapsImplementation.useAndroidViewSurface = true;
      await GoogleMapsFlutterAndroid().initializeWithRenderer(
        AndroidMapRenderer.latest,
      );
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

  void _handleDeepLink(Uri uri) {
    if (uri.path == AppNavigationContract.resetPasswordPath) {
      final oobCode = uri.queryParameters['oobCode'] ?? '';
      final nav = MyApp.navigatorKey.currentState;
      if (nav != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(initialOobCode: oobCode),
          ),
        );
      }
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
      final uri = Uri.base;
      if (uri.path == AppNavigationContract.resetPasswordPath) {
        return ResetPasswordScreen(
          initialOobCode: uri.queryParameters['oobCode'] ?? '',
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

  void _finishSplash() {
    if (!mounted) return;
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return StartupSplashScreen(onFinished: _finishSplash);
    }
    return const RequiredPermissionsScreen(child: AuthGate());
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
