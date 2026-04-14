import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'app_features.dart';
import 'image_viewer.dart';
import 'incident_service.dart';
import 'notification_service.dart';
import 'review_notification_formatter.dart';
import 'ui_components.dart';

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
  final IncidentService _incidentService = IncidentService();
  final NotificationService _notificationService = NotificationService();
  late String _status;
  late String _severity;
  late String _notes;
  final _notesController = TextEditingController();
  bool _saving = false;
  bool _hasChanges = false;

  bool _isPermissionDeniedError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('permission denied') ||
        message.contains('permission_denied');
  }

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

  bool _computeHasChanges({String? status, String? severity, String? notes}) {
    final originalStatus = (widget.report['status'] ?? 'open')
        .toString()
        .toLowerCase();
    final originalSeverity = (widget.report['severity'] ?? '')
        .toString()
        .toLowerCase();
    final originalNotes = (widget.report['notes'] ?? '').toString().trim();

    return originalStatus != (status ?? _status) ||
        originalSeverity != (severity ?? _severity) ||
        originalNotes != (notes ?? _notesController.text).trim();
  }

  Future<void> _markIncidentAsRead() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _notificationService.markIncidentAsReadBySupervisor(
          currentUser.uid,
          widget.reportId,
        );
      }
    } catch (e) {
      // Silent fail
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
      // Silent fail
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!mounted) return;
    if (!_computeHasChanges()) {
      showAppSnackBar(
        context,
        'No changes to save yet.',
        type: AppSnackBarType.info,
      );
      return;
    }
    setState(() => _saving = true);
    var notificationWarning = false;
    var notificationWarningMessage = '';
    var successMessage = 'Report updated successfully.';
    try {
      // Get the original status, severity, and notes to check if they changed
      final originalStatus = (widget.report['status'] ?? 'open')
          .toString()
          .toLowerCase();
      final originalSeverity = (widget.report['severity'] ?? '')
          .toString()
          .toLowerCase();
      final originalNotes = (widget.report['notes'] ?? '').toString().trim();
      final newNotes = _notesController.text.trim();
      final statusChanged = originalStatus != _status;
      final severityChanged =
          originalSeverity != _severity && _severity.isNotEmpty;
      final notesChanged = originalNotes != newNotes;
      final notesAdded = notesChanged && newNotes.isNotEmpty;

      await _incidentService.updateIncidentReview(
        incidentId: widget.reportId,
        update: IncidentReviewUpdate(
          status: _status,
          severity: _severity,
          notes: newNotes,
        ),
      );

      widget.report['status'] = _status;
      widget.report['severity'] = _severity;
      widget.report['notes'] = newNotes;

      if (!mounted) return;

      // Get reporter UID - try multiple possible field names
      var reporterUid = '';

      // Try different possible field names from widget.report
      final possibleUidFields = [
        'reporterUid',
        'reporterId',
        'uid',
        'createdBy',
      ];
      for (final field in possibleUidFields) {
        final value = widget.report[field];
        if (value != null) {
          reporterUid = value.toString().trim();
          if (reporterUid.isNotEmpty) break;
        }
      }

      // If still not found, try loading from Firebase directly
      if (reporterUid.isEmpty) {
        debugPrint(
          '⚠️ Reporter UID not found in widget.report, trying Firebase...',
        );
        try {
          final snapshot = await _dbRef
              .child('incidents/${widget.reportId}')
              .get();
          if (snapshot.exists) {
            final incidentData = snapshot.value as Map?;
            if (incidentData != null) {
              reporterUid = (incidentData['reporterUid'] ?? '')
                  .toString()
                  .trim();
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error loading reporter UID from Firebase: $e');
        }
      }

      if (reporterUid.isEmpty) {
        debugPrint(
          '⚠️ Available report fields: ${widget.report.keys.toList()}',
        );
      }
      debugPrint(
        '🔍 Reporter UID extracted: $reporterUid (length: ${reporterUid.length})',
      );

      final reportType = widget.report['type'] ?? 'Report';
      final supervisorName =
          FirebaseAuth.instance.currentUser?.displayName ??
          FirebaseAuth.instance.currentUser?.email?.split('@').first ??
          'Supervisor';
      final reviewNotification = ReviewNotificationFormatter.build(
        reportId: widget.reportId,
        reportType: reportType.toString(),
        supervisorName: supervisorName,
        statusChanged: statusChanged,
        status: _status,
        severityChanged: severityChanged,
        severity: _severity,
        notesAdded: notesAdded,
        notePreview: notesAdded
            ? (newNotes.length > 80
                  ? '${newNotes.substring(0, 80)}...'
                  : newNotes)
            : null,
      );

      if (reviewNotification != null) {
        debugPrint(
          '🔔 Sending one combined reporter notification for this review action',
        );
        try {
          if (reporterUid.isNotEmpty) {
            await _notificationService.saveNotificationForUser(
              userId: reporterUid,
              notificationData: {
                'title': reviewNotification.reporterMessage.title,
                'body': reviewNotification.reporterMessage.body,
                'reportId': widget.reportId,
                'reportType': reportType,
                'status': _status,
                'severity': _severity,
                'supervisorName': supervisorName,
                'timestamp': DateTime.now().toIso8601String(),
                'read': false,
              },
              dedupeKey: reviewNotification.reporterMessage.dedupeKey,
            );
          }

          await _notificationService.notifyAllReportersOnUpdate(
            reportId: widget.reportId,
            reportType: reportType,
            description: widget.report['description'] ?? '',
            status: _status,
            severity: _severity,
            supervisorName: supervisorName,
            notificationTitle: reviewNotification.broadcastMessage.title,
            notificationBody: reviewNotification.broadcastMessage.body,
            excludeReporterUid: reporterUid.isNotEmpty ? reporterUid : null,
            dedupeKey: reviewNotification.broadcastMessage.dedupeKey,
          );
        } catch (notificationError) {
          notificationWarning = true;
          notificationWarningMessage =
              _isPermissionDeniedError(notificationError)
              ? 'Report updated, but notification delivery permissions were denied.'
              : 'Report updated, but the notification could not be sent.';
          debugPrint(
            '⚠️ Combined review notification failed: $notificationError',
          );
        }

        successMessage = reporterUid.isNotEmpty
            ? 'Report updated and notifications were sent.'
            : 'Report updated. Reporter notification was skipped because the reporter ID was missing.';
      }

      // Send notification if notes were added
      if (notesAdded) {
        // Get additional report details for better notification formatting
        final reportTitle = widget.report['description'] ?? reportType;
        final location = widget.report['location'] ?? 'Unknown Location';
        final notePreview = newNotes.length > 80
            ? '${newNotes.substring(0, 80)}...'
            : newNotes;

        try {
          await _notificationService.notifySupervisorsOnNoteAdded(
            reportId: widget.reportId,
            reportType: reportType,
            reportTitle: reportTitle,
            location: location,
            supervisorName: supervisorName,
            notePreview: notePreview,
            severity: _severity,
          );
        } catch (notificationError) {
          notificationWarning = true;
          notificationWarningMessage =
              _isPermissionDeniedError(notificationError)
              ? 'Report updated, but notification delivery permissions were denied.'
              : 'Report updated, but the note notification could not be sent.';
          debugPrint('⚠️ Note notification failed: $notificationError');
        }
      }

      if (mounted) {
        setState(() => _hasChanges = false);
        showAppSnackBar(
          context,
          notificationWarning ? notificationWarningMessage : successMessage,
          type: notificationWarning
              ? AppSnackBarType.info
              : AppSnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating report: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Convert Firebase Map to List (Firebase stores lists as Maps with numeric keys)
    final imageParams = widget.report['imageUrls'];
    final imageUrlsList = imageParams is List
        ? List<String>.from(imageParams.whereType<String>())
        : imageParams is Map
        ? imageParams.values.whereType<String>().toList()
        : <String>[];

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_hasChanges && _saving == false) {
          final shouldPop =
              await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Discard changes?'),
                  content: const Text('You have unsaved changes.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Discard'),
                    ),
                  ],
                ),
              ) ??
              false;
          if (shouldPop) {
            if (context.mounted) Navigator.pop(context);
          }
        } else {
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: _buildScaffold(imageUrlsList),
    );
  }

  Widget _buildScaffold(List<String> imageUrlsList) {
    final aiAnalysis = widget.report['aiAnalysis'] is Map
        ? Map<String, dynamic>.from(widget.report['aiAnalysis'] as Map)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Incident Details'),
        elevation: 2,
        backgroundColor: AppColors.primary,
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
                borderRadius: AppRadii.large,
                color: AppColors.surfaceRaised,
                border: Border.all(color: AppColors.outline, width: 1),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.info.withValues(alpha: 0.1),
                                borderRadius: AppRadii.small,
                              ),
                              child: Text(
                                (widget.report['type'] ?? 'Unknown')
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.info,
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
                                color: AppColors.textPrimary,
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
                          color: AppStatus.resolve(
                            _status,
                          ).color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppStatus.resolve(
                              _status,
                            ).color.withValues(alpha: 0.3),
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
                    style: const TextStyle(
                      color: AppColors.textSecondary,
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
                borderRadius: AppRadii.large,
                color: AppColors.surfaceRaised,
                border: Border.all(color: AppColors.outline, width: 1),
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
                          AppColors.info,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoTile(
                          'Reporter',
                          (widget.report['reporterEmail'] as String?)
                                  ?.split('@')
                                  .first ??
                              'Unknown',
                          Icons.person,
                          AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    'Description',
                    widget.report['description'] ?? 'No description provided',
                    Icons.description,
                    AppColors.statusOpen,
                    isExpanded: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Image Section (if available)
            if (imageUrlsList.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incident Photos (${imageUrlsList.length})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: imageUrlsList.length,
                      itemBuilder: (context, index) {
                        final imageUrl = imageUrlsList[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ImageViewer(
                                  imageUrl: imageUrl,
                                  title: 'Incident Image ${index + 1}',
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.error),
                                      ),
                                    );
                                  },
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else if (widget.report['imageUrl'] != null &&
                (widget.report['imageUrl'] as String).isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
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
                                  color: Colors.black.withValues(alpha: 0.1),
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
            ],

            const SizedBox(height: 20),

            // Video Section (if available)
            if (widget.report['videoUrl'] != null &&
                (widget.report['videoUrl'] as String).isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incident Video',
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
                              imageUrl: widget.report['videoUrl'],
                              title: 'Incident Video',
                              isVideo: true,
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
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              color: Colors.black87,
                            ),
                            width: double.infinity,
                            height: 220,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.video_library,
                                  size: 64,
                                  color: Colors.orange.shade300,
                                ),
                                Positioned(
                                  right: 12,
                                  bottom: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.fiber_manual_record,
                                          color: Colors.white,
                                          size: 8,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Tap to play',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            if (kAiAnalysisEnabled && aiAnalysis != null) ...[
              _buildAiAnalysisCard(aiAnalysis),
              const SizedBox(height: 20),
            ],

            // Management Controls Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[200]!, width: 1),
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
                        final nextStatus = newSelection.first;
                        setState(() {
                          _status = nextStatus;
                          _hasChanges = _computeHasChanges(status: nextStatus);
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
                                Text(
                                  'Critical',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      selected: {_severity},
                      onSelectionChanged: (Set<String> newSelection) {
                        final nextSeverity = newSelection.first;
                        setState(() {
                          _severity = nextSeverity;
                          _hasChanges = _computeHasChanges(
                            severity: nextSeverity,
                          );
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
                borderRadius: AppRadii.large,
                border: Border.all(color: AppColors.outline, width: 1),
                color: AppColors.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.note_outlined,
                        color: AppColors.secondary,
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
                    onChanged: (value) {
                      setState(() {
                        _hasChanges = _computeHasChanges(notes: value);
                      });
                    },
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Add your observations and actions taken...',
                      border: OutlineInputBorder(
                        borderRadius: AppRadii.medium,
                        borderSide: const BorderSide(color: AppColors.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadii.medium,
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceRaised,
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
                onPressed: (_saving || !_hasChanges) ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.outline,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: AppRadii.medium),
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  _saving
                      ? 'Saving...'
                      : _hasChanges
                      ? 'Save Changes'
                      : 'No Changes Yet',
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

  Widget _buildAiAnalysisCard(Map<String, dynamic> aiAnalysis) {
    final status = (aiAnalysis['status'] ?? 'pending').toString().toLowerCase();
    final suggestedSeverity = (aiAnalysis['suggestedSeverity'] ?? '')
        .toString()
        .toLowerCase();
    final category = (aiAnalysis['category'] ?? '').toString();
    final summary = (aiAnalysis['summary'] ?? '').toString();
    final confidenceValue = aiAnalysis['confidence'];
    final confidence = confidenceValue is num
        ? confidenceValue.toDouble()
        : null;
    final recommendedActions = _asStringList(aiAnalysis['recommendedActions']);
    final riskFactors = _asStringList(aiAnalysis['riskFactors']);
    final missingFields = _asStringList(aiAnalysis['missingFields']);
    final disabledReason = (aiAnalysis['reason'] ?? '').toString();

    final statusColor = status == 'completed'
        ? AppColors.secondary
        : status == 'failed'
        ? AppColors.error
        : status == 'disabled'
        ? AppColors.textSecondary
        : status == 'processing'
        ? AppColors.statusOpen
        : AppColors.primaryDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: statusColor.withValues(alpha: 0.08),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: statusColor),
              const SizedBox(width: 8),
              Text(
                'AI Suggestions',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            kAiAnalysisEnabled
                ? 'AI output is advisory only. Supervisor review still decides the final severity and action.'
                : 'AI suggestions are currently turned off. Supervisor review remains the source of truth for severity and action.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (status == 'completed') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    'Suggested Severity',
                    suggestedSeverity.isEmpty
                        ? 'Not available'
                        : suggestedSeverity.toUpperCase(),
                    Icons.priority_high,
                    AppColors.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoTile(
                    'Category',
                    category.isEmpty ? 'Not available' : category,
                    Icons.sell_outlined,
                    AppColors.secondary,
                  ),
                ),
              ],
            ),
            if (suggestedSeverity.isNotEmpty &&
                suggestedSeverity != _severity) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _severity = suggestedSeverity;
                      _hasChanges = _computeHasChanges(
                        severity: suggestedSeverity,
                      );
                    });
                  },
                  icon: const Icon(Icons.bolt_outlined, size: 18),
                  label: Text(
                    _severity.isEmpty
                        ? 'Use AI suggested severity'
                        : 'Replace with AI suggested severity',
                  ),
                ),
              ),
            ],
            if (confidence != null) ...[
              const SizedBox(height: 12),
              _buildInfoTile(
                'Confidence',
                '${(confidence * 100).toStringAsFixed(0)}%',
                Icons.analytics_outlined,
                AppColors.primaryDark,
              ),
            ],
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoTile(
                'Summary',
                summary,
                Icons.summarize_outlined,
                AppColors.info,
                isExpanded: true,
              ),
            ],
            if (recommendedActions.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildAiBulletBlock('Recommended Actions', recommendedActions),
            ],
            if (riskFactors.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildAiBulletBlock('Risk Factors', riskFactors),
            ],
            if (missingFields.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildAiBulletBlock('Missing Information', missingFields),
            ],
          ] else if (status == 'failed') ...[
            const SizedBox(height: 12),
            Text(
              (aiAnalysis['error'] ?? 'The AI analysis could not be generated.')
                  .toString(),
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ] else if (status == 'disabled' || !kAiAnalysisEnabled) ...[
            const SizedBox(height: 12),
            Text(
              disabledReason.isNotEmpty
                  ? disabledReason
                  : 'AI suggestions are temporarily unavailable while backend deployment is disabled.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'The report has been queued for AI review. Suggestions will appear here after processing.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiBulletBlock(String title, List<String> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.medium,
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('* '),
                  Expanded(
                    child: Text(item, style: const TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is Map) {
      return value.values
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
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
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
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
                  color: AppColors.textSecondary,
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
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Icon _getStatusIcon(String status) {
    final resolved = AppStatus.resolve(status);
    return Icon(resolved.icon, color: Colors.white, size: 28);
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
