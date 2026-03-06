import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../ui/theme/design_tokens.dart';
import '../../utils/validators.dart';
import 'auth_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    this.initialOobCode = '',
    this.verifyOobCode,
    this.confirmPasswordReset,
    this.onBackToLogin,
  });

  final String initialOobCode;
  final Future<String> Function(String code)? verifyOobCode;
  final Future<void> Function({
    required String code,
    required String newPassword,
  })?
  confirmPasswordReset;
  final void Function(BuildContext context)? onBackToLogin;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _checkingCode = true;
  bool _submitting = false;
  bool _invalidOrExpired = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _success = false;
  String? _emailHint;
  String? _inlineError;
  String _oobCode = '';

  @override
  void initState() {
    super.initState();
    _resolveOobCodeAndVerify();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<String> _verifyCode(String code) async {
    final verify = widget.verifyOobCode;
    if (verify != null) {
      return verify(code);
    }
    return FirebaseAuth.instance.verifyPasswordResetCode(code);
  }

  Future<void> _confirmReset({
    required String code,
    required String newPassword,
  }) async {
    final confirm = widget.confirmPasswordReset;
    if (confirm != null) {
      await confirm(code: code, newPassword: newPassword);
      return;
    }
    await FirebaseAuth.instance.confirmPasswordReset(
      code: code,
      newPassword: newPassword,
    );
  }

  Future<void> _resolveOobCodeAndVerify() async {
    final fromWidget = widget.initialOobCode.trim();
    final fromUrl = kIsWeb ? (Uri.base.queryParameters['oobCode'] ?? '') : '';
    final code = fromWidget.isNotEmpty ? fromWidget : fromUrl.trim();

    if (code.isEmpty) {
      setState(() {
        _checkingCode = false;
        _invalidOrExpired = true;
      });
      return;
    }

    setState(() {
      _oobCode = code;
      _checkingCode = true;
      _invalidOrExpired = false;
      _inlineError = null;
    });

    try {
      final email = await _verifyCode(code);
      if (!mounted) return;
      setState(() {
        _emailHint = email;
        _checkingCode = false;
      });
    } on FirebaseAuthException catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingCode = false;
        _invalidOrExpired = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingCode = false;
        _invalidOrExpired = true;
      });
    }
  }

  String? _confirmPasswordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirm password is required';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String _strengthLabel(String value) {
    if (value.length < 6) return 'Weak';
    if (value.length < 10) return 'Medium';
    return 'Strong';
  }

  Color _strengthColor(String value) {
    if (value.length < 6) return Colors.red.shade700;
    if (value.length < 10) return const Color(0xFFC47C00);
    return DesignTokens.authWebSuccessText;
  }

  void _backToLogin() {
    final callback = widget.onBackToLogin;
    if (callback != null) {
      callback(context);
      return;
    }
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _submitting = true;
      _inlineError = null;
    });

    try {
      await _confirmReset(
        code: _oobCode,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _success = true;
        _submitting = false;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _inlineError = _mapConfirmError(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _inlineError = 'Could not reset your password. Try again.';
      });
    }
  }

  String _mapConfirmError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'expired-action-code':
      case 'invalid-action-code':
        return 'This reset link is invalid or expired.';
      default:
        return e.message ?? 'Could not reset your password. Try again.';
    }
  }

  Widget _buildStateCard({
    required IconData icon,
    required String title,
    required String body,
    required Color iconColor,
    required Widget action,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DesignTokens.authWebPanelSurface,
        borderRadius: BorderRadius.circular(DesignTokens.authWebPanelRadius),
        border: Border.all(color: DesignTokens.authWebPanelBorder),
        boxShadow: const [
          BoxShadow(
            color: DesignTokens.authWebPanelShadow,
            blurRadius: DesignTokens.authWebPanelShadowBlur,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 40, color: iconColor),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: DesignTokens.authWebPanelTitle,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              color: DesignTokens.authWebPanelMuted,
              height: 1.45,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 20),
          action,
        ],
      ),
    );
  }

  Widget _buildResetCard() {
    final passwordText = _passwordController.text;
    final strengthLabel = _strengthLabel(passwordText);
    final strengthColor = _strengthColor(passwordText);

    return Container(
      key: const Key('reset_password_card'),
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DesignTokens.authWebPanelSurface,
        borderRadius: BorderRadius.circular(DesignTokens.authWebPanelRadius),
        border: Border.all(color: DesignTokens.authWebPanelBorder),
        boxShadow: const [
          BoxShadow(
            color: DesignTokens.authWebPanelShadow,
            blurRadius: DesignTokens.authWebPanelShadowBlur,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create a new password',
              style: TextStyle(
                color: DesignTokens.authWebPanelTitle,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _emailHint == null || _emailHint!.isEmpty
                  ? 'Set a new password to secure your Lanka Connect account.'
                  : 'Set a new password for $_emailHint.',
              style: const TextStyle(
                color: DesignTokens.authWebPanelMuted,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('reset_password_new'),
              controller: _passwordController,
              obscureText: !_showPassword,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'New password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _showPassword = !_showPassword);
                  },
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: (value) =>
                  Validators.passwordField(value, isLogin: false),
            ),
            const SizedBox(height: 10),
            Text(
              'Strength: $strengthLabel',
              key: const Key('reset_password_strength'),
              style: TextStyle(
                color: strengthColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('reset_password_confirm'),
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(
                      () => _showConfirmPassword = !_showConfirmPassword,
                    );
                  },
                  icon: Icon(
                    _showConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                ),
              ),
              validator: _confirmPasswordValidator,
            ),
            if (_inlineError != null) ...[
              const SizedBox(height: 12),
              Container(
                key: const Key('reset_password_error'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: DesignTokens.authWebErrorSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DesignTokens.authWebErrorBorder),
                ),
                child: Text(
                  _inlineError!,
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              key: const Key('reset_password_submit'),
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.authWebPrimaryAction,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_submitting ? 'Saving...' : 'Save New Password'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _submitting ? null : _backToLogin,
              child: const Text('Back to login'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _checkingCode
        ? const Center(child: CircularProgressIndicator())
        : _invalidOrExpired
        ? _buildStateCard(
            icon: Icons.link_off,
            title: 'Reset link expired',
            body:
                'This password reset link is invalid or no longer active. Request a new reset email from the login screen.',
            iconColor: Colors.red.shade700,
            action: ElevatedButton(
              key: const Key('reset_password_back_login_invalid'),
              onPressed: _backToLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.authWebPrimaryAction,
                foregroundColor: Colors.white,
              ),
              child: const Text('Back to login'),
            ),
          )
        : _success
        ? _buildStateCard(
            icon: Icons.check_circle,
            title: 'Password updated',
            body:
                'Your password has been reset successfully. Sign in with your new password.',
            iconColor: DesignTokens.authWebSuccessText,
            action: ElevatedButton(
              key: const Key('reset_password_back_login_success'),
              onPressed: _backToLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.authWebPrimaryAction,
                foregroundColor: Colors.white,
              ),
              child: const Text('Back to login'),
            ),
          )
        : _buildResetCard();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: DesignTokens.authWebBackgroundGradient,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -80,
              top: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x21F59E0B),
                ),
              ),
            ),
            Positioned(
              right: -100,
              bottom: -120,
              child: Container(
                width: 340,
                height: 340,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x1E0D9488),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: content,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
