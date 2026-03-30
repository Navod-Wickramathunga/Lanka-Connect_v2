import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_connect/screens/auth/auth_screen.dart';

void main() {
  testWidgets('auth screen renders guest entry button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: AuthScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue as Guest'), findsOneWidget);
  });

  testWidgets('mobile auth screen uses community portal heading', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: AuthScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Community Portal Login'), findsOneWidget);
    expect(find.text('Lanka Connect'), findsOneWidget);
  });
}
