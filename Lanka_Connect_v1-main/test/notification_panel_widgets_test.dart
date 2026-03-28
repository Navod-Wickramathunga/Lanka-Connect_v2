import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_connect/widgets/notification_panel_widgets.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('notification toolbar disables actions when empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const NotificationToolbar(
          unreadCount: 0,
          hasNotifications: false,
          onMarkAllRead: null,
          onClearAll: null,
        ),
      ),
    );

    final markAll = tester.widget<IconButton>(find.byIcon(Icons.done_all));
    final clearAll = tester.widget<IconButton>(
      find.byIcon(Icons.delete_sweep_outlined),
    );

    expect(markAll.onPressed, isNull);
    expect(clearAll.onPressed, isNull);
    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets('notification toolbar triggers mark all read and clear all', (
    tester,
  ) async {
    var markAllTapped = 0;
    var clearAllTapped = 0;

    await tester.pumpWidget(
      wrap(
        NotificationToolbar(
          unreadCount: 3,
          hasNotifications: true,
          onMarkAllRead: () => markAllTapped++,
          onClearAll: () => clearAllTapped++,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Mark all read'));
    await tester.pump();
    await tester.tap(find.byTooltip('Clear all'));
    await tester.pump();

    expect(markAllTapped, 1);
    expect(clearAllTapped, 1);
    expect(find.text('Clear all'), findsOneWidget);
  });

  testWidgets('notification list item opens popup actions and tap callback', (
    tester,
  ) async {
    var opened = 0;
    var viewed = 0;
    var removed = 0;

    await tester.pumpWidget(
      wrap(
        NotificationListItem(
          title: 'Booking update',
          body: 'Provider accepted your booking',
          type: 'booking',
          timeLabel: '5m ago',
          isRead: false,
          onOpen: () => opened++,
          onViewDetails: () => viewed++,
          onRemove: () => removed++,
        ),
      ),
    );

    await tester.tap(find.text('Booking update'));
    await tester.pump();
    expect(opened, 1);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View details').last);
    await tester.pumpAndSettle();
    expect(viewed, 1);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(removed, 1);
  });
}
