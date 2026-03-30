import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_connect/screens/auth/auth_screen.dart';

void main() {
  testWidgets(
    'auth mobile entry toggles signup mode while keeping mobile layout',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));

      expect(find.text('Lanka Connect'), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      // 'Forgot password?' is shown in mobile login mode
      expect(find.text('Forgot password?'), findsOneWidget);

      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Create Seeker Account'), findsOneWidget);
      expect(find.text('Already have an account? Sign in'), findsOneWidget);
      expect(find.text('Forgot password?'), findsNothing);
    },
  );
}
