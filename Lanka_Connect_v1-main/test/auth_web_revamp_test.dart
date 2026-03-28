import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_connect/screens/auth/auth_screen.dart';

Future<void> _pumpWebAuth(
  WidgetTester tester, {
  Size size = const Size(1280, 900),
  Future<void> Function(String email)? passwordResetHandler,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: AuthScreen(
        forceWebLayoutForTest: true,
        passwordResetHandler: passwordResetHandler,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'web auth defaults to seeker portal with provider chip behavior',
    (tester) async {
      await _pumpWebAuth(tester);

      expect(find.text('Continue as Guest'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byKey(const Key('forgot_password_button')), findsOneWidget);

      // Admin chip should be present on login page
      expect(find.text('Admin'), findsOneWidget);

      await tester.tap(find.text('Admin').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Seeker').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Provider').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Seeker').first);
      await tester.pumpAndSettle();
      expect(find.text('Sign In'), findsOneWidget);
    },
  );

  testWidgets('signup mode shows only seeker and provider portals', (
    tester,
  ) async {
    await _pumpWebAuth(tester);

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forgot_password_button')), findsNothing);

    // Admin chip should not be present
    expect(find.text('Admin'), findsNothing);

    // Only Seeker and Provider should be selectable
    expect(find.text('Seeker'), findsOneWidget);
    expect(find.text('Provider'), findsOneWidget);

    await tester.tap(find.text('Provider').first);
    await tester.pumpAndSettle();
    expect(find.text('Create Provider Account'), findsOneWidget);
  });

  testWidgets('forgot password dialog validates and sends email', (
    tester,
  ) async {
    String? submittedEmail;
    await _pumpWebAuth(
      tester,
      passwordResetHandler: (email) async {
        submittedEmail = email;
      },
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.tap(find.byKey(const Key('forgot_password_button')));
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.byKey(const Key('forgot_password_email')), findsOneWidget);
    // Email appears in both the login field and pre-filled dialog field
    expect(find.text('user@example.com'), findsAtLeast(1));

    await tester.enterText(find.byKey(const Key('forgot_password_email')), '');
    await tester.tap(find.byKey(const Key('forgot_password_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('forgot_password_email')),
      'invalid-email',
    );
    await tester.tap(find.byKey(const Key('forgot_password_submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('You are not entering a correct email address.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('forgot_password_email')),
      'user@example.com',
    );
    await tester.tap(find.byKey(const Key('forgot_password_submit')));
    await tester.pumpAndSettle();

    expect(submittedEmail, 'user@example.com');
    expect(find.byKey(const Key('forgot_password_success')), findsOneWidget);
    expect(
      find.text(
        'If an account exists for this email, you will receive reset instructions shortly.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Password'), findsNothing);
  });

  testWidgets('forgot password shows mapped firebase errors', (tester) async {
    await _pumpWebAuth(
      tester,
      passwordResetHandler: (email) async {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'invalid email from firebase',
        );
      },
    );

    await tester.tap(find.byKey(const Key('forgot_password_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('forgot_password_email')),
      'good@example.com',
    );
    await tester.tap(find.byKey(const Key('forgot_password_submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('You are not entering a correct email address.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('forgot_password_error')), findsOneWidget);
  });

  testWidgets('web auth adapts layout across wide medium and compact widths', (
    tester,
  ) async {
    await _pumpWebAuth(tester, size: const Size(1400, 900));
    expect(find.byKey(const Key('auth_web_layout_wide')), findsOneWidget);
    expect(find.byKey(const Key('auth_web_hero')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpWebAuth(tester, size: const Size(980, 900));
    expect(find.byKey(const Key('auth_web_layout_medium')), findsOneWidget);
    expect(find.byKey(const Key('auth_web_hero')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpWebAuth(tester, size: const Size(600, 900));
    expect(find.byKey(const Key('auth_web_layout_compact')), findsOneWidget);
    expect(find.byKey(const Key('auth_web_hero')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
