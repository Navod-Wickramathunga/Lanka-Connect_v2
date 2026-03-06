import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_connect/screens/auth/auth_screen.dart';

void main() {
  testWidgets('auth mobile entry toggles signup mode while keeping mobile layout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthScreen()),
    );

    expect(find.text('Seeker portal login'), findsOneWidget);
    expect(find.text('Login to Seeker Portal'), findsOneWidget);
    expect(find.text('Welcome back to your local service network'), findsOneWidget);
    // 'Forgot password?' is shown in mobile login mode
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Create account as'), findsNothing);

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(find.text('Create your Lanka Connect account'), findsOneWidget);
    expect(find.text('Create account as'), findsOneWidget);
    expect(find.text('Create Seeker Account'), findsOneWidget);
    expect(find.text('Already have an account? Sign in'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);
  });
}
