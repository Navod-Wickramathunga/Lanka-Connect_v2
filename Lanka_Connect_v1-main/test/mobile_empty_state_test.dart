import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_connect/ui/mobile/mobile_components.dart';

void main() {
  group('MobileEmptyState', () {
    testWidgets('renders title and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MobileEmptyState(title: 'No items found', icon: Icons.inbox),
          ),
        ),
      );

      expect(find.text('No items found'), findsOneWidget);
      expect(find.byIcon(Icons.inbox), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MobileEmptyState(
              title: 'No bookings',
              icon: Icons.calendar_today,
              subtitle: 'Your bookings will appear here',
            ),
          ),
        ),
      );

      expect(find.text('No bookings'), findsOneWidget);
      expect(find.text('Your bookings will appear here'), findsOneWidget);
    });

    testWidgets('does not render subtitle when null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MobileEmptyState(title: 'Empty', icon: Icons.info),
          ),
        ),
      );

      expect(find.text('Empty'), findsOneWidget);
      // Only the title text should be present, no subtitle
      final textWidgets = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();
      expect(textWidgets, contains('Empty'));
      expect(textWidgets.length, 1);
    });

    testWidgets('does not render empty subtitle string', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MobileEmptyState(
              title: 'Empty',
              icon: Icons.info,
              subtitle: '   ',
            ),
          ),
        ),
      );

      // Trimmed empty subtitle should not render
      final textWidgets = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();
      expect(textWidgets, contains('Empty'));
      expect(textWidgets.length, 1);
    });

    testWidgets('renders action widget when provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileEmptyState(
              title: 'No results',
              icon: Icons.search_off,
              action: ElevatedButton(
                onPressed: () {},
                child: const Text('Retry'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('No results'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('does not render action widget when null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MobileEmptyState(
              title: 'Nothing here',
              icon: Icons.info_outline,
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
    });
  });

  group('MobileStatePanel', () {
    testWidgets('displays title, subtitle, icon in centered layout', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MobileStatePanel(
              icon: Icons.error_outline,
              title: 'Something went wrong',
              subtitle: 'Try again later',
              tone: MobileStateTone.error,
            ),
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Try again later'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(Center), findsWidgets);
    });

    testWidgets('uses muted tone by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MobileStatePanel(icon: Icons.info, title: 'Test'),
          ),
        ),
      );

      final panel = tester.widget<MobileStatePanel>(
        find.byType(MobileStatePanel),
      );
      expect(panel.tone, MobileStateTone.muted);
    });

    testWidgets('renders action and subtitle together', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileStatePanel(
              icon: Icons.wifi_off,
              title: 'Offline',
              subtitle: 'No internet connection',
              tone: MobileStateTone.info,
              action: TextButton(
                onPressed: () {},
                child: const Text('Reconnect'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('No internet connection'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
    });
  });
}
