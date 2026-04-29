import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'app_theme.dart';
import 'incident_ai_service.dart';
import 'incident_media_service.dart';
import 'incident_service.dart';
import 'notification_service.dart';
import 'offline_incident_queue_service.dart';
import 'reporter_identity.dart';
import 'ui_components.dart';

class ReportIncidentForm extends StatefulWidget {
  final ReporterIdentity reporter;
  final bool forceOffline;

  const ReportIncidentForm({
    super.key,
    required this.reporter,
    this.forceOffline = false,
  });

  @override
  State<ReportIncidentForm> createState() => _ReportIncidentFormState();
}

class _ReportIncidentFormState extends State<ReportIncidentForm> {
  static const List<String> _departmentOptions = [
    'Production',
    'Maintenance',
    'Warehouse',
    'Quality',
    'Safety',
    'Logistics',
    'Administration',
    'HR',
    'Security',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _typeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _picker = ImagePicker();
  final _notificationService = NotificationService();
  final _incidentService = IncidentService();
  final _incidentAiService = IncidentAiService();
  final _incidentMediaService = const IncidentMediaService();
  final _offlineQueueService = OfflineIncidentQueueService();

  DateTime _incidentDate = DateTime.now();
  final List<File> _imageFiles = [];
  File? _videoFile;
  bool _submitting = false;
  bool _gettingLocation = false;
  Position? _currentPosition;
  String? _autoLocationName;
  String? _selectedDepartment;

  String get _formattedCoordinates {
    final position = _currentPosition;
    if (position == null) {
      return '';
    }
    return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
  }

  bool get _hasManualLocation => _locationController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _typeController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _offlineQueueService.dispose();
    super.dispose();
  }

  void _runAiAnalysisInBackground({
    required String incidentId,
    required IncidentDraft incidentDraft,
  }) {
    unawaited(
      _incidentAiService.analyzeIncident(
        incidentId: incidentId,
        draft: incidentDraft,
      ),
    );
  }

  Future<void> _pickImage() async {
    final pickedFiles = await _picker.pickMultiImage(maxWidth: 1200);
    if (pickedFiles.isEmpty) return;
    setState(() {
      _imageFiles.addAll(pickedFiles.map((file) => File(file.path)));
    });
  }

