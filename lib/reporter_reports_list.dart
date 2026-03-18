import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'reporter_report_detail.dart';

class ReporterReportsList extends StatefulWidget {
  final User user;
  final String? filterStatus;

  const ReporterReportsList({
    super.key,
    required this.user,
    this.filterStatus,
  });

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
      appBar: AppBar(
        title: const Text('My Reports'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: _selectedFilter == 'all',
                  onPressed: () {
                    setState(() => _selectedFilter = 'all');
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Awaiting Review',
                  isSelected: _selectedFilter == 'open',
                  onPressed: () {
                    setState(() => _selectedFilter = 'open');
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'In Progress',
                  isSelected: _selectedFilter == 'active',
                  onPressed: () {
                    setState(() => _selectedFilter = 'active');
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Resolved',
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
                    final reporterUid = value['reporterUid']?.toString() ?? '';
                    if (reporterUid == widget.user.uid) {
                      final status = (value['status'] ?? 'open').toString().toLowerCase();

                      bool includeReport = _selectedFilter == 'all';
                      if (_selectedFilter == 'open' && status == 'open') includeReport = true;
                      if (_selectedFilter == 'active' && status == 'active') includeReport = true;
                      if (_selectedFilter == 'closed' && status == 'closed') includeReport = true;

                      if (includeReport) {
                        reports.add({
                          'id': key,
                          'type': value['type'] ?? 'Unknown',
                          'location': value['location'] ?? 'Unknown',
                          'status': status,
                          'date': value['date']?.toString() ?? 'Unknown',
                          'description': value['description'] ?? 'No description',
                          'imageUrl': value['imageUrl'] ?? '',
                          'createdAt': value['createdAt'] ?? '',
                          'reporterEmail': value['reporterEmail'] ?? 'Unknown',
                          'notes': value['notes'] ?? '',
                        });
                      }
                    }
                  }
                });

                if (reports.isEmpty) {
                  return const Center(
                    child: Text('No reports found'),
                  );
                }

                return ListView.builder(
                  itemCount: reports.length,
                  padding: const EdgeInsets.all(8.0),
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final status = report['status'] as String;
                    final statusColor = status == 'closed'
                        ? Colors.green
                        : status == 'active'
                            ? Colors.orange
                            : Colors.amber;

                    return _ReportCardWidget(
                      report: report,
                      statusColor: statusColor,
                      onTap: () {
                        _showReportDetails(context, report);
                      },
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

  void _showReportDetails(BuildContext context, Map<String, dynamic> report) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReporterReportDetail(
          reportId: report['id'],
          report: report,
        ),
      ),
    );
  }
}

class _ReportCardWidget extends StatefulWidget {
  final Map<String, dynamic> report;
  final Color statusColor;
  final VoidCallback onTap;

  const _ReportCardWidget({
    required this.report,
    required this.statusColor,
    required this.onTap,
  });

  @override
  State<_ReportCardWidget> createState() => _ReportCardWidgetState();
}

class _ReportCardWidgetState extends State<_ReportCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          elevation: 4,
          shadowColor: widget.statusColor.withOpacity(0.3),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.report_problem,
                color: widget.statusColor,
              ),
            ),
            title: Text(
              widget.report['type'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(widget.report['location'] ?? 'Unknown'),
            trailing: Chip(
              label: Text(
                widget.report['status'].toString().toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: widget.statusColor,
            ),
          ),
        ),
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
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.green.withOpacity(0.3),
      labelStyle: TextStyle(
        color: isSelected ? Colors.green : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
