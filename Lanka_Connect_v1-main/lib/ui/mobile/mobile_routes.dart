import 'package:flutter/material.dart';

import '../../screens/admin/admin_web_dashboard_screen.dart';
import '../../screens/bookings/booking_list_screen.dart';
import '../../screens/chat/chat_list_screen.dart';
import '../../screens/home/seeker_home_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/provider/provider_dashboard_screen.dart';
import '../../screens/provider/provider_services_screen.dart';
import '../../screens/requests/request_list_screen.dart';
import '../../screens/requests/seeker_request_list_screen.dart';
import '../../screens/services/service_list_screen.dart';
import '../../utils/user_roles.dart';

enum MobileAppRouteId {
  home,
  dashboard,
  services,
  requests,
  bookings,
  chats,
  profile,
  users,
}

class MobileRouteSpec {
  const MobileRouteSpec({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
  });

  final MobileAppRouteId id;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

class MobileRoutes {
  const MobileRoutes._();

  static List<MobileRouteSpec> forRole(String role) {
    if (role == UserRoles.admin) {
      return [
        MobileRouteSpec(
          id: MobileAppRouteId.dashboard,
          label: 'Dashboard',
          icon: Icons.space_dashboard_outlined,
          builder: (_) => const AdminWebDashboardScreen(),
        ),
        MobileRouteSpec(
          id: MobileAppRouteId.services,
          label: 'Services',
          icon: Icons.search,
          builder: (_) => const ServiceListScreen(),
        ),
        MobileRouteSpec(
          id: MobileAppRouteId.users,
          label: 'Users',
          icon: Icons.person_outline,
          builder: (_) => const AdminUsersScreen(),
        ),
      ];
    }

    if (role == UserRoles.provider) {
      return [
        MobileRouteSpec(
          id: MobileAppRouteId.dashboard,
          label: 'Dashboard',
          icon: Icons.space_dashboard_outlined,
          builder: (_) => const ProviderDashboardScreen(),
        ),
        MobileRouteSpec(
          id: MobileAppRouteId.services,
          label: 'My Services',
          icon: Icons.store,
          builder: (_) => const ProviderServicesScreen(),
        ),
        MobileRouteSpec(
          id: MobileAppRouteId.requests,
          label: 'Requests',
          icon: Icons.inbox,
          builder: (_) => const RequestListScreen(),
        ),
        MobileRouteSpec(
          id: MobileAppRouteId.bookings,
          label: 'Bookings',
          icon: Icons.calendar_today,
          builder: (_) => const BookingListScreen(),
        ),
        MobileRouteSpec(
          id: MobileAppRouteId.chats,
          label: 'Chats',
          icon: Icons.chat,
          builder: (_) => const ChatListScreen(),
        ),
        MobileRouteSpec(
          id: MobileAppRouteId.profile,
          label: 'Profile',
          icon: Icons.person,
          builder: (_) => const ProfileScreen(),
        ),
      ];
    }

    if (role == UserRoles.guest) {
      return [
        MobileRouteSpec(
          id: MobileAppRouteId.home,
          label: 'Home',
          icon: Icons.home_rounded,
          builder: (_) => const SeekerHomeScreen(),
        ),
        MobileRouteSpec(
          id: MobileAppRouteId.services,
          label: 'Services',
          icon: Icons.search,
          builder: (_) => const ServiceListScreen(),
        ),
        MobileRouteSpec(
          id: MobileAppRouteId.bookings,
          label: 'Bookings',
          icon: Icons.calendar_today,
          builder: (_) => const BookingListScreen(),
        ),
      ];
    }

    return [
      MobileRouteSpec(
        id: MobileAppRouteId.home,
        label: 'Home',
        icon: Icons.home_rounded,
        builder: (_) => const SeekerHomeScreen(),
      ),
      MobileRouteSpec(
        id: MobileAppRouteId.services,
        label: 'Services',
        icon: Icons.search,
        builder: (_) => const ServiceListScreen(),
      ),
      MobileRouteSpec(
        id: MobileAppRouteId.requests,
        label: 'Requests',
        icon: Icons.assignment,
        builder: (_) => const SeekerRequestListScreen(),
      ),
      MobileRouteSpec(
        id: MobileAppRouteId.bookings,
        label: 'Bookings',
        icon: Icons.calendar_today,
        builder: (_) => const BookingListScreen(),
      ),
      MobileRouteSpec(
        id: MobileAppRouteId.chats,
        label: 'Chats',
        icon: Icons.chat,
        builder: (_) => const ChatListScreen(),
      ),
      MobileRouteSpec(
        id: MobileAppRouteId.profile,
        label: 'Profile',
        icon: Icons.person,
        builder: (_) => const ProfileScreen(),
      ),
    ];
  }
}
