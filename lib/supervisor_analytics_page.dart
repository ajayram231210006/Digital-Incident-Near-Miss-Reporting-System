import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'analytics_widgets.dart';
import 'app_theme.dart';
import 'incident_analytics_service.dart';
import 'supervisor_report_detail.dart';
import 'ui_components.dart';

class SupervisorAnalyticsPage extends StatefulWidget {
  final User user;

  const SupervisorAnalyticsPage({super.key, required this.user});

  @override
  State<SupervisorAnalyticsPage> createState() =>
      _SupervisorAnalyticsPageState();
}

class _SupervisorAnalyticsPageState extends State<SupervisorAnalyticsPage> {
  final IncidentAnalyticsService _analyticsService = IncidentAnalyticsService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  AnalyticsWindow _window = AnalyticsWindow.thirtyDays;

  DateTime? get _windowStart {
    final now = DateTime.now();
    switch (_window) {
      case AnalyticsWindow.sevenDays:
        return now.subtract(const Duration(days: 7));
      case AnalyticsWindow.thirtyDays:
        return now.subtract(const Duration(days: 30));
      case AnalyticsWindow.allTime:
        return null;
    }
  }

  Future<void> _openIncident(String reportId) async {
    try {
      final snapshot = await _dbRef.child('incidents').child(reportId).get();
      if (!mounted) return;
      if (!snapshot.exists) {
        showAppSnackBar(
          context,
          'That report is no longer available.',
          type: AppSnackBarType.info,
        );
        return;
      }

      final reportData = Map<String, dynamic>.from(snapshot.value as Map);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              SupervisorReportDetail(reportId: reportId, report: reportData),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'We could not open that report right now.',
        type: AppSnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVeryCompact = screenWidth < 420;

    return Scaffold(
      appBar: AppBar(title: const Text('Supervisor Analytics')),
      body: StreamBuilder<List<IncidentAnalyticsRecord>>(
        stream: _analyticsService.watchIncidents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final filtered = _analyticsService.filterSupervisorWindow(
            incidents: snapshot.data ?? <IncidentAnalyticsRecord>[],
            supervisorUid: widget.user.uid,
            start: _windowStart,
          );
          final summary = _analyticsService.buildSupervisorSummary(
            incidents: filtered,
            supervisorUid: widget.user.uid,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnalyticsHero(
                  title: 'Your review performance',
                  subtitle:
                      'Track your reviewed workload, closure pace, and recurring risk areas.',
                  highlight: summary.totalReviewed == 0
                      ? 'No reviewed reports in this window'
                      : '${summary.totalReviewed} reviewed reports',
                  chips: [
                    AnalyticsWindowChip(
                      label: '7 days',
                      selected: _window == AnalyticsWindow.sevenDays,
                      onTap: () =>
                          setState(() => _window = AnalyticsWindow.sevenDays),
                    ),
                    AnalyticsWindowChip(
                      label: '30 days',
                      selected: _window == AnalyticsWindow.thirtyDays,
                      onTap: () =>
                          setState(() => _window = AnalyticsWindow.thirtyDays),
                    ),
                    AnalyticsWindowChip(
                      label: 'All time',
                      selected: _window == AnalyticsWindow.allTime,
                      onTap: () =>
                          setState(() => _window = AnalyticsWindow.allTime),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.section),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  mainAxisExtent: isVeryCompact ? 206 : 192,
                  childAspectRatio: isVeryCompact ? 0.92 : 1.0,
                  children: [
                    AnalyticsMetricCard(
                      label: 'Reviewed',
                      value: '${summary.totalReviewed}',
                      hint: 'Reports attributed to your review',
                      icon: Icons.fact_check_outlined,
                      color: AppColors.primary,
                    ),
                    AnalyticsMetricCard(
                      label: 'Open owned',
                      value: '${summary.openOwned}',
                      hint: 'Reviewed by you and still unresolved',
                      icon: Icons.pending_actions_rounded,
                      color: AppColors.warning,
                    ),
                    AnalyticsMetricCard(
                      label: 'Closure rate',
                      value: '${summary.closureRate.toStringAsFixed(1)}%',
                      hint: 'Closed out of your reviewed reports',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                    ),
                    AnalyticsMetricCard(
                      label: 'Avg closure',
                      value:
                          '${summary.averageResolutionDays.toStringAsFixed(1)} d',
                      hint: 'Average resolution time for closed reviews',
                      icon: Icons.timer_outlined,
                      color: AppColors.info,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.section),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily review trend',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        height: 220,
                        child: TrendBarChart(data: summary.dailyReviewTrend),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Severity mix',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              height: 220,
                              child: BreakdownBarChart(
                                items: summary.severityBreakdown,
                                emptyLabel: 'No reviewed reports yet',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Top hotspots',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (summary.hotspotLocations.isEmpty)
                              const Text(
                                'No locations available in this window.',
                              )
                            else
                              ...summary.hotspotLocations.map(
                                (item) => RankedListTile(
                                  label: item.label,
                                  value: '${item.count}',
                                  color: AppColors.secondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.section),
                if (summary.attentionReports.isNotEmpty) ...[
                  Text(
                    'Needs attention',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...summary.attentionReports.map(
                    (incident) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: IncidentAnalyticsTile(
                        incident: incident,
                        accentColor: AppPriority.resolve(
                          incident.severity,
                        ).color,
                        subtitle:
                            '${incident.type} • ${incident.location} • ${incident.status.toUpperCase()}',
                        onTap: () => _openIncident(incident.id),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section),
                ],
                Text(
                  'Recent reviews',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                if (summary.recentReviews.isEmpty)
                  const AppEmptyState(
                    icon: Icons.analytics_outlined,
                    title: 'No review activity yet',
                    description:
                        'Once you start reviewing incidents, your analytics will appear here.',
                  )
                else
                  ...summary.recentReviews.map(
                    (incident) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: IncidentAnalyticsTile(
                        incident: incident,
                        accentColor: AppStatus.resolve(incident.status).color,
                        subtitle:
                            '${incident.location} • ${incident.status.toUpperCase()} • ${incident.createdAt.day}/${incident.createdAt.month}/${incident.createdAt.year}',
                        onTap: () => _openIncident(incident.id),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
