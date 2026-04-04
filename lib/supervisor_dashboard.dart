import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'supervisor_reports_list.dart';
import 'supervisor_report_detail.dart';
import 'supervisor_notifications_viewer.dart';
import 'notification_service.dart';

class SupervisorDashboard extends StatefulWidget {
  final User user;
  const SupervisorDashboard({super.key, required this.user});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final NotificationService _notificationService = NotificationService();
  StreamSubscription<Map<String, dynamic>>? _notificationTapSubscription;
  StreamSubscription<int>? _badgeCountSubscription;
  late final Stream<int> _unreadCountStream;
  
  // Stats
  int _totalReports = 0;
  int _openReports = 0;
  int _activeReports = 0;
  int _closedReports = 0;
  
  // Severity Counts
  int _criticalCount = 0;
  int _highCount = 0;
  int _mediumCount = 0;
  int _lowCount = 0;

  @override
  void initState() {
    super.initState();
    _unreadCountStream = _notificationService
        .getUnreadNotificationCount(widget.user.uid)
        .asBroadcastStream();
    _initializeNotifications();
    _listenToReports();
  }

  Future<void> _initializeNotifications() async {
    _notificationTapSubscription =
        _notificationService.notificationTapStream.listen((notificationData) {
      _handleNotificationTap(notificationData);
    });

    _badgeCountSubscription = _unreadCountStream.listen((count) {
      _notificationService.updateAppBadgeCount(count);
    });

    final pendingNotification =
        _notificationService.consumePendingLaunchNotification();
    if (pendingNotification != null && mounted) {
      _handleNotificationTap(pendingNotification);
    }
  }

  Future<void> _handleNotificationTap(
    Map<String, dynamic> notificationData,
  ) async {
    final reportId = notificationData['reportId']?.toString();
    if (reportId == null || reportId.isEmpty || !mounted) {
      return;
    }

    await _openIncidentReport(reportId);
  }

