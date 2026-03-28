import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../ui/theme/design_tokens.dart';
import '../../utils/firebase_env.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/user_roles.dart';
import '../../utils/validators.dart';

enum _AuthMode { login, signup }

enum _WebAuthViewport { wide, medium, compact }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.forceWebLayoutForTest = false,
    this.passwordResetHandler,
  });

  final bool forceWebLayoutForTest;
  final Future<void> Function(String email)? passwordResetHandler;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  _AuthMode _mode = _AuthMode.login;
  bool _loading = false;
  String _role = UserRoles.seeker;
  String _portalRole = UserRoles.seeker;
  String? _error;
  bool _showPassword = false;
  bool _panelsVisible = false;
  bool _staySignedIn = false;

  bool get _isLogin => _mode == _AuthMode.login;
  bool get _usingEmulators => FirebaseEnv.useEmulators;
  bool get _isWebLayout => kIsWeb || widget.forceWebLayoutForTest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _panelsVisible = true);
    });
  }

  _WebAuthViewport _viewportForWidth(double width) {
    if (width >= 1120) return _WebAuthViewport.wide;
    if (width >= 760) return _WebAuthViewport.medium;
    return _WebAuthViewport.compact;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if (!_isLogin && _portalRole == UserRoles.admin && !_usingEmulators) {
      setState(() {
        _error =
            'Admin accounts cannot be created here. Use an existing admin account to sign in.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
        await _validatePortalRole(credential.user);
      } else {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
        await _createUserProfile(credential.user);
      }
    } on _PortalRoleMismatch catch (e) {
      setState(() {
        _error = e.message;
      });
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists for this email.';
          break;
        case 'invalid-email':
          errorMessage = 'You are not entering a correct email address.';
          break;
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password.';
          break;
        default:
          errorMessage = e.message ?? 'Authentication failed';
      }
      setState(() {
        _error = errorMessage;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final credential = await FirebaseAuth.instance.signInAnonymously();
      final user = credential.user;
      if (user != null) {
        await FirestoreRefs.users().doc(user.uid).set({
          'role': UserRoles.guest,
          'name': 'Guest User',
          'email': '',
          'isGuest': true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _guestLoginError(e);
      });
    } catch (_) {
      setState(() {
        _error = 'Guest login failed.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _createUserProfile(User? user, {String? roleOverride}) async {
    if (user == null) return;

    final email = user.email ?? _emailController.text.trim();
    final emailName = _nameFromEmail(email);

    if (user.displayName == null || user.displayName!.isEmpty) {
      await user.updateDisplayName(emailName);
    }

    final doc = FirestoreRefs.users().doc(user.uid);
    final data = {
      'role': roleOverride ?? _role,
      'name': emailName,
      'email': email,
      'contact': '',
      'district': '',
      'city': '',
      'skills': <String>[],
      'bio': '',
      'imageUrl': '',
      'createdAt': FieldValue.serverTimestamp(),
    };
    await doc.set(data, SetOptions(merge: true));
  }

  Future<void> _validatePortalRole(User? user) async {
    if (user == null) return;

    final snapshot = await FirestoreRefs.users().doc(user.uid).get();

    // If no Firestore profile exists yet (e.g. user created via Firebase
    // Console or migrated from another project), auto-create one so the
    // login succeeds instead of throwing a role-mismatch error.
    if (!snapshot.exists || snapshot.data() == null) {
      await _createUserProfile(user, roleOverride: _portalRole);
      return;
    }

    final profileRole = UserRoles.normalize(snapshot.data()?['role']);
    if (profileRole == _portalRole) {
      // Enrich profile with Firebase Auth identity data (email, name) if
      // those fields are missing — mirrors the ProfileIdentity fallback
      // used across the app so that every user is identifiable in the
      // admin panel and other user lists.
      await _enrichProfileIfNeeded(user, snapshot.data()!);
      return;
    }

    await FirebaseAuth.instance.signOut();
    throw _PortalRoleMismatch(
      'This account is registered as ${_roleLabel(profileRole)}. '
      'Please sign in via the ${_roleLabel(profileRole)} portal.',
    );
  }

  /// Updates the user's Firestore profile with Firebase Auth identity fields
  /// (email, displayName → name) if they are currently blank.  Only writes
  /// the document when there is something new to persist.
  Future<void> _enrichProfileIfNeeded(
    User user,
    Map<String, dynamic> existing,
  ) async {
    final storedEmail = (existing['email'] ?? '').toString().trim();
    final storedName = (existing['name'] ?? '').toString().trim();
    final storedDisplayName = (existing['displayName'] ?? '').toString().trim();

    final updates = <String, dynamic>{};

    // Sync email from Firebase Auth when missing in Firestore
    final authEmail = (user.email ?? '').trim();
    if (storedEmail.isEmpty && authEmail.isNotEmpty) {
      updates['email'] = authEmail;
    }

    // Derive a readable name from email when the name field is blank
    if (storedName.isEmpty) {
      final authDisplayName = (user.displayName ?? '').trim();
      if (authDisplayName.isNotEmpty) {
        updates['name'] = authDisplayName;
      } else {
        final emailSource = updates['email'] as String? ?? storedEmail;
        if (emailSource.isNotEmpty) {
          updates['name'] = _nameFromEmail(emailSource);
        } else if (authEmail.isNotEmpty) {
          updates['name'] = _nameFromEmail(authEmail);
        }
      }
    }

    // Sync displayName for consistent look-ups in ProfileIdentity
    if (storedDisplayName.isEmpty) {
      final authDisplayName = (user.displayName ?? '').trim();
      if (authDisplayName.isNotEmpty) {
        updates['displayName'] = authDisplayName;
      } else if (updates.containsKey('name')) {
        updates['displayName'] = updates['name'];
      }
    }

    if (updates.isNotEmpty) {
      await FirestoreRefs.users().doc(user.uid).update(updates);
    }
  }

  Future<void> _sendPasswordResetEmail(String email) async {
    final handler = widget.passwordResetHandler;
    if (handler != null) {
      await handler(email);
      return;
    }

    // Staging demo mode: use Firebase's built-in reset email flow directly to
    // avoid SendGrid deliverability issues when no authenticated sender domain
    // is available.
    if (FirebaseEnv.isStaging) {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return;
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'requestPasswordResetEmail',
      );
      final result = await callable.call<Map<String, dynamic>>({
        'email': email,
      });
      final data = result.data;
      if (data['accountExists'] == false) {
        throw const _PasswordResetAccountNotFound();
      }
      return;
    } on _PasswordResetAccountNotFound {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message:
            e.message ??
            'Could not send reset email. Check your connection and try again.',
      );
    } catch (_) {
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message:
            'Could not send reset email. Check your connection and try again.',
      );
    }
  }

  String _guestLoginError(FirebaseAuthException e) {
    final message = e.message?.toLowerCase() ?? '';
    switch (e.code) {
      case 'operation-not-allowed':
      case 'admin-restricted-operation':
        return 'Guest access is currently disabled. Please sign in with an account.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try guest access again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        if (message.contains('restricted to administrators only')) {
          return 'Guest access is currently disabled. Please sign in with an account.';
        }
        return e.message ?? 'Guest login failed.';
    }
  }

  String _passwordResetError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'You are not entering a correct email address.';
      case 'missing-email':
        return 'Email is required.';
      default:
        return e.message ?? 'Could not send reset email. Try again.';
    }
  }

  String _passwordResetCallableError(FirebaseFunctionsException e) {
    if (e.code == 'invalid-argument') {
      return 'You are not entering a correct email address.';
    }
    return e.message ?? 'Could not send reset email. Try again.';
  }

  Future<void> _openForgotPasswordDialog() async {
    if (_loading) return;
    final initialEmail = _emailController.text.trim();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return _ForgotPasswordDialog(
          initialEmail: initialEmail,
          onSubmit: _sendPasswordResetEmail,
          onOpenSignup: (email) {
            Navigator.of(context).pop();
            if (_emailController.text.trim() != email) {
              _emailController.text = email;
            }
            _setMode(_AuthMode.signup);
          },
          autoRouteUnknownAccount: _isWebLayout,
          mapError: _passwordResetError,
          mapCallableError: _passwordResetCallableError,
        );
      },
    );
  }

  String _roleLabel(String role) {
    if (role == UserRoles.provider) return 'Provider';
    if (role == UserRoles.admin) return 'Admin';
    if (role == UserRoles.guest) return 'Guest';
    return 'Seeker';
  }

  void _setMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _formKey = GlobalKey<FormState>();
      _error = null;
      _showPassword = false;
      if (!_isLogin && _portalRole == UserRoles.admin && !_usingEmulators) {
        _portalRole = UserRoles.seeker;
        _role = UserRoles.seeker;
      }
    });
  }

  Widget _authModeSwitcher({required bool webLayout}) {
    if (!webLayout) {
      return Container(
        key: const Key('auth_mode_switcher'),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD9E2E8)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _MobileSegmentButton(
                label: 'Login',
                selected: _isLogin,
                onTap: _loading ? null : () => _setMode(_AuthMode.login),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _MobileSegmentButton(
                label: 'Sign up',
                selected: !_isLogin,
                onTap: _loading ? null : () => _setMode(_AuthMode.signup),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      key: const Key('auth_mode_switcher'),
      children: [
        _WebAuthTab(
          label: 'Login',
          selected: _isLogin,
          onTap: _loading ? null : () => _setMode(_AuthMode.login),
        ),
        const SizedBox(width: 26),
        _WebAuthTab(
          label: 'Sign up',
          selected: !_isLogin,
          onTap: _loading ? null : () => _setMode(_AuthMode.signup),
        ),
      ],
    );
  }

  Widget _portalSelector({required bool compact}) {
    if (_isWebLayout) {
      final webRoles = <({String label, String role})>[
        (label: 'Seeker', role: UserRoles.seeker),
        (label: 'Provider', role: UserRoles.provider),
        if (_isLogin) (label: 'Admin', role: UserRoles.admin),
      ];
      return Container(
        key: const Key('portal_selector'),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFEBEEEE),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            for (var i = 0; i < webRoles.length; i++) ...[
              Expanded(
                child: _WebRoleSegment(
                  label: webRoles[i].label,
                  selected: _portalRole == webRoles[i].role,
                  onTap: _loading
                      ? null
                      : () {
                          setState(() {
                            _portalRole = webRoles[i].role;
                            if (!_isLogin) {
                              _role = webRoles[i].role;
                            }
                          });
                        },
                ),
              ),
              if (i != webRoles.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
      );
    }

    final mobileRoles = <({String label, String role, IconData icon})>[
      (label: 'Seeker', role: UserRoles.seeker, icon: Icons.person_outline),
      (
        label: 'Provider',
        role: UserRoles.provider,
        icon: Icons.engineering_outlined,
      ),
      if (_isLogin)
        (
          label: 'Admin',
          role: UserRoles.admin,
          icon: Icons.admin_panel_settings_outlined,
        ),
    ];

    return Container(
      key: const Key('portal_selector'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8EE)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < mobileRoles.length; i++) ...[
            Expanded(
              child: _MobileRoleSegment(
                label: mobileRoles[i].label,
                icon: mobileRoles[i].icon,
                selected: _portalRole == mobileRoles[i].role,
                onTap: _loading
                    ? null
                    : () {
                        setState(() {
                          _portalRole = mobileRoles[i].role;
                          if (!_isLogin) {
                            _role = mobileRoles[i].role;
                          }
                        });
                      },
              ),
            ),
            if (i != mobileRoles.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  String _mobileHeadline() {
    if (_isLogin) return 'Welcome Back';
    return 'Create Account';
  }

  String _mobileSupportText() {
    if (_isLogin) return '';
    return 'Create a seeker or provider account to book services or offer your skills.';
  }

  InputDecoration _mobileInputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFE0E6EB)),
    );
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF9AA6B2), fontSize: 16),
      prefixIcon: Icon(icon, color: const Color(0xFF98A2B3)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFF0A7B81), width: 1.5),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFFE07A7A)),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFFD54F4F), width: 1.5),
      ),
    );
  }

  Widget _buildMobileFormShell({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFDFEFE),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFFE5EAEE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22041F23),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        child: child,
      ),
    );
  }

  Widget _buildAuthForm({required bool webLayout}) {
    if (!webLayout) {
      return _buildMobileAuthForm();
    }

    return _buildWebAuthForm();
  }

  Widget _buildWebAuthForm() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: _authModeSwitcher(webLayout: true),
                ),
                const SizedBox(height: 26),
                if (FirebaseEnv.backendLabel().isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F7F7),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFC8E6E8)),
                      ),
                      child: Text(
                        'Environment: ${FirebaseEnv.backendLabel()}',
                        style: const TextStyle(
                          color: Color(0xFF0C6369),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                if (!_isLogin) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF5F5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFD4E9E9)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create your Lanka Connect account',
                          style: TextStyle(
                            color: Color(0xFF18484B),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Choose your role and sign up to find trusted help or offer local services.',
                          style: TextStyle(
                            color: Color(0xFF4B6363),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                const Text(
                  'I am a...',
                  style: TextStyle(
                    color: Color(0xFF4B6363),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(2),
                  child: _portalSelector(compact: false),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Email Address',
                  style: TextStyle(
                    color: Color(0xFF3F4949),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(3),
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    decoration: _webInputDecoration(
                      hintText: 'name@company.com',
                      icon: Icons.mail_outline,
                    ),
                    validator: Validators.emailField,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Password',
                        style: TextStyle(
                          color: Color(0xFF3F4949),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_isLogin)
                      TextButton(
                        key: const Key('forgot_password_button'),
                        onPressed: _loading ? null : _openForgotPasswordDialog,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF005458),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        child: const Text('Forgot?'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(4),
                  child: TextFormField(
                    controller: _passwordController,
                    textInputAction: TextInputAction.done,
                    autofillHints: _isLogin
                        ? const [AutofillHints.password]
                        : const [AutofillHints.newPassword],
                    enableSuggestions: false,
                    autocorrect: false,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: _webInputDecoration(
                      hintText: '********',
                      icon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _showPassword = !_showPassword;
                          });
                        },
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF9AA7AB),
                        ),
                      ),
                    ),
                    obscureText: !_showPassword,
                    validator: (value) =>
                        Validators.passwordField(value, isLogin: _isLogin),
                  ),
                ),
                if (_isLogin) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Checkbox(
                        value: _staySignedIn,
                        onChanged: _loading
                            ? null
                            : (value) {
                                setState(() {
                                  _staySignedIn = value ?? false;
                                });
                              },
                        side: const BorderSide(color: Color(0xFFB9C6CA)),
                        activeColor: const Color(0xFF005458),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Stay signed in for 30 days',
                        style: TextStyle(
                          color: Color(0xFF4B6363),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _InlineAuthMessage(
                    icon: Icons.error_outline,
                    message: _error!,
                    foreground: Colors.red.shade800,
                    background: DesignTokens.authWebErrorSurface,
                    borderColor: DesignTokens.authWebErrorBorder,
                  ),
                ],
                const SizedBox(height: 24),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(6),
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _submit,
                    style: _primaryActionButtonStyle(true),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 22),
                    label: Text(
                      _loading
                          ? 'Please wait...'
                          : _isLogin
                          ? 'Sign In'
                          : 'Create ${_roleLabel(_role)} Account',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Divider(color: Color(0x1A6D7C80), thickness: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: const Text(
                        'OR',
                        style: TextStyle(
                          color: Color(0xFF6F7979),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(color: Color(0x1A6D7C80), thickness: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _continueAsGuest,
                      style: _guestActionButtonStyle(true),
                      child: const Text('Continue as Guest'),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'By continuing, you agree to Lanka Connect\'s Terms of Service and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4B6363),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _webInputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: const BorderSide(color: Color(0x1A788A8D)),
    );
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF7D8E92), fontSize: 15),
      prefixIcon: Icon(icon, color: const Color(0xFF8C9B9F), size: 21),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFF0A6E73), width: 1.6),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFFE07A7A)),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFFD54F4F), width: 1.5),
      ),
    );
  }

  ButtonStyle _primaryActionButtonStyle(bool webLayout) {
    if (!webLayout) {
      return ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        backgroundColor: const Color(0xFF0A7B81),
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      );
    }

    return ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 18)),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return const Color(0xFF005458).withValues(alpha: 0.45);
        }
        if (states.contains(WidgetState.pressed)) {
          return const Color(0xFF004F52);
        }
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFF126E72);
        }
        return const Color(0xFF005458);
      }),
      foregroundColor: const WidgetStatePropertyAll(Colors.white),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return 0.0;
        if (states.contains(WidgetState.hovered)) return 1.0;
        return 0.0;
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
    );
  }

  ButtonStyle _guestActionButtonStyle(bool webLayout) {
    if (!webLayout) {
      return ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        backgroundColor: const Color(0xFFD8F1F2),
        foregroundColor: const Color(0xFF0F686D),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      );
    }

    return ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 18)),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return const Color(0xFFCEE8E8).withValues(alpha: 0.65);
        }
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFFB2CBCB);
        }
        return const Color(0xFFCEE8E8);
      }),
      foregroundColor: const WidgetStatePropertyAll(Color(0xFF516969)),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildHeroPanel({required bool compact, bool condensed = false}) {
    final panelPadding = switch ((compact, condensed)) {
      (true, _) => 24.0,
      (false, true) => 30.0,
      (false, false) => 44.0,
    };
    final brandFontSize = switch ((compact, condensed)) {
      (true, _) => 24.0,
      (false, true) => 28.0,
      (false, false) => 34.0,
    };
    final headlineFontSize = switch ((compact, condensed)) {
      (true, _) => 42.0,
      (false, true) => 52.0,
      (false, false) => 64.0,
    };
    final headerSpacing = switch ((compact, condensed)) {
      (true, _) => 28.0,
      (false, true) => 28.0,
      (false, false) => 44.0,
    };
    final sectionSpacing = switch ((compact, condensed)) {
      (true, _) => 20.0,
      (false, true) => 18.0,
      (false, false) => 24.0,
    };

    return AnimatedSlide(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      offset: _panelsVisible ? Offset.zero : const Offset(-0.04, 0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 460),
        opacity: _panelsVisible ? 1 : 0,
        child: Container(
          key: const Key('auth_web_hero'),
          padding: EdgeInsets.all(panelPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(42),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF005458), Color(0xFF126E72)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3300363A),
                blurRadius: 40,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, heroConstraints) {
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFFA2F0F4),
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Lanka Connect',
                        style: TextStyle(
                          color: const Color(0xFFA2F0F4),
                          fontSize: brandFontSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: headerSpacing),
                  Text(
                    'Lanka Connect -\nTrusted local services\nin minutes.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: headlineFontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      height: 1.06,
                    ),
                  ),
                  SizedBox(height: condensed ? 18 : 28),
                  if (condensed) ...[
                    const Text(
                      'Verified providers, quick matching, and protected payments in one trusted local marketplace.',
                      style: TextStyle(
                        color: Color(0xFFD5F1F3),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: sectionSpacing),
                    const _HeroTrustStrip(),
                    SizedBox(height: sectionSpacing),
                    const Text(
                      'Join over 12,000 satisfied users in Sri Lanka.',
                      style: TextStyle(
                        color: Color(0xFFD5F1F3),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else ...[
                    const _FeatureLine(
                      icon: Icons.verified_user_rounded,
                      title: 'Verified Professionals',
                      text:
                          'Every provider undergoes a rigorous identity and skill verification process.',
                    ),
                    SizedBox(height: sectionSpacing),
                    const _FeatureLine(
                      icon: Icons.schedule_rounded,
                      title: 'Instant Matching',
                      text:
                          'Our intelligent algorithm connects you with local experts quickly.',
                    ),
                    SizedBox(height: sectionSpacing),
                    const _FeatureLine(
                      icon: Icons.payments_rounded,
                      title: 'Secure Escrow',
                      text:
                          'Payments are held safely and released only after satisfaction.',
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'Join over 12,000 satisfied users in Sri Lanka.',
                      style: TextStyle(
                        color: const Color(0xFFD5F1F3),
                        fontSize: compact ? 18 : 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              );

              if (!heroConstraints.hasBoundedHeight) {
                return content;
              }

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: heroConstraints.maxHeight,
                  ),
                  child: content,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMobileWebBrandHeader() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 460),
      opacity: _panelsVisible ? 1 : 0,
      child: Container(
        key: const Key('auth_web_hero'),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF005458), Color(0xFF126E72)],
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: Color(0xFFA2F0F4), size: 26),
            const SizedBox(width: 10),
            const Text(
              'Lanka Connect',
              style: TextStyle(
                color: Color(0xFFA2F0F4),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = _viewportForWidth(constraints.maxWidth);
            final isWide = viewport == _WebAuthViewport.wide;
            final isCompact = viewport == _WebAuthViewport.compact;
            // Use the shorter hero variant for typical laptop-height web viewports
            // so the marketing panel does not overflow before the auth form.
            final condensedWideHero = isWide && constraints.maxHeight < 980;
            final panelPadding = isCompact ? 16.0 : 26.0;
            final pagePadding = isCompact ? 0.0 : 24.0;

            final authPanel = AnimatedSlide(
              duration: const Duration(milliseconds: 460),
              curve: Curves.easeOut,
              offset: _panelsVisible ? Offset.zero : const Offset(0.04, 0),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _panelsVisible ? 1 : 0,
                child: Container(
                  key: Key(switch (viewport) {
                    _WebAuthViewport.wide => 'auth_web_layout_wide',
                    _WebAuthViewport.medium => 'auth_web_layout_medium',
                    _WebAuthViewport.compact => 'auth_web_layout_compact',
                  }),
                  padding: EdgeInsets.all(panelPadding),
                  decoration: isCompact
                      ? null
                      : BoxDecoration(
                          color: const Color(0xFFF1F4F4),
                          borderRadius: BorderRadius.circular(38),
                          border: Border.all(color: const Color(0x1A6C7A7D)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1400383B),
                              blurRadius: 30,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                  child: _buildAuthForm(webLayout: true),
                ),
              ),
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMobileWebBrandHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: authPanel,
                    ),
                  ),
                ],
              );
            }

            // Wide: full-viewport height — hero panel stretches to fill the
            // viewport, auth panel scrolls independently if the form is taller
            // than the available space.
            if (isWide) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1520),
                  child: Padding(
                    padding: EdgeInsets.all(pagePadding),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 52,
                          child: _buildHeroPanel(
                            compact: false,
                            condensed: condensedWideHero,
                          ),
                        ),
                        const SizedBox(width: 22),
                        Expanded(
                          flex: 48,
                          child: SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight:
                                    constraints.maxHeight - (pagePadding * 2),
                              ),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: authPanel,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Medium (stacked): hero panel above, auth form below, page scrolls
            // as a whole.
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1520),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(pagePadding),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (pagePadding * 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeroPanel(compact: true),
                        const SizedBox(height: 18),
                        authPanel,
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _nameFromEmail(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex <= 0) return '';
    final raw = email.substring(0, atIndex).trim();
    if (raw.isEmpty) return '';

    return raw
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          final first = part.substring(0, 1).toUpperCase();
          final rest = part.length > 1 ? part.substring(1).toLowerCase() : '';
          return '$first$rest';
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (_isWebLayout) {
      return _buildWebLayout();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF062F33),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF148189),
                  Color(0xFF0C5960),
                  Color(0xFF062F33),
                ],
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
          ),
          Positioned(
            bottom: -160,
            right: -90,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.08),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 52,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Lanka Connect',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Community Portal Login',
                          key: const Key('auth_mobile_title'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 30),
                        _buildMobileFormShell(
                          child: AnimatedSwitcher(
                            key: const Key('auth_mobile_panel'),
                            duration: const Duration(milliseconds: 220),
                            child: KeyedSubtree(
                              key: ValueKey('mobile|$_mode'),
                              child: _buildAuthForm(webLayout: false),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileAuthForm() {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FocusTraversalOrder(
              order: const NumericFocusOrder(1),
              child: _authModeSwitcher(webLayout: false),
            ),
            const SizedBox(height: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _mobileHeadline(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF101828),
                  ),
                ),
                if (FirebaseEnv.backendLabel().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF7F7),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFCDE9EA)),
                    ),
                    child: Text(
                      'Environment: ${FirebaseEnv.backendLabel()}',
                      style: const TextStyle(
                        color: Color(0xFF148189),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (_mobileSupportText().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _mobileSupportText(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF667085),
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 22),
            FocusTraversalOrder(
              order: const NumericFocusOrder(2),
              child: _portalSelector(compact: true),
            ),
            const SizedBox(height: 22),
            FocusTraversalOrder(
              order: const NumericFocusOrder(3),
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: Colors.black87),
                cursorColor: const Color(0xFF101828),
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                decoration: _mobileInputDecoration(
                  hintText: 'Email',
                  icon: Icons.mail_outline,
                ),
                validator: Validators.emailField,
              ),
            ),
            const SizedBox(height: 14),
            FocusTraversalOrder(
              order: const NumericFocusOrder(4),
              child: TextFormField(
                controller: _passwordController,
                textInputAction: TextInputAction.done,
                style: const TextStyle(color: Colors.black87),
                cursorColor: const Color(0xFF101828),
                autofillHints: _isLogin
                    ? const [AutofillHints.password]
                    : const [AutofillHints.newPassword],
                enableSuggestions: false,
                autocorrect: false,
                onFieldSubmitted: (_) => _submit(),
                decoration: _mobileInputDecoration(
                  hintText: 'Password',
                  icon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF98A2B3),
                    ),
                  ),
                ),
                obscureText: !_showPassword,
                validator: (value) =>
                    Validators.passwordField(value, isLogin: _isLogin),
              ),
            ),
            if (_isLogin) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(5),
                  child: TextButton(
                    key: const Key('forgot_password_button'),
                    onPressed: _loading ? null : _openForgotPasswordDialog,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0A7B81),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ),
              ),
            ] else
              const SizedBox(height: 14),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _InlineAuthMessage(
                icon: Icons.error_outline,
                message: _error!,
                foreground: Colors.red.shade800,
                background: Colors.red.shade50,
                borderColor: Colors.red.shade200,
              ),
            ],
            const SizedBox(height: 18),
            FocusTraversalOrder(
              order: const NumericFocusOrder(6),
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: _primaryActionButtonStyle(false),
                child: Text(
                  _loading
                      ? 'Please wait...'
                      : _isLogin
                      ? 'Sign In'
                      : 'Create ${_roleLabel(_role)} Account',
                ),
              ),
            ),
            const SizedBox(height: 14),
            FocusTraversalOrder(
              order: const NumericFocusOrder(7),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _continueAsGuest,
                  style: _guestActionButtonStyle(false),
                  child: const Text('Continue as Guest'),
                ),
              ),
            ),
            const SizedBox(height: 14),
            FocusTraversalOrder(
              order: const NumericFocusOrder(8),
              child: TextButton(
                onPressed: _loading
                    ? null
                    : () => _setMode(
                        _isLogin ? _AuthMode.signup : _AuthMode.login,
                      ),
                child: Text(
                  _isLogin
                      ? 'Need an account? Sign up here'
                      : 'Already have an account? Sign in',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.onSubmit,
    required this.onOpenSignup,
    required this.autoRouteUnknownAccount,
    required this.mapError,
    this.mapCallableError,
  });

  final String initialEmail;
  final Future<void> Function(String email) onSubmit;
  final void Function(String email) onOpenSignup;
  final bool autoRouteUnknownAccount;
  final String Function(FirebaseAuthException e) mapError;
  final String Function(FirebaseFunctionsException e)? mapCallableError;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  static const _genericSuccessMessage =
      'If an account exists for this email, you will receive reset instructions shortly.';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _loading = false;
  String? _error;
  String? _success;
  bool _accountNotFound = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleUnknownAccount() {
    final email = _emailController.text.trim();
    if (widget.autoRouteUnknownAccount) {
      widget.onOpenSignup(email);
      return;
    }
    setState(() {
      _accountNotFound = true;
    });
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
      _accountNotFound = false;
    });

    try {
      await widget.onSubmit(_emailController.text.trim());
      setState(() {
        _success = _genericSuccessMessage;
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _handleUnknownAccount();
        return;
      }
      setState(() {
        _error = widget.mapError(e);
      });
    } on _PasswordResetAccountNotFound {
      _handleUnknownAccount();
      return;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') {
        _handleUnknownAccount();
        return;
      }
      setState(() {
        _error =
            widget.mapCallableError?.call(e) ??
            'Could not send reset email. Try again.';
      });
    } catch (_) {
      setState(() {
        _error = 'Could not send reset email. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.authWebDialogRadius),
      ),
      title: const Text('Reset Password'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your account email and we will send a password reset link.',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('forgot_password_email'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: Validators.emailField,
                ),
                if (_accountNotFound) ...[
                  const SizedBox(height: 10),
                  Container(
                    key: const Key('forgot_password_not_found'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      border: Border.all(color: const Color(0xFFFFD54F)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Color(0xFFF57F17),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'No account found for this email.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5D4037),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'You can create a new account with this email.',
                                style: TextStyle(
                                  color: Color(0xFF5D4037),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextButton.icon(
                                key: const Key(
                                  'forgot_password_signup_shortcut',
                                ),
                                onPressed: () => widget.onOpenSignup(
                                  _emailController.text.trim(),
                                ),
                                icon: const Icon(
                                  Icons.person_add_outlined,
                                  size: 16,
                                ),
                                label: const Text('Sign up'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: Color(0xFFF57F17),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  _InlineAuthMessage(
                    key: const Key('forgot_password_error'),
                    icon: Icons.error_outline,
                    message: _error!,
                    foreground: Colors.red.shade800,
                    background: DesignTokens.authWebErrorSurface,
                    borderColor: DesignTokens.authWebErrorBorder,
                  ),
                ],
                if (_success != null) ...[
                  const SizedBox(height: 10),
                  _InlineAuthMessage(
                    key: const Key('forgot_password_success'),
                    icon: Icons.check_circle_outline,
                    message: _success!,
                    foreground: DesignTokens.authWebSuccessText,
                    background: const Color(0xFFEAF8F1),
                    borderColor: const Color(0xFFB7E4CD),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          key: const Key('forgot_password_submit'),
          onPressed: _loading ? null : _submit,
          child: Text(_loading ? 'Sending...' : 'Send reset link'),
        ),
      ],
    );
  }
}

class _PortalRoleMismatch implements Exception {
  _PortalRoleMismatch(this.message);

  final String message;
}

class _PasswordResetAccountNotFound implements Exception {
  const _PasswordResetAccountNotFound();
}

class _InlineAuthMessage extends StatelessWidget {
  const _InlineAuthMessage({
    super.key,
    required this.icon,
    required this.message,
    required this.foreground,
    required this.background,
    required this.borderColor,
  });

  final IconData icon;
  final String message;
  final Color foreground;
  final Color background;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: foreground),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileSegmentButton extends StatelessWidget {
  const _MobileSegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0A7B81) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x220A7B81),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF475467),
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileRoleSegment extends StatelessWidget {
  const _MobileRoleSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE3F6F7) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFFB7E7EA) : Colors.transparent,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x110A7B81),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? const Color(0xFF0A7B81)
                    : const Color(0xFF667085),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF0A7B81)
                        : const Color(0xFF475467),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebAuthTab extends StatelessWidget {
  const _WebAuthTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF0A666B)
                      : const Color(0xFF5C6E72),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                height: 3,
                width: 88,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF0A666B)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebRoleSegment extends StatelessWidget {
  const _WebRoleSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x14003E42),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF0A666B)
                  : const Color(0xFF4E6166),
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: const Color(0xFFA2F0F4), size: 23),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                text,
                style: const TextStyle(
                  color: Color(0xFFD6F2F3),
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroTrustStrip extends StatelessWidget {
  const _HeroTrustStrip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _HeroTrustMetric(
              value: '3 portals',
              label: 'Seeker, provider, admin',
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _HeroTrustMetric(
              value: 'Guest access',
              label: 'Try the marketplace first',
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _HeroTrustMetric(
              value: 'Reset ready',
              label: 'Recover access inline',
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTrustMetric extends StatelessWidget {
  const _HeroTrustMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: DesignTokens.authWebHeroAccent,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: DesignTokens.authWebHeroTextMuted,
            height: 1.35,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
