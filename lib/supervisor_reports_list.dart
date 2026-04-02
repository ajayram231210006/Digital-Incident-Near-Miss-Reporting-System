import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'supervisor_report_detail.dart';

class SupervisorReportsList extends StatefulWidget {
  final User user;
  final String? filterStatus;
  final String? filterSeverity;

  const SupervisorReportsList({
    super.key,
    required this.user,
    this.filterStatus,
    this.filterSeverity,
  });

  @override
  State<SupervisorReportsList> createState() => _SupervisorReportsListState();
}

class _SupervisorReportsListState extends State<SupervisorReportsList>
    with AutomaticKeepAliveClientMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  String _selectedFilter = 'all';
  bool _isSeverityFilter = false;

  @override
  void initState() {
    super.initState();
    _isSeverityFilter = widget.filterSeverity != null;
    if (_isSeverityFilter) {
      // Keep empty string for 'not set' severity filter, only default to 'all' if null
      _selectedFilter = widget.filterSeverity ?? 'all';
    } else {
      _selectedFilter = (widget.filterStatus?.isEmpty ?? true) ? 'all' : widget.filterStatus!;
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Incident Reports'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: _isSeverityFilter
                  ? [
                      // Severity filter chips
                      _FilterChip(
                        label: 'All',
                        isSelected: _selectedFilter == 'all',
                        onPressed: () {
                          setState(() => _selectedFilter = 'all');
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Critical',
                        isSelected: _selectedFilter == 'critical',
                        onPressed: () {
                          setState(() => _selectedFilter = 'critical');
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'High',
                        isSelected: _selectedFilter == 'high',
                        onPressed: () {
                          setState(() => _selectedFilter = 'high');
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Medium',
                        isSelected: _selectedFilter == 'medium',
                        onPressed: () {
                          setState(() => _selectedFilter = 'medium');
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Low',
                        isSelected: _selectedFilter == 'low',
                        onPressed: () {
                          setState(() => _selectedFilter = 'low');
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Not Set',
                        isSelected: _selectedFilter == '',
                        onPressed: () {
                          setState(() => _selectedFilter = '');
                        },
                      ),
                    ]
                  : [
                      // Status filter chips
                      _FilterChip(
                        label: 'All',
                        isSelected: _selectedFilter == 'all',
                        onPressed: () {
                          setState(() => _selectedFilter = 'all');
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Active',
                        isSelected: _selectedFilter == 'active',
                        onPressed: () {
                          setState(() => _selectedFilter = 'active');
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Pending',
                        isSelected: _selectedFilter == 'pending',
                        onPressed: () {
                          setState(() => _selectedFilter = 'pending');
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Closed',
                        isSelected: _selectedFilter == 'closed',
                        onPressed: () {
                          setState(() => _selectedFilter = 'closed');
                        },
                      ),
                    ],
            ),
          ),
          // Reports List
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _dbRef.child('incidents').onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                  return const Center(
                    child: Text('No reports found'),
                  );
                }

                final data = snapshot.data!.snapshot.value as Map?;
                if (data == null) {
                  return const Center(child: Text('No reports found'));
                }

                final reports = <Map<String, dynamic>>[];
                data.forEach((key, value) {
                  if (value is Map) {
                    reports.add({
                      'id': key,
                      ...Map<String, dynamic>.from(value),
                    });
                  }
                });

                // Filter reports
                final filtered = reports.where((report) {
                  if (_selectedFilter == 'all') return true;
                  
                  if (_isSeverityFilter) {
                    // Filter by severity
                    final severity = (report['severity'] ?? '').toString().toLowerCase();
                    return severity == _selectedFilter;
                  } else {
                    // Filter by status
                    final status = (report['status'] ?? 'open').toString().toLowerCase();
                    
                    // Pending filter includes both open and active reports
                    if (_selectedFilter == 'pending') {
                      return status == 'open' || status == 'active';
                    }
                    
                    return status == _selectedFilter;
                  }
                }).toList();

                // Sort by date (newest first)
                filtered.sort((a, b) {
                  final dateA = DateTime.tryParse(a['createdAt'] ?? '') ??
                      DateTime(2000);
                  final dateB = DateTime.tryParse(b['createdAt'] ?? '') ??
                      DateTime(2000);
                  return dateB.compareTo(dateA);
                });

                if (filtered.isEmpty) {
                  return Center(
                    child: Text('No ${_selectedFilter} reports found'),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.withOpacity(0.05),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  margin: const EdgeInsets.all(12.0),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final report = filtered[index];
                      return _ReportCard(
                        report: report,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => SupervisorReportDetail(
                                reportId: report['id'],
                                report: report,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onPressed(),
    );
  }
}

class _ReportCard extends StatefulWidget {
  final Map<String, dynamic> report;
  final VoidCallback onTap;

  const _ReportCard({
    required this.report,
    required this.onTap,
  });

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard>
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
    final status = (widget.report['status'] ?? 'open').toString().toLowerCase();
    final severity = (widget.report['severity'] ?? 'Not Set').toString();
    final reportType = widget.report['type'] ?? 'Unknown Type';
    final location = widget.report['location'] ?? 'No Location';
    final reporter = widget.report['reporterEmail'] ?? 'Unknown';
    final createdAt = DateTime.tryParse(widget.report['createdAt'] ?? '')
        ?.toLocal();

    // Get colors based on status
    final statusColor = status == 'closed'
        ? Colors.green
        : status == 'active'
            ? Colors.orange
            : Colors.amber;

    // Get severity color
    final severityColor = severity.toLowerCase() == 'critical'
        ? Colors.red
        : severity.toLowerCase() == 'high'
            ? Colors.orange
            : severity.toLowerCase() == 'medium'
                ? Colors.yellow
                : Colors.blue;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.98).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side - Icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: statusColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Middle - Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Report Type
                            Text(
                              reportType,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            // Location
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.grey.shade600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Right side - Badge
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status[0].toUpperCase() + status.substring(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Divider
                  Divider(
                    height: 1,
                    color: Colors.grey.shade200,
                  ),
                  const SizedBox(height: 10),
                  // Footer row
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.blue.withOpacity(0.2),
                              child: Text(
                                (reporter.split('@').first.substring(0, 1))
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reporter',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.grey.shade500,
                                          fontSize: 11,
                                        ),
                                  ),
                                  Text(
                                    reporter.split('@').first,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Severity badge
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          severity.length > 3
                              ? severity.substring(0, 3).toUpperCase()
                              : severity.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: severityColor,
                          ),
                        ),
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ],
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
