import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'reporter_report_detail.dart';

class SystemReportsViewer extends StatefulWidget {
  final User user;

  const SystemReportsViewer({super.key, required this.user});

  @override
  State<SystemReportsViewer> createState() => _SystemReportsViewerState();
}

class _SystemReportsViewerState extends State<SystemReportsViewer>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  late String _selectedFilter;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _selectedFilter = 'all';
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
        title: const Text('System Reports'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // Filter Chips
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
                  onPressed: () {
                    setState(() => _selectedFilter = 'open');
                  },
                ),
                const SizedBox(width: 10),
                _ModernFilterChip(
                  label: 'Active',
                  isSelected: _selectedFilter == 'active',
                  onPressed: () {
                    setState(() => _selectedFilter = 'active');
                  },
                ),
                const SizedBox(width: 10),
                _ModernFilterChip(
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

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Error: ${snapshot.error}'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                try {
                  if (!snapshot.hasData || !snapshot.data!.snapshot.exists) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No reports found'),
                        ],
                      ),
                    );
                  }

                  final data = snapshot.data!.snapshot.value as Map?;
                  if (data == null || data.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No reports found'),
                        ],
                      ),
                    );
                  }

                  // Filter reports
                  List<MapEntry<String, dynamic>> filteredReports = [];
                  data.forEach((key, value) {
                    if (value is Map) {
                      final status = (value['status'] ?? 'open').toString().toLowerCase();
                      if (_selectedFilter == 'all' || status == _selectedFilter) {
                        filteredReports.add(MapEntry(key, value));
                      }
                    }
                  });

                  // Sort by creation date (newest first)
                  filteredReports.sort((a, b) {
                    try {
                      final dateA = DateTime.parse((a.value['createdAt'] ?? '').toString());
                      final dateB = DateTime.parse((b.value['createdAt'] ?? '').toString());
                      return dateB.compareTo(dateA);
                    } catch (e) {
                      return 0;
                    }
                  });

                  if (filteredReports.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.filter_list_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No reports with this filter'),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredReports.length,
                    itemBuilder: (context, index) {
                      try {
                        final reportId = filteredReports[index].key;
                        final reportData = filteredReports[index].value as Map;
                        
                        final report = <String, dynamic>{};
                        for (var key in reportData.keys) {
                          report[key.toString()] = reportData[key];
                        }

                        return _ReportCard(
                          reportId: reportId,
                          report: report,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ReporterReportDetail(
                                  reportId: reportId,
                                  report: report,
                                ),
                              ),
                            );
                          },
                        );
                      } catch (e) {
                        debugPrint('Error rendering report card: $e');
                        return const SizedBox.shrink();
                      }
                    },
                  );
                } catch (e) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Error: $e'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const _ModernFilterChip({
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
      selectedColor: Colors.blue.shade400,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.blue.shade400 : Colors.transparent,
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String reportId;
  final Map<String, dynamic> report;
  final VoidCallback onTap;

  const _ReportCard({
    required this.reportId,
    required this.report,
    required this.onTap,
  });

  String _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'closed':
        return 'Resolved';
      case 'active':
        return 'Active';
      case 'open':
        return 'Pending';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (report['status'] ?? 'open').toString().toLowerCase();
    final type = (report['type'] ?? 'Report').toString();
    final description = (report['description'] ?? '').toString();
    final createdAt = (report['createdAt'] ?? '').toString();
    final severity = (report['severity'] ?? 'Not Set').toString();
    final reporterEmail = (report['reporterEmail'] ?? 'Unknown').toString();

    Color getStatusBadgeColor() {
      switch (status) {
        case 'closed':
          return Colors.green;
        case 'active':
          return Colors.orange;
        default:
          return Colors.red;
      }
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Type and Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: $reportId',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: getStatusBadgeColor(),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusColor(status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description
              if (description.isNotEmpty)
                Text(
                  description,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              else
                const Text(
                  'No description',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              const SizedBox(height: 12),

              // Meta Information
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            reporterEmail.length > 15
                                ? '${reporterEmail.substring(0, 15)}...'
                                : reporterEmail,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (severity.isNotEmpty && severity != 'Not Set')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        severity,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Timestamp
              if (createdAt.isNotEmpty)
                Text(
                  _formatDate(createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final dateTime = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes} min ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }
}
