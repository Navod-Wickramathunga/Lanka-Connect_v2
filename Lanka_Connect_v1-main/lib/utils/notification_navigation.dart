import 'user_roles.dart';

enum NotificationNavigationTarget {
  chat,
  payment,
  providerRequests,
  seekerRequests,
  bookingList,
  notifications,
}

class NotificationNavigation {
  const NotificationNavigation._();

  static NotificationNavigationTarget resolveTarget(
    Map<String, dynamic> data, {
    String role = UserRoles.seeker,
  }) {
    final type = (data['type'] ?? '').toString();
    final bookingId = (data['bookingId'] ?? '').toString();
    final chatId = (data['chatId'] ?? '').toString();
    final requestId = (data['requestId'] ?? '').toString();

    if (chatId.isNotEmpty) {
      return NotificationNavigationTarget.chat;
    }

    if (type == 'payment' && bookingId.isNotEmpty) {
      return NotificationNavigationTarget.payment;
    }

    if (requestId.isNotEmpty) {
      return role == UserRoles.provider
          ? NotificationNavigationTarget.providerRequests
          : NotificationNavigationTarget.seekerRequests;
    }

    if (bookingId.isNotEmpty) {
      return NotificationNavigationTarget.bookingList;
    }

    return NotificationNavigationTarget.notifications;
  }
}
