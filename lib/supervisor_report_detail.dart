import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'image_viewer.dart';
import 'notification_service.dart';

class SupervisorReportDetail extends StatefulWidget {
  final String reportId;
  final Map<String, dynamic> report;

  const SupervisorReportDetail({
    super.key,
    required this.reportId,
    required this.report,
  });

  @override
  State<SupervisorReportDetail> createState() => _SupervisorReportDetailState();
}

class _SupervisorReportDetailState extends State<SupervisorReportDetail> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final NotificationService _notificationService = NotificationService();
  late String _status;
  late String _severity;
  late String _notes;
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = (widget.report['status'] ?? 'open').toString().toLowerCase();
    _severity = (widget.report['severity'] ?? '').toString().toLowerCase();
    _notes = widget.report['notes'] ?? '';
    _notesController.text = _notes;
    _loadLatestNotes();
    _markIncidentAsRead();
  }

  Future<void> _markIncidentAsRead() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _notificationService.markIncidentAsReadBySupervisor(
          currentUser.uid,
          widget.reportId,
        );
        print('✅ Report marked as read for supervisor');
      }
    } catch (e) {
      print('❌ Error marking report as read: $e');
    }
  }

  Future<void> _loadLatestNotes() async {
    try {
      final snapshot = await _dbRef.child('incidents/${widget.reportId}').get();
      if (snapshot.exists && mounted) {
        final data = snapshot.value as Map?;
        if (data != null) {
          final latestNotes = data['notes'] ?? '';
          setState(() {
            _notes = latestNotes;
            _notesController.text = latestNotes;
          });
        }
      }
    } catch (e) {
      print('Error loading notes: $e');
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);
    try {
      // Get the original status, severity, and notes to check if they changed
      final originalStatus = (widget.report['status'] ?? 'open').toString().toLowerCase();
      final originalSeverity = (widget.report['severity'] ?? '').toString().toLowerCase();
      final originalNotes = (widget.report['notes'] ?? '').toString().trim();
      final newNotes = _notesController.text.trim();
      final notesChanged = originalNotes != newNotes;

      print('📝 Saving changes - Status: $originalStatus→$_status, Severity: $originalSeverity→$_severity, Notes changed: $notesChanged');
      
      // Update the report
      await _dbRef.child('incidents/${widget.reportId}').update({
        'status': _status,
        'severity': _severity,
        'notes': newNotes,
        'lastModified': DateTime.now().toIso8601String(),
      });

      final reporterUid = widget.report['reporterUid']?.toString();
      final reportType = widget.report['type'] ?? 'Report';
      final supervisorName = FirebaseAuth.instance.currentUser?.displayName ?? 
                             FirebaseAuth.instance.currentUser?.email?.split('@').first ?? 
                             'Supervisor';

      print('📋 Report Details - ReporterUID: $reporterUid, Type: $reportType, Supervisor: $supervisorName');

      // Send notification if status or severity changed
      if (originalStatus != _status || originalSeverity != _severity) {
        if (reporterUid != null && reporterUid.isNotEmpty) {
          print('🔔 Notifying reporter of status/severity change');
          
          // Create detailed notification message based on changes
          String notificationTitle = '';
          String notificationBody = '';
          
          if (originalStatus != _status && originalSeverity != _severity) {
            // Both changed
            notificationTitle = 'Status & Severity Updated';
            notificationBody = '$supervisorName updated your $reportType status to ${_status.toUpperCase()} and severity to ${_severity.toUpperCase()}';
          } else if (originalStatus != _status) {
            // Only status changed
            notificationTitle = 'Status Updated: ${_status.toUpperCase()}';
            notificationBody = '$supervisorName updated your $reportType status to ${_status.toUpperCase()}';
          } else if (originalSeverity != _severity && _severity.isNotEmpty) {
            // Only severity changed
            notificationTitle = 'Severity Updated: ${_severity.toUpperCase()}';
            notificationBody = '$supervisorName updated your $reportType severity to ${_severity.toUpperCase()}';
          }
          
          if (notificationTitle.isNotEmpty && notificationBody.isNotEmpty) {
            // Save custom notification with detailed information
            final notificationData = {
              'title': notificationTitle,
              'body': notificationBody,
              'reportId': widget.reportId,
              'reportType': reportType,
              'status': _status,
              'severity': _severity,
              'supervisorName': supervisorName,
              'timestamp': DateTime.now().toIso8601String(),
              'read': false,
            };

            await _dbRef
                .child('userNotifications')
                .child(reporterUid)
                .push()
                .set(notificationData);
            print('✅ Reporter notified about status/severity change: $notificationTitle');
          }
        } else {
          print('⚠️ Reporter UID is null or empty! Cannot notify reporter.');
        }
      }

      // Send notification if notes were added
      if (notesChanged && newNotes.isNotEmpty) {
        print('📝 Notes changed - notifying reporter and supervisors');
        
        // Get additional report details for better notification formatting
        final reportTitle = widget.report['description'] ?? reportType;
        final location = widget.report['location'] ?? 'Unknown Location';
        final notePreview = newNotes.length > 80 
            ? '${newNotes.substring(0, 80)}...' 
            : newNotes;
        
        print('📋 Notification details - Title: $reportTitle, Location: $location');
        
        // Notify reporter about notes added
        if (reporterUid != null && reporterUid.isNotEmpty) {
          final reporterNoteNotificationData = {
            'title': 'Notes Added: $reportType',
            'body': '$supervisorName added notes to your report "$reportTitle": "$notePreview"',
            'reportId': widget.reportId,
            'reportType': reportType,
            'reportTitle': reportTitle,
            'location': location,
            'supervisorName': supervisorName,
            'timestamp': DateTime.now().toIso8601String(),
            'read': false,
          };

          await _dbRef
              .child('userNotifications')
              .child(reporterUid)
              .push()
              .set(reporterNoteNotificationData);
          
          print('✅ Reporter notified about notes: $reportTitle');
        }

        // Notify supervisors about notes added
        await _notificationService.notifySupervisorsOnNoteAdded(
          reportId: widget.reportId,
          reportType: reportType,
          reportTitle: reportTitle,
          location: location,
          supervisorName: supervisorName,
          notePreview: notePreview,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report updated successfully')),
        );
      }
    } catch (e) {
      print('❌ Error during save: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Incident Details'),
        elevation: 2,
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section with Title and Badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[50],
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                (widget.report['type'] ?? 'Unknown').toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.report['location'] ?? 'Location Unknown',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: _getStatusIcon(_status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Reported: ${_formatDate(widget.report['createdAt'])}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Key Information Grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[50],
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Incident Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoTile(
                          'Date',
                          _formatDate(widget.report['date']),
                          Icons.calendar_today,
                          Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoTile(
                          'Reporter',
                          (widget.report['reporterEmail'] as String?)?.split('@').first ?? 'Unknown',
                          Icons.person,
                          Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    'Description',
                    widget.report['description'] ?? 'No description provided',
                    Icons.description,
                    Colors.orangeAccent,
                    isExpanded: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Image Section (if available)
            if (widget.report['imageUrl'] != null &&
                (widget.report['imageUrl'] as String).isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incident Photo',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ImageViewer(
                              imageUrl: widget.report['imageUrl'],
                              title: 'Incident Image',
                            ),
                          ),
                        );
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Image.network(
                              widget.report['imageUrl'],
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 220,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Text('Failed to load image'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Management Controls Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[50],
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Incident',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 20),

                  // Status Selection
                  Text(
                    'Current Status',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'open',
                          label: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.radio_button_unchecked, size: 16),
                                SizedBox(width: 4),
                                Text('Open', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        ButtonSegment(
                          value: 'active',
                          label: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.hourglass_bottom, size: 16),
                                SizedBox(width: 4),
                                Text('Active', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        ButtonSegment(
                          value: 'closed',
                          label: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 16),
                                SizedBox(width: 4),
                                Text('Closed', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      selected: {_status},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _status = newSelection.first;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Severity Selection with Color Coding
                  Text(
                    'Severity Level',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: '',
                          label: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.block, size: 16),
                                SizedBox(width: 4),
                                Text('Not Set', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        ButtonSegment(
                          value: 'low',
                          label: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.trending_down, size: 16),
                                SizedBox(width: 4),
                                Text('Low', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        ButtonSegment(
                          value: 'medium',
                          label: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.trending_flat, size: 16),
                                SizedBox(width: 4),
                                Text('Medium', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        ButtonSegment(
                          value: 'high',
                          label: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.trending_up, size: 16),
                                SizedBox(width: 4),
                                Text('High', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        ButtonSegment(
                          value: 'critical',
                          label: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.crisis_alert, size: 16),
                                SizedBox(width: 4),
                                Text('Critical', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      selected: {_severity},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _severity = newSelection.first;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Notes Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.note_outlined,
                        color: Colors.tealAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Supervisor Notes',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Add your observations and actions taken...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.blueAccent,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  shadowColor: Colors.blue.withOpacity(0.3),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  _saving ? 'Saving...' : 'Save Changes',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isExpanded = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.08),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: isExpanded ? 4 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isExpanded ? 13 : 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Icon _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'closed':
        return const Icon(Icons.task_alt, color: Colors.white, size: 28);
      case 'active':
        return const Icon(Icons.loop, color: Colors.white, size: 28);
      case 'open':
      default:
        return const Icon(Icons.radio_button_unchecked, color: Colors.white, size: 28);
    }
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null || dateString.toString().isEmpty) {
      return 'Unknown';
    }
    try {
      final date = DateTime.parse(dateString.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

}


