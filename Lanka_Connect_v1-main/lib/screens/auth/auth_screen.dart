import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../ui/mobile/mobile_components.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/theme/design_tokens.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/user_roles.dart';
import '../../utils/validators.dart';

enum _AuthMode { login, signup }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

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

  bool get _isLogin => _mode == _AuthMode.login;

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
    if (!_isLogin && _portalRole == UserRoles.admin) {
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
        _error = 'Something went wrong. Please try again.';
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

  String _roleLabel(String role) {
    if (role == UserRoles.provider) return 'Provider';
    if (role == UserRoles.admin) return 'Admin';
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
      if (!_isLogin && _portalRole == UserRoles.admin) {
        _portalRole = UserRoles.seeker;
        _role = UserRoles.seeker;
      }
    });
  }

  Widget _authModeSwitcher() {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Login'),
          selected: _isLogin,
          onSelected: _loading ? null : (_) => _setMode(_AuthMode.login),
        ),
        ChoiceChip(
          label: const Text('Sign up'),
          selected: !_isLogin,
          onSelected: _loading ? null : (_) => _setMode(_AuthMode.signup),
        ),
      ],
    );
  }

  Widget _portalSelector({required bool compact}) {
    return Wrap(
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _authModeSwitcher(),
          const SizedBox(height: 14),
          Text(
            _portalHeadline(),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _isLogin
                ? 'Use the correct portal for your account type.'
                : 'Create a seeker or provider account. Admin signup is disabled.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFC9D7E6)
                  : const Color(0xFF4A6072),
            ),
          ),
          const SizedBox(height: 18),
          _portalSelector(compact: !webLayout),
          const SizedBox(height: 18),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            validator: (value) => Validators.emailField(value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
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
          const SizedBox(height: 12),
          if (!_isLogin)
            DropdownButtonFormField<String>(
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _loading
                  ? 'Please wait...'
                  : _isLogin
                  ? 'Login to ${_roleLabel(_portalRole)} Portal'
                  : 'Create ${_roleLabel(_role)} Account',
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _loading
                ? null
                : () => _setMode(_isLogin ? _AuthMode.signup : _AuthMode.login),
            child: Text(
              _isLogin
                  ? 'Need an account? Sign up here'
                  : 'Already have an account? Sign in',
            ),
          ),
        ],
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
            colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
          ),
        ),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 980;
              final content = <Widget>[
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F766E), Color(0xFF0F172A)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Lanka Connect',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Sign in as seeker, provider, or admin and manage trusted local services.',
                        style: TextStyle(
                          color: Color(0xFFCFE8E5),
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 26),
                      _FeatureLine(
                        icon: Icons.search,
                        text:
                            'Seekers discover trusted local services quickly.',
                      ),
                      SizedBox(height: 10),
                      _FeatureLine(
                        icon: Icons.engineering,
                        text:
                            'Providers manage visibility, bookings, and communication.',
                      ),
                      SizedBox(height: 10),
                      _FeatureLine(
                        icon: Icons.admin_panel_settings,
                        text:
                            'Admins monitor quality and maintain platform safety.',
                      ),
                    ],
                  ),
                ),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: _buildAuthForm(webLayout: true),
                  ),
                ),
              ];

              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1140),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: isNarrow
                      ? SingleChildScrollView(
                          child: Column(
                            children: [
                              content[0],
                              const SizedBox(height: 16),
                              content[1],
                            ],
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(child: content[0]),
                            const SizedBox(width: 24),
                            Expanded(child: content[1]),
                          ],
                        ),
                ),
              );
            },
          ),
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
    if (kIsWeb) {
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

class _PortalRoleMismatch implements Exception {
  _PortalRoleMismatch(this.message);

  final String message;
}

class _PortalChip extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = selected
        ? (isDark ? const Color(0xFF79B7FF) : const Color(0xFF1769AA))
        : (isDark ? const Color(0xFF3B4E66) : const Color(0xFFD0DCE8));
    final backgroundColor = selected
        ? (isDark ? const Color(0xFF2A4E7A) : const Color(0xFFE7F1FA))
        : (isDark ? const Color(0xFF1A2635) : Colors.white);
    final contentColor = selected
        ? (isDark ? const Color(0xFFEAF4FF) : const Color(0xFF0D3E63))
        : (isDark ? const Color(0xFFD6E5F5) : const Color(0xFF1E3245));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 16 : 18, color: contentColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: contentColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
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
        Icon(icon, color: Color(0xFF8FE3C4), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFFE8F2FA), height: 1.4),
          ),
        ),
      ],
    );
  }
}
