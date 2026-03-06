import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_connect/screens/auth/reset_password_screen.dart';

void main() {
  testWidgets('shows invalid state when oobCode is missing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ResetPasswordScreen(initialOobCode: '')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reset link expired'), findsOneWidget);
    expect(find.byKey(const Key('reset_password_back_login_invalid')), findsOneWidget);
  });

  testWidgets('renders form and validates password fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResetPasswordScreen(
          initialOobCode: 'abc123',
          verifyOobCode: (code) async => 'user@example.com',
          confirmPasswordReset: ({required code, required newPassword}) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reset_password_card')), findsOneWidget);
    expect(find.text('Set a new password for user@example.com.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reset_password_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Password is required'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('reset_password_new')), '123456');
    await tester.enterText(find.byKey(const Key('reset_password_confirm')), '1234567');
    await tester.tap(find.byKey(const Key('reset_password_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('submits and shows success state', (tester) async {
    String? submittedCode;
    String? submittedPassword;

    await tester.pumpWidget(
      MaterialApp(
        home: ResetPasswordScreen(
          initialOobCode: 'validCode',
          verifyOobCode: (code) async => 'user@example.com',
          confirmPasswordReset: ({required code, required newPassword}) async {
            submittedCode = code;
            submittedPassword = newPassword;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('reset_password_new')), 'newpass123');
    await tester.enterText(find.byKey(const Key('reset_password_confirm')), 'newpass123');
    await tester.tap(find.byKey(const Key('reset_password_submit')));
    await tester.pumpAndSettle();

    expect(submittedCode, 'validCode');
    expect(submittedPassword, 'newpass123');
    expect(find.text('Password updated'), findsOneWidget);
    expect(find.byKey(const Key('reset_password_back_login_success')), findsOneWidget);
  });
}
