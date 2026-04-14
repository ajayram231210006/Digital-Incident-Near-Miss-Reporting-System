import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'app_theme.dart';

import 'homepage.dart';
import 'login.dart';
import 'notification_service.dart';
import 'offline_reporter_home.dart';
import 'splash_screen.dart';
import 'reporter_dashboard.dart';
import 'reporter_identity.dart';
import 'supervisor_dashboard.dart';
import 'admin_dashboard.dart';
import 'user_profile_service.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  late Future<bool> _splashFuture;
  final NotificationService _notificationService = NotificationService();
  final UserProfileService _userProfileService = UserProfileService();
  final Connectivity _connectivity = Connectivity();
  String? _notificationSetupForUid;
  String? _roleDirectorySyncedUid;

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

        return FutureBuilder<bool>(
          future: _isOnline(),
          builder: (context, onlineSnapshot) {
            if (onlineSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final isOnline = onlineSnapshot.data ?? false;
            if (!isOnline) {
              return FutureBuilder<ReporterIdentity?>(
                future: _userProfileService.getOfflineReporterSession(),
                builder: (context, sessionSnapshot) {
                  if (sessionSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final reporter = sessionSnapshot.data;
                  if (reporter != null) {
                    return OfflineReporterHome(reporter: reporter);
                  }

                  return const LoginPage();
                },
              );
            }

            // 🔹 Auth State
            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              initialData: FirebaseAuth.instance.currentUser,
              builder: (context, authSnapshot) {
                if (authSnapshot.connectionState == ConnectionState.waiting &&
                    authSnapshot.data == null) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final user = authSnapshot.data;

                // 🔹 If user not logged in
                if (user == null) {
                  _notificationSetupForUid = null;
                  _roleDirectorySyncedUid = null;
                  return const LoginPage();
                }

                if (_notificationSetupForUid != user.uid) {
                  _notificationSetupForUid = user.uid;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _notificationService.initializeNotifications();
                  });
                }

                // 🔹 Fetch user data from Realtime DB
                return FutureBuilder<UserProfile?>(
                  future: _resolveProfile(user.uid),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (userSnapshot.hasError) {
                      debugPrint("Database Error: ${userSnapshot.error}");
                      return _buildStatusScreen(
                        icon: Icons.wifi_off_rounded,
                        title: 'Unable To Load Account',
                        message:
                            'We could not verify your account details right now. Reconnect to continue.',
                        color: AppColors.warning,
                        showLogout: true,
                      );
                    }

                    final profile = userSnapshot.data;
                    if (profile == null) {
                      return _buildStatusScreen(
                        icon: Icons.wifi_off_rounded,
                        title: 'Profile Unavailable',
                        message:
                            'Your account details are not available on this device yet. Connect to the internet and sign in once to continue.',
                        color: AppColors.warning,
                        showLogout: true,
                      );
                    }

                    if (!profile.isInactive &&
                        !profile.isPendingApproval &&
                        !profile.isRejected &&
                        _roleDirectorySyncedUid != user.uid) {
                      _roleDirectorySyncedUid = user.uid;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _syncRoleDirectoryEntry(user.uid, profile);
                      });
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _userProfileService.cacheOfflineReporterSession(
                        profile: profile,
                        user: user,
                      );
                    });

                    // 🔹 Pending Approval
                    if (profile.isPendingApproval) {
                      return _buildStatusScreen(
                        icon: Icons.hourglass_empty,
                        title: 'Account Pending Approval',
                        message:
                            'Your ${profile.role.toUpperCase()} account is awaiting admin approval.',
                        color: AppColors.statusOpen,
                      );
                    }

                    // 🔹 Rejected
                    if (profile.isRejected) {
                      return _buildStatusScreen(
                        icon: Icons.block,
                        title: 'Account Rejected',
                        message:
                            'Your account has been rejected. Contact support.',
                        color: AppColors.error,
                      );
                    }

                    if (profile.isInactive) {
                      return _buildStatusScreen(
                        icon: Icons.pause_circle_outline,
                        title: 'Account Inactive',
                        message:
                            'Your account is inactive. Contact an administrator to restore access.',
                        color: AppColors.textSecondary,
                      );
                    }

                    // 🔹 Role-based navigation
                    switch (profile.role) {
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
      },
    );
  }

  Future<UserProfile?> _resolveProfile(String uid) async {
    try {
      return await _userProfileService.fetchProfile(uid);
    } catch (error) {
      final isOnline = await _isOnline();
      final cachedProfile = await _userProfileService.getCachedProfile(uid);

      if (!isOnline &&
          cachedProfile != null &&
          !cachedProfile.isInactive &&
          !cachedProfile.isPendingApproval &&
          !cachedProfile.isRejected) {
        if (cachedProfile.role == 'reporter') {
          return cachedProfile;
        }

        throw Exception(
          'Offline access is currently available only for reporter accounts.',
        );
      }

      if (cachedProfile != null && !isOnline) {
        return cachedProfile;
      }

      rethrow;
    }
  }

  Future<bool> _isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.any((item) => item != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncRoleDirectoryEntry(String uid, UserProfile profile) async {
    try {
      final normalizedRole = profile.role.toLowerCase();
      if (normalizedRole != 'reporter' && normalizedRole != 'supervisor') {
        return;
      }

      final directoryRef = FirebaseDatabase.instance.ref().child(
        'roleDirectory/${normalizedRole == 'reporter' ? 'reporters' : 'supervisors'}/$uid',
      );
      await directoryRef.set(true);
    } catch (e) {
      debugPrint('Role directory sync skipped for $uid: $e');
    }
  }

  // 🔥 Reusable UI for status screens
  Widget _buildStatusScreen({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
    bool showLogout = false,
  }) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.xl,
                boxShadow: AppShadows.subtle,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 44, color: color),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (showLogout)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final currentUser = FirebaseAuth.instance.currentUser;
                        if (currentUser != null) {
                          await _userProfileService.clearCachedProfile(
                            currentUser.uid,
                          );
                        }
                        await FirebaseAuth.instance.signOut();
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
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
