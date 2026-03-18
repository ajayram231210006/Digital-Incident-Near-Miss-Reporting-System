import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'supervisor_report_detail.dart';

class SupervisorReportsList extends StatefulWidget {
  final User user;
  final String? filterStatus;

  const SupervisorReportsList({
    super.key,
    required this.user,
    this.filterStatus,
  });

  @override
  State<SupervisorReportsList> createState() => _SupervisorReportsListState();
}

class _SupervisorReportsListState extends State<SupervisorReportsList> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.filterStatus ?? 'all';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  final status = (report['status'] ?? '').toString().toLowerCase();
                  
                  // Pending filter includes both open and active reports
                  if (_selectedFilter == 'pending') {
                    return status == 'open' || status == 'active' || status == '';
                  }
                  
                  return status == _selectedFilter;
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

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
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
    final status = (widget.report['status'] ?? 'open').toString().toLowerCase();
    final statusColor = status == 'closed'
        ? Colors.green
        : status == 'active'
            ? Colors.orange
            : Colors.amber;

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
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 4,
          shadowColor: statusColor.withOpacity(0.3),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: statusColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  status == 'closed'
                      ? Icons.check_circle
                      : status == 'active'
                          ? Icons.schedule
                          : Icons.hourglass_top,
                  color: statusColor,
                ),
              ),
              title: Text(
                widget.report['type'] ?? 'Unknown Type',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    widget.report['location'] ?? 'Unknown Location',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reporter: ${widget.report['reporterEmail'] ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: Chip(
                label: Text(
                  status[0].toUpperCase() + status.substring(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: statusColor,
              ),
              isThreeLine: true,
            ),
          ),
        ),
      ),
    );
  }
}
