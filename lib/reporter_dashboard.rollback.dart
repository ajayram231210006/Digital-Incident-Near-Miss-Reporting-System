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

class ReporterDashboard extends StatefulWidget {
  final User user;
  const ReporterDashboard({super.key, required this.user});

  @override
  State<ReporterDashboard> createState() => _ReporterDashboardState();
}

class _ReporterDashboardState extends State<ReporterDashboard>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final NotificationService _notificationService = NotificationService();
  final OfflineIncidentQueueService _offlineQueueService =
      OfflineIncidentQueueService();
  late AnimationController _animationController;
  StreamSubscription<Map<String, dynamic>>? _notificationTapSubscription;
  StreamSubscription<int>? _badgeCountSubscription;
  StreamSubscription<bool>? _offlineStatusSubscription;
  StreamSubscription<int>? _offlinePendingSubscription;
  late final Stream<int> _unreadCountStream;
  bool _isFABOpen = false;
  bool _syncingOfflineReports = false;
  int _pendingOfflineReports = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
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
    _animationController.dispose();
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

          return SingleChildScrollView(
            child: Column(
              children: [
                // Hero Section
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    boxShadow: AppShadows.soft(AppColors.primary),
                  ),
                  child: ClipPath(
                    clipper: _WaveClipper(),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Welcome Header with Icon
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: AppRadii.medium,
                                ),
                                child: const Icon(
                                  Icons.waving_hand_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome back!',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text:
                                                (widget.user.displayName ??
                                                        widget.user.email
                                                            ?.split('@')
                                                            .first ??
                                                        'Reporter')
                                                    .split(' ')
                                                    .first,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
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
                          const SizedBox(height: 16),
                          // Subtitle with Icon
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: AppRadii.small,
                                ),
                                child: const Icon(
                                  Icons.checklist_rtl,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Stay on top of your reports and track progress',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Stats Section with Modern Design
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modern Stat Cards with Circular Progress
                      Row(
                        children: [
                          Expanded(
                            child: _CircularStatCard(
                              title: 'Total',
                              count: totalReports,
                              total:
                                  totalReports +
                                  openReports +
                                  activeReports +
                                  approvedReports,
                              color: AppColors.primary,
                              icon: Icons.assignment,
                              onTap: () => _navigateToReports(context, 'all'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CircularStatCard(
                              title: 'Pending',
                              count: openReports,
                              total: totalReports,
                              color: AppColors.statusOpen,
                              icon: Icons.schedule,
                              onTap: () => _navigateToReports(context, 'open'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _CircularStatCard(
                              title: 'Active',
                              count: activeReports,
                              total: totalReports,
                              color: AppColors.statusActive,
                              icon: Icons.autorenew_rounded,
                              onTap: () =>
                                  _navigateToReports(context, 'active'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CircularStatCard(
                              title: 'Resolved',
                              count: approvedReports,
                              total: totalReports,
                              color: AppColors.statusClosed,
                              icon: Icons.check_circle,
                              onTap: () =>
                                  _navigateToReports(context, 'closed'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Quick Actions Section
                      Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _OfflineQueueCard(
                        pendingCount: _pendingOfflineReports,
                        syncing: _syncingOfflineReports,
                        onSync:
                            _pendingOfflineReports == 0 ||
                                _syncingOfflineReports
                            ? null
                            : () => _syncOfflineReports(),
                      ),
                      const SizedBox(height: 10),
                      _QuickActionButton(
                        label: 'Submit New Report',
                        icon: Icons.add_circle_outline,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ReportIncidentForm(
                                    reporter: ReporterIdentity.fromFirebaseUser(
                                      widget.user,
                                    ),
                                  ),
                            ),
                          ).then((_) {
                            setState(() {});
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _QuickActionButton(
                        label: 'Use Template',
                        icon: Icons.description_outlined,
                        isPrimary: false,
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) =>
                                ReportTemplatesDialog(user: widget.user),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _QuickActionButton(
                        label: 'View All Reports',
                        icon: Icons.list_alt,
                        isPrimary: false,
                        onPressed: () => _navigateToReports(context, 'all'),
                      ),
                      const SizedBox(height: 10),
                      _QuickActionButton(
                        label: 'System Reports',
                        icon: Icons.public,
                        isPrimary: false,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SystemReportsViewer(user: widget.user),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      // Trends Section
                      ReporterTrendsWidget(user: widget.user),
                      const SizedBox(height: 32),

                      // Recent Activity
                      ActivityTimelineWidget(user: widget.user),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_isFABOpen) ...[
            _FABAction(
              icon: Icons.analytics_outlined,
              label: 'Analytics',
              color: AppColors.secondary,
              onTap: () {
                setState(() => _isFABOpen = false);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PerformanceAnalyticsPage(user: widget.user),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _FABAction(
              icon: Icons.description_outlined,
              label: 'Templates',
              color: AppColors.statusOpen,
              onTap: () {
                setState(() => _isFABOpen = false);
                showDialog(
                  context: context,
                  builder: (context) =>
                      ReportTemplatesDialog(user: widget.user),
                );
              },
            ),
            const SizedBox(height: 10),
            _FABAction(
              icon: Icons.list,
              label: 'My Reports',
              color: AppColors.primary,
              onTap: () {
                setState(() => _isFABOpen = false);
                _navigateToReports(context, 'all');
              },
            ),
            const SizedBox(height: 10),
          ],
          FloatingActionButton.extended(
            onPressed: () {
              setState(() => _isFABOpen = !_isFABOpen);
            },
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: AnimatedRotation(
              turns: _isFABOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.add, color: Colors.white),
            ),
            label: Text(
              _isFABOpen ? 'Close' : 'Report',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
          ),
        ],
      ),
    );
  }
}

// Custom Wave Clipper for Hero Section
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
      size.width / 4,
      size.height,
      size.width / 2,
      size.height - 20,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 40,
      size.width,
      size.height - 20,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// Circular Stat Card Widget
class _CircularStatCard extends StatefulWidget {
  final String title;
  final int count;
  final int total;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _CircularStatCard({
    required this.title,
    required this.count,
    required this.total,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_CircularStatCard> createState() => _CircularStatCardState();
}

class _CircularStatCardState extends State<_CircularStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = widget.total > 0
        ? (widget.count / widget.total * 100).toInt()
        : 0;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadii.large,
            boxShadow: AppShadows.soft(widget.color),
          ),
          child: ClipRRect(
            borderRadius: AppRadii.large,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.surface, AppColors.surfaceRaised],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Circular Progress
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: widget.total > 0
                              ? widget.count / widget.total
                              : 0,
                          strokeWidth: 6,
                          backgroundColor: AppColors.surfaceMuted,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.color,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(widget.icon, color: widget.color, size: 28),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.count.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: widget.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      borderRadius: AppRadii.small,
                    ),
                    child: Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                      ),
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

// Quick Action Button Widget
class _QuickActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = true,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

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

class _QuickActionButtonState extends State<_QuickActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.95).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: widget.isPrimary ? AppColors.primaryGradient : null,
            color: widget.isPrimary ? null : AppColors.surfaceRaised,
            boxShadow: widget.isPrimary
                ? AppShadows.soft(AppColors.primary)
                : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.isPrimary ? Colors.white : AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: widget.isPrimary ? Colors.white : AppColors.primary,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: widget.isPrimary
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Floating Action Menu Item Widget
class _FABAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FABAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_FABAction> createState() => _FABActionState();
}

class _FABActionState extends State<_FABAction>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.9).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.medium,
            boxShadow: AppShadows.soft(widget.color),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.15),
                  borderRadius: AppRadii.small,
                ),
                child: Icon(widget.icon, size: 20, color: widget.color),
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
