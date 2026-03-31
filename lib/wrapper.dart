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
    _splashFuture =
        Future.delayed(const Duration(milliseconds: 1500), () => true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _splashFuture,
      initialData: false,
      builder: (context, snapshot) {
        // 🔹 Splash Screen
        if (snapshot.data == false) {
          return SplashScreen(
            onComplete: () {},
          );
        }

        // 🔹 Auth State
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final user = authSnapshot.data;

            // 🔹 If user not logged in
            if (user == null) {
              return const LoginPage();
            }

            // 🔹 Fetch user data from Realtime DB
            return FutureBuilder<DatabaseEvent>(
              future:
              FirebaseDatabase.instance.ref('users/${user.uid}').once(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (userSnapshot.hasError) {
                  debugPrint("Database Error: ${userSnapshot.error}");
                  FirebaseAuth.instance.signOut();
                  return const LoginPage();
                }

                final snapshotData = userSnapshot.data?.snapshot;

                // ❗ SAFE CHECK (CRITICAL FIX)
                if (snapshotData == null ||
                    !snapshotData.exists ||
                    snapshotData.value == null) {
                  FirebaseAuth.instance.signOut();
                  return const LoginPage();
                }

                Map<String, dynamic> userData;

                try {
                  userData = Map<String, dynamic>.from(
                    snapshotData.value as Map<Object?, Object?>,
                  );
                } catch (e) {
                  debugPrint("Data parsing error: $e");
                  FirebaseAuth.instance.signOut();
                  return const LoginPage();
                }

                final role = userData['role'] as String?;
                final status =
                    userData['status'] as String? ?? 'pending_approval';

                if (role == null) {
                  FirebaseAuth.instance.signOut();
                  return const LoginPage();
                }

                // 🔹 Pending Approval
                if (status == 'pending_approval') {
                  return _buildStatusScreen(
                    icon: Icons.hourglass_empty,
                    title: 'Account Pending Approval',
                    message:
                    'Your ${role.toUpperCase()} account is awaiting admin approval.',
                    color: Colors.orange,
                  );
                }

                // 🔹 Rejected
                if (status == 'rejected') {
                  return _buildStatusScreen(
                    icon: Icons.block,
                    title: 'Account Rejected',
                    message:
                    'Your account has been rejected. Contact support.',
                    color: Colors.red,
                  );
                }

                // 🔹 Role-based navigation
                switch (role) {
                  case 'reporter':
                    return ReporterDashboard(user: user);
                  case 'supervisor':
                    return SupervisorDashboard(user: user);
                  case 'admin':
                    return AdminDashboard(user: user);
                  default:
                    return const HomePage();
                }
              },
            );
          },
        );
      },
    );
  }

  // 🔥 Reusable UI for status screens
  Widget _buildStatusScreen({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: color),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
