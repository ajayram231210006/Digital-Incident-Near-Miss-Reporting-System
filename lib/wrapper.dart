import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'homepage.dart';
import 'login.dart';
import 'splash_screen.dart';
import 'reporter_dashboard.dart';
import 'supervisor_dashboard.dart';
import 'admin_dashboard.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  late Future<bool> _splashFuture;

  @override
  void initState() {
    super.initState();
    // Create a future that completes after splash screen duration (reduced to 2 seconds)
    _splashFuture = Future.delayed(const Duration(milliseconds: 1500), () => true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _splashFuture,
      initialData: false,
      builder: (context, snapshot) {
        // Show splash screen while it's loading or initial state
        if (snapshot.data == false) {
          return SplashScreen(
            onComplete: () {
              // This will be called but splash screen auto-closes after 1.5 seconds
            },
          );
        }

        // Show auth state after splash completes
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (authSnapshot.hasData) {
              final user = authSnapshot.data!;
              // Fetch entire user profile from Realtime Database
              return FutureBuilder<DatabaseEvent>(
                future: FirebaseDatabase.instance
                    .ref('users/${user.uid}')
                    .once(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
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
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                              SizedBox(height: 20),
                              Text(
                                'Loading Dashboard...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (userSnapshot.hasError) {
                    // Error fetching user data - sign out and return to login
                    FirebaseAuth.instance.signOut();
                    return const LoginPage();
                  }

                  if (!userSnapshot.data!.snapshot.exists) {
                    // User profile not found - sign out
                    FirebaseAuth.instance.signOut();
                    return const LoginPage();
                  }

                  final userData = Map<String, dynamic>.from(
                    userSnapshot.data!.snapshot.value as Map,
                  );
                  final role = userData['role'] as String?;
                  final status = userData['status'] as String? ?? 'pending_approval';

                  if (role == null) {
                    FirebaseAuth.instance.signOut();
                    return const LoginPage();
                  }

                  // Check account status
                  if (status == 'pending_approval') {
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
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.hourglass_empty,
                                  size: 80,
                                  color: Colors.orange.shade400,
                                ),
                                const SizedBox(height: 30),
                                Text(
                                  'Account Pending Approval',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Your ${role.toUpperCase()} account is awaiting admin verification and approval.\n\nPlease wait for your account to be activated.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 40),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await FirebaseAuth.instance.signOut();
                                  },
                                  icon: const Icon(Icons.logout),
                                  label: const Text('Logout'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  if (status == 'rejected') {
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
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.block,
                                  size: 80,
                                  color: Colors.red.shade400,
                                ),
                                const SizedBox(height: 30),
                                Text(
                                  'Account Rejected',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Your account registration has been rejected by the administrator.\n\nPlease contact support for more information.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 40),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await FirebaseAuth.instance.signOut();
                                  },
                                  icon: const Icon(Icons.logout),
                                  label: const Text('Logout'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  // Show appropriate dashboard based on role
                  if (role == 'reporter') {
                    return ReporterDashboard(user: user);
                  } else if (role == 'supervisor') {
                    return SupervisorDashboard(user: user);
                  } else if (role == 'admin') {
                    return AdminDashboard(user: user);
                  }

                  return const HomePage();
                },
              );
            } else {
              return const LoginPage();
            }
          },
        );
      },
    );
  }
}
