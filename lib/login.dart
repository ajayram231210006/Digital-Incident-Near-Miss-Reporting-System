import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'app_theme.dart';
import 'user_profile_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutQuad),
        );

    _slideController.forward();
    _initializeConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _initializeConnectivity() async {
    _isOnline = await _hasConnection();
    if (mounted) {
      setState(() {});
    }

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      _,
    ) async {
      final isOnline = await _hasConnection();
      if (!mounted) return;
      setState(() => _isOnline = isOnline);
    });
  }

  Future<bool> _hasConnection() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((item) => item != ConnectivityResult.none);
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: AppColors.overlay,
      builder: (context) => const _LoginDialog(),
    );
  }

  void _showSignUpDialog() {
    // Close the login dialog if it's open
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    // Show signup dialog
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: AppColors.overlay,
      builder: (context) => _SignUpDialog(onBackToLogin: _showLoginDialog),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.authGradient),
        child: SlideTransition(
          position: _slideAnimation,
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: const [Colors.white, AppColors.surfaceMuted],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withValues(alpha: 0.24),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.security_outlined,
                      size: 50,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Incident Report System',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Secure Reporting Platform',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 50),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        if (!_isOnline) ...[
                          const _OfflineAuthBanner(
                            message:
                                'Internet is required for login, sign up, and password reset. If you have already signed in before as a reporter, reconnect once and the app can later reopen in offline reporting mode.',
                          ),
                          const SizedBox(height: 20),
                        ],
                        ElevatedButton.icon(
                          onPressed: _showLoginDialog,
                          icon: const Icon(Icons.login, size: 20),
                          label: const Text('Open Login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.info,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadii.medium,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            children: [
                              const TextSpan(text: 'Don\'t have an account? '),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: _showSignUpDialog,
                                  child: Text(
                                    'Sign up',
                                    style: const TextStyle(
                                      color: Color(0xFFAEDFF7),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginDialog extends StatefulWidget {
  const _LoginDialog();

  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _fieldController;

  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  final ValueNotifier<String> _loginRole = ValueNotifier('reporter');
  final UserProfileService _userProfileService = UserProfileService();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fieldController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutQuad),
    );

    _scaleController.forward();
    _fieldController.forward();
    _initializeConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _scaleController.dispose();
    _fieldController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _loginRole.dispose();
    super.dispose();
  }

  Future<void> _initializeConnectivity() async {
    _isOnline = await _hasConnection();
    if (mounted) {
      setState(() {});
    }

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      _,
    ) async {
      final isOnline = await _hasConnection();
      if (!mounted) return;
      setState(() => _isOnline = isOnline);
    });
  }

  Future<bool> _hasConnection() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((item) => item != ConnectivityResult.none);
  }

  Future<void> _showMessage(String message, {bool isError = true}) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          isError ? Icons.error_outline : Icons.check_circle_outline,
          color: isError ? AppColors.error : AppColors.success,
          size: 32,
        ),
        title: Text(
          isError ? 'Error' : 'Success',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isError ? AppColors.error : AppColors.success,
              shape: RoundedRectangleBorder(borderRadius: AppRadii.small),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!await _hasConnection()) {
      await _showMessage(
        'Internet is required to sign in. Reconnect and try again.',
      );
      return;
    }
    final isValid = _loginFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      await _showMessage('Please fill in all fields');
      return;
    }

    setState(() => _loading = true);
    try {
      // Sign in with email and password
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _loginEmail.text.trim(),
            password: _loginPassword.text.trim(),
          );

      // Verify that the selected role matches the user's actual role in database
      final user = userCredential.user;
      if (user != null) {
        final profile = await _loadOrRecoverProfile(user);

        if (profile == null) {
          await FirebaseAuth.instance.signOut();
          await _showMessage('User profile not found. Please sign up first.');
          if (mounted) setState(() => _loading = false);
          return;
        }

        // Check if account is approved
        if (profile.isPendingApproval) {
          await FirebaseAuth.instance.signOut();
          await _showMessage(
            'Your account is pending admin approval. Please wait for verification.',
          );
          if (mounted) setState(() => _loading = false);
          return;
        }

        if (profile.isRejected) {
          await FirebaseAuth.instance.signOut();
          await _showMessage(
            'Your account has been rejected. Contact administrator for details.',
          );
          if (mounted) setState(() => _loading = false);
          return;
        }

        if (profile.isInactive) {
          await FirebaseAuth.instance.signOut();
          await _showMessage(
            'Your account is inactive. Contact administrator to restore access.',
          );
          if (mounted) setState(() => _loading = false);
          return;
        }

        if (profile.role != _loginRole.value) {
          // Role mismatch - user tried to login with wrong role
          await FirebaseAuth.instance.signOut();
          await _showMessage(
            'Role mismatch! Your actual role is "${profile.role}" but you selected "${_loginRole.value}". Please select the correct role.',
          );
          if (mounted) setState(() => _loading = false);
          return;
        }

        await _userProfileService.cacheOfflineReporterSession(
          profile: profile,
          user: user,
        );

        // Account verified and active - close dialog and proceed
        if (mounted) {
          // CLEAR all snackbars before moving to the next screen
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          Navigator.of(context).pop();
        }
      }
    } on FormatException catch (e) {
      await FirebaseAuth.instance.signOut();
      await _showMessage(e.message);
      if (mounted) setState(() => _loading = false);
    } on FirebaseAuthException catch (e) {
      await _showMessage(e.message ?? 'Sign in failed');
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      await _showMessage('Sign in failed');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<UserProfile?> _loadOrRecoverProfile(User user) async {
    try {
      return await _userProfileService.fetchProfile(user.uid);
    } on FormatException catch (error) {
      if (error.message != 'User profile is missing a role.') {
        rethrow;
      }

      final recovered = await _attemptProfileRecovery(user);
      if (!recovered) {
        rethrow;
      }

      return _userProfileService.fetchProfile(user.uid);
    }
  }

  Future<bool> _attemptProfileRecovery(User user) async {
    final selectedRole = _loginRole.value.toLowerCase();
    if (selectedRole != 'reporter' && selectedRole != 'supervisor') {
      return false;
    }

    final userRef = FirebaseDatabase.instance.ref().child('users').child(user.uid);
    final snapshot = await userRef.get();

    Map<String, dynamic> existing = <String, dynamic>{};
    if (snapshot.exists && snapshot.value != null) {
      final rawValue = snapshot.value;
      if (rawValue is! Map<Object?, Object?>) {
        return false;
      }
      existing = Map<String, dynamic>.from(rawValue);
    }

    final existingRole = existing['role']?.toString().trim().toLowerCase() ?? '';
    if (existingRole.isNotEmpty && existingRole != selectedRole) {
      return false;
    }

    final existingStatus = existing['status']?.toString().trim().toLowerCase() ?? '';
    final status = existingStatus.isNotEmpty ? existingStatus : 'pending_approval';
    final createdAt =
        existing['createdAt']?.toString().trim().isNotEmpty == true
            ? existing['createdAt'].toString()
            : DateTime.now().toIso8601String();

    final nameParts = _deriveNameParts(
      existing['firstName']?.toString(),
      existing['lastName']?.toString(),
      user.displayName,
    );

    final repairedProfile = <String, Object?>{
      'firstName': nameParts.$1,
      'lastName': nameParts.$2,
      'email': existing['email']?.toString().trim().isNotEmpty == true
          ? existing['email'].toString()
          : (user.email ?? _loginEmail.text.trim()),
      'role': selectedRole,
      'status': status,
      'createdAt': createdAt,
    };

    try {
      await userRef.update(repairedProfile);
      return true;
    } catch (e) {
      debugPrint('Profile recovery failed for ${user.uid}: $e');
      return false;
    }
  }

  (String, String) _deriveNameParts(
    String? existingFirstName,
    String? existingLastName,
    String? displayName,
  ) {
    final firstName = existingFirstName?.trim() ?? '';
    final lastName = existingLastName?.trim() ?? '';
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return (firstName, lastName);
    }

    final normalizedDisplayName = displayName?.trim() ?? '';
    if (normalizedDisplayName.isEmpty) {
      return ('', '');
    }

    final parts = normalizedDisplayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return ('', '');
    }

    return (parts.first, parts.skip(1).join(' '));
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(text: _loginEmail.text);
    bool resetting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Reset Password',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your email address to receive a password reset link.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: resetting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: resetting
                  ? null
                  : () async {
                      if (emailController.text.isEmpty) {
                        _showMessage('Please enter your email');
                        return;
                      }
                      if (!await _hasConnection()) {
                        _showMessage(
                          'Internet is required to send a password reset email.',
                        );
                        return;
                      }
                      setDialogState(() => resetting = true);
                      try {
                        await FirebaseAuth.instance.sendPasswordResetEmail(
                          email: emailController.text.trim(),
                        );
                        if (context.mounted) Navigator.of(context).pop();
                        _showMessage(
                          'Password reset email sent. Please check your inbox.',
                          isError: false,
                        );
                      } catch (e) {
                        _showMessage(
                          'Failed to send reset email. Please try again.',
                        );
                      } finally {
                        if (context.mounted) {
                          setDialogState(() => resetting = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                shape: RoundedRectangleBorder(borderRadius: AppRadii.medium),
              ),
              child: resetting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send Reset Link'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Material(
              color: Theme.of(context).cardColor,
              elevation: 8,
              shadowColor: AppColors.textPrimary.withValues(alpha: 0.14),
              borderRadius: AppRadii.xl,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _loginFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.login, color: AppColors.info),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Login',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!_isOnline) ...[
                                const _OfflineAuthBanner(
                                  compact: true,
                                  message:
                                      'You are offline. Login requires internet access.',
                                ),
                                const SizedBox(height: 14),
                              ],
                              SlideTransition(
                                position:
                                    Tween<Offset>(
                                      begin: const Offset(-1, 0),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: _fieldController,
                                        curve: Curves.easeOutQuad,
                                      ),
                                    ),
                                child: FadeTransition(
                                  opacity: _fieldController,
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _loginEmail,
                                        decoration: InputDecoration(
                                          labelText: 'Email',
                                          prefixIcon: const Icon(Icons.email),
                                        ),
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: (value) =>
                                            value == null ||
                                                value.trim().isEmpty
                                            ? 'Email is required'
                                            : null,
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _loginPassword,
                                        obscureText: _obscurePassword,
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          prefixIcon: const Icon(Icons.lock),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
                                              });
                                            },
                                          ),
                                        ),
                                        validator: (value) =>
                                            value == null ||
                                                value.trim().isEmpty
                                            ? 'Password is required'
                                            : null,
                                        onFieldSubmitted: (_) {
                                          if (!_loading) {
                                            _signIn();
                                          }
                                        },
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _showForgotPasswordDialog,
                                          child: Text(
                                            'Forgot Password?',
                                            style: const TextStyle(
                                              color: AppColors.info,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ValueListenableBuilder<String>(
                                        valueListenable: _loginRole,
                                        builder: (context, value, _) {
                                          return DropdownButtonFormField<
                                            String
                                          >(
                                            initialValue: value,
                                            decoration: InputDecoration(
                                              labelText: 'Role',
                                              prefixIcon: const Icon(
                                                Icons.person,
                                              ),
                                            ),
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 16,
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'reporter',
                                                child: Text('Reporter'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'supervisor',
                                                child: Text('Supervisor'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'admin',
                                                child: Text('Admin'),
                                              ),
                                            ],
                                            onChanged: (v) {
                                              if (v != null) {
                                                _loginRole.value = v;
                                              }
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _loading ? null : _signIn,
                                  icon: _loading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Icon(Icons.login),
                                  label: Text(
                                    _loading ? 'Logging in...' : 'Login',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: AppRadii.medium,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignUpDialog extends StatefulWidget {
  final VoidCallback onBackToLogin;

  const _SignUpDialog({required this.onBackToLogin});

  @override
  State<_SignUpDialog> createState() => _SignUpDialogState();
}

class _SignUpDialogState extends State<_SignUpDialog>
    with TickerProviderStateMixin {
  static const String _adminSignupCode = String.fromEnvironment(
    'ADMIN_SIGNUP_CODE',
  );
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _fieldController;

  final _signUpFormKey = GlobalKey<FormState>();
  final _signFirstName = TextEditingController();
  final _signLastName = TextEditingController();
  final _signEmail = TextEditingController();
  final _signPassword = TextEditingController();
  final _adminCode = TextEditingController();
  final ValueNotifier<String> _signRole = ValueNotifier('reporter');
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureAdminCode = true;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fieldController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutQuad),
    );

    _scaleController.forward();
    _fieldController.forward();
    _initializeConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _scaleController.dispose();
    _fieldController.dispose();
    _signFirstName.dispose();
    _signLastName.dispose();
    _signEmail.dispose();
    _signPassword.dispose();
    _adminCode.dispose();
    _signRole.dispose();
    super.dispose();
  }

  Future<void> _initializeConnectivity() async {
    _isOnline = await _hasConnection();
    if (mounted) {
      setState(() {});
    }

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      _,
    ) async {
      final isOnline = await _hasConnection();
      if (!mounted) return;
      setState(() => _isOnline = isOnline);
    });
  }

  Future<bool> _hasConnection() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((item) => item != ConnectivityResult.none);
  }

  Future<void> _showMessage(String message, {bool isError = true}) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          isError ? Icons.error_outline : Icons.check_circle_outline,
          color: isError ? AppColors.error : AppColors.success,
          size: 32,
        ),
        title: Text(
          isError ? 'Error' : 'Success',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isError ? AppColors.error : AppColors.success,
              shape: RoundedRectangleBorder(borderRadius: AppRadii.small),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();
    if (!await _hasConnection()) {
      await _showMessage(
        'Internet is required to create an account. Reconnect and try again.',
      );
      return;
    }
    final isValid = _signUpFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      await _showMessage('Please fill in all fields');
      return;
    }

    if (_signPassword.text.length < 6) {
      await _showMessage('Password must be at least 6 characters');
      return;
    }

    final role = _signRole.value;

    // Validate admin code if registering as admin
    if (role == 'admin') {
      if (_adminCode.text.isEmpty) {
        await _showMessage('Admin code is required');
        return;
      }
      if (_adminSignupCode.isEmpty) {
        await _showMessage(
          'Admin sign-up is disabled in this build. Configure ADMIN_SIGNUP_CODE with --dart-define to enable it.',
        );
        return;
      }
      if (_adminCode.text.trim() != _adminSignupCode) {
        await _showMessage('Invalid admin code');
        return;
      }
    }

    setState(() => _loading = true);
    try {
      // Create user account
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _signEmail.text.trim(),
        password: _signPassword.text.trim(),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final first = _signFirstName.text.trim();
        final last = _signLastName.text.trim();

        // Update display name
        await user.updateDisplayName(
          (first.isNotEmpty || last.isNotEmpty) ? '$first $last' : null,
        );

        // Only admins can become active immediately.
        // Reporters and supervisors must wait for admin verification.
        final status = (role == 'admin') ? 'active' : 'pending_approval';

        // Keep a lightweight role directory readable to authenticated users
        // so reporters can notify approved supervisors without exposing
        // the full users collection.
        final updates = <String, Object?>{
          'users/${user.uid}': {
            'firstName': first,
            'lastName': last,
            'email': user.email,
            'role': role,
            'status': status,
            'createdAt': DateTime.now().toIso8601String(),
          },
        };
        if (status == 'active') {
          if (role == 'reporter') {
            updates['roleDirectory/reporters/${user.uid}'] = true;
          } else if (role == 'supervisor') {
            updates['roleDirectory/supervisors/${user.uid}'] = true;
          }
        }

        try {
          await FirebaseDatabase.instance.ref().update(updates);
        } catch (e) {
          debugPrint('Error saving profile: $e');

          // Avoid leaving behind an auth account with no database profile.
          try {
            await FirebaseDatabase.instance.ref().child('users').child(user.uid).remove();
          } catch (_) {}

          try {
            await user.delete();
          } on FirebaseAuthException catch (_) {
            await FirebaseAuth.instance.signOut();
          }

          await _showMessage(
            'Account created, but we could not finish setting up your profile. Please try signing up again.',
          );
          if (mounted) setState(() => _loading = false);
          return;
        }

        await UserProfileService().cacheOfflineReporterSession(
          profile: UserProfile(
            uid: user.uid,
            email: user.email ?? _signEmail.text.trim(),
            firstName: first,
            lastName: last,
            role: role,
            status: status,
            raw: {
              'firstName': first,
              'lastName': last,
              'email': user.email,
              'role': role,
              'status': status,
            },
          ),
          user: user,
        );

        // Close dialog immediately - profile save happens in background
        if (mounted) {
          // CLEAR snackbar on successful signup
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          Navigator.of(context).pop();
        }
      }
    } on FirebaseAuthException catch (e) {
      await _showMessage(e.message ?? 'Sign up failed');
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      await _showMessage('Sign up failed');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _backToLogin() {
    // Close signup dialog
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    // Show login dialog
    widget.onBackToLogin();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Material(
              color: Theme.of(context).cardColor,
              elevation: 8,
              shadowColor: AppColors.textPrimary.withValues(alpha: 0.14),
              borderRadius: AppRadii.xl,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: 0,
                ),
                child: Form(
                  key: _signUpFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person_add,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Sign Up',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: SingleChildScrollView(
                          reverse: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!_isOnline) ...[
                                const _OfflineAuthBanner(
                                  compact: true,
                                  message:
                                      'You are offline. Sign up requires internet access.',
                                ),
                                const SizedBox(height: 12),
                              ],
                              SlideTransition(
                                position:
                                    Tween<Offset>(
                                      begin: const Offset(-1, 0),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: _fieldController,
                                        curve: Curves.easeOutQuad,
                                      ),
                                    ),
                                child: FadeTransition(
                                  opacity: _fieldController,
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _signFirstName,
                                        decoration: InputDecoration(
                                          labelText: 'First name',
                                          prefixIcon: const Icon(Icons.person),
                                        ),
                                        validator: (value) =>
                                            value == null ||
                                                value.trim().isEmpty
                                            ? 'First name is required'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _signLastName,
                                        decoration: InputDecoration(
                                          labelText: 'Last name',
                                          prefixIcon: const Icon(Icons.person),
                                        ),
                                        validator: (value) =>
                                            value == null ||
                                                value.trim().isEmpty
                                            ? 'Last name is required'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _signEmail,
                                        decoration: InputDecoration(
                                          labelText: 'Email',
                                          prefixIcon: const Icon(Icons.email),
                                        ),
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: (value) =>
                                            value == null ||
                                                value.trim().isEmpty
                                            ? 'Email is required'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _signPassword,
                                        obscureText: _obscurePassword,
                                        decoration: InputDecoration(
                                          labelText: 'Password (6+ chars)',
                                          prefixIcon: const Icon(Icons.lock),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
                                              });
                                            },
                                          ),
                                        ),
                                        validator: (value) =>
                                            value == null ||
                                                value.trim().isEmpty
                                            ? 'Password is required'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      ValueListenableBuilder<String>(
                                        valueListenable: _signRole,
                                        builder: (context, value, _) {
                                          return DropdownButtonFormField<
                                            String
                                          >(
                                            initialValue: value,
                                            decoration: InputDecoration(
                                              labelText: 'Role',
                                              prefixIcon: const Icon(
                                                Icons.person,
                                              ),
                                            ),
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 16,
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'reporter',
                                                child: Text('Reporter'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'supervisor',
                                                child: Text('Supervisor'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'admin',
                                                child: Text('Admin'),
                                              ),
                                            ],
                                            onChanged: (v) {
                                              if (v != null) {
                                                _signRole.value = v;
                                              }
                                            },
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      ValueListenableBuilder<String>(
                                        valueListenable: _signRole,
                                        builder: (context, role, _) {
                                          if (role == 'admin') {
                                            return TextFormField(
                                              controller: _adminCode,
                                              obscureText: _obscureAdminCode,
                                              decoration: InputDecoration(
                                                labelText: 'Admin Code',
                                                helperText:
                                                    'Enter the build-configured admin code provided by the system owner',
                                                helperMaxLines: 2,
                                                prefixIcon: const Icon(
                                                  Icons.vpn_key,
                                                ),
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    _obscureAdminCode
                                                        ? Icons.visibility
                                                        : Icons.visibility_off,
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _obscureAdminCode =
                                                          !_obscureAdminCode;
                                                    });
                                                  },
                                                ),
                                              ),
                                              validator: (value) {
                                                if (role != 'admin') {
                                                  return null;
                                                }
                                                return value == null ||
                                                        value.trim().isEmpty
                                                    ? 'Admin code is required'
                                                    : null;
                                              },
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _loading ? null : _signUp,
                                  icon: _loading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Icon(Icons.person_add),
                                  label: Text(
                                    _loading
                                        ? 'Creating account...'
                                        : 'Sign Up',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: AppRadii.medium,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: _loading ? null : _backToLogin,
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                      ),
                                      children: [
                                        const TextSpan(
                                          text: 'Already have an account? ',
                                        ),
                                        WidgetSpan(
                                          child: const Text(
                                            'Login',
                                            style: TextStyle(
                                              color: AppColors.info,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: 20,
                              ), // Added extra space for better scrolling
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineAuthBanner extends StatelessWidget {
  final String message;
  final bool compact;

  const _OfflineAuthBanner({
    required this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontSize: compact ? 12 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
