import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_connect/utils/page_transitions.dart';

void main() {
  group('SlideUpRoute', () {
    testWidgets('navigates to destination with slide-up transition', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    SlideUpRoute(builder: (_) => const _DestinationPage()),
                  );
                },
                child: const Text('Navigate'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(find.text('Destination'), findsOneWidget);
    });

    testWidgets('transition includes FadeTransition and SlideTransition', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    SlideUpRoute(builder: (_) => const _DestinationPage()),
                  );
                },
                child: const Text('Navigate'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Navigate'));
      // Pump a single frame to see animation in progress
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FadeTransition), findsWidgets);
      expect(find.byType(SlideTransition), findsWidgets);
    });

    test('has correct transition duration of 300ms', () {
      final route = SlideUpRoute(builder: (_) => const SizedBox());
      expect(route.transitionDuration, const Duration(milliseconds: 300));
    });

    test('has correct reverse transition duration of 250ms', () {
      final route = SlideUpRoute(builder: (_) => const SizedBox());
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 250),
      );
    });

    testWidgets('can pop back to previous screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    SlideUpRoute(
                      builder: (_) => Scaffold(
                        body: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Go Back'),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Navigate'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(find.text('Go Back'), findsOneWidget);

      await tester.tap(find.text('Go Back'));
      await tester.pumpAndSettle();

      expect(find.text('Navigate'), findsOneWidget);
    });
  });
}

class _DestinationPage extends StatelessWidget {
  const _DestinationPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Destination')));
  }
}
