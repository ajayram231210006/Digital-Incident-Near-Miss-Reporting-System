import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'app_theme.dart';

class PerformanceAnalyticsPage extends StatefulWidget {
  final User user;

  const PerformanceAnalyticsPage({super.key, required this.user});

  @override
  State<PerformanceAnalyticsPage> createState() =>
      _PerformanceAnalyticsPageState();
}

class _PerformanceAnalyticsPageState extends State<PerformanceAnalyticsPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Stream<Map<String, dynamic>> _getAnalyticsStream() {
    return _dbRef.child('incidents').onValue.map((event) {
      int total = 0;
      int resolved = 0;
      int pending = 0;
      int active = 0;
      DateTime? firstReportDate;
      DateTime? lastReportDate;
      int totalDaysActive = 0;

      if (!event.snapshot.exists) {
        return {
          'total': 0,
          'resolved': 0,
          'pending': 0,
          'active': 0,
          'resolutionRate': 0.0,
          'avgResolutionTime': '0 days',
          'daysActive': 0,
          'reportsPerDay': 0.0,
        };
      }

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
                resolved++;
              } else if (status == 'active') {
                active++;
              } else {
                pending++;
              }

              try {
                // Use createdAt if available, fallback to date
                final dateStr =
                    (value['createdAt'] ?? value['date'])?.toString() ?? '';
                if (dateStr.isNotEmpty) {
                  final date = DateTime.parse(dateStr);
                  if (firstReportDate == null ||
                      date.isBefore(firstReportDate!)) {
                    firstReportDate = date;
                  }
                  if (lastReportDate == null || date.isAfter(lastReportDate!)) {
                    lastReportDate = date;
                  }
                }
              } catch (e) {
                // Handle date parsing errors
              }
            }
          }
        });
      }

      if (firstReportDate != null && lastReportDate != null) {
        totalDaysActive =
            lastReportDate!.difference(firstReportDate!).inDays + 1;
      }

      final resolutionRate = total > 0 ? (resolved / total * 100).toInt() : 0;
      final reportsPerDay = totalDaysActive > 0 ? total / totalDaysActive : 0.0;

      return {
        'total': total,
        'resolved': resolved,
        'pending': pending,
        'active': active,
        'resolutionRate': resolutionRate,
        'avgResolutionTime': totalDaysActive > 0
            ? '${(totalDaysActive / (resolved > 0 ? resolved : 1)).toStringAsFixed(0)} days'
            : '0 days',
        'daysActive': totalDaysActive,
        'reportsPerDay': reportsPerDay.toStringAsFixed(1),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performance Analytics'), elevation: 0),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _getAnalyticsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final analytics = snapshot.data ?? {};
          final total = analytics['total'] ?? 0;
          final resolved = analytics['resolved'] ?? 0;
          final pending = analytics['pending'] ?? 0;
          final active = analytics['active'] ?? 0;
          final resolutionRate = analytics['resolutionRate'] ?? 0;
          final avgResolutionTime = analytics['avgResolutionTime'] ?? '0 days';
          final daysActive = analytics['daysActive'] ?? 0;
          final reportsPerDay = analytics['reportsPerDay'] ?? '0.0';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Performance Score Card
                _PerformanceScoreCard(
                  resolutionRate: resolutionRate,
                  daysActive: daysActive,
                  reportsPerDay: reportsPerDay,
                ),
                const SizedBox(height: 24),

                // Key Metrics
                Text(
                  'Key Metrics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _MetricCard(
                      label: 'Total Reports',
                      value: total.toString(),
                      icon: Icons.assignment,
                      color: AppColors.primary,
                      subtitle: 'All submissions',
                    ),
                    _MetricCard(
                      label: 'Resolved',
                      value: resolved.toString(),
                      icon: Icons.check_circle,
                      color: AppColors.statusClosed,
                      subtitle: 'Closed reports',
                    ),
                    _MetricCard(
                      label: 'Pending',
                      value: pending.toString(),
                      icon: Icons.schedule,
                      color: AppColors.statusOpen,
                      subtitle: 'Awaiting review',
                    ),
                    _MetricCard(
                      label: 'Active',
                      value: active.toString(),
                      icon: Icons.autorenew_rounded,
                      color: AppColors.statusActive,
                      subtitle: 'In progress',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Performance Insights
                Text(
                  'Performance Insights',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _InsightCard(
                  title: 'Resolution Rate',
                  value: '$resolutionRate%',
                  description: 'Percentage of reports that have been resolved',
                  icon: Icons.trending_up,
                  color: AppColors.statusClosed,
                ),
                const SizedBox(height: 10),
                _InsightCard(
                  title: 'Average Resolution Time',
                  value: avgResolutionTime,
                  description: 'Average time to resolve a report',
                  icon: Icons.schedule,
                  color: AppColors.info,
                ),
                const SizedBox(height: 10),
                _InsightCard(
                  title: 'Reports Per Day',
                  value: reportsPerDay,
                  description: 'Average submissions per day',
                  icon: Icons.show_chart,
                  color: AppColors.secondary,
                ),
                const SizedBox(height: 10),
                _InsightCard(
                  title: 'Days Active',
                  value: daysActive > 0 ? '$daysActive days' : 'No data',
                  description: 'Time since first report submission',
                  icon: Icons.calendar_today,
                  color: AppColors.primaryDark,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Performance Score Card
class _PerformanceScoreCard extends StatelessWidget {
  final int resolutionRate;
  final int daysActive;
  final String reportsPerDay;

  const _PerformanceScoreCard({
    required this.resolutionRate,
    required this.daysActive,
    required this.reportsPerDay,
  });

  String _getScoreGrade() {
    if (resolutionRate >= 90) return 'A+';
    if (resolutionRate >= 80) return 'A';
    if (resolutionRate >= 70) return 'B+';
    if (resolutionRate >= 60) return 'B';
    if (resolutionRate >= 50) return 'C';
    return '-';
  }

  Color _getScoreColor() {
    if (resolutionRate >= 80) return AppColors.statusClosed;
    if (resolutionRate >= 60) return AppColors.statusOpen;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadii.large,
        gradient: AppColors.analyticsGradient,
        boxShadow: AppShadows.soft(AppColors.primary),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Score',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getScoreColor().withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getScoreGrade(),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Overall Rating',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatRow(
                      label: 'Resolution Rate',
                      value: '$resolutionRate%',
                    ),
                    const SizedBox(height: 8),
                    _StatRow(
                      label: 'Days Active',
                      value: daysActive > 0 ? '$daysActive' : '-',
                    ),
                    const SizedBox(height: 8),
                    _StatRow(label: 'Daily Avg', value: reportsPerDay),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Stat Row
class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Metric Card
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.surface,
        boxShadow: AppShadows.soft(color),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// Insight Card
class _InsightCard extends StatelessWidget {
  final String title;
  final String value;
  final String description;
  final IconData icon;
  final Color color;

  const _InsightCard({
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
