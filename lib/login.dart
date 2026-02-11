import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  final _signEmail = TextEditingController();
  final _signPassword = TextEditingController();
  final _signFirstName = TextEditingController();
  final _signLastName = TextEditingController();
  final ValueNotifier<String> _loginRole = ValueNotifier('reporter');
  final ValueNotifier<String> _signRole = ValueNotifier('reporter');
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _signEmail.dispose();
    _signPassword.dispose();
    _signFirstName.dispose();
    _signLastName.dispose();
    _loginRole.dispose();
    _signRole.dispose();
    super.dispose();
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _loginEmail.text.trim(),
        password: _loginPassword.text.trim(),
      );
      // Enforce role: compare stored role in Realtime Database with selected role
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final ref = FirebaseDatabase.instance.ref('users/${user.uid}/role');
        final snapshot = await ref.get();
        if (!snapshot.exists) {
          await FirebaseAuth.instance.signOut();
          await _showMessage('No user profile found. Please sign up first.');
          return;
        }
        final storedRole = snapshot.value as String?;
        if (storedRole != null && storedRole != _loginRole.value) {
          await FirebaseAuth.instance.signOut();
          await _showMessage(
            'Role mismatch: your account is registered as "$storedRole". Please select that role to login.',
          );
          return;
        }
      }
    } on FirebaseAuthException catch (e) {
      await _showMessage(e.message ?? 'Sign in failed');
    } catch (e) {
      await _showMessage('Sign in failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _signEmail.text.trim(),
        password: _signPassword.text.trim(),
      );
      // Update the user's display name with first + last name and persist role to Realtime Database
      final user = FirebaseAuth.instance.currentUser;
      final first = _signFirstName.text.trim();
      final last = _signLastName.text.trim();
      final role = _signRole.value;
      if (user != null) {
        await user.updateDisplayName(
          (first.isNotEmpty || last.isNotEmpty) ? '$first $last' : null,
        );
        await FirebaseDatabase.instance.ref('users/${user.uid}').set({
          'firstName': first,
          'lastName': last,
          'email': user.email,
          'role': role,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      await _showMessage('Account created. You are now signed in.');
    } on FirebaseAuthException catch (e) {
      await _showMessage(e.message ?? 'Sign up failed');
    } catch (e) {
      await _showMessage('Sign up failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildLoginTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _loginEmail,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _loginPassword,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: _loginRole,
            builder: (context, value, _) {
              return DropdownButtonFormField<String>(
                initialValue: value,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'reporter', child: Text('Reporter')),
                  DropdownMenuItem(
                    value: 'supervisor',
                    child: Text('Supervisor'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) _loginRole.value = v;
                },
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _signIn,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Login'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _signFirstName,
            decoration: const InputDecoration(labelText: 'First name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _signLastName,
            decoration: const InputDecoration(labelText: 'Last name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _signEmail,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _signPassword,
            decoration: const InputDecoration(labelText: 'Password (6+ chars)'),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: _signRole,
            builder: (context, value, _) {
              return DropdownButtonFormField<String>(
                initialValue: value,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'reporter', child: Text('Reporter')),
                  DropdownMenuItem(
                    value: 'supervisor',
                    child: Text('Supervisor'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) _signRole.value = v;
                },
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _signUp,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Create account'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authenticate'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Login'),
            Tab(text: 'Sign Up'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(child: _buildLoginTab()),
          SingleChildScrollView(child: _buildSignUpTab()),
        ],
      ),
    );
  }
}