  Future<void> _openIncidentReport(String reportId) async {
    try {
      final snapshot = await _dbRef.child('incidents').child(reportId).get();
      if (snapshot.exists && mounted) {
        final reportData = Map<String, dynamic>.from(snapshot.value as Map);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SupervisorReportDetail(
              reportId: reportId,
              report: reportData,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error handling supervisor notification tap: $e');
    }
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    _badgeCountSubscription?.cancel();
    super.dispose();
  }

  void _listenToReports() {
    _dbRef.child('incidents').onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map?;
        if (data != null) {
          int total = 0;
          int open = 0;
          int active = 0;
          int closed = 0;
          
          int critical = 0;
          int high = 0;
          int medium = 0;
          int low = 0;

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

              if (severity == 'critical') {
                critical++;
              } else if (severity == 'high') {
                high++;
              } else if (severity == 'medium') {
                medium++;
              } else if (severity == 'low') {
                low++;
              }
            }
          });

          if (mounted) {
            setState(() {
              _totalReports = total;
              _openReports = open;
              _activeReports = active;
              _closedReports = closed;
              
              _criticalCount = critical;
              _highCount = high;
              _mediumCount = medium;
              _lowCount = low;
            });
          }
        }
      }
    });
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SupervisorNotificationsViewer(user: widget.user),
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
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
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
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${widget.user.displayName ?? widget.user.email?.split('@').first}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            
            // Stats Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  'Total Reports',
                  '$_totalReports',
                  Colors.blue,
                  Icons.assignment,
                  () => _navigateToReports('all'),
                ),
                _buildStatCard(
                  'Pending',
                  '$_openReports',
                  Colors.orange,
                  Icons.pending_actions,
                  () => _navigateToReports('open'),
                ),
                _buildStatCard(
                  'Active',
                  '$_activeReports',
                  Colors.amber,
                  Icons.bolt,
                  () => _navigateToReports('active'),
                ),
                _buildStatCard(
                  'Resolved',
                  '$_closedReports',
                  Colors.green,
                  Icons.check_circle,
                  () => _navigateToReports('closed'),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Severity Distribution Chart
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Severity Distribution',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: _totalReports == 0 
                      ? const Center(child: Text('No data available'))
                      : PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: [
                            if (_criticalCount > 0)
                              PieChartSectionData(
                                color: Colors.red.shade900,
                                value: _criticalCount.toDouble(),
                                title: 'Crit',
                                radius: 50,
                                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            if (_highCount > 0)
                              PieChartSectionData(
                                color: Colors.red.shade600,
                                value: _highCount.toDouble(),
                                title: 'High',
                                radius: 50,
                                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            if (_mediumCount > 0)
                              PieChartSectionData(
                                color: Colors.orange,
                                value: _mediumCount.toDouble(),
                                title: 'Med',
                                radius: 50,
                                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            if (_lowCount > 0)
                              PieChartSectionData(
                                color: Colors.green,
                                value: _lowCount.toDouble(),
                                title: 'Low',
                                radius: 50,
                                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem('Critical', Colors.red.shade900),
                        const SizedBox(width: 10),
                        _buildLegendItem('High', Colors.red.shade600),
                        const SizedBox(width: 10),
                        _buildLegendItem('Medium', Colors.orange),
                        const SizedBox(width: 10),
                        _buildLegendItem('Low', Colors.green),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Trends Section
            const Text(
              'Incident Trends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTrendsChart(),
            
            const SizedBox(height: 24),
            
            // Recent Reports List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Reports',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => _navigateToReports('all'),
                  child: const Text('View All'),
                ),
              ],
            ),
            _buildRecentReportsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shadowColor: color.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                count,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildRecentReportsList() {
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('incidents').limitToLast(5).onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('No recent reports')),
            ),
          );
        }

        final data = snapshot.data!.snapshot.value as Map?;
        if (data == null) return const SizedBox();

        final reports = <Map<String, dynamic>>[];
        data.forEach((key, value) {
          if (value is Map) {
            reports.add({
              'id': key,
              ...Map<String, dynamic>.from(value),
            });
          }
        });

        // Sort by date descending
        reports.sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            final status = (report['status'] ?? 'open').toString().toLowerCase();
            final severity = (report['severity'] ?? '').toString().toLowerCase();
            
            Color statusColor = Colors.orange;
            if (status == 'closed') {
              statusColor = Colors.green;
            } else if (status == 'active') {
              statusColor = Colors.amber;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupervisorReportDetail(
                        reportId: report['id'],
                        report: report,
                      ),
                    ),
                  );
                },
                leading: CircleAvatar(
                  backgroundColor: _getSeverityColor(severity).withValues(alpha: 0.1),
                  child: Icon(
                    _getSeverityIcon(severity),
                    color: _getSeverityColor(severity),
                    size: 20,
                  ),
                ),
                title: Text(
                  report['type'] ?? 'Incident',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  report['location'] ?? 'Unknown Location',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical': return Colors.red.shade900;
      case 'high': return Colors.red.shade600;
      case 'medium': return Colors.orange;
      case 'low': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity) {
      case 'critical': return Icons.gavel;
      case 'high': return Icons.priority_high;
      case 'medium': return Icons.report_problem;
      case 'low': return Icons.info;
      default: return Icons.help_outline;
    }
  }

  void _navigateToReports(String filter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupervisorReportsList(
          user: widget.user,
          filterStatus: filter,
        ),
      ),
    );
  }

  Widget _buildTrendsChart() {
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('incidents').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const SizedBox(
            height: 200,
            child: Center(child: Text('Loading trends...')),
          );
        }

        final data = snapshot.data!.snapshot.value as Map?;
        if (data == null) return const SizedBox();

        // Group by date
        final Map<String, int> dateCounts = {};
        data.forEach((key, value) {
          if (value is Map) {
            final createdAt = value['createdAt']?.toString();
            if (createdAt != null && createdAt.length >= 10) {
              final date = createdAt.substring(0, 10); // YYYY-MM-DD
              dateCounts[date] = (dateCounts[date] ?? 0) + 1;
            }
          }
        });

        // Sort dates
        final sortedDates = dateCounts.keys.toList()..sort();
        // Take last 7 days
        final recentDates = sortedDates.length > 7 
            ? sortedDates.sublist(sortedDates.length - 7)
            : sortedDates;

        if (recentDates.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(child: Text('No data for trends')),
          );
        }

        final spots = <FlSpot>[];
        for (int i = 0; i < recentDates.length; i++) {
          spots.add(FlSpot(i.toDouble(), dateCounts[recentDates[i]]!.toDouble()));
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < recentDates.length) {
                                final date = recentDates[value.toInt()];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    date.substring(5), // MM-DD
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Colors.blue,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
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
                            color: Colors.blue.withValues(alpha: 0.15),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (spot) => Colors.white,
                          fitInsideHorizontally: true,
                          getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
                            return lineBarsSpot.map((lineBarSpot) {
                              if (lineBarSpot.x.toInt() < sortedDates.length) {
                                final dateStr = sortedDates[lineBarSpot.x.toInt()];
                                return LineTooltipItem(
                                  '$dateStr\n${lineBarSpot.y.toInt()} incidents',
                                  const TextStyle(
                                    color: Colors.black,
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
                const SizedBox(height: 10),
                const Text(
                  'Reports over the last 7 active days',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
