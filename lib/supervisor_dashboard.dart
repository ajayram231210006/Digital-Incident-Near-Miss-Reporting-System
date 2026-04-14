import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'notification_service.dart';
import 'supervisor_notifications_viewer.dart';
import 'supervisor_report_detail.dart';
import 'supervisor_reports_list.dart';
import 'ui_components.dart';
import 'user_profile_service.dart';

class SupervisorDashboard extends StatefulWidget {
  final User user;

  const SupervisorDashboard({super.key, required this.user});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final NotificationService _notificationService = NotificationService();
  final UserProfileService _userProfileService = UserProfileService();

  StreamSubscription<Map<String, dynamic>>? _notificationTapSubscription;
  StreamSubscription<int>? _badgeCountSubscription;
  late final Stream<int> _unreadCountStream;
  late final Stream<Map<String, dynamic>> _reportStatsStream;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _validateSupervisorRole();
    _unreadCountStream = _notificationService
        .getUnreadNotificationCount(widget.user.uid)
        .asBroadcastStream();
    _reportStatsStream = _getReportStatsStream().asBroadcastStream();
    _initializeNotifications();
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    _badgeCountSubscription?.cancel();
    super.dispose();
  }

  Future<void> _validateSupervisorRole() async {
    try {
      final profile = await _userProfileService.fetchProfile(widget.user.uid);
      if (!mounted) return;
      final isValid =
          profile != null &&
          profile.role == 'supervisor' &&
          !profile.isPendingApproval &&
          !profile.isRejected &&
          !profile.isInactive;
      if (!isValid) {
        showAppSnackBar(
          context,
          'Unauthorized: approved supervisor access required.',
          type: AppSnackBarType.error,
        );
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {}
  }

  Future<void> _initializeNotifications() async {
    _notificationTapSubscription = _notificationService.notificationTapStream
        .listen(_handleNotificationTap);
    _badgeCountSubscription = _unreadCountStream.listen(
      _notificationService.updateAppBadgeCount,
    );

    final pending = _notificationService.consumePendingLaunchNotification();
    if (pending != null && mounted) {
      await _handleNotificationTap(pending);
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    final reportId = data['reportId']?.toString();
    if (reportId == null || reportId.isEmpty || !mounted) return;

    try {
      final snapshot = await _dbRef.child('incidents').child(reportId).get();
      if (!snapshot.exists || !mounted) return;
      final reportData = Map<String, dynamic>.from(snapshot.value as Map);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              SupervisorReportDetail(reportId: reportId, report: reportData),
        ),
      );
    } catch (_) {}
  }

  int _resolveCreatedAtMillis(Map value) {
    final raw = value['timestamp'] ?? value['createdAt'];
    if (raw is int) {
      return raw;
    }
    if (raw is String && raw.isNotEmpty) {
      final parsedInt = int.tryParse(raw);
      if (parsedInt != null) {
        return parsedInt;
      }
      final parsedDate = DateTime.tryParse(raw);
      if (parsedDate != null) {
        return parsedDate.millisecondsSinceEpoch;
      }
    }

    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    return createdAt?.millisecondsSinceEpoch ?? 0;
  }

  Stream<Map<String, dynamic>> _getReportStatsStream() {
    return _dbRef.child('incidents').onValue.map((event) {
      final result = <String, dynamic>{
        'total': 0,
        'open': 0,
        'active': 0,
        'closed': 0,
        'high': 0,
        'medium': 0,
        'low': 0,
        'critical': 0,
        'notSet': 0,
        'recent': <Map<String, dynamic>>[],
        'priorityQueue': <Map<String, dynamic>>[],
        'overdue': <Map<String, dynamic>>[],
        'dailyTrends': <String, int>{},
        'resolutionRate': 0.0,
        'openIncidentRate': 0.0,
        'newToday': 0,
        'needsReview': 0,
        'criticalOpen': 0,
      };

      final dailyTrends = <String, int>{};
      final startOfToday = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final key =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailyTrends[key] = 0;
      }

      if (!event.snapshot.exists) {
        result['dailyTrends'] = dailyTrends;
        return result;
      }

      final data = event.snapshot.value as Map?;
      final recentIncidents = <Map<String, dynamic>>[];
      final priorityQueue = <Map<String, dynamic>>[];
      final overdueIncidents = <Map<String, dynamic>>[];

      data?.forEach((key, value) {
        if (value is! Map) return;
        result['total'] = (result['total'] as int) + 1;

        final status = (value['status'] ?? 'open').toString().toLowerCase();
        final severity = (value['severity'] ?? '').toString().toLowerCase();

        if (status == 'closed') {
          result['closed'] = (result['closed'] as int) + 1;
        } else if (status == 'active') {
          result['active'] = (result['active'] as int) + 1;
        } else {
          result['open'] = (result['open'] as int) + 1;
        }

        switch (severity) {
          case 'critical':
            result['critical'] = (result['critical'] as int) + 1;
            break;
          case 'high':
            result['high'] = (result['high'] as int) + 1;
            break;
          case 'medium':
            result['medium'] = (result['medium'] as int) + 1;
            break;
          case 'low':
            result['low'] = (result['low'] as int) + 1;
            break;
          default:
            result['notSet'] = (result['notSet'] as int) + 1;
        }

        final createdMillis = _resolveCreatedAtMillis(value);
        final date = createdMillis > 0
            ? DateTime.fromMillisecondsSinceEpoch(createdMillis)
            : DateTime.tryParse(value['createdAt']?.toString() ?? '') ??
                  DateTime.now();
        final dailyKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        if (dailyTrends.containsKey(dailyKey)) {
          dailyTrends[dailyKey] = (dailyTrends[dailyKey] ?? 0) + 1;
        }

        final incident = <String, dynamic>{
          'id': key,
          'title':
              value['title'] ??
              value['type'] ??
              value['incidentType'] ??
              'Untitled',
          'description': value['description'] ?? '',
          'status': status,
          'priority': severity,
          'type': value['type'] ?? 'Incident',
          'location': value['location'] ?? 'N/A',
          'reporterEmail': value['reporterEmail'] ?? 'Unknown',
          'createdAt': value['createdAt'] ?? '',
          'timestamp': createdMillis,
        };

        if (!date.isBefore(startOfToday)) {
          result['newToday'] = (result['newToday'] as int) + 1;
        }
        if (status != 'closed') {
          result['needsReview'] = (result['needsReview'] as int) + 1;
        }
        if (status != 'closed' && severity == 'critical') {
          result['criticalOpen'] = (result['criticalOpen'] as int) + 1;
        }

        recentIncidents.add(incident);
        if (status != 'closed') {
          priorityQueue.add(incident);
        }
        if (status != 'closed' &&
            (severity == 'critical' || severity == 'high')) {
          overdueIncidents.add(incident);
        }
      });

      recentIncidents.sort(
        (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
      );
      overdueIncidents.sort((a, b) {
        final aCritical = a['priority'] == 'critical';
        final bCritical = b['priority'] == 'critical';
        if (aCritical != bCritical) return aCritical ? -1 : 1;
        return (b['timestamp'] as int).compareTo(a['timestamp'] as int);
      });
      priorityQueue.sort((a, b) {
        final severityCompare = _priorityRank(
          b['priority']?.toString(),
        ).compareTo(_priorityRank(a['priority']?.toString()));
        if (severityCompare != 0) return severityCompare;

        final statusCompare = _statusRank(
          b['status']?.toString(),
        ).compareTo(_statusRank(a['status']?.toString()));
        if (statusCompare != 0) return statusCompare;

        return (a['timestamp'] as int).compareTo(b['timestamp'] as int);
      });

      final total = result['total'] as int;
      final closed = result['closed'] as int;
      final open = result['open'] as int;
      final active = result['active'] as int;
      result['recent'] = recentIncidents.take(4).toList();
      result['priorityQueue'] = priorityQueue.take(6).toList();
      result['overdue'] = overdueIncidents.take(5).toList();
      result['dailyTrends'] = dailyTrends;
      result['resolutionRate'] = total == 0 ? 0.0 : (closed / total) * 100;
      result['openIncidentRate'] = total == 0
          ? 0.0
          : ((open + active) / total) * 100;
      return result;
    });
  }

  int _priorityRank(String? rawPriority) {
    switch ((rawPriority ?? '').toLowerCase()) {
      case 'critical':
        return 4;
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  int _statusRank(String? rawStatus) {
    switch ((rawStatus ?? '').toLowerCase()) {
      case 'open':
        return 2;
      case 'active':
        return 1;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Dashboard'),
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
                              SupervisorNotificationsViewer(user: widget.user),
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
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
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
              final shouldLogout =
                  await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
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
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _reportStatsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _DashboardSkeleton();
          }

          if (snapshot.hasError) {
            return AppEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Dashboard unavailable',
              description:
                  'We could not load dashboard data right now. Please try again.',
              actionLabel: 'Retry',
              onAction: () => setState(() {}),
            );
          }

          final stats = snapshot.data ?? {};
          final totalReports = stats['total'] as int? ?? 0;
          final openReports = stats['open'] as int? ?? 0;
          final activeReports = stats['active'] as int? ?? 0;
          final closedReports = stats['closed'] as int? ?? 0;
          final criticalPriority = stats['critical'] as int? ?? 0;
          final newToday = stats['newToday'] as int? ?? 0;
          final needsReview = stats['needsReview'] as int? ?? 0;
          final criticalOpen = stats['criticalOpen'] as int? ?? 0;
          final overdueIncidents = (stats['overdue'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          final priorityQueue = (stats['priorityQueue'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          final recentIncidents = (stats['recent'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: AppRadii.xl,
                    boxShadow: AppShadows.soft(AppColors.primary),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.86),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.user.displayName ??
                            widget.user.email?.split('@').first ??
                            'Supervisor',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Monitor incidents, prioritize critical work, and respond quickly.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    _MiniStatCard(
                      label: 'New today',
                      value: '$newToday',
                      icon: Icons.today_rounded,
                    ),
                    _MiniStatCard(
                      label: 'Needs review',
                      value: '$needsReview',
                      icon: Icons.fact_check_outlined,
                    ),
                    _MiniStatCard(
                      label: 'Critical open',
                      value: '$criticalOpen',
                      icon: Icons.warning_amber_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.section),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    _QuickActionButton(
                      label: 'Review critical',
                      icon: Icons.priority_high_rounded,
                      onTap: () => _navigateToReports(
                        context,
                        filterStatus: 'pending',
                        filterSeverity: 'critical',
                        initialSort: 'stale_first',
                      ),
                    ),
                    _QuickActionButton(
                      label: 'Open workload',
                      icon: Icons.playlist_add_check_circle_outlined,
                      onTap: () => _navigateToReports(
                        context,
                        filterStatus: 'pending',
                        initialSort: 'stale_first',
                      ),
                    ),
                    _QuickActionButton(
                      label: 'Newest reports',
                      icon: Icons.schedule_rounded,
                      onTap: () =>
                          _navigateToReports(context, initialSort: 'newest'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.section),
                Text(
                  'Performance Metrics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final metricCards = [
                      _MetricCard(
                        title: 'Resolution rate',
                        value:
                            '${(stats['resolutionRate'] as double? ?? 0).toStringAsFixed(1)}%',
                        icon: Icons.check_circle_outline_rounded,
                        subtitle: 'Closed out of all reports',
                        onTap: () =>
                            _navigateToReports(context, initialSort: 'oldest'),
                      ),
                      _MetricCard(
                        title: 'Open workload',
                        value:
                            '${(stats['openIncidentRate'] as double? ?? 0).toStringAsFixed(1)}%',
                        icon: Icons.pie_chart_outline_rounded,
                        subtitle: 'Open + active reports',
                        onTap: () => _navigateToReports(
                          context,
                          filterStatus: 'pending',
                          initialSort: 'stale_first',
                        ),
                      ),
                      _MetricCard(
                        title: 'Total reports',
                        value: '$totalReports',
                        icon: Icons.assignment_outlined,
                        subtitle: 'Full supervisor queue',
                        onTap: () =>
                            _navigateToReports(context, initialSort: 'newest'),
                      ),
                      _MetricCard(
                        title: 'Critical issues',
                        value: '$criticalPriority',
                        icon: Icons.priority_high_rounded,
                        subtitle: 'Critical severity across system',
                        onTap: () => _navigateToReports(
                          context,
                          filterSeverity: 'critical',
                          initialSort: 'stale_first',
                        ),
                      ),
                    ];

                    final isCompactPhone = constraints.maxWidth < 380;

                    return GridView.builder(
                      itemCount: metricCards.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        mainAxisExtent: isCompactPhone ? 190 : 176,
                      ),
                      itemBuilder: (context, index) => metricCards[index],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.section),
                if (overdueIncidents.isNotEmpty) ...[
                  _AttentionBanner(
                    incidents: overdueIncidents,
                    onTapIncident: _openIncident,
                  ),
                  const SizedBox(height: AppSpacing.section),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Priority Queue',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _navigateToReports(
                        context,
                        filterStatus: 'pending',
                        initialSort: 'stale_first',
                      ),
                      child: const Text('View Queue'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Prioritized by severity, unresolved status, and oldest-first review needs.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (priorityQueue.isEmpty)
                  const AppEmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Queue is clear',
                    description:
                        'No open or active incidents need supervisor attention right now.',
                  )
                else
                  ...priorityQueue.map(
                    (incident) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _IncidentSummaryCard(
                        incident: incident,
                        onTap: () => _openIncident(incident),
                      ),
                    ),
                  ),
                if (recentIncidents.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.section),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Recent Activity',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            _navigateToReports(context, initialSort: 'newest'),
                        child: const Text('Newest'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...recentIncidents.map(
                    (incident) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _IncidentSummaryCard(
                        incident: incident,
                        onTap: () => _openIncident(incident),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.section),
                Text(
                  'Incident Trends',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                AppSectionCard(
                  child: _buildIncidentTrendsChart(
                    (stats['dailyTrends'] as Map<String, int>? ?? {}),
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                Text(
                  'Incident Status Distribution',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                AppSectionCard(
                  child: Column(
                    children: [
                      _buildStatusPieChart(
                        openReports,
                        activeReports,
                        closedReports,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _LegendItem(
                            label: 'Open',
                            color: AppColors.statusOpen,
                            count: openReports,
                          ),
                          _LegendItem(
                            label: 'Active',
                            color: AppColors.statusActive,
                            count: activeReports,
                          ),
                          _LegendItem(
                            label: 'Closed',
                            color: AppColors.statusClosed,
                            count: closedReports,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openIncident(Map<String, dynamic> incident) async {
    final id = incident['id']?.toString();
    if (id == null || id.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            SupervisorReportDetail(reportId: id, report: incident),
      ),
    );
  }

  void _navigateToReports(
    BuildContext context, {
    String? filterStatus,
    String? filterSeverity,
    String initialSort = 'newest',
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SupervisorReportsList(
          user: widget.user,
          filterStatus: filterStatus,
          filterSeverity: filterSeverity,
          initialSort: initialSort,
        ),
      ),
    );
  }

  Widget _buildStatusPieChart(int open, int active, int closed) {
    final total = open + active + closed;
    if (total == 0) {
      return const SizedBox(
        height: 240,
        child: Center(child: Text('No incidents to display')),
      );
    }

    return SizedBox(
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              centerSpaceRadius: 58,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  final nextIndex =
                      event.isInterestedForInteractions && response != null
                      ? response.touchedSection?.touchedSectionIndex ?? -1
                      : -1;

                  if (_touchedIndex == nextIndex) {
                    return;
                  }

                  setState(() => _touchedIndex = nextIndex);
                },
              ),
              sections: [
                _pieSection(0, AppColors.statusOpen, open, total),
                _pieSection(1, AppColors.statusActive, active, total),
                _pieSection(2, AppColors.statusClosed, closed, total),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              Text('$total', style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _pieSection(
    int index,
    Color color,
    int value,
    int total,
  ) {
    final percentage = total == 0 ? 0 : ((value / total) * 100).round();
    return PieChartSectionData(
      color: color,
      value: value.toDouble(),
      title: value == 0 ? '' : '$percentage%',
      radius: _touchedIndex == index ? 70 : 62,
      titleStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }

  Widget _buildIncidentTrendsChart(Map<String, int> dailyTrends) {
    if (dailyTrends.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('No incident data available')),
      );
    }

    final sortedDates = dailyTrends.keys.toList()..sort();
    final values = sortedDates
        .map((key) => (dailyTrends[key] ?? 0).toDouble())
        .toList();
    final spots = <FlSpot>[
      for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final maxValue = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue <= 0 ? 1.0 : maxValue + 1;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.outline.withValues(alpha: 0.7),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(color: AppColors.outline.withValues(alpha: 0.8)),
              bottom: BorderSide(
                color: AppColors.outline.withValues(alpha: 0.8),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= sortedDates.length) {
                    return const SizedBox.shrink();
                  }
                  final parts = sortedDates[index].split('-');
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${parts[2]}/${parts[1]}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final index = spot.x.toInt();
                  return LineTooltipItem(
                    '${sortedDates[index]}\n${spot.y.toInt()} incidents',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: maxValue > 0,
              curveSmoothness: maxValue > 0 ? 0.25 : 0,
              preventCurveOverShooting: true,
              color: AppColors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    AppColors.primary.withValues(alpha: 0.02),
                  ],
                ),
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: spot.y == 0 ? 3 : 4,
                    color: spot.y == 0
                        ? AppColors.surfaceMuted
                        : AppColors.primary,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final String subtitle;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.large,
        child: AppSectionCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: AppRadii.medium,
                    ),
                    child: Icon(icon, color: AppColors.primary),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 18,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      child: AppSectionCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppColors.primaryDark),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}

class _AttentionBanner extends StatelessWidget {
  final List<Map<String, dynamic>> incidents;
  final Future<void> Function(Map<String, dynamic>) onTapIncident;

  const _AttentionBanner({
    required this.incidents,
    required this.onTapIncident,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: AppRadii.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Immediate Attention',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${incidents.length} high-risk incident${incidents.length == 1 ? '' : 's'} need action.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...incidents.map((incident) {
            final priority = AppPriority.resolve(
              incident['priority']?.toString(),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: AppRadii.large,
                child: InkWell(
                  onTap: () => onTapIncident(incident),
                  borderRadius: AppRadii.large,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Icon(priority.icon, color: Colors.white),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                incident['title']?.toString() ?? 'Untitled',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                incident['location']?.toString() ??
                                    'No location',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _IncidentSummaryCard extends StatelessWidget {
  final Map<String, dynamic> incident;
  final VoidCallback onTap;

  const _IncidentSummaryCard({required this.incident, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.large,
        child: AppSectionCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppStatus.resolve(
                    incident['status']?.toString(),
                  ).color.withValues(alpha: 0.12),
                  borderRadius: AppRadii.medium,
                ),
                child: Icon(
                  AppStatus.resolve(incident['status']?.toString()).icon,
                  color: AppStatus.resolve(
                    incident['status']?.toString(),
                  ).color,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident['title']?.toString() ?? 'Untitled',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      incident['description']?.toString() ?? 'No description',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        AppStatusBadge(
                          status: incident['status']?.toString() ?? 'open',
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppPriorityBadge(
                          priority: incident['priority']?.toString(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final int count;

  const _LegendItem({
    required this.label,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          '$count',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        AppSkeletonBox(height: 140),
        SizedBox(height: AppSpacing.section),
        Row(
          children: [
            Expanded(child: AppSkeletonBox(height: 120)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: AppSkeletonBox(height: 120)),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: AppSkeletonBox(height: 120)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: AppSkeletonBox(height: 120)),
          ],
        ),
        SizedBox(height: AppSpacing.section),
        AppSkeletonBox(height: 110),
        SizedBox(height: AppSpacing.section),
        AppSkeletonBox(height: 90),
        SizedBox(height: AppSpacing.md),
        AppSkeletonBox(height: 90),
      ],
    );
  }
}
