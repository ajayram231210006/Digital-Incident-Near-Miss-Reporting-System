import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'supervisor_reports_list.dart';
import 'supervisor_report_detail.dart';
import 'notification_settings.dart';

class SupervisorDashboard extends StatefulWidget {
  final User user;
  const SupervisorDashboard({super.key, required this.user});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  int _touchedIndex = -1;
  bool _isValidSupervisor = true;

  @override
  void initState() {
    super.initState();
    _validateSupervisorRole();
  }

  Future<void> _validateSupervisorRole() async {
    try {
      final userRole = await _dbRef.child('users').child(widget.user.uid).child('role').get();
      if (!mounted) return;
      setState(() {
        _isValidSupervisor = (userRole.value?.toString().toLowerCase() == 'supervisor');
      });
      if (!_isValidSupervisor) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unauthorized: Supervisor access required'),
            backgroundColor: Colors.red,
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      print('Error validating supervisor role: $e');
    }
  }

  Stream<Map<String, dynamic>> _getReportStatsStream() {
    return _dbRef.child('incidents').onValue.map((event) {
      if (!event.snapshot.exists) {
        return {
          'total': 0,
          'open': 0,
          'active': 0,
          'closed': 0,
          'high': 0,
          'medium': 0,
          'low': 0,
          'critical': 0,
          'notSet': 0,
          'recent': [],
          'overdue': [],
        };
      }

      int total = 0;
      int open = 0;
      int active = 0;
      int closed = 0;
      int high = 0;
      int medium = 0;
      int low = 0;
      int critical = 0;
      int notSet = 0;
      int now = DateTime.now().millisecondsSinceEpoch;
      Map<String, int> dailyIncidents = {};
      List<Map<String, dynamic>> recentIncidents = [];
      List<Map<String, dynamic>> overdueIncidents = [];

      final data = event.snapshot.value as Map?;
      if (data != null) {
        data.forEach((key, value) {
          if (value is Map) {
            total++;
            final status = (value['status'] ?? 'open').toString().toLowerCase();
            final severity = (value['severity'] ?? '').toString().toLowerCase();
            
            // Count by status
            if (status == 'closed') {
              closed++;
            } else if (status == 'active') {
              active++;
            } else {
              open++;
            }
            
            // Count by severity
            if (severity == 'high') {
              high++;
            } else if (severity == 'low') {
              low++;
            } else if (severity == 'critical') {
              critical++;
            } else if (severity == 'medium') {
              medium++;
            } else {
              notSet++;
            }
            
            // Extract reporter name - simplified with cleaner fallbacks
            var reporterName = _extractReporterName(value);
            
            // Extract image URL
            var imageUrl = value['imageUrl'] ?? '';

            // Collect recent incidents
            var ts = value['timestamp'] ?? value['createdAt'];
            int timestamp = ts is int ? ts : (int.tryParse(ts.toString()) ?? 0);
            recentIncidents.add({
              'id': key,
              'title': value['title'] ?? value['type'] ?? value['incidentType'] ?? 'Untitled',
              'description': value['description'] ?? '',
              'status': status,
              'priority': severity,
              'date': value['date'] ?? 'N/A',
              'timestamp': timestamp,
              'reporter': reporterName,
              'reporterEmail': value['reporterEmail'] ?? 'N/A',
              'location': value['location'] ?? 'N/A',
              'category': value['category'] ?? value['type'] ?? 'Incident',
              'type': value['type'] ?? value['incidentType'] ?? value['category'] ?? 'Incident',
              'imageUrl': imageUrl,
              'attachments': value['attachments'] ?? '',
              'createdAt': value['createdAt'] ?? value['timestamp'] ?? '',
            });

            // Identify overdue/critical incidents
            if (status != 'closed' && (severity == 'critical' || severity == 'high')) {
              overdueIncidents.add({
                'id': key,
                'title': value['title'] ?? value['type'] ?? value['incidentType'] ?? 'Untitled',
                'description': value['description'] ?? '',
                'status': status,
                'severity': severity,
                'date': value['date'] ?? 'N/A',
                'timestamp': timestamp,
                'reporter': reporterName,
                'reporterEmail': value['reporterEmail'] ?? 'N/A',
                'location': value['location'] ?? 'N/A',
                'category': value['category'] ?? value['type'] ?? 'Incident',
                'type': value['type'] ?? value['incidentType'] ?? value['category'] ?? 'Incident',
                'imageUrl': imageUrl,
                'attachments': value['attachments'] ?? '',
                'createdAt': value['createdAt'] ?? value['timestamp'] ?? '',
              });
            }
          }
        });
      }

      // Sort by timestamp (most recent first), then by date string if no timestamp
      recentIncidents.sort((a, b) {
        int timestampA = a['timestamp'] as int? ?? 0;
        int timestampB = b['timestamp'] as int? ?? 0;
        
        if (timestampA != 0 && timestampB != 0) {
          return timestampB.compareTo(timestampA);
        }
        return (b['date'] ?? '').compareTo(a['date'] ?? '');
      });
      recentIncidents = recentIncidents.take(3).toList();

      // Sort overdue by severity (critical first) then by timestamp
      overdueIncidents.sort((a, b) {
        if (a['severity'] == 'critical' && b['severity'] != 'critical') return -1;
        if (a['severity'] != 'critical' && b['severity'] == 'critical') return 1;
        int timestampA = a['timestamp'] as int? ?? 0;
        int timestampB = b['timestamp'] as int? ?? 0;
        return timestampB.compareTo(timestampA);
      });
      overdueIncidents = overdueIncidents.take(5).toList();

      // Calculate KPI metrics
      double resolutionRate = total > 0 ? (closed / total * 100) : 0;
      double openIncidentRate = total > 0 ? ((open + active) / total * 100) : 0;
      
      // Calculate daily incident trends for last 7 days
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailyIncidents[dateStr] = 0;
      }
      
      data?.forEach((key, value) {
        if (value is Map) {
          final status = (value['status'] ?? 'open').toString().toLowerCase();
          if (status == 'closed') {
            // Get creation time
            var createdTimestamp = value['timestamp'] ?? value['createdAt'] ?? 0;
            int createdTime = createdTimestamp is int 
              ? createdTimestamp 
              : (int.tryParse(createdTimestamp.toString()) ?? 0);
            
            // Get closure time (check multiple possible field names)
            var closedTimestamp = value['closedAt'] ?? 
                                 value['resolvedAt'] ?? 
                                 value['updatedAt'] ?? 
                                 value['statusChangedAt'] ?? 
                                 now;
            int closedTime = closedTimestamp is int 
              ? closedTimestamp 
              : (int.tryParse(closedTimestamp.toString()) ?? now);
            
            // Only count if we have valid times and closure time is after creation time
            if (createdTime > 0 && closedTime >= createdTime) {
              // Response time tracking for analytics
            }
          }
          
          // Count incident by creation date
          var tsValue = value['timestamp'] ?? value['createdAt'];
          int timestamp = tsValue is int ? tsValue : (int.tryParse(tsValue.toString()) ?? now);
          final incidentDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final dateStr = '${incidentDate.year}-${incidentDate.month.toString().padLeft(2, '0')}-${incidentDate.day.toString().padLeft(2, '0')}';
          if (dailyIncidents.containsKey(dateStr)) {
            dailyIncidents[dateStr] = (dailyIncidents[dateStr] ?? 0) + 1;
          }
        }
      });
      
      return {
        'total': total,
        'open': open,
        'active': active,
        'closed': closed,
        'high': high,
        'medium': medium,
        'low': low,
        'critical': critical,
        'notSet': notSet,
        'recent': recentIncidents,
        'overdue': overdueIncidents,
        'resolutionRate': resolutionRate,
        'openIncidentRate': openIncidentRate,
        'dailyTrends': dailyIncidents,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Supervisor Dashboard'),
        elevation: 2,
        shadowColor: Colors.grey.withOpacity(0.5),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            tooltip: 'Notification Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => NotificationSettings(user: widget.user),
                ),
              );
            },
            icon: const Icon(Icons.notifications_active),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _getReportStatsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final stats = snapshot.data ?? {};
          final totalReports = stats['total'] ?? 0;
          final openReports = stats['open'] ?? 0;
          final activeReports = stats['active'] ?? 0;
          final closedReports = stats['closed'] ?? 0;
          final highPriority = stats['high'] ?? 0;
          final mediumPriority = stats['medium'] ?? 0;
          final lowPriority = stats['low'] ?? 0;
          final criticalPriority = stats['critical'] ?? 0;
          final notSetPriority = stats['notSet'] ?? 0;
          final overdueIncidents = stats['overdue'] as List<dynamic>? ?? [];
          final resolutionRate = stats['resolutionRate'] as double? ?? 0.0;
          final openIncidentRate = stats['openIncidentRate'] as double? ?? 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Welcome ',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            TextSpan(
                              text: widget.user.displayName ?? widget.user.email?.split('@').first ?? 'Supervisor',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Here\'s your incident report overview',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // KPI Dashboard Cards Section
                Text(
                  'Key Performance Indicators',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    // Resolution Rate Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade400, Colors.green.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${resolutionRate.toStringAsFixed(1)}%',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Resolution Rate',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.85),
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // Open Incident Rate Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade400, Colors.orange.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${openIncidentRate.toStringAsFixed(1)}%',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Open Rate',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.85),
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Critical/Overdue Alerts Banner
                if (overdueIncidents.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade600, Colors.red.shade800],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '⚠️ ATTENTION NEEDED',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    '${overdueIncidents.length} critical or high-priority incident${overdueIncidents.length > 1 ? 's' : ''} require immediate attention',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...overdueIncidents.map((incident) {
                          final inc = incident as Map<String, dynamic>;
                          final severity = inc['severity'] ?? 'high';
                          final severityColor = severity == 'critical' ? Colors.yellow : Colors.orange;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () {
                                if (inc['id'] != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SupervisorReportDetail(
                                        reportId: inc['id'],
                                        report: inc,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: severityColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          inc['title'] ?? 'Untitled',
                                          style:
                                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Type: ${(inc['type'] ?? 'Incident').toUpperCase()}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Colors.white.withOpacity(0.85),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white.withOpacity(0.6),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                if (overdueIncidents.isNotEmpty)
                  const SizedBox(height: 24),

                // Real-time Notifications Section
                Text(
                  'Recent Incidents',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.blue.withOpacity(0.05),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((stats['recent'] as List<dynamic>? ?? []).isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              'No recent incidents',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else
                        ...((stats['recent'] as List<dynamic>? ?? []).map((inc) {
                          final incident = inc as Map<String, dynamic>;
                          final severity = incident['priority'] ?? 'low';
                          final severityColor = severity == 'critical'
                              ? Colors.red
                              : severity == 'high'
                                  ? Colors.deepOrange
                                  : severity == 'medium'
                                      ? Colors.orange
                                      : Colors.blue;
                          final statusColor = incident['status'] == 'open'
                              ? Colors.amber
                              : incident['status'] == 'active'
                                  ? Colors.orange
                                  : Colors.green;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: GestureDetector(
                              onTap: () {
                                if (incident['id'] != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SupervisorReportDetail(
                                        reportId: incident['id'],
                                        report: incident,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Title and Type
                                      Text(
                                        incident['title'] ?? 'Untitled',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Type: ${incident['type'] ?? 'Unknown'}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.grey[600],
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      
                                      // Status and Severity Pills
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    incident['status'] == 'closed'
                                                        ? Icons.check_circle
                                                        : incident['status'] == 'active'
                                                            ? Icons.schedule
                                                            : Icons.radio_button_unchecked,
                                                    color: statusColor,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    incident['status']?.toString().toUpperCase() ?? 'OPEN',
                                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                          color: statusColor,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: severityColor.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    severity == 'critical'
                                                        ? Icons.error
                                                        : severity == 'high'
                                                            ? Icons.warning
                                                            : Icons.info,
                                                    color: severityColor,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    severity.toUpperCase(),
                                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                          color: severityColor,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                  ),
                                                ],
                                              ),
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
                        }).toList()),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Incident Trends Chart Section
                Text(
                  'Incident Trends (Last 7 Days)',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: _buildIncidentTrendsChart(stats['dailyTrends'] as Map<String, dynamic>? ?? {}),
                ),
                const SizedBox(height: 28),

                Text(
                  'Incident Status Distribution',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      _buildStatusPieChart(openReports, activeReports, closedReports),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildLegendItem('Open', Colors.amber, openReports),
                          _buildLegendItem('Active', Colors.orange, activeReports),
                          _buildLegendItem('Closed', Colors.green, closedReports),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Report Statistics Header
                Text(
                  'Report Statistics',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                // Status Statistics - Text-based Layout
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.withOpacity(0.05),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatisticTextRow('Total Reports', totalReports, Colors.blue, () => _navigateToReports(context, 'all')),
                      const SizedBox(height: 12),
                      _buildStatisticTextRow('Awaiting Review', openReports, Colors.amber, () => _navigateToReports(context, 'open')),
                      const SizedBox(height: 12),
                      _buildStatisticTextRow('In Progress', activeReports, Colors.orange, () => _navigateToReports(context, 'active')),
                      const SizedBox(height: 12),
                      _buildStatisticTextRow('Closed', closedReports, Colors.green, () => _navigateToReports(context, 'closed')),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Priority Distribution Header - NEW SECTION
                Text(
                  'Priority Distribution',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                // Priority Statistics - Text-based Layout
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.withOpacity(0.05),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatisticTextRow('Not Set', notSetPriority, Colors.grey, () => _navigateToBySeverity(context, 'notset')),
                      const SizedBox(height: 12),
                      _buildStatisticTextRow('Low', lowPriority, Colors.blue, () => _navigateToBySeverity(context, 'low')),
                      const SizedBox(height: 12),
                      _buildStatisticTextRow('Medium', mediumPriority, Colors.orange, () => _navigateToBySeverity(context, 'medium')),
                      const SizedBox(height: 12),
                      _buildStatisticTextRow('High', highPriority, Colors.orange, () => _navigateToBySeverity(context, 'high')),
                      const SizedBox(height: 12),
                      _buildStatisticTextRow('Critical', criticalPriority, Colors.red, () => _navigateToBySeverity(context, 'critical')),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusPieChart(int open, int active, int closed) {
    final total = open + active + closed;
    if (total == 0) {
      return SizedBox(
        height: 250,
        child: Center(
          child: Text(
            'No incidents to display',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              if (!event.isInterestedForInteractions || pieTouchResponse == null) {
                if (_touchedIndex != -1) {
                  setState(() {
                    _touchedIndex = -1;
                  });
                }
                return;
              }
              final newTouchedIndex = pieTouchResponse.touchedSection?.touchedSectionIndex ?? -1;
              if (_touchedIndex != newTouchedIndex) {
                setState(() {
                  _touchedIndex = newTouchedIndex;
                });
              }
            },
          ),
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: [
            PieChartSectionData(
              color: Colors.amber,
              value: open.toDouble(),
              title: '$open',
              radius: _touchedIndex == 0 ? 70 : 60,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              color: Colors.orange,
              value: active.toDouble(),
              title: '$active',
              radius: _touchedIndex == 1 ? 70 : 60,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              color: Colors.green,
              value: closed.toDouble(),
              title: '$closed',
              radius: _touchedIndex == 2 ? 70 : 60,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentTrendsChart(Map<String, dynamic> dailyTrends) {
    if (dailyTrends.isEmpty) {
      return SizedBox(
        height: 250,
        child: Center(
          child: Text(
            'No incident data available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ),
      );
    }

    // Convert daily trends to list of FlSpot for chart
    final sortedDates = dailyTrends.keys.toList()..sort();
    final List<FlSpot> spots = [];
    for (int i = 0; i < sortedDates.length; i++) {
      final count = (dailyTrends[sortedDates[i]] as int?) ?? 0;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
    }

    // Find max value for Y axis
    final maxValue = spots.isEmpty ? 10.0 : spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final yAxisMax = (maxValue + 2).ceilToDouble();

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: (yAxisMax / 5).roundToDouble(),
                verticalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.2),
                    strokeWidth: 1,
                  );
                },
                getDrawingVerticalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.15),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < sortedDates.length) {
                        final dateStr = sortedDates[index];
                        final parts = dateStr.split('-');
                        if (parts.length == 3) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${parts[2]}/${parts[1]}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                      }
                      return const Text('');
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(
                  color: Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
              ),
              minX: 0,
              maxX: (sortedDates.length - 1).toDouble(),
              minY: 0,
              maxY: yAxisMax,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.blue.shade500,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percentageOffset, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Colors.blue.shade600,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blue.withOpacity(0.15),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipBorder: const BorderSide(color: Colors.white),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
                    return lineBarsSpot.map((lineBarSpot) {
                      if (lineBarSpot.x.toInt() < sortedDates.length) {
                        final dateStr = sortedDates[lineBarSpot.x.toInt()];
                        return LineTooltipItem(
                          '${dateStr}\n${lineBarSpot.y.toInt()} incidents',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }
                      return null;
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.blue.shade500,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Shows incident creation trend over the last 7 days',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue.shade700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticTextRow(String label, int count, Color color, VoidCallback onTap) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.grey.withOpacity(0.1),
            highlightColor: Colors.grey.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        count.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey.withOpacity(0.5),
                        size: 20,
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
        ),
      ],
    );
  }





  void _navigateToReports(BuildContext context, String filter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupervisorReportsList(
          user: widget.user,
          filterStatus: filter == 'all' ? '' : filter,
        ),
      ),
    );
  }

  void _navigateToBySeverity(BuildContext context, String severity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupervisorReportsList(
          user: widget.user,
          filterSeverity: severity == 'notset' ? '' : severity,
        ),
      ),
    );
  }

  // ===== REFACTORED BUILD HELPER METHODS =====





  // ===== NEW SUPERVISOR FUNCTIONS =====
  
  String _extractReporterName(dynamic value) {
    // Simplified reporter name extraction with cleaner fallbacks
    if (value is Map) {
      return value['reporter'] ?? 
             value['reporterName'] ?? 
             value['reportedBy'] ?? 
             (value['reporterInfo'] is Map ? value['reporterInfo']['name'] : null) ??
             'Unknown';
    }
    return 'Unknown';
  }

  Stream<List<Map<String, dynamic>>> getAssignedIncidentsForSupervisor() {
    return _dbRef.child('incidents').onValue.map((event) {
      List<Map<String, dynamic>> assigned = [];
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map?;
        data?.forEach((key, value) {
          if (value is Map && value['assignedBy'] == widget.user.uid) {
            assigned.add({
              'id': key,
              'title': value['title'] ?? 'Untitled',
              'status': value['status'] ?? 'open',
              'assignedTo': value['assignedTo'] ?? 'Unassigned',
              'createdAt': value['createdAt'] ?? 0,
            });
          }
        });
      }
      return assigned;
    });
  }

  Stream<List<Map<String, dynamic>>> getOverdueIncidents() {
    return _dbRef.child('incidents').onValue.map((event) {
      List<Map<String, dynamic>> overdue = [];
      if (event.snapshot.exists) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final oneDayMs = 24 * 60 * 60 * 1000;
        final data = event.snapshot.value as Map?;
        
        data?.forEach((key, value) {
          if (value is Map) {
            final status = value['status']?.toString().toLowerCase() ?? 'open';
            final severity = value['severity']?.toString().toLowerCase() ?? '';
            final createdTime = (value['timestamp'] ?? value['createdAt']) as int? ?? 0;
            final ageMs = now - createdTime;
            
            // Mark as overdue if: not closed AND (critical OR (high/medium and over 1 day old))
            final isCritical = severity == 'critical';
            final isHighPriority = severity == 'high' || severity == 'medium';
            final isOldEnough = ageMs > oneDayMs;
            
            if (status != 'closed' && (isCritical || (isHighPriority && isOldEnough))) {
              overdue.add({
                'id': key,
                'title': value['title'] ?? 'Untitled',
                'status': status,
                'severity': severity,
                'ageHours': (ageMs / (60 * 60 * 1000)).toStringAsFixed(1),
              });
            }
          }
        });
      }
      return overdue;
    });
  }
}




