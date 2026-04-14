import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'reporter.dart' show ReportIncidentForm;
import 'reporter_identity.dart';
import 'reporter_reports_list.dart';
import 'reporter_report_detail.dart';
import 'notifications_viewer.dart';
import 'notification_service.dart';
import 'offline_incident_queue_service.dart';
import 'reporter_trends_widget.dart';
import 'activity_timeline_widget.dart';
import 'report_templates_dialog.dart';
import 'performance_analytics_page.dart';
import 'system_reports_viewer.dart';
import 'app_theme.dart';
import 'ui_components.dart';
import 'user_profile_service.dart';

class ReporterDashboard extends StatefulWidget {
  final User user;
  const ReporterDashboard({super.key, required this.user});

  @override
  State<ReporterDashboard> createState() => _ReporterDashboardState();
}

class _ReporterDashboardState extends State<ReporterDashboard> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final NotificationService _notificationService = NotificationService();
  final OfflineIncidentQueueService _offlineQueueService =
      OfflineIncidentQueueService();
  final UserProfileService _userProfileService = UserProfileService();
  StreamSubscription<Map<String, dynamic>>? _notificationTapSubscription;
  StreamSubscription<int>? _badgeCountSubscription;
  StreamSubscription<bool>? _offlineStatusSubscription;
  StreamSubscription<int>? _offlinePendingSubscription;
  late final Stream<int> _unreadCountStream;
  bool _syncingOfflineReports = false;
  int _pendingOfflineReports = 0;

  @override
  void initState() {
    super.initState();
    _validateReporterAccess();
    _unreadCountStream = _notificationService
        .getUnreadNotificationCount(widget.user.uid)
        .asBroadcastStream();

    _initializeNotifications();
    _refreshOfflinePendingCount();
    unawaited(_syncOfflineReports(silent: true));
    _offlinePendingSubscription = _offlineQueueService
        .watchPendingCount(widget.user.uid)
        .listen((count) {
          if (!mounted) return;
          setState(() => _pendingOfflineReports = count);
        });
    _offlineStatusSubscription = _offlineQueueService.onlineStatusStream.listen(
      (isOnline) {
        if (!mounted) return;
        if (isOnline) {
          unawaited(_syncOfflineReports(silent: true));
        }
      },
    );
  }

  Future<void> _validateReporterAccess() async {
    try {
      final profile = await _userProfileService.fetchProfile(widget.user.uid);
      if (!mounted) return;

      final isValid =
          profile != null &&
          profile.role == 'reporter' &&
          !profile.isPendingApproval &&
          !profile.isRejected &&
          !profile.isInactive;

      if (!isValid) {
        showAppSnackBar(
          context,
          'Unauthorized: approved reporter access required.',
          type: AppSnackBarType.error,
        );
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {}
  }

  Future<void> _initializeNotifications() async {
    _notificationTapSubscription = _notificationService.notificationTapStream
        .listen((notificationData) {
          _handleNotificationTap(notificationData);
        });

    _badgeCountSubscription = _unreadCountStream.listen((count) {
      _notificationService.updateAppBadgeCount(count);
    });

    final pendingNotification = _notificationService
        .consumePendingLaunchNotification();
    if (pendingNotification != null && mounted) {
      _handleNotificationTap(pendingNotification);
    }
  }

  Future<void> _handleNotificationTap(
    Map<String, dynamic> notificationData,
  ) async {
    try {
      final reportId = notificationData['reportId'];
      if (reportId != null && reportId.toString().isNotEmpty && mounted) {
        // Fetch incident details
        final snapshot = await _dbRef
            .child('incidents')
            .child(reportId.toString())
            .get();
        if (snapshot.exists && mounted) {
          final reportData = Map<String, dynamic>.from(snapshot.value as Map);

          // Navigate to report detail
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ReporterReportDetail(
                reportId: reportId.toString(),
                report: reportData,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    _badgeCountSubscription?.cancel();
    _offlineStatusSubscription?.cancel();
    _offlinePendingSubscription?.cancel();
    _offlineQueueService.dispose();
    super.dispose();
  }

  Future<void> _refreshOfflinePendingCount() async {
    final count = await _offlineQueueService.getPendingCount(widget.user.uid);
    if (!mounted) return;
    setState(() => _pendingOfflineReports = count);
  }

  Future<void> _syncOfflineReports({bool silent = false}) async {
    if (_syncingOfflineReports) return;

    setState(() => _syncingOfflineReports = true);
    try {
      final synced = await _offlineQueueService.syncPendingReportsForUser(
        widget.user.uid,
      );
      await _refreshOfflinePendingCount();

      if (!mounted || silent || synced == 0) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            synced == 1
                ? '1 offline report was synced successfully.'
                : '$synced offline reports were synced successfully.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _syncingOfflineReports = false);
      }
    }
  }

  Stream<Map<String, int>> _getReportStatsStream() {
    return _dbRef.child('incidents').onValue.map((event) {
      if (!event.snapshot.exists) {
        return {'total': 0, 'open': 0, 'active': 0, 'approved': 0};
      }

      int total = 0;
      int open = 0;
      int active = 0;
      int approved = 0;

      final data = event.snapshot.value as Map?;
      if (data != null) {
        data.forEach((key, value) {
          if (value is Map) {
            final reporterUid = value['reporterUid']?.toString() ?? '';
            if (reporterUid == widget.user.uid) {
              total++;
              final status = (value['status'] ?? 'open')
                  .toString()
                  .toLowerCase();

              if (status == 'closed') {
                approved++;
              } else if (status == 'active') {
                active++;
              } else {
                open++;
              }
            }
          }
        });
      }

      return {
        'total': total,
        'open': open,
        'active': active,
        'approved': approved,
      };
    });
  }

  void _navigateToReports(BuildContext context, String filter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ReporterReportsList(user: widget.user, filterStatus: filter),
      ),
    );
  }

  void _openNewReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportIncidentForm(
          reporter: ReporterIdentity.fromFirebaseUser(widget.user),
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _openTemplates() {
    showDialog(
      context: context,
      builder: (context) => ReportTemplatesDialog(user: widget.user),
    );
  }

  void _openAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PerformanceAnalyticsPage(user: widget.user),
      ),
    );
  }

  void _openSystemReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SystemReportsViewer(user: widget.user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        actions: [
          StreamBuilder<int>(
            stream: _unreadCountStream,
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              NotificationsViewer(user: widget.user),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_outlined),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: AppRadii.pill,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              // Show confirmation dialog before logout
              final shouldLogout =
                  await showDialog<bool>(
                    context: context,
                    builder: (BuildContext dialogContext) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ) ??
                  false;

              if (shouldLogout && context.mounted) {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<Map<String, int>>(
        stream: _getReportStatsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final stats = snapshot.data ?? {};
          final totalReports = stats['total'] ?? 0;
          final openReports = stats['open'] ?? 0;
          final activeReports = stats['active'] ?? 0;
          final approvedReports = stats['approved'] ?? 0;
          final firstName =
              (widget.user.displayName ??
                      widget.user.email?.split('@').first ??
                      'Reporter')
                  .split(' ')
                  .first;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DashboardHero(
                  firstName: firstName,
                  totalReports: totalReports,
                  pendingReports: openReports,
                  onViewReports: () => _navigateToReports(context, 'all'),
                ),
                const SizedBox(height: 20),
                Text(
                  'Report overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.98,
                  children: [
                    _DashboardStatCard(
                      title: 'Total reports',
                      count: totalReports,
                      total: totalReports,
                      color: AppColors.primary,
                      icon: Icons.assignment_outlined,
                      hint: 'Everything you have submitted',
                      onTap: () => _navigateToReports(context, 'all'),
                    ),
                    _DashboardStatCard(
                      title: 'Pending review',
                      count: openReports,
                      total: totalReports,
                      color: AppColors.statusOpen,
                      icon: Icons.hourglass_top_rounded,
                      hint: 'Waiting for action',
                      onTap: () => _navigateToReports(context, 'open'),
                    ),
                    _DashboardStatCard(
                      title: 'Active work',
                      count: activeReports,
                      total: totalReports,
                      color: AppColors.statusActive,
                      icon: Icons.autorenew_rounded,
                      hint: 'Currently being processed',
                      onTap: () => _navigateToReports(context, 'active'),
                    ),
                    _DashboardStatCard(
                      title: 'Resolved',
                      count: approvedReports,
                      total: totalReports,
                      color: AppColors.statusClosed,
                      icon: Icons.check_circle_outline,
                      hint: 'Closed successfully',
                      onTap: () => _navigateToReports(context, 'closed'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Quick actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DashboardShortcutCard(
                        icon: Icons.analytics_outlined,
                        label: 'Analytics',
                        color: AppColors.secondary,
                        onTap: _openAnalytics,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DashboardShortcutCard(
                        icon: Icons.description_outlined,
                        label: 'Templates',
                        color: AppColors.statusOpen,
                        onTap: _openTemplates,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DashboardShortcutCard(
                        icon: Icons.public,
                        label: 'System',
                        color: AppColors.statusActive,
                        onTap: _openSystemReports,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _OfflineQueueCard(
                  pendingCount: _pendingOfflineReports,
                  syncing: _syncingOfflineReports,
                  onSync: _pendingOfflineReports == 0 || _syncingOfflineReports
                      ? null
                      : () => _syncOfflineReports(),
                ),
                const SizedBox(height: 28),
                ReporterTrendsWidget(user: widget.user),
                const SizedBox(height: 28),
                ActivityTimelineWidget(user: widget.user),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewReport,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text(
          'New report',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  final String firstName;
  final int totalReports;
  final int pendingReports;
  final VoidCallback onViewReports;

  const _DashboardHero({
    required this.firstName,
    required this.totalReports,
    required this.pendingReports,
    required this.onViewReports,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadii.xl,
        boxShadow: AppShadows.soft(AppColors.primary),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: AppRadii.medium,
                ),
                child: const Icon(
                  Icons.dashboard_customize_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good to see you, $firstName',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track progress, submit updates, and stay ahead of pending reports.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.84),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'Reports filed',
                  value: '$totalReports',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroMetric(
                  label: 'Need review',
                  value: '$pendingReports',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onViewReports,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.35),
              ),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadii.medium,
              ),
            ),
            icon: const Icon(Icons.list_alt_outlined),
            label: const Text('My reports'),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: AppRadii.large,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  final String title;
  final int count;
  final int total;
  final Color color;
  final IconData icon;
  final String hint;
  final VoidCallback onTap;

  const _DashboardStatCard({
    required this.title,
    required this.count,
    required this.total,
    required this.color,
    required this.icon,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? ((count / total) * 100).round() : 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.xl,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.xl,
            boxShadow: AppShadows.subtle,
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: AppRadii.medium,
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const Spacer(),
                  if (total > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: AppRadii.pill,
                      ),
                      child: Text(
                        '$percentage%',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                '$count',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                hint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardShortcutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DashboardShortcutCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.large,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.large,
            boxShadow: AppShadows.subtle,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadii.medium,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Quick Action Button Widget
class _OfflineQueueCard extends StatelessWidget {
  final int pendingCount;
  final bool syncing;
  final VoidCallback? onSync;

  const _OfflineQueueCard({
    required this.pendingCount,
    required this.syncing,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final accent = pendingCount > 0 ? AppColors.warning : AppColors.success;
    final title = pendingCount > 0
        ? '$pendingCount offline report${pendingCount == 1 ? '' : 's'} waiting'
        : 'Offline queue is empty';
    final subtitle = pendingCount > 0
        ? 'Reports saved without internet will sync from this device when you reconnect.'
        : 'You can keep reporting even without internet. New offline submissions will appear here.';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: AppRadii.large,
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: AppRadii.medium,
            ),
            child: Icon(
              pendingCount > 0
                  ? Icons.cloud_upload_outlined
                  : Icons.cloud_done_outlined,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: onSync,
            icon: syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            label: Text(syncing ? 'Syncing' : 'Sync'),
          ),
        ],
      ),
    );
  }
}
