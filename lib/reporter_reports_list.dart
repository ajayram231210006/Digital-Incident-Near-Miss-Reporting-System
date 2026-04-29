import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'reporter_report_detail.dart';
import 'ui_components.dart';

class ReporterReportsList extends StatefulWidget {
  final User user;
  final String? filterStatus;

  const ReporterReportsList({super.key, required this.user, this.filterStatus});

  @override
  State<ReporterReportsList> createState() => _ReporterReportsListState();
}

class _ReporterReportsListState extends State<ReporterReportsList> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  late String _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.filterStatus ?? 'all';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Reports')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                for (final filter in const [
                  ('All', 'all'),
                  ('Pending', 'open'),
                  ('Active', 'active'),
                  ('Resolved', 'closed'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: FilterChip(
                      label: Text(filter.$1),
                      selected: _selectedFilter == filter.$2,
                      onSelected: (_) =>
                          setState(() => _selectedFilter = filter.$2),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _dbRef.child('incidents').onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data?.snapshot.value as Map?;
                if (data == null) {
                  return const AppEmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No reports yet',
                    description: 'Your submitted incidents will appear here.',
                  );
                }

                final reports = <Map<String, dynamic>>[];
                data.forEach((key, value) {
                  if (value is! Map) return;
                  if (value['reporterUid']?.toString() != widget.user.uid) {
                    return;
                  }
                  final status = (value['status'] ?? 'open')
                      .toString()
                      .toLowerCase();
                  if (_selectedFilter != 'all' && status != _selectedFilter) {
                    return;
                  }
                  reports.add({
                    'id': key,
                    'type': value['type'] ?? 'Incident',
                    'location': value['location'] ?? 'Unknown location',
                    'status': status,
                    'date': value['date']?.toString() ?? '',
                    'description': value['description'] ?? '',
                    'createdAt': value['createdAt'] ?? '',
                    'reporterEmail': value['reporterEmail'] ?? '',
                  });
                });

                reports.sort((a, b) {
                  final dateA = _resolveIncidentDate(a) ?? DateTime(1970);
                  final dateB = _resolveIncidentDate(b) ?? DateTime(1970);
                  return dateB.compareTo(dateA);
                });

                if (reports.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matching reports',
                    description:
                        'Try another filter to view your incident history.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ReporterReportDetail(
                                reportId: report['id'],
                                report: report,
                              ),
                            ),
                          ),
                          borderRadius: AppRadii.large,
                          child: AppSectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.md,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppStatus.resolve(
                                          report['status'],
                                        ).color.withValues(alpha: 0.12),
                                        borderRadius: AppRadii.medium,
                                      ),
                                      child: Icon(
                                        AppStatus.resolve(
                                          report['status'],
                                        ).icon,
                                        color: AppStatus.resolve(
                                          report['status'],
                                        ).color,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            report['type'].toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            report['location'].toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    AppStatusBadge(
                                      status: report['status'].toString(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  report['description'].toString().isEmpty
                                      ? 'No description provided.'
                                      : report['description'].toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _formatDate(report),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.textSecondary.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _resolveIncidentDate(Map<String, dynamic> report) {
    for (final key in const ['date', 'incidentDate', 'createdAt', 'timestamp']) {
      final value = report[key];
      final parsed = _parseDate(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }

    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    final parsedInt = int.tryParse(text);
    if (parsedInt != null) {
      return DateTime.fromMillisecondsSinceEpoch(parsedInt);
    }

    return DateTime.tryParse(text);
  }

  String _formatDate(Map<String, dynamic> report) {
    final date = _resolveIncidentDate(report);
    if (date == null) return 'Unknown date';
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hr ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
