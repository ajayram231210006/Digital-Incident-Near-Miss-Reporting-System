import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'supervisor_report_detail.dart';
import 'ui_components.dart';

class SupervisorReportsList extends StatefulWidget {
  final User user;
  final String? filterStatus;
  final String? filterSeverity;
  final String initialSort;

  const SupervisorReportsList({
    super.key,
    required this.user,
    this.filterStatus,
    this.filterSeverity,
    this.initialSort = 'newest',
  });

  @override
  State<SupervisorReportsList> createState() => _SupervisorReportsListState();
}

class _SupervisorReportsListState extends State<SupervisorReportsList>
    with AutomaticKeepAliveClientMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _searchController = TextEditingController();

  late String _selectedStatus;
  late String _selectedSeverity;
  late String _selectedSort;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedStatus =
        (widget.filterStatus == null || (widget.filterStatus?.isEmpty ?? true))
        ? 'all'
        : widget.filterStatus!.toLowerCase();
    _selectedSeverity =
        (widget.filterSeverity == null ||
            (widget.filterSeverity?.isEmpty ?? true))
        ? 'all'
        : widget.filterSeverity!.toLowerCase();
    _selectedSort = widget.initialSort;
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text.trim().toLowerCase();
    if (nextQuery == _searchQuery) return;
    setState(() => _searchQuery = nextQuery);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Incident Reports')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by type, location, reporter, or description',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () => _searchController.clear(),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: _FilterGroup(
                    title: 'Status',
                    options: _statusFilters,
                    selectedValue: _selectedStatus,
                    onSelected: (value) {
                      setState(() => _selectedStatus = value);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _FilterGroup(
                    title: 'Severity',
                    options: _severityFilters,
                    selectedValue: _selectedSeverity,
                    onSelected: (value) {
                      setState(() => _selectedSeverity = value);
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (_selectedStatus != 'all')
                        _ActiveFilterChip(
                          label: 'Status: ${_labelForStatus(_selectedStatus)}',
                          onClear: () =>
                              setState(() => _selectedStatus = 'all'),
                        ),
                      if (_selectedSeverity != 'all')
                        _ActiveFilterChip(
                          label:
                              'Severity: ${_labelForSeverity(_selectedSeverity)}',
                          onClear: () =>
                              setState(() => _selectedSeverity = 'all'),
                        ),
                      if (_searchQuery.isNotEmpty)
                        _ActiveFilterChip(
                          label: 'Search: ${_searchController.text.trim()}',
                          onClear: () => _searchController.clear(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                DropdownButton<String>(
                  value: _selectedSort,
                  underline: const SizedBox.shrink(),
                  borderRadius: AppRadii.medium,
                  items: const [
                    DropdownMenuItem(value: 'newest', child: Text('Newest')),
                    DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                    DropdownMenuItem(
                      value: 'highest_severity',
                      child: Text('Highest severity'),
                    ),
                    DropdownMenuItem(
                      value: 'stale_first',
                      child: Text('Needs review'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedSort = value);
                  },
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
                    title: 'No reports found',
                    description:
                        'Incident reports will appear here when available.',
                  );
                }

                final reports = <Map<String, dynamic>>[];
                data.forEach((key, value) {
                  if (value is! Map) return;
                  reports.add({'id': key, ...Map<String, dynamic>.from(value)});
                });

                final filtered = reports.where(_matchesFilters).toList()
                  ..sort(_sortReports);

                if (filtered.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.filter_list_off_rounded,
                    title: 'No matching reports',
                    description:
                        'Try widening the search or clearing one of the filters.',
                    actionLabel: 'Clear filters',
                    onAction: _clearFilters,
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${filtered.length} report${filtered.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const Spacer(),
                          Text(
                            _sortLabel(_selectedSort),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final report = filtered[index];
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: _ReportCard(
                              report: report,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        SupervisorReportDetail(
                                          reportId: report['id'],
                                          report: report,
                                        ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesFilters(Map<String, dynamic> report) {
    final status = (report['status'] ?? 'open').toString().toLowerCase();
    final severity = (report['severity'] ?? '').toString().toLowerCase();

    if (_selectedStatus != 'all') {
      final matchesStatus = switch (_selectedStatus) {
        'pending' => status == 'open' || status == 'active',
        _ => status == _selectedStatus,
      };
      if (!matchesStatus) return false;
    }

    if (_selectedSeverity != 'all' && severity != _selectedSeverity) {
      return false;
    }

    if (_searchQuery.isEmpty) return true;

    final haystack = [
      report['type'],
      report['title'],
      report['location'],
      report['description'],
      report['reporterEmail'],
      report['notes'],
    ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');

    return haystack.contains(_searchQuery);
  }

  int _sortReports(Map<String, dynamic> a, Map<String, dynamic> b) {
    final createdA = _resolveCreatedAt(a);
    final createdB = _resolveCreatedAt(b);

    switch (_selectedSort) {
      case 'oldest':
        return createdA.compareTo(createdB);
      case 'highest_severity':
        final severityCompare = _severityRank(
          b['severity'],
        ).compareTo(_severityRank(a['severity']));
        if (severityCompare != 0) return severityCompare;
        return createdB.compareTo(createdA);
      case 'stale_first':
        final staleCompare = _staleRank(b).compareTo(_staleRank(a));
        if (staleCompare != 0) return staleCompare;
        return createdA.compareTo(createdB);
      case 'newest':
      default:
        return createdB.compareTo(createdA);
    }
  }

  DateTime _resolveCreatedAt(Map<String, dynamic> report) {
    final rawTimestamp = report['timestamp'];
    if (rawTimestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    }
    final rawCreatedAt = report['createdAt']?.toString();
    return DateTime.tryParse(rawCreatedAt ?? '') ?? DateTime(2000);
  }

  int _severityRank(dynamic rawSeverity) {
    switch ((rawSeverity ?? '').toString().toLowerCase()) {
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

  int _staleRank(Map<String, dynamic> report) {
    final status = (report['status'] ?? 'open').toString().toLowerCase();
    final createdAt = _resolveCreatedAt(report);
    final ageHours = DateTime.now().difference(createdAt).inHours;
    final severityRank = _severityRank(report['severity']);

    if (status == 'closed') return 0;
    if (severityRank >= 4) return 1000 + ageHours;
    if (severityRank == 3) return 750 + ageHours;
    if (status == 'open') return 500 + ageHours;
    if (status == 'active') return 300 + ageHours;
    return ageHours;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedStatus = 'all';
      _selectedSeverity = 'all';
      _selectedSort = 'newest';
      _searchQuery = '';
    });
  }

  String _labelForStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'active':
        return 'Active';
      case 'closed':
        return 'Closed';
      default:
        return 'All';
    }
  }

  String _labelForSeverity(String severity) {
    switch (severity) {
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return 'All';
    }
  }

  String _sortLabel(String sortBy) {
    switch (sortBy) {
      case 'oldest':
        return 'Sorted by oldest first';
      case 'highest_severity':
        return 'Sorted by highest severity';
      case 'stale_first':
        return 'Sorted by attention needed';
      case 'newest':
      default:
        return 'Sorted by newest first';
    }
  }

  List<(String, String)> get _statusFilters => const [
    ('All', 'all'),
    ('Pending', 'pending'),
    ('Active', 'active'),
    ('Closed', 'closed'),
  ];

  List<(String, String)> get _severityFilters => const [
    ('All', 'all'),
    ('Critical', 'critical'),
    ('High', 'high'),
    ('Medium', 'medium'),
    ('Low', 'low'),
  ];
}

class _FilterGroup extends StatelessWidget {
  final String title;
  final List<(String, String)> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  const _FilterGroup({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((option) {
              final label = option.$1;
              final value = option.$2;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: FilterChip(
                  label: Text(label),
                  selected: selectedValue == value,
                  onSelected: (_) => onSelected(value),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _ActiveFilterChip({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: AppRadii.pill,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            InkWell(
              borderRadius: AppRadii.pill,
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onTap;

  const _ReportCard({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = (report['status'] ?? 'open').toString();
    final priority = report['severity']?.toString();
    final statusStyle = AppStatus.resolve(status);
    final createdAt = _resolveCreatedAt(report);
    final reporter = (report['reporterEmail'] ?? 'Unknown').toString();
    final age = DateTime.now().difference(createdAt);
    final ageMinutes = age.inMinutes <= 0 ? 1 : age.inMinutes;
    final ageLabel = age.inDays > 0
        ? '${age.inDays}d old'
        : age.inHours > 0
        ? '${age.inHours}h old'
        : '${ageMinutes}m old';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadii.large,
        onTap: onTap,
        child: AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: statusStyle.color.withValues(alpha: 0.12),
                      borderRadius: AppRadii.medium,
                    ),
                    child: Icon(statusStyle.icon, color: statusStyle.color),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (report['type'] ?? report['title'] ?? 'Incident')
                              .toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (report['location'] ?? 'Location unavailable')
                              .toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppStatusBadge(status: status),
                      const SizedBox(height: AppSpacing.sm),
                      AppPriorityBadge(priority: priority),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                (report['description'] ?? 'No description provided').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  _MetaInfo(icon: Icons.person_outline_rounded, text: reporter),
                  _MetaInfo(icon: Icons.schedule_rounded, text: ageLabel),
                  _MetaInfo(
                    icon: Icons.calendar_today_rounded,
                    text: _formatDate(createdAt),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime _resolveCreatedAt(Map<String, dynamic> report) {
    final rawTimestamp = report['timestamp'];
    if (rawTimestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    }
    final createdAt = report['createdAt']?.toString();
    return DateTime.tryParse(createdAt ?? '') ?? DateTime(2000);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _MetaInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
