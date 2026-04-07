import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

Future<bool> _isOnline() async {
  try {
    final result = await InternetAddress.lookup(
      'one.one.one.one',
    ).timeout(const Duration(seconds: 3));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

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
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
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
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => _SignUpDialog(onBackToLogin: _showLoginDialog),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade900,
              Colors.deepPurple.shade600,
              Colors.blue.shade400,
            ],
          ),
        ),
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
                        colors: [Colors.white, Colors.blue.shade100],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.security_outlined,
                      size: 50,
                      color: Colors.deepPurple,
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
                  const Text(
                    'Secure Reporting Platform',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 50),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _showLoginDialog,
                          icon: const Icon(Icons.login, size: 20),
                          label: const Text('Open Login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                                    style: TextStyle(
                                      color: Colors.cyan.shade200,
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
  bool _loading = false;
  bool _obscurePassword = true;

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
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fieldController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _loginRole.dispose();
    super.dispose();
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
          color: isError ? Colors.red.shade700 : Colors.green.shade600,
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
              backgroundColor: isError
                  ? Colors.red.shade700
                  : Colors.green.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
    final isValid = _loginFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      await _showMessage('Please fill in all fields');
      return;
    }

    final online = await _isOnline();
    if (!online) {
      await _showMessage(
        'You are offline. Please connect to the internet to login.',
      );
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
        final userSnapshot = await FirebaseDatabase.instance
            .ref('users/${user.uid}')
            .get();

        if (!userSnapshot.exists) {
          // User profile not found
          await FirebaseAuth.instance.signOut();
          await _showMessage('User profile not found. Please sign up first.');
          if (mounted) setState(() => _loading = false);
          return;
        }

        final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
        final actualRole = userData['role'] as String?;
        final status = userData['status'] as String? ?? 'pending_approval';

        if (actualRole == null) {
          await FirebaseAuth.instance.signOut();
          await _showMessage('Invalid user profile. Please sign up again.');
          if (mounted) setState(() => _loading = false);
          return;
        }

        // Check if account is approved
        if (status == 'pending_approval') {
          await FirebaseAuth.instance.signOut();
          await _showMessage(
            'Your account is pending admin approval. Please wait for verification.',
          );
          if (mounted) setState(() => _loading = false);
          return;
        }

        if (status == 'rejected') {
          await FirebaseAuth.instance.signOut();
          await _showMessage(
            'Your account has been rejected. Contact administrator for details.',
          );
          if (mounted) setState(() => _loading = false);
          return;
        }

        if (actualRole != _loginRole.value) {
          // Role mismatch - user tried to login with wrong role
          await FirebaseAuth.instance.signOut();
          await _showMessage(
            'Role mismatch! Your actual role is "$actualRole" but you selected "${_loginRole.value}". Please select the correct role.',
          );
          if (mounted) setState(() => _loading = false);
          return;
        }

        // Account verified and active - close dialog and proceed
        if (mounted) {
          // CLEAR all snackbars before moving to the next screen
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          Navigator.of(context).pop();
        }
      }
    } on FirebaseAuthException catch (e) {
      await _showMessage(e.message ?? 'Sign in failed');
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      await _showMessage('Sign in failed');
      if (mounted) setState(() => _loading = false);
    }
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
                        if (context.mounted)
                          setDialogState(() => resetting = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _loginFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.login, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Login',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.close,
                              color: Colors.grey.shade600,
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
                                          filled: true,
                                          fillColor:
                                              Theme.of(context).brightness ==
                                                  Brightness.light
                                              ? Colors.grey[100]
                                              : Colors.grey[800],
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
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
                                          filled: true,
                                          fillColor:
                                              Theme.of(context).brightness ==
                                                  Brightness.light
                                              ? Colors.grey[100]
                                              : Colors.grey[800],
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide.none,
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
                                            style: TextStyle(
                                              color: Colors.blue.shade700,
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
                                              filled: true,
                                              fillColor:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.light
                                                  ? Colors.grey[100]
                                                  : Colors.grey[800],
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: BorderSide.none,
                                              ),
                                            ),
                                            style: TextStyle(
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.light
                                                  ? Colors.grey.shade700
                                                  : Colors.grey.shade300,
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
                                              if (v != null)
                                                _loginRole.value = v;
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
                                      borderRadius: BorderRadius.circular(12),
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
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureAdminCode = true;

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
  }

  @override
  void dispose() {
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

  Future<void> _showMessage(String message, {bool isError = true}) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          isError ? Icons.error_outline : Icons.check_circle_outline,
          color: isError ? Colors.red.shade700 : Colors.green.shade600,
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
              backgroundColor: isError
                  ? Colors.red.shade700
                  : Colors.green.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
      // Check if admin code is valid (you should replace this with your actual admin code)
      const validAdminCode =
          'ADMIN_SETUP_2024'; // Change this to your secret code
      if (_adminCode.text.trim() != validAdminCode) {
        await _showMessage('Invalid admin code');
        return;
      }
    }

    final online = await _isOnline();
    if (!online) {
      await _showMessage(
        'You are offline. Please connect to the internet to register.',
      );
      return;
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

        // Determine account status based on role
        // Reporters & Admins are auto-approved, supervisors need admin approval
        final status = (role == 'supervisor') ? 'pending_approval' : 'active';

        // Save user profile to database (non-blocking)
        FirebaseDatabase.instance
            .ref('users/${user.uid}')
            .set({
              'firstName': first,
              'lastName': last,
              'email': user.email,
              'role': role,
              'status': status,
              'createdAt': DateTime.now().toIso8601String(),
            })
            .catchError((e) {
              debugPrint('Error saving profile: $e');
            });

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
              borderRadius: BorderRadius.circular(20),
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
                          Icon(Icons.person_add, color: Colors.green.shade700),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.close,
                              color: Colors.grey.shade600,
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
                                          filled: true,
                                          fillColor:
                                              Theme.of(context).brightness ==
                                                  Brightness.light
                                              ? Colors.grey[100]
                                              : Colors.grey[800],
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
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
                                          filled: true,
                                          fillColor:
                                              Theme.of(context).brightness ==
                                                  Brightness.light
                                              ? Colors.grey[100]
                                              : Colors.grey[800],
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
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
                                          filled: true,
                                          fillColor:
                                              Theme.of(context).brightness ==
                                                  Brightness.light
                                              ? Colors.grey[100]
                                              : Colors.grey[800],
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
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
                                          filled: true,
                                          fillColor:
                                              Theme.of(context).brightness ==
                                                  Brightness.light
                                              ? Colors.grey[100]
                                              : Colors.grey[800],
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide.none,
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
                                              filled: true,
                                              fillColor:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.light
                                                  ? Colors.grey[100]
                                                  : Colors.grey[800],
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: BorderSide.none,
                                              ),
                                            ),
                                            style: TextStyle(
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.light
                                                  ? Colors.grey.shade700
                                                  : Colors.grey.shade300,
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
                                              if (v != null)
                                                _signRole.value = v;
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
                                                    'Enter the admin setup code (contact system owner)',
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
                                                filled: true,
                                                fillColor:
                                                    Theme.of(
                                                          context,
                                                        ).brightness ==
                                                        Brightness.light
                                                    ? Colors.grey[100]
                                                    : Colors.grey[800],
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  borderSide: BorderSide.none,
                                                ),
                                              ),
                                              validator: (value) {
                                                if (role != 'admin')
                                                  return null;
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
                                      borderRadius: BorderRadius.circular(12),
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
                                        color: Colors.black54,
                                        fontSize: 14,
                                      ),
                                      children: [
                                        const TextSpan(
                                          text: 'Already have an account? ',
                                        ),
                                        WidgetSpan(
                                          child: Text(
                                            'Login',
                                            style: TextStyle(
                                              color: Colors.blue.shade700,
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
