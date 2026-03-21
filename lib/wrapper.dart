import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'homepage.dart';
import 'login.dart';
import 'splash_screen.dart';
import 'reporter_dashboard.dart';
import 'supervisor_dashboard.dart';

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
    // Create a future that completes after splash screen duration
    _splashFuture = Future.delayed(const Duration(seconds: 3), () => true);
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
              // This will be called but splash screen auto-closes after 3 seconds
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
              // Fetch role from Realtime Database
              return FutureBuilder<DatabaseEvent>(
                future: FirebaseDatabase.instance
                    .ref('users/${user.uid}/role')
                    .once(),
                builder: (context, roleSnapshot) {
                  if (roleSnapshot.connectionState == ConnectionState.waiting) {
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

                  if (roleSnapshot.hasError) {
                    // Error fetching role - sign out and return to login
                    FirebaseAuth.instance.signOut();
                    return const LoginPage();
                  }

                  final role = roleSnapshot.data?.snapshot.value as String?;

                  // If no profile found, sign out
                  if (role == null) {
                    FirebaseAuth.instance.signOut();
                    return const LoginPage();
                  }

                  // Show appropriate dashboard based on role
                  if (role == 'reporter') {
                    return ReporterDashboard(user: user);
                  } else if (role == 'supervisor') {
                    return SupervisorDashboard(user: user);
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
