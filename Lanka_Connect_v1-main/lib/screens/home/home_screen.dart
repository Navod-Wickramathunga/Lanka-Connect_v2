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
import '../../utils/demo_data_service.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/firebase_env.dart';
import '../../utils/notification_service.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _webRouteId;
  bool _seeding = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _notificationSubscription;
  final Set<String> _seenNotificationIds = <String>{};
  String? _notificationKey;
  bool _notificationPrimed = false;

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
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
              final title = (data['title'] ?? 'Notification').toString();
              final body = (data['body'] ?? '').toString();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(body.isEmpty ? title : '$title: $body')),
              );
              break;
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Seeding demo data...')));

    try {
      final result = await DemoDataService.seed();
      final ok = (result['ok'] ?? false) == true;
      final created = (result['created'] ?? 0).toString();
      final updated = (result['updated'] ?? 0).toString();
      final skipped = (result['skipped'] ?? 0).toString();
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Demo data seeded. Created: $created, Updated: $updated, Skipped: $skipped.'
                : 'Seeder finished with partial result.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
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
        _ensureNotificationSubscription(user.uid, role);

        final mobileRoutes = MobileRoutes.forRole(role);
        final selectedIndex = _currentIndex.clamp(0, mobileRoutes.length - 1);
        final webRouteMap = _webRouteMapForRole(role);
        final webNavItems = _webNavItemsForRole(role);

        if (_webRouteId == null || !webRouteMap.containsKey(_webRouteId)) {
          _webRouteId = webNavItems.first.id;
        }

        if (kIsWeb && role != UserRoles.admin) {
          final routeId = _webRouteId!;
          final routeWidget = webRouteMap[routeId]!;
          final routeLabel = webNavItems
              .firstWhere((item) => item.id == routeId)
              .label;
          final backendLabel = FirebaseEnv.backendLabel();
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
              if (role == UserRoles.admin)
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
          drawer: _buildDrawer(context, user, data, role),
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
              destinations: mobileRoutes
                  .map(
                    (route) => NavigationDestination(
                      icon: Icon(route.icon, size: 22),
                      selectedIcon: Icon(
                        route.icon,
                        size: 24,
                        color: RoleVisuals.forRole(role).accent,
                      ),
                      label: route.label,
                    ),
                  )
                  .toList(),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$value — feature coming soon!')),
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
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: Colors.grey.shade800,
        shape: const CircleBorder(),
        elevation: 6,
        child: PopupMenuButton<String>(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          offset: const Offset(0, -320),
          icon: const Icon(Icons.question_mark, color: Colors.white, size: 18),
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

  Drawer _buildDrawer(
    BuildContext context,
    User user,
    Map<String, dynamic> data,
    String role,
  ) {
    final displayName = (data['name'] ?? user.displayName ?? 'User').toString();
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
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL == null
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
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
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
