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
                        eyebrow: 'Connection issue',
                        steps: const [
                          'Check your internet connection.',
                          'Tap refresh to retry account verification.',
                          'Use logout if you want to switch accounts.',
                        ],
                        primaryActionLabel: 'Refresh',
                        onPrimaryAction: _refreshStatusScreen,
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
                        eyebrow: 'Setup incomplete',
                        steps: const [
                          'Reconnect to the internet.',
                          'Try refreshing this screen once.',
                          'If it still fails, sign out and sign in again.',
                        ],
                        primaryActionLabel: 'Refresh',
                        onPrimaryAction: _refreshStatusScreen,
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
                            'Your ${profile.role.toUpperCase()} account has been created and is now waiting for admin approval.',
                        color: AppColors.statusOpen,
                        eyebrow: 'Sign-up complete',
                        highlights: [
                          'Signed in as ${profile.displayName}',
                          profile.email,
                        ],
                        steps: [
                          'An administrator will review your account request.',
                          'Once approved, this screen will automatically stop appearing the next time you open the app.',
                          'If you signed up with the wrong details, log out and create the correct account.',
                        ],
                        primaryActionLabel: 'Refresh Status',
                        onPrimaryAction: _refreshStatusScreen,
                        showLogout: true,
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
                        eyebrow: 'Action needed',
                        steps: const [
                          'Contact your administrator or support team.',
                          'Confirm that your submitted role and details were correct.',
                          'Sign out if you need to register with different information.',
                        ],
                        showLogout: true,
                      );
                    }

                    if (profile.isInactive) {
                      return _buildStatusScreen(
                        icon: Icons.pause_circle_outline,
                        title: 'Account Inactive',
                        message:
                            'Your account is inactive. Contact an administrator to restore access.',
                        color: AppColors.textSecondary,
                        eyebrow: 'Access paused',
                        steps: const [
                          'Ask an administrator to reactivate your account.',
                          'Refresh this screen after your access has been restored.',
                        ],
                        primaryActionLabel: 'Refresh',
                        onPrimaryAction: _refreshStatusScreen,
                        showLogout: true,
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

  void _refreshStatusScreen() {
    if (!mounted) return;
    setState(() {});
  }

  // 🔥 Reusable UI for status screens
  Widget _buildStatusScreen({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
    String? eyebrow,
    List<String> highlights = const [],
    List<String> steps = const [],
    String? primaryActionLabel,
    VoidCallback? onPrimaryAction,
    bool showLogout = false,
  }) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.xl,
                  boxShadow: AppShadows.subtle,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.18),
                            color.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (eyebrow != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.72),
                                borderRadius: AppRadii.pill,
                              ),
                              child: Text(
                                eyebrow,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, size: 36, color: color),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      message,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (highlights.isNotEmpty) ...[
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: highlights
                                  .where((item) => item.trim().isNotEmpty)
                                  .map(
                                    (item) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceRaised,
                                        borderRadius: AppRadii.large,
                                        border: Border.all(
                                          color: AppColors.outline,
                                        ),
                                      ),
                                      child: Text(
                                        item,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (steps.isNotEmpty) ...[
                            Text(
                              'What happens next',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 14),
                            for (int i = 0; i < steps.length; i++) ...[
                              _StatusStep(
                                number: i + 1,
                                text: steps[i],
                                color: color,
                              ),
                              if (i != steps.length - 1)
                                const SizedBox(height: 12),
                            ],
                            const SizedBox(height: 28),
                          ],
                          Row(
                            children: [
                              if (primaryActionLabel != null &&
                                  onPrimaryAction != null)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: onPrimaryAction,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: Text(primaryActionLabel),
                                  ),
                                ),
                              if (primaryActionLabel != null &&
                                  onPrimaryAction != null &&
                                  showLogout)
                                const SizedBox(width: 12),
                              if (showLogout)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final currentUser =
                                          FirebaseAuth.instance.currentUser;
                                      if (currentUser != null) {
                                        await _userProfileService
                                            .clearCachedProfile(currentUser.uid);
                                      }
                                      await FirebaseAuth.instance.signOut();
                                    },
                                    icon: const Icon(Icons.logout),
                                    label: const Text('Logout'),
                                  ),
                                ),
                            ],
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
      ),
    );
  }
}

class _StatusStep extends StatelessWidget {
  final int number;
  final String text;
  final Color color;

  const _StatusStep({
    required this.number,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
