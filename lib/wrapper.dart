import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'homepage.dart';
import 'login.dart';
import 'notification_service.dart';
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
  final NotificationService _notificationService = NotificationService();
  String? _notificationSetupForUid;
  String? _profileFutureUid;
  Future<Map<String, dynamic>?>? _profileFuture;
  static const String _sessionBoxName = 'user_session_cache';

  @override
  void initState() {
    super.initState();
    _splashFuture = Future.delayed(
      const Duration(milliseconds: 1500),
      () => true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _splashFuture,
      initialData: false,
      builder: (context, snapshot) {
        // 🔹 Splash Screen
        if (snapshot.data == false) {
          return SplashScreen(onComplete: () {});
        }

        // 🔹 Auth State
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          initialData: FirebaseAuth.instance.currentUser,
          builder: (context, authSnapshot) {
            final user = authSnapshot.data;

            // 🔹 If user not logged in
            if (user == null) {
              _notificationSetupForUid = null;
              return const LoginPage();
            }

            if (_notificationSetupForUid != user.uid) {
              _notificationSetupForUid = user.uid;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _notificationService.initializeNotifications();
              });
            }

            if (_profileFutureUid != user.uid || _profileFuture == null) {
              _profileFutureUid = user.uid;
              _profileFuture = _loadUserDataWithOfflineFallback(user.uid);
            }

            // 🔹 Fetch user data from Realtime DB
            return FutureBuilder<Map<String, dynamic>?>(
              future: _profileFuture,
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final userData = userSnapshot.data;
                if (userData == null) {
                  return _buildOfflineUnavailableScreen();
                }

                final role = userData['role'] as String?;
                final status =
                    userData['status'] as String? ?? 'pending_approval';

                if (role == null) {
                  return _buildOfflineUnavailableScreen();
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
                    message: 'Your account has been rejected. Contact support.',
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

  Future<Map<String, dynamic>?> _loadUserDataWithOfflineFallback(
    String uid,
  ) async {
    try {
      final event = await FirebaseDatabase.instance
          .ref('users/$uid')
          .once()
          .timeout(const Duration(seconds: 4));

      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) {
        return _loadCachedUserData(uid);
      }

      final userData = Map<String, dynamic>.from(
        snapshot.value as Map<Object?, Object?>,
      );
      await _cacheUserData(uid, userData);
      return userData;
    } catch (e) {
      debugPrint('Wrapper: remote profile load failed, using cache. $e');
      return _loadCachedUserData(uid);
    }
  }

  Future<Map<String, dynamic>?> _loadCachedUserData(String uid) async {
    try {
      final box = await _openSessionBox();
      final cached = box.get(uid);
      if (cached is Map) {
        return Map<String, dynamic>.from(cached.cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('Wrapper: cache read failed. $e');
    }
    return null;
  }

  Future<void> _cacheUserData(String uid, Map<String, dynamic> userData) async {
    try {
      final box = await _openSessionBox();
      await box.put(uid, {
        'role': userData['role'],
        'status': userData['status'],
      });
    } catch (e) {
      debugPrint('Wrapper: cache write failed. $e');
    }
  }

  Future<Box<dynamic>> _openSessionBox() async {
    if (Hive.isBoxOpen(_sessionBoxName)) {
      return Hive.box<dynamic>(_sessionBoxName);
    }
    return Hive.openBox<dynamic>(_sessionBoxName);
  }

  Widget _buildOfflineUnavailableScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 72, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Offline Mode Unavailable',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Connect to the internet once so profile data can be cached for offline dashboard access.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
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
              Text(message, textAlign: TextAlign.center),
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
