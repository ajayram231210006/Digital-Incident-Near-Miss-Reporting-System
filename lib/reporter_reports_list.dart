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

class _ReporterReportsListState extends State<ReporterReportsList>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  late String _selectedFilter;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.filterStatus ?? 'all';
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // Modern Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                _ModernFilterChip(
                  label: 'All',
                  isSelected: _selectedFilter == 'all',
                  onPressed: () {
                    setState(() => _selectedFilter = 'all');
                  },
                ),
                const SizedBox(width: 10),
                _ModernFilterChip(
                  label: 'Pending',
                  isSelected: _selectedFilter == 'open',
                  count: 0,
                  onPressed: () {
                    setState(() => _selectedFilter = 'open');
                  },
                ),
                const SizedBox(width: 10),
                _ModernFilterChip(
                  label: 'Active',
                  isSelected: _selectedFilter == 'active',
                  count: 0,
                  onPressed: () {
                    setState(() => _selectedFilter = 'active');
                  },
                ),
                const SizedBox(width: 10),
                _ModernFilterChip(
                  label: 'Resolved',
                  isSelected: _selectedFilter == 'closed',
                  count: 0,
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No reports yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final data = snapshot.data!.snapshot.value as Map?;
                if (data == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No reports found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final reports = <Map<String, dynamic>>[];
                data.forEach((key, value) {
                  if (value is Map) {
                    final reporterUid = value['reporterUid']?.toString() ?? '';
                    if (reporterUid == widget.user.uid) {
                      final status =
                          (value['status'] ?? 'open').toString().toLowerCase();

                      bool includeReport = _selectedFilter == 'all';
                      if (_selectedFilter == 'open' && status == 'open') {
                        includeReport = true;
                      }
                      if (_selectedFilter == 'active' && status == 'active') {
                        includeReport = true;
                      }
                      if (_selectedFilter == 'closed' && status == 'closed') {
                        includeReport = true;
                      }

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

                // Sort reports by date in descending order (newest first)
                reports.sort((a, b) {
                  try {
                    final dateA = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(1970);
                    final dateB = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(1970);
                    return dateB.compareTo(dateA); // Descending order (newest first)
                  } catch (e) {
                    return 0;
                  }
                });

                if (reports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_selectedFilter != 'all' ? _selectedFilter : ''} reports',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: reports.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final status = report['status'] as String;
                    final statusColor = status == 'closed'
                        ? Colors.green
                        : status == 'active'
                            ? Colors.orange
                            : Colors.amber;

                    return _ModernReportCard(
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

// Modern Report Card Widget with Swipe Support
class _ModernReportCard extends StatefulWidget {
  final Map<String, dynamic> report;
  final Color statusColor;
  final VoidCallback onTap;

  const _ModernReportCard({
    required this.report,
    required this.statusColor,
    required this.onTap,
  });

  @override
  State<_ModernReportCard> createState() => _ModernReportCardState();
}

class _ModernReportCardState extends State<_ModernReportCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.1, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: widget.statusColor.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.grey.shade50],
                  ),
                ),
                child: Column(
                  children: [
                    // Header with Status
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom:
                              BorderSide(color: Colors.grey.shade100, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Type Icon
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: widget.statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: widget.statusColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Title and Type
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.report['type'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.report['location'] ?? 'No location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: widget.statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: widget.statusColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: widget.statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.report['status']
                                      .toString()
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: widget.statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Description
                          Text(
                            widget.report['description'] ?? 'No description',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          // Date
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatDate(
                                    widget.report['date'] ?? 'Unknown'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    }

    String _formatDate(String dateString) {
      try {
        if (dateString == 'Unknown') return 'Unknown date';
        final date = DateTime.parse(dateString);
        final now = DateTime.now();
        final difference = now.difference(date);

        if (difference.inDays == 0) {
          if (difference.inHours == 0) {
            return '${difference.inMinutes}m ago';
          }
          return '${difference.inHours}h ago';
        } else if (difference.inDays < 7) {
          return '${difference.inDays}d ago';
        } else {
          return '${date.day}/${date.month}/${date.year}';
        }
      } catch (e) {
        return 'Unknown date';
      }
    }
  }

// Modern Filter Chip
class _ModernFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final int? count;
  final VoidCallback onPressed;

  const _ModernFilterChip({
    required this.label,
    required this.isSelected,
    this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isSelected
              ? LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.grey.shade100,
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
