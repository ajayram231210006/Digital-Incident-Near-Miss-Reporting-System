import 'package:flutter/material.dart';
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

class _SupervisorReportsListState extends State<SupervisorReportsList> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  String _selectedFilter = 'all';
  bool _isSeverityFilter = false;

  @override
  void initState() {
    super.initState();
    _isSeverityFilter = widget.filterSeverity != null;
    if (_isSeverityFilter) {
      _selectedFilter = (widget.filterSeverity?.isEmpty ?? true) ? 'all' : widget.filterSeverity!;
    } else {
      _selectedFilter = (widget.filterStatus?.isEmpty ?? true) ? 'all' : widget.filterStatus!;
    }
  }

  @override
  Widget build(BuildContext context) {
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

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onTap;

  const _ReportCard({
    required this.report,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = (report['status'] ?? 'open').toString().toLowerCase();
    final statusColor = status == 'closed'
        ? Colors.green
        : status == 'active'
            ? Colors.orange
            : Colors.amber;

    final reportType = report['type'] ?? 'Unknown Type';
    final location = report['location'] ?? 'No Location';
    final reporter = report['reporterEmail'] ?? 'Unknown';

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.grey.withOpacity(0.1),
            highlightColor: Colors.grey.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Report Type (Title)
                        Text(
                          reportType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Location
                        Text(
                          'Location: $location',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Reporter
                        Text(
                          'Reporter: $reporter',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status Badge and Chevron
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status[0].toUpperCase() + status.substring(1),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey.withOpacity(0.5),
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(
          color: Colors.grey.withOpacity(0.2),
          height: 1,
          indent: 16,
          endIndent: 16,
        ),
      ],
    );
  }
}
