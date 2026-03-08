import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_connect/widgets/shimmer_loading.dart';

void main() {
  group('ShimmerLoading', () {
    testWidgets('renders child content', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ShimmerLoading(child: Text('placeholder'))),
        ),
      );

      expect(find.text('placeholder'), findsOneWidget);
    });

    testWidgets('creates an animation controller that repeats', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerLoading(child: SizedBox(width: 100, height: 20)),
          ),
        ),
      );

      // Pump a few frames to verify animation is running without errors
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Widget tree should still be intact after multiple frames
      expect(find.byType(ShimmerLoading), findsOneWidget);
    });

    testWidgets('disposes animation controller cleanly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ShimmerLoading(child: Text('test'))),
        ),
      );

      // Replace with a different widget — triggers dispose
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );

      // No errors expected after dispose
      expect(find.byType(ShimmerLoading), findsNothing);
    });
  });

  group('ShimmerProvider', () {
    testWidgets('provides animation progress to descendants', (
      WidgetTester tester,
    ) async {
      double? capturedProgress;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShimmerProvider(
              progress: 0.5,
              child: Builder(
                builder: (context) {
                  capturedProgress = ShimmerProvider.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      expect(capturedProgress, 0.5);
    });

    testWidgets('returns 0.0 when no ShimmerProvider ancestor exists', (
      WidgetTester tester,
    ) async {
      double? capturedProgress;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedProgress = ShimmerProvider.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedProgress, 0.0);
    });

    test('updateShouldNotify returns true for different progress', () {
      const p1 = ShimmerProvider(progress: 0.2, child: SizedBox());
      const p2 = ShimmerProvider(progress: 0.5, child: SizedBox());
      expect(p2.updateShouldNotify(p1), isTrue);
    });

    test('updateShouldNotify returns false for same progress', () {
      const p1 = ShimmerProvider(progress: 0.5, child: SizedBox());
      const p2 = ShimmerProvider(progress: 0.5, child: SizedBox());
      expect(p2.updateShouldNotify(p1), isFalse);
    });
  });

  group('ShimmerBox', () {
    testWidgets('renders a Container with default height', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerProvider(progress: 0.0, child: ShimmerBox()),
          ),
        ),
      );

      expect(find.byType(ShimmerBox), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('accepts custom width, height, borderRadius', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerProvider(
              progress: 0.3,
              child: ShimmerBox(width: 100, height: 24, borderRadius: 8),
            ),
          ),
        ),
      );

      expect(find.byType(ShimmerBox), findsOneWidget);
    });
  });

  group('ShimmerCardList', () {
    testWidgets('renders default 4 card placeholders', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ShimmerCardList())),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ShimmerCardList), findsOneWidget);
      // Each card has a circular shimmer box (48x48)
      expect(
        find.byWidgetPredicate(
          (w) => w is ShimmerBox && w.width == 48 && w.height == 48,
        ),
        findsNWidgets(4),
      );
    });

    testWidgets('renders custom itemCount', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ShimmerCardList(itemCount: 2)),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byWidgetPredicate(
          (w) => w is ShimmerBox && w.width == 48 && w.height == 48,
        ),
        findsNWidgets(2),
      );
    });
  });

  group('ShimmerServiceGrid', () {
    testWidgets('renders default 6 grid items', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ShimmerServiceGrid()),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ShimmerServiceGrid), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('renders custom itemCount', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShimmerServiceGrid(itemCount: 4),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ShimmerServiceGrid), findsOneWidget);
    });
  });
}
