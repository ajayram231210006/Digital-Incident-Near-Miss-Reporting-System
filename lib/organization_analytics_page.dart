import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'analytics_widgets.dart';
import 'app_theme.dart';
import 'incident_analytics_service.dart';
import 'supervisor_report_detail.dart';
import 'ui_components.dart';

class OrganizationAnalyticsPage extends StatefulWidget {
  final User user;

  const OrganizationAnalyticsPage({super.key, required this.user});

  @override
  State<OrganizationAnalyticsPage> createState() =>
      _OrganizationAnalyticsPageState();
}

class _OrganizationAnalyticsPageState extends State<OrganizationAnalyticsPage> {
  static const MethodChannel _downloadsChannel = MethodChannel(
    'com.incitrack.app/downloads',
  );
  final IncidentAnalyticsService _analyticsService = IncidentAnalyticsService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  AnalyticsWindow _window = AnalyticsWindow.thirtyDays;
  String _selectedDepartment = 'All departments';
  String _selectedLocation = 'All locations';
  String _selectedStatus = 'all';

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

  Future<void> _exportCsv(List<IncidentAnalyticsRecord> incidents) async {
    if (incidents.isEmpty) {
      showAppSnackBar(
        context,
        'There is no filtered analytics data to export.',
        type: AppSnackBarType.info,
      );
      return;
    }

    try {
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final fileName = 'org_analytics_$timestamp.csv';
      final buffer = StringBuffer();
      buffer.writeln(
        'reportId,type,description,department,location,status,severity,createdAt,closedAt,lastReviewedByName,lastReviewedAt,reporterEmail',
      );

      for (final incident in incidents) {
        buffer.writeln(
          [
            incident.id,
            incident.type,
            incident.description,
            incident.department,
            incident.location,
            incident.status,
            incident.severity,
            incident.createdAt.toIso8601String(),
            incident.closedAt?.toIso8601String() ?? '',
            incident.lastReviewedByName ?? '',
            incident.lastReviewedAt?.toIso8601String() ?? '',
            incident.reporterEmail,
          ].map(_csvCell).join(','),
        );
      }

      final csvContent = buffer.toString();
      String message;

      if (Platform.isAndroid) {
        try {
          final savedPath = await _downloadsChannel.invokeMethod<String>(
            'saveCsvToDownloads',
            {'fileName': fileName, 'content': csvContent},
          );
          message = savedPath == null || savedPath.isEmpty
              ? 'CSV saved to Downloads.'
              : 'CSV saved to $savedPath';
        } on PlatformException {
          final file = await _writeCsvToAppDocuments(fileName, csvContent);
          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'Organization analytics export',
            subject: 'Organization analytics export',
          );
          message =
              'Downloads save was unavailable, so the CSV is ready to share.';
        }
      } else {
        final file = await _writeCsvToAppDocuments(fileName, csvContent);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Organization analytics export',
          subject: 'Organization analytics export',
        );
        message = 'CSV export is ready to share or save.';
      }

