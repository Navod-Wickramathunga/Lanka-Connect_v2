import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../ui/mobile/mobile_routes.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/theme/app_theme_controller.dart';
import '../../ui/theme/design_tokens.dart';
import '../../ui/web/web_shell.dart';
import '../../utils/app_feedback.dart';
import '../../utils/demo_data_service.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/firebase_env.dart';
import '../../utils/notification_service.dart';
import '../../utils/presence_service.dart';
import '../../utils/profile_identity.dart';
import '../../utils/user_roles.dart';
import '../admin/admin_web_dashboard_screen.dart';
import '../admin/admin_services_screen.dart';
import '../bookings/booking_list_screen.dart';
import '../chat/chat_list_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../provider/provider_dashboard_screen.dart';
import '../provider/provider_services_screen.dart';
import '../requests/request_list_screen.dart';
import '../requests/seeker_request_list_screen.dart';
import '../services/service_list_screen.dart';
import 'seeker_home_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  String? _webRouteId;
  bool _seeding = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _notificationSubscription;
  final Set<String> _seenNotificationIds = <String>{};
  String? _notificationKey;
  bool _notificationPrimed = false;
  String? _presenceUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final presenceUid = _presenceUid;
    if (presenceUid != null) {
      unawaited(PresenceService.markOffline(presenceUid));
    }
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final presenceUid = _presenceUid;
    if (presenceUid == null) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(PresenceService.markOnline(presenceUid));
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(PresenceService.markOffline(presenceUid));
    }
  }

  void _setIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _setWebRoute(String routeId) {
    setState(() {
      _webRouteId = routeId;
    });
  }

  void _ensurePresence(String uid) {
    if (_presenceUid == uid) return;
    _presenceUid = uid;
    unawaited(PresenceService.markOnline(uid));
  }

  String _roleLabel(String role) {
    if (role == UserRoles.provider) return 'Provider';
    if (role == UserRoles.admin) return 'Admin';
    if (role == UserRoles.guest) return 'Guest';
    return 'Seeker';
  }

  Query<Map<String, dynamic>> _notificationQuery({
    required String uid,
    required String role,
  }) {
    if (role == UserRoles.admin) {
      return FirestoreRefs.notifications().where(
        'recipientId',
        whereIn: [uid, NotificationService.adminChannelRecipientId],
      );
    }
    return FirestoreRefs.notifications().where('recipientId', isEqualTo: uid);
  }

  List<WebShellNavItem> _webNavItemsForRole(String role) {
    if (role == UserRoles.admin) {
      return const [
        WebShellNavItem(
          id: 'dashboard',
          label: 'Dashboard',
          icon: Icons.space_dashboard,
        ),
        WebShellNavItem(
          id: 'moderation',
          label: 'Moderation',
          icon: Icons.verified_user,
        ),
        WebShellNavItem(
          id: 'services',
          label: 'Services',
          icon: Icons.storefront,
        ),
        WebShellNavItem(
          id: 'bookings',
          label: 'Bookings',
          icon: Icons.calendar_today,
        ),
        WebShellNavItem(id: 'profile', label: 'Profile', icon: Icons.person),
      ];
    }

    if (role == UserRoles.provider) {
      return const [
        WebShellNavItem(
          id: 'dashboard',
          label: 'Dashboard',
          icon: Icons.space_dashboard,
        ),
        WebShellNavItem(
          id: 'my-services',
          label: 'My Services',
          icon: Icons.store,
        ),
        WebShellNavItem(id: 'requests', label: 'Requests', icon: Icons.inbox),
        WebShellNavItem(
          id: 'bookings',
          label: 'Bookings',
          icon: Icons.calendar_today,
        ),
        WebShellNavItem(id: 'chat', label: 'Chat', icon: Icons.chat),
        WebShellNavItem(id: 'profile', label: 'Profile', icon: Icons.person),
      ];
    }

    if (role == UserRoles.guest) {
      return const [
        WebShellNavItem(id: 'home', label: 'Home', icon: Icons.home_rounded),
        WebShellNavItem(id: 'services', label: 'Services', icon: Icons.search),
        WebShellNavItem(
          id: 'bookings',
          label: 'Bookings',
          icon: Icons.calendar_today,
        ),
      ];
    }

    return const [
      WebShellNavItem(id: 'home', label: 'Home', icon: Icons.home_rounded),
      WebShellNavItem(id: 'services', label: 'Services', icon: Icons.search),
      WebShellNavItem(
        id: 'requests',
        label: 'Requests',
        icon: Icons.assignment,
      ),
      WebShellNavItem(
        id: 'bookings',
        label: 'Bookings',
        icon: Icons.calendar_today,
      ),
      WebShellNavItem(id: 'chat', label: 'Chat', icon: Icons.chat),
      WebShellNavItem(id: 'profile', label: 'Profile', icon: Icons.person),
    ];
  }

  Map<String, Widget> _webRouteMapForRole(String role) {
    if (role == UserRoles.admin) {
      return const {
        'dashboard': AdminWebDashboardScreen(),
        'moderation': AdminServicesScreen(),
        'services': ServiceListScreen(),
        'bookings': BookingListScreen(),
        'profile': ProfileScreen(),
      };
    }

    if (role == UserRoles.provider) {
      return const {
        'dashboard': ProviderDashboardScreen(),
        'my-services': ProviderServicesScreen(),
        'requests': RequestListScreen(),
        'bookings': BookingListScreen(),
        'chat': ChatListScreen(),
        'profile': ProfileScreen(),
      };
    }

    if (role == UserRoles.guest) {
      return const {
        'home': SeekerHomeScreen(),
        'services': ServiceListScreen(),
        'bookings': BookingListScreen(),
      };
    }

    return const {
      'home': SeekerHomeScreen(),
      'services': ServiceListScreen(),
      'requests': SeekerRequestListScreen(),
      'bookings': BookingListScreen(),
      'chat': ChatListScreen(),
      'profile': ProfileScreen(),
    };
  }

  Widget _notificationAction(String uid, String role) {
    final iconColor = kIsWeb ? null : null;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _notificationQuery(uid: uid, role: role).snapshots(),
      builder: (context, snapshot) {
        final unreadCount =
            snapshot.data?.docs
                .where((doc) => (doc.data()['isRead'] ?? false) != true)
                .length ??
            0;
        final badgeText = unreadCount > 99 ? '99+' : '$unreadCount';
        return IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications, color: iconColor),
              if (unreadCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      badgeText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _ensureNotificationSubscription(String uid, String role) {
    final key = '$uid|$role';
    if (_notificationKey == key && _notificationSubscription != null) {
      return;
    }

    _notificationSubscription?.cancel();
    _notificationKey = key;
    _notificationPrimed = false;
    _seenNotificationIds.clear();

    _notificationSubscription = _notificationQuery(uid: uid, role: role)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted || snapshot.docs.isEmpty) return;

            if (!_notificationPrimed) {
              for (final doc in snapshot.docs) {
                _seenNotificationIds.add(doc.id);
              }
              _notificationPrimed = true;
              return;
            }

            for (final doc in snapshot.docs) {
              final data = doc.data();
              final isRead = (data['isRead'] ?? false) == true;
              if (isRead || _seenNotificationIds.contains(doc.id)) {
                continue;
              }
              _seenNotificationIds.add(doc.id);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Notification stream error: $error');
            debugPrint(stackTrace.toString());
          },
        );
  }

  Future<void> _seedDemoData() async {
    if (_seeding) return;

    setState(() {
      _seeding = true;
    });
    TigerFeedback.show(
      context,
      'Tiger is preparing demo jobs.',
      tone: TigerFeedbackTone.info,
    );

    try {
      final result = await DemoDataService.seed();
      final ok = (result['ok'] ?? false) == true;
      final created = (result['created'] ?? 0).toString();
      final updated = (result['updated'] ?? 0).toString();
      final skipped = (result['skipped'] ?? 0).toString();
      if (!mounted) return;
      TigerFeedback.show(
        context,
        ok
            ? 'Tiger loaded demo data: $created new, $updated updated, $skipped unchanged.'
            : 'Tiger loaded part of the demo data.',
        tone: ok ? TigerFeedbackTone.success : TigerFeedbackTone.warning,
      );
    } catch (e) {
      if (!mounted) return;
      FirestoreErrorHandler.showError(
        context,
        FirestoreErrorHandler.toUserMessageForOperation(
          e,
          operation: 'seed_demo_data',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _seeding = false;
        });
      }
    }
  }

  void _showGuestUpgradePrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create an Account'),
        content: const Text(
          'You are using guest mode. Create an account to keep booking history, chat, and notifications permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await FirebaseAuth.instance.signOut();
            },
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _notificationSubscription?.cancel();
      _notificationSubscription = null;
      _notificationKey = null;
      final presenceUid = _presenceUid;
      _presenceUid = null;
      if (presenceUid != null) {
        unawaited(PresenceService.markOffline(presenceUid));
      }
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.users().doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data?.data() ?? {};
        final role = user.isAnonymous
            ? UserRoles.guest
            : UserRoles.normalize(data['role']);
        _ensurePresence(user.uid);
        _ensureNotificationSubscription(user.uid, role);

        final mobileRoutes = MobileRoutes.forRole(role);
        final selectedIndex = _currentIndex.clamp(0, mobileRoutes.length - 1);
        final webRouteMap = _webRouteMapForRole(role);
        final webNavItems = _webNavItemsForRole(role);
        final backendLabel = FirebaseEnv.backendLabel();

        if (_webRouteId == null || !webRouteMap.containsKey(_webRouteId)) {
          _webRouteId = webNavItems.first.id;
        }

        if (kIsWeb && role != UserRoles.admin) {
          final routeId = _webRouteId!;
          final routeWidget = webRouteMap[routeId]!;
          final routeLabel = webNavItems
              .firstWhere((item) => item.id == routeId)
              .label;
          final subtitleParts = <String>[
            _roleLabel(role),
            if (user.email != null) user.email!,
            if (backendLabel.isNotEmpty) 'Backend: $backendLabel',
          ];
          return WebShell(
            appTitle: 'Lanka Connect',
            navItems: webNavItems,
            currentId: routeId,
            onSelect: _setWebRoute,
            pageTitle: routeLabel,
            pageSubtitle: subtitleParts.join(' | '),
            actions: [
              ValueListenableBuilder<ThemeMode>(
                valueListenable: AppThemeController.themeMode,
                builder: (context, mode, _) {
                  return IconButton(
                    onPressed: AppThemeController.toggleTheme,
                    tooltip: mode == ThemeMode.dark
                        ? 'Switch to light theme'
                        : 'Switch to dark theme',
                    icon: Icon(
                      mode == ThemeMode.dark
                          ? Icons.light_mode
                          : Icons.dark_mode,
                    ),
                  );
                },
              ),
              if (role == UserRoles.admin && !FirebaseEnv.isProduction)
                IconButton(
                  onPressed: _seeding ? null : _seedDemoData,
                  icon: _seeding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.dataset),
                  tooltip: 'Seed demo data',
                ),
              _notificationAction(user.uid, role),
              if (role == UserRoles.guest)
                IconButton(
                  onPressed: _showGuestUpgradePrompt,
                  tooltip: 'Create account',
                  icon: const Icon(Icons.person_add_alt_1),
                ),
              IconButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
              ),
            ],
            child: routeWidget,
          );
        }

        return Scaffold(
          drawer: _buildDrawer(
            context,
            user,
            data,
            role,
            mobileRoutes,
            selectedIndex,
          ),
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Theme.of(context).colorScheme.surface,
            iconTheme: IconThemeData(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
            title: Text(
              'Lanka Connect',
              style: TextStyle(
                color: DesignTokens.brandPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              if (backendLabel.isNotEmpty)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: DesignTokens.brandPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: DesignTokens.brandPrimary.withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ),
                    child: Text(
                      backendLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.brandPrimary,
                      ),
                    ),
                  ),
                ),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: AppThemeController.themeMode,
                builder: (context, mode, _) {
                  return IconButton(
                    onPressed: AppThemeController.toggleTheme,
                    tooltip: mode == ThemeMode.dark
                        ? 'Switch to light theme'
                        : 'Switch to dark theme',
                    icon: Icon(
                      mode == ThemeMode.dark
                          ? Icons.light_mode
                          : Icons.dark_mode,
                    ),
                  );
                },
              ),
              _notificationAction(user.uid, role),
              if (role == UserRoles.guest)
                IconButton(
                  onPressed: _showGuestUpgradePrompt,
                  tooltip: 'Create account',
                  icon: const Icon(Icons.person_add_alt_1),
                ),
            ],
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(
              key: ValueKey(selectedIndex),
              child: mobileRoutes[selectedIndex].builder(context),
            ),
          ),
          floatingActionButton: _buildHelpFab(),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: _setIndex,
              indicatorColor: RoleVisuals.forRole(role).chipBackground,
              elevation: 0,
              height: 68,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: List.generate(mobileRoutes.length, (index) {
                final route = mobileRoutes[index];
                return NavigationDestination(
                  icon: _navIcon(route.icon, active: false, role: role),
                  selectedIcon: _navIcon(route.icon, active: true, role: role),
                  label: route.label,
                );
              }),
            ),
          ),
        );
      },
    );
  }

  void _handleHelpOption(String value) {
    switch (value) {
      case 'Help Center':
        _showInfoDialog(
          'Help Center',
          'Visit our help documentation for guides, FAQs, and troubleshooting tips.\n\nEmail: support@lankaconnect.lk',
        );
        break;
      case 'Contact support':
        _showInfoDialog(
          'Contact Support',
          'Email: support@lankaconnect.lk\nPhone: +94 11 234 5678\nHours: Mon-Fri 9AM-6PM',
        );
        break;
      case 'Report abuse':
        _showInfoDialog(
          'Report Abuse',
          'To report a user or service, go to the service/user profile and tap the flag icon.\n\nOr email: abuse@lankaconnect.lk',
        );
        break;
      case 'Legal summary':
        _showInfoDialog(
          'Legal Summary',
          'Lanka Connect is a service marketplace platform.\n\n• Terms of Service apply to all users\n• Privacy Policy governs data handling\n• Users are responsible for service quality\n• Disputes handled via in-app resolution',
        );
        break;
      case 'Release notes':
        _showInfoDialog(
          'Release Notes - v1.0',
          '• Service listing & discovery\n• Real-time chat\n• Booking management\n• Provider verification\n• Admin moderation dashboard\n• Push notifications',
        );
        break;
      default:
        TigerFeedback.show(
          context,
          'Tiger note: $value is coming soon.',
          tone: TigerFeedbackTone.info,
        );
    }
  }

  void _showInfoDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpFab() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.95, end: 1.05),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEA580C).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: PopupMenuButton<String>(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          offset: const Offset(0, -320),
          icon: const Icon(Icons.pets, color: Colors.white, size: 22),
          tooltip: 'Tiger help',
          onSelected: _handleHelpOption,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'Help Center',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.help_outline, size: 20),
                title: Text('Help Center'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'Release notes',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.new_releases_outlined, size: 20),
                title: Text('Release Notes'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'Legal summary',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.gavel, size: 20),
                title: Text('Legal Summary'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'Contact support',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.support_agent, size: 20),
                title: Text('Contact Support'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'Report abuse',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.flag_outlined, size: 20),
                title: Text('Report Abuse'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, {required bool active, required String role}) {
    final accent = RoleVisuals.forRole(role).accent;
    if (!active) return Icon(icon, size: 22);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.24)),
        ),
        child: Icon(icon, size: 22, color: accent),
      ),
    );
  }

  Drawer _buildDrawer(
    BuildContext context,
    User user,
    Map<String, dynamic> data,
    String role,
    List<MobileRouteSpec> mobileRoutes,
    int selectedIndex,
  ) {
    final displayName = ProfileIdentity.displayNameFrom(data, authUser: user);
    final profileImageUrl = ProfileIdentity.profileImageUrlFrom(
      data,
      authUser: user,
    );
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: Column(
        children: [
          // ── Drawer header ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 8,
              bottom: 16,
            ),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Lanka Connect',
                    style: TextStyle(
                      color: DesignTokens.brandPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          // ── User section ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: scheme.surfaceContainerHigh,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: profileImageUrl.isNotEmpty
                      ? NetworkImage(profileImageUrl)
                      : null,
                  onBackgroundImageError: profileImageUrl.isNotEmpty
                      ? (_, __) {}
                      : null,
                  child: profileImageUrl.isEmpty
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(fontSize: 20),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      _roleLabel(role),
                      style: TextStyle(color: scheme.primary, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF1E293B)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pets, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tiger tip: jump to any section from here instead of scrolling through the app.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(mobileRoutes.length, (index) {
                  final route = mobileRoutes[index];
                  final active = index == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: _navIcon(route.icon, active: active, role: role),
                      title: Text(route.label),
                      trailing: active
                          ? Icon(
                              Icons.check_circle,
                              color: RoleVisuals.forRole(role).accent,
                            )
                          : const Icon(Icons.chevron_right),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      tileColor: active
                          ? RoleVisuals.forRole(
                              role,
                            ).chipBackground.withValues(alpha: 0.7)
                          : scheme.surfaceContainerLow,
                      onTap: () {
                        Navigator.of(context).pop();
                        _setIndex(index);
                      },
                    ),
                  );
                }),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: AppThemeController.themeMode.value == ThemeMode.dark,
                  title: const Text('Dark mode'),
                  subtitle: const Text('Switch the current theme'),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  tileColor: scheme.surfaceContainerLow,
                  onChanged: (_) => AppThemeController.toggleTheme(),
                ),
                const SizedBox(height: 12),
                // ── Quick stats section ──
                _DrawerQuickStats(userId: user.uid, role: role),
              ],
            ),
          ),
          // ── Sign Out ── (always visible, no Spacer)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    FirebaseAuth.instance.signOut();
                  },
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.errorContainer,
                    foregroundColor: scheme.onErrorContainer,
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick stats card shown in the drawer below navigation items.
class _DrawerQuickStats extends StatelessWidget {
  const _DrawerQuickStats({required this.userId, required this.role});

  final String userId;
  final String role;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSeekerLike = role == UserRoles.seeker || role == UserRoles.guest;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'Quick Stats',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreRefs.bookings()
                .where(
                  isSeekerLike ? 'seekerId' : 'providerId',
                  isEqualTo: userId,
                )
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final active = docs.where((d) {
                final s = (d.data()['status'] ?? '').toString();
                return s == 'pending' || s == 'accepted';
              }).length;
              final completed = docs
                  .where((d) => d.data()['status'] == 'completed')
                  .length;
              return Row(
                children: [
                  _miniStat(context, Icons.timelapse, '$active', 'Active'),
                  const SizedBox(width: 12),
                  _miniStat(context, Icons.task_alt, '$completed', 'Done'),
                  const SizedBox(width: 12),
                  _miniStat(
                    context,
                    Icons.folder_outlined,
                    '${docs.length}',
                    'Total',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Lanka Connect v1.1.1',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: scheme.onSurface,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
