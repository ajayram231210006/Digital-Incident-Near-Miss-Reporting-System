import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutQuad));

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
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) => _LoginDialog(),
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
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
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
                          color: Colors.black.withOpacity(0.3),
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
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
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
                                      decoration: TextDecoration.underline,
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

class _LoginDialogState extends State<_LoginDialog> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _fieldController;

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

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.lime.shade400,
        duration: const Duration(seconds: 5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        elevation: 10,
      ),
    );
  }

  Future<void> _signIn() async {
    if (_loginEmail.text.isEmpty || _loginPassword.text.isEmpty) {
      await _showMessage('Please fill in all fields');
      return;
    }

    setState(() => _loading = true);
    try {
      // Sign in with email and password
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
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
          await _showMessage('Your account has been rejected. Contact administrator for details.');
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

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.login, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            const Text('Login', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: _fieldController, curve: Curves.easeOutQuad)),
                child: FadeTransition(
                  opacity: _fieldController,
                  child: Column(
                    children: [
                      TextField(
                        controller: _loginEmail,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.blue,
                              width: 2,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
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
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.blue,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ValueListenableBuilder<String>(
                        valueListenable: _loginRole,
                        builder: (context, value, _) {
                          return DropdownButtonFormField<String>(
                            value: value,
                            decoration: InputDecoration(
                              labelText: 'Role',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.blue,
                                  width: 2,
                                ),
                              ),
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
                              if (v != null) _loginRole.value = v;
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.login),
                  label: Text(_loading ? 'Logging in...' : 'Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
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

class _SignUpDialogState extends State<_SignUpDialog> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _fieldController;

  final _signFirstName = TextEditingController();
  final _signLastName = TextEditingController();
  final _signEmail = TextEditingController();
  final _signPassword = TextEditingController();
  final _adminCode = TextEditingController();
  final ValueNotifier<String> _signRole = ValueNotifier('reporter');
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
    _signFirstName.dispose();
    _signLastName.dispose();
    _signEmail.dispose();
    _signPassword.dispose();
    _adminCode.dispose();
    _signRole.dispose();
    super.dispose();
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.lime.shade400,
        duration: const Duration(seconds: 5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        elevation: 10,
      ),
    );
  }

  Future<void> _signUp() async {
    if (_signFirstName.text.isEmpty ||
        _signLastName.text.isEmpty ||
        _signEmail.text.isEmpty ||
        _signPassword.text.isEmpty) {
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
      const validAdminCode = 'ADMIN_SETUP_2024'; // Change this to your secret code
      if (_adminCode.text.trim() != validAdminCode) {
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

        // Determine account status based on role
        // Reporters & Admins are auto-approved, supervisors need admin approval
        final status = (role == 'supervisor') ? 'pending_approval' : 'active';

        // Save user profile to database (non-blocking)
        FirebaseDatabase.instance.ref('users/${user.uid}').set({
          'firstName': first,
          'lastName': last,
          'email': user.email,
          'role': role,
          'status': status,
          'createdAt': DateTime.now().toIso8601String(),
        }).catchError((e) {
          print('Error saving profile: $e');
        });

        // Close dialog immediately - profile save happens in background
        if (mounted) {
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
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.person_add, color: Colors.green.shade700),
            const SizedBox(width: 12),
            const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: _fieldController, curve: Curves.easeOutQuad)),
                child: FadeTransition(
                  opacity: _fieldController,
                  child: Column(
                    children: [
                      TextField(
                        controller: _signFirstName,
                        decoration: InputDecoration(
                          labelText: 'First name',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.green,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _signLastName,
                        decoration: InputDecoration(
                          labelText: 'Last name',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.green,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _signEmail,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.green,
                              width: 2,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
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
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.green,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<String>(
                        valueListenable: _signRole,
                        builder: (context, value, _) {
                          return DropdownButtonFormField<String>(
                            value: value,
                            decoration: InputDecoration(
                              labelText: 'Role',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.green,
                                  width: 2,
                                ),
                              ),
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
                              if (v != null) _signRole.value = v;
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<String>(
                        valueListenable: _signRole,
                        builder: (context, role, _) {
                          if (role == 'admin') {
                            return TextField(
                              controller: _adminCode,
                              decoration: InputDecoration(
                                labelText: 'Admin Code',
                                helperText: 'Enter the admin setup code (contact system owner)',
                                prefixIcon: const Icon(Icons.vpn_key),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.green,
                                    width: 2,
                                  ),
                                ),
                              ),
                              obscureText: true,
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.person_add),
                  label: Text(_loading ? 'Creating account...' : 'Sign Up'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                      style: const TextStyle(color: Colors.black54, fontSize: 14),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
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
            ],
          ),
        ),
      ),
    );
  }
}