      if (!mounted) return;
      showAppSnackBar(context, message, type: AppSnackBarType.success);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'We could not export the CSV right now.',
        type: AppSnackBarType.error,
      );
    }
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Future<File> _writeCsvToAppDocuments(
    String fileName,
    String csvContent,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(path.join(directory.path, fileName));
    await file.writeAsString(csvContent);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 720;
    final isVeryCompact = screenWidth < 420;

    return Scaffold(
      appBar: AppBar(title: const Text('Organization Analytics')),
      body: StreamBuilder<List<IncidentAnalyticsRecord>>(
        stream: _analyticsService.watchIncidents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final baseIncidents = _analyticsService.filterByCreatedAtWindow(
            incidents: snapshot.data ?? <IncidentAnalyticsRecord>[],
            start: _windowStart,
          );
          final availableLocations = {
            'All locations',
            ...baseIncidents
                .map((incident) => incident.location.trim())
                .where((location) => location.isNotEmpty),
          }.toList()..sort();
          final availableDepartments = {
            'All departments',
            ...baseIncidents
                .map((incident) => incident.department.trim())
                .where((department) => department.isNotEmpty),
          }.toList()..sort();
          if (!availableDepartments.contains(_selectedDepartment)) {
            _selectedDepartment = 'All departments';
          }
          if (!availableLocations.contains(_selectedLocation)) {
            _selectedLocation = 'All locations';
          }
          final incidents = baseIncidents.where((incident) {
            final matchesDepartment =
                _selectedDepartment == 'All departments' ||
                incident.department.trim() == _selectedDepartment;
            final matchesLocation =
                _selectedLocation == 'All locations' ||
                incident.location.trim() == _selectedLocation;
            final matchesStatus =
                _selectedStatus == 'all' || incident.status == _selectedStatus;
            return matchesDepartment && matchesLocation && matchesStatus;
          }).toList();
          final summary = _analyticsService.buildOrganizationSummary(incidents);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnalyticsHero(
                  title: 'Organization health snapshot',
                  subtitle:
                      'See overall reporting volume, unresolved risk, and where supervisors are spending review effort.',
                  highlight: summary.totalReports == 0
                      ? 'No reports in this window'
                      : '${summary.totalReports} reports in scope',
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
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filters',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (isCompact) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _selectedDepartment,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Department',
                          ),
                          items: availableDepartments
                              .map(
                                (department) => DropdownMenuItem<String>(
                                  value: department,
                                  child: Text(
                                    department,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedDepartment = value);
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedLocation,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Location',
                          ),
                          items: availableLocations
                              .map(
                                (location) => DropdownMenuItem<String>(
                                  value: location,
                                  child: Text(
                                    location,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedLocation = value);
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedStatus,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All statuses'),
                            ),
                            DropdownMenuItem(
                              value: 'open',
                              child: Text('Open'),
                            ),
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Active'),
                            ),
                            DropdownMenuItem(
                              value: 'closed',
                              child: Text('Closed'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedStatus = value);
                          },
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedDepartment,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Department',
                                ),
                                items: availableDepartments
                                    .map(
                                      (department) => DropdownMenuItem<String>(
                                        value: department,
                                        child: Text(
                                          department,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _selectedDepartment = value);
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedLocation,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Location',
                                ),
                                items: availableLocations
                                    .map(
                                      (location) => DropdownMenuItem<String>(
                                        value: location,
                                        child: Text(
                                          location,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _selectedLocation = value);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedStatus,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'all',
                                    child: Text('All statuses'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'open',
                                    child: Text('Open'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'active',
                                    child: Text('Active'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'closed',
                                    child: Text('Closed'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _selectedStatus = value);
                                },
                              ),
                            ),
                            const Expanded(child: SizedBox.shrink()),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      if (isCompact) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _exportCsv(incidents),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Export CSV'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedDepartment = 'All departments';
                                _selectedLocation = 'All locations';
                                _selectedStatus = 'all';
                                _window = AnalyticsWindow.thirtyDays;
                              });
                            },
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('Reset filters'),
                          ),
                        ),
                      ] else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedDepartment = 'All departments';
                                    _selectedLocation = 'All locations';
                                    _selectedStatus = 'all';
                                    _window = AnalyticsWindow.thirtyDays;
                                  });
                                },
                                icon: const Icon(Icons.restart_alt_rounded),
                                label: const Text('Reset filters'),
                              ),
                              FilledButton.icon(
                                onPressed: () => _exportCsv(incidents),
                                icon: const Icon(Icons.download_rounded),
                                label: const Text('Export CSV'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth >= 1100 ? 4 : 2;

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      mainAxisExtent: isVeryCompact ? 206 : 192,
                      childAspectRatio: constraints.maxWidth >= 1100
                          ? 1.2
                          : 0.92,
                      children: [
                        AnalyticsMetricCard(
                          label: 'Reports',
                          value: '${summary.totalReports}',
                          hint: 'All incidents in this window',
                          icon: Icons.assignment_outlined,
                          color: AppColors.primary,
                        ),
                        AnalyticsMetricCard(
                          label: 'Closure rate',
                          value: '${summary.closureRate.toStringAsFixed(1)}%',
                          hint: 'Closed out of total reports',
                          icon: Icons.check_circle_outline_rounded,
                          color: AppColors.success,
                        ),
                        AnalyticsMetricCard(
                          label: 'Critical',
                          value: '${summary.criticalReports}',
                          hint: 'Critical-severity reports raised',
                          icon: Icons.priority_high_rounded,
                          color: AppColors.critical,
                        ),
                        AnalyticsMetricCard(
                          label: 'Unreviewed',
                          value: '${summary.unreviewedReports}',
                          hint: 'Reports with no recorded supervisor review',
                          icon: Icons.visibility_off_outlined,
                          color: AppColors.warning,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.section),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily reporting volume',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        height: 220,
                        child: TrendBarChart(data: summary.dailyTrend),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                if (isCompact) ...[
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status distribution',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          height: 260,
                          child: _StatusDonutChart(
                            open: summary.openReports,
                            active: summary.activeReports,
                            closed: summary.closedReports,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Severity breakdown',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          height: 220,
                          child: BreakdownBarChart(
                            items: summary.severityBreakdown,
                            emptyLabel: 'No severity data available',
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status distribution',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              SizedBox(
                                height: 220,
                                child: _StatusDonutChart(
                                  open: summary.openReports,
                                  active: summary.activeReports,
                                  closed: summary.closedReports,
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
                                'Severity breakdown',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              SizedBox(
                                height: 220,
                                child: BreakdownBarChart(
                                  items: summary.severityBreakdown,
                                  emptyLabel: 'No severity data available',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.section),
                if (isCompact) ...[
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top locations',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (summary.topLocations.isEmpty)
                          const Text('No location data available.')
                        else
                          ...summary.topLocations.map(
                            (item) => RankedListTile(
                              label: item.label,
                              value: '${item.count}',
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top departments',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (summary.topDepartments.isEmpty)
                          const Text('No department data available.')
                        else
                          ...summary.topDepartments.map(
                            (item) => RankedListTile(
                              label: item.label,
                              value: '${item.count}',
                              color: AppColors.secondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Top locations',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              if (summary.topLocations.isEmpty)
                                const Text('No location data available.')
                              else
                                ...summary.topLocations.map(
                                  (item) => RankedListTile(
                                    label: item.label,
                                    value: '${item.count}',
                                    color: AppColors.primary,
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
                                'Top departments',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              if (summary.topDepartments.isEmpty)
                                const Text('No department data available.')
                              else
                                ...summary.topDepartments.map(
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
                Text(
                  'Supervisor leaderboard',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                if (summary.supervisorLeaderboard.isEmpty)
                  const AppEmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No review ownership yet',
                    description:
                        'Supervisor comparison will appear after reviews are saved with ownership metadata.',
                  )
                else
                  AppSectionCard(
                    child: Column(
                      children: [
                        for (final entry in summary.supervisorLeaderboard)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.secondary
                                      .withValues(alpha: 0.12),
                                  foregroundColor: AppColors.secondary,
                                  child: Text(
                                    entry.name.isEmpty
                                        ? '?'
                                        : entry.name[0].toUpperCase(),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${entry.totalReviewed} reviewed • ${entry.openReviewed} open • ${entry.closedReviewed} closed • ${entry.criticalReviewed} critical',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
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
                  ),
                const SizedBox(height: AppSpacing.section),
                if (summary.urgentReports.isNotEmpty) ...[
                  Text(
                    'Urgent reports',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...summary.urgentReports.map(
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
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusDonutChart extends StatelessWidget {
  final int open;
  final int active;
  final int closed;

  const _StatusDonutChart({
    required this.open,
    required this.active,
    required this.closed,
  });

  @override
  Widget build(BuildContext context) {
    final total = open + active + closed;
    if (total == 0) {
      return const Center(child: Text('No reports to display.'));
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            centerSpaceRadius: 52,
            sectionsSpace: 3,
            borderData: FlBorderData(show: false),
            sections: [
              PieChartSectionData(
                value: open.toDouble(),
                color: AppColors.statusOpen,
                title: open == 0 ? '' : '${((open / total) * 100).round()}%',
                radius: 58,
                titleStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              PieChartSectionData(
                value: active.toDouble(),
                color: AppColors.statusActive,
                title: active == 0
                    ? ''
                    : '${((active / total) * 100).round()}%',
                radius: 58,
                titleStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              PieChartSectionData(
                value: closed.toDouble(),
                color: AppColors.statusClosed,
                title: closed == 0
                    ? ''
                    : '${((closed / total) * 100).round()}%',
                radius: 58,
                titleStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Total'),
            Text('$total', style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ],
    );
  }
}
