import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'supervisor_reports_list.dart';
import 'supervisor_report_detail.dart';
import 'supervisor_notifications_viewer.dart';
import 'notification_service.dart';
import 'offline_report_queue_service.dart';

class SupervisorDashboard extends StatefulWidget {
  final User user;
  const SupervisorDashboard({super.key, required this.user});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final NotificationService _notificationService = NotificationService();
  final OfflineReportQueueService _offlineQueueService =
      OfflineReportQueueService();
  int _touchedIndex = -1;
  bool _isValidSupervisor = true;

  @override
  void initState() {
    super.initState();
    _dbRef.child('incidents').keepSynced(true);
    _validateSupervisorRole();

    // Listen for notification taps to open incident reports
    _notificationService.notificationTapStream.listen((notificationData) {
      _handleNotificationTap(notificationData);
    });
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
              builder: (context) => SupervisorReportDetail(
                reportId: reportId.toString(),
                report: reportData,
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _validateSupervisorRole() async {
    try {
      final userRole = await _dbRef
          .child('users')
          .child(widget.user.uid)
          .child('role')
          .get();
      if (!mounted) return;
      setState(() {
        _isValidSupervisor =
            (userRole.value?.toString().toLowerCase() == 'supervisor');
      });
      if (!_isValidSupervisor) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unauthorized: Supervisor access required'),
            backgroundColor: Colors.red,
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      // Silent fail
    }
  }

  Stream<Map<String, dynamic>> _getReportStatsStream() {
    final controller = StreamController<Map<String, dynamic>>();

    Map<String, dynamic> baseStats = {
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
      'overdue': <Map<String, dynamic>>[],
      'resolutionRate': 0.0,
      'openIncidentRate': 0.0,
      'dailyTrends': <String, int>{},
    };

    Map<String, dynamic> calculateBaseStats(Map<dynamic, dynamic>? data) {
      int total = 0;
      int open = 0;
      int active = 0;
      int closed = 0;
      int high = 0;
      int medium = 0;
      int low = 0;
      int critical = 0;
      int notSet = 0;
      final int now = DateTime.now().millisecondsSinceEpoch;
      final Map<String, int> dailyIncidents = {};
      List<Map<String, dynamic>> recentIncidents = [];
      List<Map<String, dynamic>> overdueIncidents = [];

      if (data != null) {
        data.forEach((key, value) {
          if (value is Map) {
            total++;
            final status = (value['status'] ?? 'open').toString().toLowerCase();
            final severity = (value['severity'] ?? '').toString().toLowerCase();

            if (status == 'closed') {
              closed++;
            } else if (status == 'active') {
              active++;
            } else {
              open++;
            }

            if (severity == 'high') {
              high++;
            } else if (severity == 'low') {
              low++;
            } else if (severity == 'critical') {
              critical++;
            } else if (severity == 'medium') {
              medium++;
            } else {
              notSet++;
            }

            final reporterName = _extractReporterName(value);
            final imageUrl = value['imageUrl'] ?? '';
            final ts = value['timestamp'] ?? value['createdAt'];
            final int timestamp = ts is int
                ? ts
                : (int.tryParse(ts.toString()) ?? 0);

            recentIncidents.add({
              'id': key,
              'title':
                  value['title'] ??
                  value['type'] ??
                  value['incidentType'] ??
                  'Untitled',
              'description': value['description'] ?? '',
              'status': status,
              'priority': severity,
              'date': value['date'] ?? 'N/A',
              'timestamp': timestamp,
              'reporter': reporterName,
              'reporterEmail': value['reporterEmail'] ?? 'N/A',
              'location': value['location'] ?? 'N/A',
              'category': value['category'] ?? value['type'] ?? 'Incident',
              'type':
                  value['type'] ??
                  value['incidentType'] ??
                  value['category'] ??
                  'Incident',
              'imageUrl': imageUrl,
              'attachments': value['attachments'] ?? '',
              'createdAt': value['createdAt'] ?? value['timestamp'] ?? '',
            });

            if (status != 'closed' &&
                (severity == 'critical' || severity == 'high')) {
              overdueIncidents.add({
                'id': key,
                'title':
                    value['title'] ??
                    value['type'] ??
                    value['incidentType'] ??
                    'Untitled',
                'description': value['description'] ?? '',
                'status': status,
                'severity': severity,
                'date': value['date'] ?? 'N/A',
                'timestamp': timestamp,
                'reporter': reporterName,
                'reporterEmail': value['reporterEmail'] ?? 'N/A',
                'location': value['location'] ?? 'N/A',
                'category': value['category'] ?? value['type'] ?? 'Incident',
                'type':
                    value['type'] ??
                    value['incidentType'] ??
                    value['category'] ??
                    'Incident',
                'imageUrl': imageUrl,
                'attachments': value['attachments'] ?? '',
                'createdAt': value['createdAt'] ?? value['timestamp'] ?? '',
              });
            }
          }
        });
      }

      recentIncidents.sort((a, b) {
        final int timestampA = a['timestamp'] as int? ?? 0;
        final int timestampB = b['timestamp'] as int? ?? 0;
        if (timestampA != 0 && timestampB != 0) {
          return timestampB.compareTo(timestampA);
        }
        return (b['date'] ?? '').compareTo(a['date'] ?? '');
      });
      recentIncidents = recentIncidents.take(3).toList();

      overdueIncidents.sort((a, b) {
        if (a['severity'] == 'critical' && b['severity'] != 'critical') {
          return -1;
        }
        if (a['severity'] != 'critical' && b['severity'] == 'critical') {
          return 1;
        }
        final int timestampA = a['timestamp'] as int? ?? 0;
        final int timestampB = b['timestamp'] as int? ?? 0;
        return timestampB.compareTo(timestampA);
      });
      overdueIncidents = overdueIncidents.take(5).toList();

      final double resolutionRate = total > 0 ? (closed / total * 100) : 0;
      final double openIncidentRate = total > 0
          ? ((open + active) / total * 100)
          : 0;

      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailyIncidents[dateStr] = 0;
      }

      data?.forEach((key, value) {
        if (value is Map) {
          final tsValue = value['timestamp'] ?? value['createdAt'];
          final int timestamp = tsValue is int
              ? tsValue
              : (int.tryParse(tsValue.toString()) ?? now);
          final incidentDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final dateStr =
              '${incidentDate.year}-${incidentDate.month.toString().padLeft(2, '0')}-${incidentDate.day.toString().padLeft(2, '0')}';
          if (dailyIncidents.containsKey(dateStr)) {
            dailyIncidents[dateStr] = (dailyIncidents[dateStr] ?? 0) + 1;
          }
        }
      });

      return {
        'total': total,
        'open': open,
        'active': active,
        'closed': closed,
        'high': high,
        'medium': medium,
        'low': low,
        'critical': critical,
        'notSet': notSet,
        'recent': recentIncidents,
        'overdue': overdueIncidents,
        'resolutionRate': resolutionRate,
        'openIncidentRate': openIncidentRate,
        'dailyTrends': dailyIncidents,
      };
    }

    Future<void> emitMergedStats() async {
      final pendingCount = await _offlineQueueService.getPendingCountGlobal();
      final baseTotal = baseStats['total'] as int? ?? 0;
      final baseOpen = baseStats['open'] as int? ?? 0;
      final baseActive = baseStats['active'] as int? ?? 0;
      final mergedTotal = baseTotal + pendingCount;
      final mergedOpen = baseOpen + pendingCount;

      final merged = Map<String, dynamic>.from(baseStats);
      merged['total'] = mergedTotal;
      merged['open'] = mergedOpen;
      merged['notSet'] = (baseStats['notSet'] as int? ?? 0) + pendingCount;
      merged['openIncidentRate'] = mergedTotal > 0
          ? ((mergedOpen + baseActive) / mergedTotal * 100)
          : 0.0;
      merged['resolutionRate'] = mergedTotal > 0
          ? ((baseStats['closed'] as int? ?? 0) / mergedTotal * 100)
          : 0.0;

      controller.add(merged);
    }

    unawaited(() async {
      try {
        baseStats = await _offlineQueueService.getCachedSupervisorStats();
      } catch (_) {
        baseStats = {
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
          'overdue': <Map<String, dynamic>>[],
          'resolutionRate': 0.0,
          'openIncidentRate': 0.0,
          'dailyTrends': <String, int>{},
        };
      }
      await emitMergedStats();
    }());

    final incidentsSub = _dbRef
        .child('incidents')
        .onValue
        .listen(
          (event) async {
            final raw = event.snapshot.value;
            if (raw is Map) {
              baseStats = calculateBaseStats(raw);
              await _offlineQueueService.cacheSupervisorStats(baseStats);
            }
            await emitMergedStats();
          },
          onError: (_) async {
            await emitMergedStats();
          },
        );

    final pendingSub = _offlineQueueService.watchPendingCountGlobal().listen((
      _,
    ) async {
      await emitMergedStats();
    });

    controller.onCancel = () async {
      await incidentsSub.cancel();
      await pendingSub.cancel();
    };

    return controller.stream;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Supervisor Dashboard'),
        elevation: 2,
        shadowColor: Colors.grey.withOpacity(0.5),
        backgroundColor: Colors.blue,
        actions: [
          // Notifications Button with Badge
          StreamBuilder<int>(
            stream: _notificationService.getUnreadNotificationCount(
              widget.user.uid,
            ),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    tooltip: 'View Notifications',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              SupervisorNotificationsViewer(user: widget.user),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade500,
                          borderRadius: BorderRadius.circular(12),
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
                            style: TextStyle(color: Colors.red),
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
        stream: _getReportStatsStream(),
        initialData: const {
          'total': 0,
          'open': 0,
          'active': 0,
          'closed': 0,
          'high': 0,
          'medium': 0,
          'low': 0,
          'critical': 0,
          'notSet': 0,
          'overdue': <dynamic>[],
          'resolutionRate': 0.0,
          'openIncidentRate': 0.0,
        },
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final stats = snapshot.data ?? {};
          final totalReports = stats['total'] ?? 0;
          final openReports = stats['open'] ?? 0;
          final activeReports = stats['active'] ?? 0;
          final closedReports = stats['closed'] ?? 0;
          final highPriority = stats['high'] ?? 0;
          final mediumPriority = stats['medium'] ?? 0;
          final lowPriority = stats['low'] ?? 0;
          final criticalPriority = stats['critical'] ?? 0;
          final notSetPriority = stats['notSet'] ?? 0;
          final overdueIncidents = stats['overdue'] as List<dynamic>? ?? [];
          final resolutionRate = stats['resolutionRate'] as double? ?? 0.0;
          final openIncidentRate = stats['openIncidentRate'] as double? ?? 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Card with Enhanced Design
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.dashboard_customize,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome Back',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                                Text(
                                  widget.user.displayName ??
                                      widget.user.email?.split('@').first ??
                                      'Supervisor',
                                  style: Theme.of(context).textTheme.titleMedium
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
                      const SizedBox(height: 16),
                      Text(
                        'Monitor and manage all incident reports in real-time',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // KPI Dashboard Cards Section with better styling
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Performance Metrics',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Today',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                  children: [
                    // Resolution Rate Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade500,
                            Colors.green.shade600,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.25),
                            blurRadius: 10,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                Text(
                                  '✓',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${resolutionRate.toStringAsFixed(1)}%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Resolution Rate',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Colors.white.withOpacity(0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Open Incident Rate Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade500,
                            Colors.orange.shade600,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.25),
                            blurRadius: 10,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.trending_up,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                Text(
                                  '→',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${openIncidentRate.toStringAsFixed(1)}%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Open Rate',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Colors.white.withOpacity(0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Total Reports Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.shade500,
                            Colors.purple.shade600,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.25),
                            blurRadius: 10,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.file_present,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                Text(
                                  '#',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$totalReports',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Total Reports',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Colors.white.withOpacity(0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Critical Issues Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade500, Colors.red.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.25),
                            blurRadius: 10,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.warning_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                Text(
                                  '!',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$criticalPriority',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Critical',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Colors.white.withOpacity(0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Critical/Overdue Alerts Banner - Enhanced
                if (overdueIncidents.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade700, Colors.red.shade900],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.35),
                          blurRadius: 10,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.priority_high,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'IMMEDIATE ATTENTION REQUIRED',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                  Text(
                                    '${overdueIncidents.length} critical incident${overdueIncidents.length > 1 ? 's' : ''} need action',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...overdueIncidents.map((incident) {
                          final inc = incident as Map<String, dynamic>;
                          final severity = inc['severity'] ?? 'high';
                          final severityColor = severity == 'critical'
                              ? Colors.yellow.shade400
                              : Colors.orange.shade400;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () {
                                if (inc['id'] != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          SupervisorReportDetail(
                                            reportId: inc['id'],
                                            report: inc,
                                          ),
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: severityColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          inc['title'] ?? 'Untitled',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Type: ${(inc['type'] ?? 'Incident').toUpperCase()}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.white.withOpacity(
                                                  0.85,
                                                ),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white.withOpacity(0.7),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                if (overdueIncidents.isNotEmpty) const SizedBox(height: 24),

                // Real-time Incidents Section - with enhanced styling
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Incidents',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'View All',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((stats['recent'] as List<dynamic>? ?? []).isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inbox,
                                  size: 48,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No recent incidents',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...((stats['recent'] as List<dynamic>? ?? []).map((
                          inc,
                        ) {
                          final incident = inc as Map<String, dynamic>;
                          final severity = incident['priority'] ?? 'low';
                          final severityColor = severity == 'critical'
                              ? Colors.red
                              : severity == 'high'
                              ? Colors.deepOrange
                              : severity == 'medium'
                              ? Colors.orange
                              : Colors.blue;
                          final statusColor = incident['status'] == 'open'
                              ? Colors.amber
                              : incident['status'] == 'active'
                              ? Colors.orange
                              : Colors.green;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: () {
                                if (incident['id'] != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          SupervisorReportDetail(
                                            reportId: incident['id'],
                                            report: incident,
                                          ),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white,
                                  border: Border.all(
                                    color: severityColor.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title and Type
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            incident['title'] ?? 'Untitled',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: severityColor.withOpacity(
                                              0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            severity.toUpperCase(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: severityColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Type: ${incident['type'] ?? 'Unknown'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey[600]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),

                                    // Status and Info Pills
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(
                                                0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  incident['status'] == 'closed'
                                                      ? Icons.check_circle
                                                      : incident['status'] ==
                                                            'active'
                                                      ? Icons.schedule
                                                      : Icons
                                                            .radio_button_unchecked,
                                                  color: statusColor,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  incident['status']
                                                          ?.toString()
                                                          .toUpperCase() ??
                                                      'OPEN',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: statusColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: severityColor.withOpacity(
                                                0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  severity == 'critical'
                                                      ? Icons.error
                                                      : severity == 'high'
                                                      ? Icons.warning
                                                      : Icons.info,
                                                  color: severityColor,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  severity.toUpperCase(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: severityColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList()),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Incident Trends Chart Section
                Text(
                  'Incident Trends (Last 7 Days)',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: _buildIncidentTrendsChart(
                    stats['dailyTrends'] as Map<String, dynamic>? ?? {},
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'Incident Status Distribution',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      _buildStatusPieChart(
                        openReports,
                        activeReports,
                        closedReports,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildLegendItem('Open', Colors.amber, openReports),
                          _buildLegendItem(
                            'Active',
                            Colors.orange,
                            activeReports,
                          ),
                          _buildLegendItem(
                            'Closed',
                            Colors.green,
                            closedReports,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Report Statistics Header
                Text(
                  'Report Statistics',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Status Statistics - Text-based Layout
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.withOpacity(0.05),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatisticTextRow(
                        'Total Reports',
                        totalReports,
                        Colors.blue,
                        () => _navigateToReports(context, 'all'),
                      ),
                      const SizedBox(height: 12),
                      _buildStatisticTextRow(
                        'Awaiting Review',
                        openReports,
                        Colors.amber,
                        () => _navigateToReports(context, 'open'),
                      ),
                      const SizedBox(height: 12),
                      _buildStatisticTextRow(
                        'In Progress',
                        activeReports,
                        Colors.orange,
                        () => _navigateToReports(context, 'active'),
                      ),
                      const SizedBox(height: 12),
                      _buildStatisticTextRow(
                        'Closed',
                        closedReports,
                        Colors.green,
                        () => _navigateToReports(context, 'closed'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Priority Distribution Header - NEW SECTION
                Text(
                  'Priority Distribution',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Priority Statistics - Text-based Layout
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.withOpacity(0.05),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatisticTextRow(
                        'Not Set',
                        notSetPriority,
                        Colors.grey,
                        () => _navigateToBySeverity(context, 'notset'),
                      ),
                      const SizedBox(height: 12),
                      _buildStatisticTextRow(
                        'Low',
                        lowPriority,
                        Colors.blue,
                        () => _navigateToBySeverity(context, 'low'),
                      ),
                      const SizedBox(height: 12),
                      _buildStatisticTextRow(
                        'Medium',
                        mediumPriority,
                        Colors.orange,
                        () => _navigateToBySeverity(context, 'medium'),
                      ),
                      const SizedBox(height: 12),
                      _buildStatisticTextRow(
                        'High',
                        highPriority,
                        Colors.orange,
                        () => _navigateToBySeverity(context, 'high'),
                      ),
                      const SizedBox(height: 12),
                      _buildStatisticTextRow(
                        'Critical',
                        criticalPriority,
                        Colors.red,
                        () => _navigateToBySeverity(context, 'critical'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusPieChart(int open, int active, int closed) {
    final total = open + active + closed;
    if (total == 0) {
      return SizedBox(
        height: 250,
        child: Center(
          child: Text(
            'No incidents to display',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              if (!event.isInterestedForInteractions ||
                  pieTouchResponse == null) {
                if (_touchedIndex != -1) {
                  setState(() {
                    _touchedIndex = -1;
                  });
                }
                return;
              }
              final newTouchedIndex =
                  pieTouchResponse.touchedSection?.touchedSectionIndex ?? -1;
              if (_touchedIndex != newTouchedIndex) {
                setState(() {
                  _touchedIndex = newTouchedIndex;
                });
              }
            },
          ),
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: [
            PieChartSectionData(
              color: Colors.amber,
              value: open.toDouble(),
              title: '$open',
              radius: _touchedIndex == 0 ? 70 : 60,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              color: Colors.orange,
              value: active.toDouble(),
              title: '$active',
              radius: _touchedIndex == 1 ? 70 : 60,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              color: Colors.green,
              value: closed.toDouble(),
              title: '$closed',
              radius: _touchedIndex == 2 ? 70 : 60,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentTrendsChart(Map<String, dynamic> dailyTrends) {
    if (dailyTrends.isEmpty) {
      return SizedBox(
        height: 250,
        child: Center(
          child: Text(
            'No incident data available',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    // Convert daily trends to list of FlSpot for chart
    final sortedDates = dailyTrends.keys.toList()..sort();
    final List<FlSpot> spots = [];
    for (int i = 0; i < sortedDates.length; i++) {
      final count = (dailyTrends[sortedDates[i]] as int?) ?? 0;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
    }

    // Find max value for Y axis
    final maxValue = spots.isEmpty
        ? 10.0
        : spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final yAxisMax = (maxValue + 2).ceilToDouble();

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: (yAxisMax / 5).roundToDouble(),
                verticalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.2),
                    strokeWidth: 1,
                  );
                },
                getDrawingVerticalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.15),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < sortedDates.length) {
                        final dateStr = sortedDates[index];
                        final parts = dateStr.split('-');
                        if (parts.length == 3) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${parts[2]}/${parts[1]}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                      }
                      return const Text('');
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(
                  color: Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
              ),
              minX: 0,
              maxX: (sortedDates.length - 1).toDouble(),
              minY: 0,
              maxY: yAxisMax,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.blue.shade500,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percentageOffset, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Colors.blue.shade600,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blue.withOpacity(0.15),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipBorder: const BorderSide(color: Colors.white),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
                    return lineBarsSpot.map((lineBarSpot) {
                      if (lineBarSpot.x.toInt() < sortedDates.length) {
                        final dateStr = sortedDates[lineBarSpot.x.toInt()];
                        return LineTooltipItem(
                          '${dateStr}\n${lineBarSpot.y.toInt()} incidents',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }
                      return null;
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.blue.shade500,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Shows incident creation trend over the last 7 days',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticTextRow(
    String label,
    int count,
    Color color,
    VoidCallback onTap,
  ) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.grey.withOpacity(0.1),
            highlightColor: Colors.grey.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 14.0,
                horizontal: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        count.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey.withOpacity(0.5),
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(color: Colors.grey.withOpacity(0.2), height: 1),
      ],
    );
  }

  void _navigateToReports(BuildContext context, String filter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupervisorReportsList(
          user: widget.user,
          filterStatus: filter == 'all' ? '' : filter,
        ),
      ),
    );
  }

  void _navigateToBySeverity(BuildContext context, String severity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupervisorReportsList(
          user: widget.user,
          filterSeverity: severity == 'notset' ? '' : severity,
        ),
      ),
    );
  }

  // ===== REFACTORED BUILD HELPER METHODS =====

  // ===== NEW SUPERVISOR FUNCTIONS =====

  String _extractReporterName(dynamic value) {
    // Simplified reporter name extraction with cleaner fallbacks
    if (value is Map) {
      return value['reporter'] ??
          value['reporterName'] ??
          value['reportedBy'] ??
          (value['reporterInfo'] is Map
              ? value['reporterInfo']['name']
              : null) ??
          'Unknown';
    }
    return 'Unknown';
  }

  Stream<List<Map<String, dynamic>>> getAssignedIncidentsForSupervisor() {
    return _dbRef.child('incidents').onValue.map((event) {
      List<Map<String, dynamic>> assigned = [];
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map?;
        data?.forEach((key, value) {
          if (value is Map && value['assignedBy'] == widget.user.uid) {
            assigned.add({
              'id': key,
              'title': value['title'] ?? 'Untitled',
              'status': value['status'] ?? 'open',
              'assignedTo': value['assignedTo'] ?? 'Unassigned',
              'createdAt': value['createdAt'] ?? 0,
            });
          }
        });
      }
      return assigned;
    });
  }

  Stream<List<Map<String, dynamic>>> getOverdueIncidents() {
    return _dbRef.child('incidents').onValue.map((event) {
      List<Map<String, dynamic>> overdue = [];
      if (event.snapshot.exists) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final oneDayMs = 24 * 60 * 60 * 1000;
        final data = event.snapshot.value as Map?;

        data?.forEach((key, value) {
          if (value is Map) {
            final status = value['status']?.toString().toLowerCase() ?? 'open';
            final severity = value['severity']?.toString().toLowerCase() ?? '';
            final createdTime =
                (value['timestamp'] ?? value['createdAt']) as int? ?? 0;
            final ageMs = now - createdTime;

            // Mark as overdue if: not closed AND (critical OR (high/medium and over 1 day old))
            final isCritical = severity == 'critical';
            final isHighPriority = severity == 'high' || severity == 'medium';
            final isOldEnough = ageMs > oneDayMs;

            if (status != 'closed' &&
                (isCritical || (isHighPriority && isOldEnough))) {
              overdue.add({
                'id': key,
                'title': value['title'] ?? 'Untitled',
                'status': status,
                'severity': severity,
                'ageHours': (ageMs / (60 * 60 * 1000)).toStringAsFixed(1),
              });
            }
          }
        });
      }
      return overdue;
    });
  }
}
