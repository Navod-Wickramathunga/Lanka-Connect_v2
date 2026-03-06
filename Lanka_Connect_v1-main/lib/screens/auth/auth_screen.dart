import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../ui/mobile/mobile_components.dart';
import '../../ui/mobile/mobile_tokens.dart';
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
          errorMessage = 'The email address is not valid.';
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

  Future<void> _createUserProfile(User? user) async {
    if (user == null) return;

    final email = user.email ?? _emailController.text.trim();
    final emailName = _nameFromEmail(email);

    if (user.displayName == null || user.displayName!.isEmpty) {
      await user.updateDisplayName(emailName);
    }

    final doc = FirestoreRefs.users().doc(user.uid);
    final data = {
      'role': _role,
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
    final profileRole = UserRoles.normalize(snapshot.data()?['role']);
    if (profileRole == _portalRole) {
      return;
    }

    await FirebaseAuth.instance.signOut();
    throw _PortalRoleMismatch(
      'This account is registered as ${_roleLabel(profileRole)}. '
      'Please sign in via the ${_roleLabel(profileRole)} portal.',
    );
  }

  Future<void> _sendPasswordResetEmail(String email) async {
    final handler = widget.passwordResetHandler;
    if (handler != null) {
      await handler(email);
      return;
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'requestPasswordResetEmail',
      );
      await callable.call({'email': email});
      return;
    } on FirebaseFunctionsException {
      // Fall back to Firebase Auth native email flow so reset still works
      // even if callable functions are unavailable/misconfigured.
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (_) {
      // Fall back to Firebase Auth native email flow so reset still works
      // even if callable functions are unavailable/misconfigured.
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
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
        return 'The email address is not valid.';
      case 'missing-email':
        return 'Email is required.';
      default:
        return e.message ?? 'Could not send reset email. Try again.';
    }
  }

  String _passwordResetCallableError(FirebaseFunctionsException e) {
    if (e.code == 'invalid-argument') {
      return 'The email address is not valid.';
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

  IconData _roleIcon(String role) {
    if (role == UserRoles.provider) return Icons.engineering;
    if (role == UserRoles.admin) return Icons.admin_panel_settings;
    return Icons.search;
  }

  String _portalHeadline() {
    if (!_isLogin) {
      return 'Create your Lanka Connect account';
    }
    if (_portalRole == UserRoles.provider) {
      return 'Provider workspace login';
    }
    if (_portalRole == UserRoles.admin) {
      return 'Admin control center login';
    }
    return 'Seeker portal login';
  }

  void _setMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _formKey = GlobalKey<FormState>();
      _error = null;
      if (!_isLogin && _portalRole == UserRoles.admin && !_usingEmulators) {
        _portalRole = UserRoles.seeker;
        _role = UserRoles.seeker;
      }
    });
  }

  Widget _authModeSwitcher({required bool webLayout}) {
    return Wrap(
      key: const Key('auth_mode_switcher'),
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Login'),
          selected: _isLogin,
          onSelected: _loading ? null : (_) => _setMode(_AuthMode.login),
          avatar: _isLogin ? const Icon(Icons.check, size: 16) : null,
        ),
        ChoiceChip(
          label: const Text('Sign up'),
          selected: !_isLogin,
          onSelected: _loading ? null : (_) => _setMode(_AuthMode.signup),
          avatar: !_isLogin ? const Icon(Icons.check, size: 16) : null,
        ),
        if (webLayout)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              'Secure role-based portals',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DesignTokens.authWebPanelMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _portalSelector({required bool compact}) {
    return Wrap(
      key: const Key('portal_selector'),
      spacing: 10,
      runSpacing: 10,
      children: [
        _PortalChip(
          label: 'Seeker',
          icon: _roleIcon(UserRoles.seeker),
          selected: _portalRole == UserRoles.seeker,
          onTap: _loading
              ? null
              : () {
                  setState(() {
                    _portalRole = UserRoles.seeker;
                    if (!_isLogin) {
                      _role = UserRoles.seeker;
                    }
                  });
                },
          compact: compact,
        ),
        _PortalChip(
          label: 'Provider',
          icon: _roleIcon(UserRoles.provider),
          selected: _portalRole == UserRoles.provider,
          onTap: _loading
              ? null
              : () {
                  setState(() {
                    _portalRole = UserRoles.provider;
                    if (!_isLogin) {
                      _role = UserRoles.provider;
                    }
                  });
                },
          compact: compact,
        ),
        _PortalChip(
          label: 'Admin',
          icon: _roleIcon(UserRoles.admin),
          selected: _portalRole == UserRoles.admin,
          onTap: _loading
              ? null
              : () {
                  setState(() {
                    _portalRole = UserRoles.admin;
                  });
                },
          compact: compact,
        ),
      ],
    );
  }

  Widget _buildAuthForm({required bool webLayout}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bodyColor = webLayout
        ? DesignTokens.authWebPanelMuted
        : (isDark ? const Color(0xFFC9D7E6) : const Color(0xFF4A6072));
    final headingColor = webLayout
        ? DesignTokens.authWebPanelTitle
        : Theme.of(context).colorScheme.onSurface;

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FocusTraversalOrder(
              order: const NumericFocusOrder(1),
              child: _authModeSwitcher(webLayout: webLayout),
            ),
            SizedBox(height: webLayout ? 18 : 14),
            Container(
              padding: EdgeInsets.all(webLayout ? 18 : 0),
              decoration: webLayout
                  ? BoxDecoration(
                      color: DesignTokens.authWebWarmSurface,
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusLg,
                      ),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _portalHeadline(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: headingColor,
                    ),
                  ),
                  if (FirebaseEnv.backendLabel().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: DesignTokens.brandPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: DesignTokens.brandPrimary.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ),
                      child: Text(
                        'Environment: ${FirebaseEnv.backendLabel()}',
                        style: TextStyle(
                          color: headingColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _isLogin
                        ? 'Use the correct portal for your account type and continue where your work already lives.'
                        : 'Create a seeker or provider account. Admin signup stays restricted to existing admin access.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: webLayout
                          ? DesignTokens.authWebWarmText
                          : bodyColor,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: webLayout ? 20 : 18),
            FocusTraversalOrder(
              order: const NumericFocusOrder(2),
              child: _portalSelector(compact: !webLayout),
            ),
            SizedBox(height: webLayout ? 20 : 18),
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
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: Validators.emailField,
              ),
            ),
            const SizedBox(height: 12),
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
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                obscureText: !_showPassword,
                validator: (value) =>
                    Validators.passwordField(value, isLogin: _isLogin),
              ),
            ),
            if (_isLogin) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(5),
                  child: TextButton(
                    key: const Key('forgot_password_button'),
                    onPressed: _loading ? null : _openForgotPasswordDialog,
                    style: webLayout
                        ? TextButton.styleFrom(
                            foregroundColor: DesignTokens.authWebPrimaryAction,
                          )
                        : null,
                    child: const Text('Forgot password?'),
                  ),
                ),
              ),
            ] else
              const SizedBox(height: 12),
            if (!_isLogin)
              FocusTraversalOrder(
                order: const NumericFocusOrder(5),
                child: DropdownButtonFormField<String>(
                  initialValue: _role,
                  items: const [
                    DropdownMenuItem(
                      value: UserRoles.seeker,
                      child: Text('Service Seeker'),
                    ),
                    DropdownMenuItem(
                      value: UserRoles.provider,
                      child: Text('Service Provider'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _role = value;
                      _portalRole = value;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Create account as',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _InlineAuthMessage(
                icon: Icons.error_outline,
                message: _error!,
                foreground: Colors.red.shade800,
                background: webLayout
                    ? DesignTokens.authWebErrorSurface
                    : Colors.red.shade50,
                borderColor: webLayout
                    ? DesignTokens.authWebErrorBorder
                    : Colors.red.shade200,
              ),
            ],
            SizedBox(height: webLayout ? 20 : 18),
            FocusTraversalOrder(
              order: const NumericFocusOrder(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: webLayout
                      ? const [
                          BoxShadow(
                            color: DesignTokens.authWebPanelShadow,
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ]
                      : null,
                ),
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: _primaryActionButtonStyle(webLayout),
                  child: Text(
                    _loading
                        ? 'Please wait...'
                        : _isLogin
                        ? 'Login to ${_roleLabel(_portalRole)} Portal'
                        : 'Create ${_roleLabel(_role)} Account',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FocusTraversalOrder(
              order: const NumericFocusOrder(7),
              child: TextButton(
                onPressed: _loading
                    ? null
                    : () => _setMode(
                        _isLogin ? _AuthMode.signup : _AuthMode.login,
                      ),
                style: webLayout
                    ? TextButton.styleFrom(
                        foregroundColor: DesignTokens.authWebPanelTitle,
                      )
                    : null,
                child: Text(
                  _isLogin
                      ? 'Need an account? Sign up here'
                      : 'Already have an account? Sign in',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: webLayout
                          ? DesignTokens.authWebPanelMuted
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            FocusTraversalOrder(
              order: const NumericFocusOrder(8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _continueAsGuest,
                  icon: const Icon(Icons.person_outline, size: 20),
                  label: const Text('Continue as Guest'),
                  style: _guestActionButtonStyle(webLayout),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Browse services without creating an account',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: webLayout
                    ? DesignTokens.authWebPanelMuted
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _primaryActionButtonStyle(bool webLayout) {
    if (!webLayout) {
      return ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      );
    }

    return ButtonStyle(
      padding: const MaterialStatePropertyAll(
        EdgeInsets.symmetric(vertical: 16),
      ),
      backgroundColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.disabled)) {
          return DesignTokens.authWebPrimaryAction.withValues(alpha: 0.45);
        }
        if (states.contains(MaterialState.pressed)) {
          return DesignTokens.authWebPrimaryActionPressed;
        }
        if (states.contains(MaterialState.hovered)) {
          return DesignTokens.authWebPrimaryActionHover;
        }
        return DesignTokens.authWebPrimaryAction;
      }),
      foregroundColor: const MaterialStatePropertyAll(Colors.white),
      elevation: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.disabled)) return 0.0;
        if (states.contains(MaterialState.hovered)) return 2.0;
        return 0.0;
      }),
      shape: MaterialStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textStyle: const MaterialStatePropertyAll(
        TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  ButtonStyle _guestActionButtonStyle(bool webLayout) {
    if (!webLayout) {
      return ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
    }

    return ButtonStyle(
      padding: const MaterialStatePropertyAll(
        EdgeInsets.symmetric(vertical: 14),
      ),
      backgroundColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.disabled)) {
          return DesignTokens.authWebSecondaryActionSurface.withValues(
            alpha: 0.65,
          );
        }
        if (states.contains(MaterialState.hovered)) {
          return DesignTokens.authWebSecondaryActionHover;
        }
        return DesignTokens.authWebSecondaryActionSurface;
      }),
      foregroundColor: const MaterialStatePropertyAll(
        DesignTokens.authWebSecondaryActionText,
      ),
      elevation: const MaterialStatePropertyAll(0),
      shape: MaterialStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildHeroPanel({required bool compact}) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      offset: _panelsVisible ? Offset.zero : const Offset(-0.04, 0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 460),
        opacity: _panelsVisible ? 1 : 0,
        child: Container(
          key: const Key('auth_web_hero'),
          padding: EdgeInsets.all(compact ? 24 : 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.authWebHeroRadius),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: DesignTokens.authWebHeroGradient,
            ),
            boxShadow: const [
              BoxShadow(
                color: DesignTokens.authWebHeroGlow,
                blurRadius: 36,
                spreadRadius: 2,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lanka Connect',
                style: TextStyle(
                  color: DesignTokens.authWebHeroText,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Trusted local services in minutes, with separate portals for seekers, providers, and admins.',
                style: TextStyle(
                  color: DesignTokens.authWebHeroTextMuted,
                  fontSize: 17,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _HeroBadge(label: 'Verified local demand'),
                  _HeroBadge(label: 'Role-based access'),
                  _HeroBadge(label: 'Fast recovery support'),
                ],
              ),
              const SizedBox(height: 28),
              const _FeatureLine(
                icon: Icons.search,
                text: 'Seekers discover verified services and book faster.',
              ),
              const SizedBox(height: 12),
              const _FeatureLine(
                icon: Icons.engineering,
                text: 'Providers manage visibility, requests, and responses.',
              ),
              const SizedBox(height: 12),
              const _FeatureLine(
                icon: Icons.admin_panel_settings,
                text: 'Admins maintain platform quality and trust standards.',
              ),
              const SizedBox(height: 28),
              _HeroTrustStrip(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebLayout() {
    return Scaffold(
      body: Container(
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
              top: -140,
              left: -110,
              child: Container(
                width: 360,
                height: 360,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x26F59E0B),
                ),
              ),
            ),
            Positioned(
              right: -120,
              bottom: -120,
              child: Container(
                width: 320,
                height: 320,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x1F0D9488),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final viewport = _viewportForWidth(constraints.maxWidth);
                    final isWide = viewport == _WebAuthViewport.wide;
                    final isCompact = viewport == _WebAuthViewport.compact;
                    final horizontalPadding = isCompact ? 14.0 : 24.0;
                    final panelPadding = isCompact
                        ? 18.0
                        : (isWide ? 30.0 : 24.0);

                    final authPanel = AnimatedSlide(
                      duration: const Duration(milliseconds: 460),
                      curve: Curves.easeOut,
                      offset: _panelsVisible
                          ? Offset.zero
                          : const Offset(0.04, 0),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 500),
                        opacity: _panelsVisible ? 1 : 0,
                        child: Container(
                          key: Key(switch (viewport) {
                            _WebAuthViewport.wide => 'auth_web_layout_wide',
                            _WebAuthViewport.medium => 'auth_web_layout_medium',
                            _WebAuthViewport.compact =>
                              'auth_web_layout_compact',
                          }),
                          padding: EdgeInsets.all(panelPadding),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              DesignTokens.authWebPanelRadius,
                            ),
                            color: DesignTokens.authWebPanelSurface,
                            border: Border.all(
                              color: DesignTokens.authWebPanelBorder,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: DesignTokens.authWebPanelShadow,
                                blurRadius: DesignTokens.authWebPanelShadowBlur,
                                offset: Offset(0, 14),
                              ),
                            ],
                          ),
                          child: _buildAuthForm(webLayout: true),
                        ),
                      ),
                    );

                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1220),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: isCompact ? 16 : 24,
                        ),
                        child: isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 6,
                                    child: _buildHeroPanel(compact: false),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(flex: 5, child: authPanel),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildHeroPanel(compact: isCompact),
                                  const SizedBox(height: 18),
                                  authPanel,
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
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
      backgroundColor: MobileTokens.backgroundDark,
      body: SizedBox.expand(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: DesignTokens.authGradient,
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: Column(
                      children: [
                        const MobileGradientHeader(
                          title: 'Lanka Connect',
                          subtitle:
                              'Welcome back to your local service network',
                          accentColor: MobileTokens.accent,
                        ),
                        const SizedBox(height: 14),
                        MobileSectionCard(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: KeyedSubtree(
                              key: ValueKey('$_mode|$_portalRole'),
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
        ),
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.onSubmit,
    required this.mapError,
    this.mapCallableError,
  });

  final String initialEmail;
  final Future<void> Function(String email) onSubmit;
  final String Function(FirebaseAuthException e) mapError;
  final String Function(FirebaseFunctionsException e)? mapCallableError;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _loading = false;
  String? _error;
  String? _success;

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

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      await widget.onSubmit(_emailController.text.trim());
      setState(() {
        _success =
            'If an account exists for this email, you will receive reset instructions shortly.';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = widget.mapError(e);
      });
    } on FirebaseFunctionsException catch (e) {
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

class _InlineAuthMessage extends StatelessWidget {
  const _InlineAuthMessage({
    this.key,
    required this.icon,
    required this.message,
    required this.foreground,
    required this.background,
    required this.borderColor,
  });

  @override
  final Key? key;
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

class _PortalChip extends StatefulWidget {
  const _PortalChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  State<_PortalChip> createState() => _PortalChipState();
}

class _PortalChipState extends State<_PortalChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = widget.selected
        ? (isDark
              ? const Color(0xFF79B7FF)
              : DesignTokens.authWebChipSelectedBorder)
        : (isDark ? const Color(0xFF3B4E66) : DesignTokens.authWebChipBorder);
    final backgroundColor = widget.selected
        ? (isDark
              ? const Color(0xFF2A4E7A)
              : DesignTokens.authWebChipSelectedFill)
        : (isDark ? const Color(0xFF1A2635) : DesignTokens.authWebChipFill);
    final contentColor = widget.selected
        ? (isDark
              ? const Color(0xFFEAF4FF)
              : DesignTokens.authWebChipSelectedLabel)
        : (isDark ? const Color(0xFFD6E5F5) : DesignTokens.authWebChipLabel);

    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() {
        _hovered = true;
      }),
      onExit: (_) => setState(() {
        _hovered = false;
      }),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 10 : 14,
            vertical: widget.compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: _hovered && !widget.selected
                ? (isDark
                      ? backgroundColor.withValues(alpha: 0.88)
                      : DesignTokens.authWebChipHover)
                : backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            scale: _hovered && widget.onTap != null ? 1.01 : 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: widget.compact ? 16 : 18,
                  color: contentColor,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: contentColor,
                    fontWeight: widget.selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: DesignTokens.authWebHeroAccent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: DesignTokens.authWebHeroText,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: DesignTokens.authWebHeroText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _HeroTrustStrip extends StatelessWidget {
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