  Future<void> _takePhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
    );
    if (picked == null) return;
    setState(() => _imageFiles.add(File(picked.path)));
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (picked == null) return;
    setState(() => _videoFile = File(picked.path));
  }

  Future<void> _recordVideo() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 5),
    );
    if (picked == null) return;
    setState(() => _videoFile = File(picked.path));
  }

  Future<String?> _uploadImageToCloudinary(File file) async {
    try {
      return await _incidentMediaService.uploadImage(file);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Image upload failed. Please try a different file.',
          type: AppSnackBarType.error,
        );
      }
      return null;
    }
  }

  Future<String?> _uploadVideoToCloudinary(File file) async {
    try {
      return await _incidentMediaService.uploadVideo(file);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Video upload failed. Make sure the file is under 100 MB.',
          type: AppSnackBarType.error,
        );
      }
      return null;
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _gettingLocation = true);

    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!isServiceEnabled) {
        showAppSnackBar(
          context,
          'Turn on location services to attach your current GPS coordinates.',
          type: AppSnackBarType.info,
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;

      if (permission == LocationPermission.denied) {
        showAppSnackBar(
          context,
          'Location permission was denied. You can still enter the location manually.',
          type: AppSnackBarType.info,
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        showAppSnackBar(
          context,
          'Location permission is permanently denied. Please enable it in app settings.',
          type: AppSnackBarType.error,
        );
        return;
      }

      final position =
          await Geolocator.getCurrentPosition(
            timeLimit: const Duration(seconds: 10),
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () async {
              return await Geolocator.getLastKnownPosition() ??
                  Position(
                    latitude: 0,
                    longitude: 0,
                    timestamp: DateTime.now(),
                    accuracy: 0,
                    altitude: 0,
                    altitudeAccuracy: 0,
                    heading: 0,
                    headingAccuracy: 0,
                    speed: 0,
                    speedAccuracy: 0,
                  );
            },
          );

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _autoLocationName =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
      showAppSnackBar(
        context,
        _hasManualLocation
            ? 'GPS coordinates captured. Your typed location was kept.'
            : 'GPS coordinates captured. Please still enter a readable incident location.',
        type: AppSnackBarType.success,
      );
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'We could not fetch your location right now. Please type it manually.',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _gettingLocation = false);
      }
    }
  }

  Future<void> _submitIncident() async {
    final missingFields = <String>[];
    if (_typeController.text.trim().isEmpty) {
      missingFields.add('incident type');
    }
    if (_descriptionController.text.trim().isEmpty) {
      missingFields.add('description');
    }
    if (_locationController.text.trim().isEmpty) {
      missingFields.add('location');
    }
    if ((_selectedDepartment ?? '').trim().isEmpty) {
      missingFields.add('department');
    }

    if (missingFields.isNotEmpty) {
      _formKey.currentState?.validate();
      showAppSnackBar(
        context,
        'Please complete: ${missingFields.join(', ')}.',
        type: AppSnackBarType.error,
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final baseDraft = IncidentDraft(
        reporterUid: widget.reporter.uid,
        reporterEmail: widget.reporter.email,
        type: _typeController.text.trim(),
        description: _descriptionController.text.trim(),
        incidentDate: _incidentDate,
        location: _locationController.text.trim(),
        department: _selectedDepartment!.trim(),
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        autoLocationName: _autoLocationName,
      );

      final isOnline = widget.forceOffline
          ? false
          : await _offlineQueueService.isOnline();
      if (!isOnline) {
        await _queueOfflineIncident(baseDraft);
        return;
      }

      final imageUrls = <String>[];
      for (final imageFile in _imageFiles) {
        final url = await _uploadImageToCloudinary(imageFile);
        if (url != null) {
          imageUrls.add(url);
        }
      }

      String? videoUrl;
      if (_videoFile != null) {
        videoUrl = await _uploadVideoToCloudinary(_videoFile!);
      }

      final draft = IncidentDraft(
        reporterUid: baseDraft.reporterUid,
        reporterEmail: baseDraft.reporterEmail,
        type: baseDraft.type,
        description: baseDraft.description,
        incidentDate: baseDraft.incidentDate,
        location: baseDraft.location,
        department: baseDraft.department,
        imageUrls: imageUrls,
        videoUrl: videoUrl,
        latitude: baseDraft.latitude,
        longitude: baseDraft.longitude,
        autoLocationName: baseDraft.autoLocationName,
      );

      await _submitIncidentOnline(draft);

      if (!mounted) return;
      showAppSnackBar(
        context,
        'Incident reported successfully. AI suggestions will appear shortly.',
        type: AppSnackBarType.success,
      );
      Navigator.of(context).pop();
    } catch (error) {
      final isOnline = widget.forceOffline
          ? false
          : await _offlineQueueService.isOnline();
      if (!isOnline) {
        final fallbackDraft = IncidentDraft(
          reporterUid: widget.reporter.uid,
          reporterEmail: widget.reporter.email,
          type: _typeController.text.trim(),
          description: _descriptionController.text.trim(),
          incidentDate: _incidentDate,
          location: _locationController.text.trim(),
          department: _selectedDepartment!.trim(),
          latitude: _currentPosition?.latitude,
          longitude: _currentPosition?.longitude,
          autoLocationName: _autoLocationName,
        );
        await _queueOfflineIncident(fallbackDraft);
      } else if (mounted) {
        debugPrint('Online submission failed: $error');
        showAppSnackBar(
          context,
          'We could not submit the report. Please check your connection and try again.',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _submitIncidentOnline(IncidentDraft draft) async {
    final newReportRef = await _incidentService.createIncident(draft);
    final incidentId = newReportRef.key;
    if (incidentId != null) {
      _runAiAnalysisInBackground(incidentId: incidentId, incidentDraft: draft);
    }

    final reporterName = widget.reporter.displayName.isNotEmpty
        ? widget.reporter.displayName
        : (widget.reporter.email ?? 'Unknown Reporter');

    try {
      await _notificationService.notifySupervisorsOnNewReport(
        reportId: newReportRef.key ?? 'unknown',
        reportType: draft.type,
        reportTitle: draft.type,
        reporterName: reporterName,
        severity: '',
      );

      await _notificationService.notifyAllReportersOnNewReport(
        reportId: newReportRef.key ?? 'unknown',
        reportType: draft.type,
        reportTitle: draft.type,
        reporterName: reporterName,
        severity: '',
        reporterUid: widget.reporter.uid,
      );
    } catch (_) {
      debugPrint('Incident created but one or more notifications failed.');
    }
  }

  Future<void> _queueOfflineIncident(IncidentDraft draft) async {
    try {
      final pendingCount = await _offlineQueueService.queueIncidentDraft(
        reporter: widget.reporter,
        draft: draft,
        imageFiles: _imageFiles,
        videoFile: _videoFile,
      );

      if (!mounted) return;
      showAppSnackBar(
        context,
        'No internet detected. Report saved offline and queued for sync. Pending: $pendingCount.',
        type: AppSnackBarType.info,
      );
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint('Offline queue save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Could not save the report offline. Please try again.',
        type: AppSnackBarType.error,
      );
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _incidentDate,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _incidentDate = picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'Report an Incident',
        gradientColors: const [AppColors.primaryDark, AppColors.primary],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<bool>(
                stream: _offlineQueueService.onlineStatusStream,
                initialData: true,
                builder: (context, snapshot) {
                  final isOnline = snapshot.data ?? true;
                  final color = isOnline ? AppColors.info : AppColors.warning;

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: AppSpacing.section),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: AppRadii.large,
                      border: Border.all(color: color.withValues(alpha: 0.24)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isOnline
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off_outlined,
                          color: color,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            widget.forceOffline
                                ? 'Offline reporting mode is active. Submitting now will save the report on this device and sync it when internet returns.'
                                : isOnline
                                ? 'You can still report even if the internet drops. We will save the report on this device and sync it later if needed.'
                                : 'You are offline. Submitting now will save the report on this device and automatically sync it when internet returns.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Text(
                'Incident details',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Capture the essential details first, then add evidence if available.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              _FormSection(
                title: 'Basic Information',
                description: 'Tell us what happened and when it happened.',
                child: Column(
                  children: [
                    ModernTextField(
                      label: 'Incident Type',
                      hint: 'e.g. Fire, Injury, Equipment damage',
                      controller: _typeController,
                      prefixIcon: Icons.category_outlined,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Please enter the incident type.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ModernTextField(
                      label: 'Description',
                      hint:
                          'Describe what happened, who was involved, and any immediate risks.',
                      controller: _descriptionController,
                      prefixIcon: Icons.description_outlined,
                      minLines: 4,
                      maxLines: 6,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Please enter a description.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDepartment,
                      isExpanded: true,
                      menuMaxHeight: 320,
                      decoration: InputDecoration(
                        labelText: 'Department',
                        hintText: 'Select the department involved',
                        prefixIcon: const Icon(
                          Icons.apartment_outlined,
                          color: AppColors.textSecondary,
                        ),
                        fillColor: AppColors.surfaceRaised,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppRadii.medium,
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: AppRadii.medium,
                          borderSide: const BorderSide(
                            color: AppColors.error,
                            width: 1.5,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: AppRadii.medium,
                          borderSide: const BorderSide(
                            color: AppColors.error,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      items: _departmentOptions
                          .map(
                            (department) => DropdownMenuItem<String>(
                              value: department,
                              child: Text(
                                department,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedDepartment = value);
                      },
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Please select a department.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ResponsiveFields(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernTextField(
                              label: 'Incident location',
                              hint:
                                  'e.g. Gate 2, Warehouse A, near loading dock',
                              controller: _locationController,
                              prefixIcon: Icons.location_on_outlined,
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                  ? 'Please enter a readable incident location.'
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _LocationCaptureCard(
                              hasCoordinates: _currentPosition != null,
                              coordinates: _formattedCoordinates,
                              hasManualLocation: _hasManualLocation,
                              onClearCoordinates: _currentPosition == null
                                  ? null
                                  : () {
                                      setState(() {
                                        _currentPosition = null;
                                        _autoLocationName = null;
                                      });
                                    },
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _currentPosition != null
                                  ? 'Readable location is required. GPS is stored separately for precision.'
                                  : 'Enter a place people recognize, then attach GPS only if you are at or near the incident site.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        _ActionTile(
                          title: _gettingLocation
                              ? 'Locating...'
                              : 'Use current location',
                          subtitle: _currentPosition != null
                              ? 'Refresh captured GPS coordinates'
                              : 'Optional: attach GPS without replacing your typed location',
                          icon: _gettingLocation
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.my_location_rounded,
                                  color: AppColors.primary,
                                ),
                          onTap: _gettingLocation ? null : _getCurrentLocation,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ActionTile(
                      title: 'Incident date',
                      subtitle: _formatDate(_incidentDate),
                      icon: const Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.primary,
                      ),
                      onTap: _pickDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              _FormSection(
                title: 'Photo Evidence',
                description: 'Add images that help explain the incident.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ResponsiveFields(
                      children: [
                        _ActionTile(
                          title: 'Upload from gallery',
                          subtitle: 'Select one or more photos',
                          icon: const Icon(
                            Icons.image_outlined,
                            color: AppColors.info,
                          ),
                          onTap: _pickImage,
                        ),
                        _ActionTile(
                          title: 'Take a photo',
                          subtitle: 'Use the camera now',
                          icon: const Icon(
                            Icons.camera_alt_outlined,
                            color: AppColors.success,
                          ),
                          onTap: _takePhoto,
                        ),
                      ],
                    ),
                    if (_imageFiles.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _imageFiles.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: AppSpacing.md,
                              mainAxisSpacing: AppSpacing.md,
                              childAspectRatio: 1.15,
                            ),
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: AppRadii.large,
                                child: Image.file(
                                  _imageFiles[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Material(
                                  color: AppColors.error,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(
                                        () => _imageFiles.removeAt(index),
                                      );
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              _FormSection(
                title: 'Video Evidence',
                description: 'Optional video footage for additional context.',
                child: Column(
                  children: [
                    _ResponsiveFields(
                      children: [
                        _ActionTile(
                          title: 'Choose video',
                          subtitle: 'Attach a video from gallery',
                          icon: const Icon(
                            Icons.video_library_outlined,
                            color: AppColors.warning,
                          ),
                          onTap: _pickVideo,
                        ),
                        _ActionTile(
                          title: 'Record video',
                          subtitle: 'Capture a short clip',
                          icon: const Icon(
                            Icons.videocam_outlined,
                            color: AppColors.error,
                          ),
                          onTap: _recordVideo,
                        ),
                      ],
                    ),
                    if (_videoFile != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      AppSectionCard(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: AppRadii.medium,
                              ),
                              child: const Icon(
                                Icons.video_file_outlined,
                                color: AppColors.warning,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _videoFile!.path
                                        .split(Platform.pathSeparator)
                                        .last,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Video ready to upload',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  setState(() => _videoFile = null),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submitIncident,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_submitting ? 'Submitting...' : 'Submit Report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _FormSection({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget icon;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceRaised,
      borderRadius: AppRadii.large,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.large,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              icon,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationCaptureCard extends StatelessWidget {
  final bool hasCoordinates;
  final String coordinates;
  final bool hasManualLocation;
  final VoidCallback? onClearCoordinates;

  const _LocationCaptureCard({
    required this.hasCoordinates,
    required this.coordinates,
    required this.hasManualLocation,
    this.onClearCoordinates,
  });

  @override
  Widget build(BuildContext context) {
    final accent = hasCoordinates ? AppColors.success : AppColors.info;
    final title = hasCoordinates ? 'GPS captured' : 'Manual place entry';
    final subtitle = hasCoordinates
        ? hasManualLocation
              ? 'Readable place saved with exact coordinates attached.'
              : 'Coordinates are attached. You can still replace the label with a more specific place.'
        : 'Type a place people recognize, such as a gate, floor, room, or landmark.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: AppRadii.large,
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasCoordinates
                    ? Icons.gps_fixed_rounded
                    : Icons.edit_location_alt_outlined,
                color: accent,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (hasCoordinates && onClearCoordinates != null)
                TextButton(
                  onPressed: onClearCoordinates,
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          if (hasCoordinates) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadii.medium,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.pin_drop_outlined,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      coordinates,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveFields({required this.children});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 760;
    if (!isWide) {
      return Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: AppSpacing.md),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1) const SizedBox(width: AppSpacing.md),
        ],
      ],
    );
  }
}

class ReporterPage extends StatefulWidget {
  final User user;

  const ReporterPage({super.key, required this.user});

  @override
  State<ReporterPage> createState() => _ReporterPageState();
}

class _ReporterPageState extends State<ReporterPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporter Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.report, size: 72),
            const SizedBox(height: 12),
            Text('Welcome Back ${widget.user.email ?? "-"}'),
            const SizedBox(height: 12),
            const Text('Use the button below to report an incident'),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ReportIncidentForm(
                  reporter: ReporterIdentity.fromFirebaseUser(widget.user),
                ),
              ),
            );
          },
          child: const Text('Report an incident'),
        ),
      ),
    );
  }
}
