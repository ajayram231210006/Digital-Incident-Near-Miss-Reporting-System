import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_service.dart';
import 'ui_components.dart';

// Incident Report Form Widget
class ReportIncidentForm extends StatefulWidget {
  final User user;
  const ReportIncidentForm({super.key, required this.user});

  @override
  State<ReportIncidentForm> createState() => _ReportIncidentFormState();
}

class _ReportIncidentFormState extends State<ReportIncidentForm> {
  final _formKey = GlobalKey<FormState>();
  final _typeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _incidentDate;
  List<File> _imageFiles = [];
  File? _videoFile;
  bool _submitting = false;
  bool _gettingLocation = false;
  Position? _currentPosition;
  String? _autoLocationName;
  final ImagePicker _picker = ImagePicker();
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    // Initialize incident date to today
    _incidentDate = DateTime.now();
    debugPrint('📅 Report form initialized with date: ${_incidentDate!.toIso8601String()}');
  }

  @override
  void dispose() {
    _typeController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      maxWidth: 1200,
    );
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _imageFiles.addAll(pickedFiles.map((f) => File(f.path)).toList());
      });
      debugPrint('📷 Added ${pickedFiles.length} images from gallery');
    }
  }

  Future<void> _takePhoto() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
    );
    if (picked != null) {
      setState(() {
        _imageFiles.add(File(picked.path));
      });
      debugPrint('📷 Added 1 image from camera');
    }
  }

  Future<void> _pickVideo() async {
    final XFile? picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (picked != null) {
      setState(() {
        _videoFile = File(picked.path);
      });
    }
  }

  Future<void> _recordVideo() async {
    final XFile? picked = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 5),
    );
    if (picked != null) {
      setState(() {
        _videoFile = File(picked.path);
      });
    }
  }

  Future<String?> _uploadVideoToCloudinary(File file) async {
    // Use unsigned upload with API key for better compatibility
    final cloudinary = CloudinaryPublic(
      'djosnccv7',
      'incident_image', // Use same preset as images for consistency
      cache: false,
    );
    try {
      debugPrint('📹 Starting video upload to Cloudinary: ${file.path}');
      final sizeMB = file.lengthSync() / (1024 * 1024);
      debugPrint('📹 File size: ${sizeMB.toStringAsFixed(2)} MB');
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Video,
          folder: 'incident_videos', // Organize videos in separate folder
        ),
      );
      debugPrint('✅ Video uploaded successfully: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      debugPrint('❌ Error uploading video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video upload failed. Make sure video is under 100MB.'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _gettingLocation = true);

    try {
      // Check location permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final newPermission = await Geolocator.requestPermission();
        if (newPermission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable location in app settings'),
            ),
          );
        }
        return;
      }

      // Get current position with timeout
      final position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 10),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () async {
          return await Geolocator.getLastKnownPosition() ?? Position(
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

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _autoLocationName =
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          // Auto-fill location controller with coordinates
          _locationController.text = _autoLocationName ?? '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location: $_autoLocationName'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<String?> _uploadImageToCloudinary(File file) async {
    final cloudinary = CloudinaryPublic(
      'djosnccv7',
      'incident_image',
      cache: false,
    );
    try {
      debugPrint('🖼️ Starting image upload to Cloudinary: ${file.path}');
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      debugPrint('✅ Image uploaded successfully: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      debugPrint('❌ Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _submitIncident() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      // Upload multiple images
      List<String> imageUrls = [];
      if (_imageFiles.isNotEmpty) {
        debugPrint('🖼️ Uploading ${_imageFiles.length} images...');
        for (int i = 0; i < _imageFiles.length; i++) {
          final url = await _uploadImageToCloudinary(_imageFiles[i]);
          if (url != null) {
            imageUrls.add(url);
            debugPrint('  ✅ Image ${i + 1}/${_imageFiles.length} uploaded');
          }
        }
      }

      String? videoUrl;
      if (_videoFile != null) {
        debugPrint('🎬 Uploading video...');
        videoUrl = await _uploadVideoToCloudinary(_videoFile!);
      }

      final incident = {
        'reporterUid': widget.user.uid,
        'reporterEmail': widget.user.email,
        'type': _typeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'date': _incidentDate != null
            ? _incidentDate!.toIso8601String()
            : DateTime.now().toIso8601String(),
        'location': _locationController.text.trim(),
        'imageUrls': imageUrls,
        'videoUrl': videoUrl,
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
        'autoLocationName': _autoLocationName,
        'status': 'open',
        'createdAt': DateTime.now().toIso8601String(),
      };

      debugPrint('📝 Saving incident to Firebase...');
      debugPrint('   - Incident Date: ${incident['date']}');
      debugPrint('   - Created At: ${incident['createdAt']}');
      debugPrint('   - Image URLs (${imageUrls.length}): $imageUrls');
      debugPrint('   - Video URL: $videoUrl');

      final newReportRef = await FirebaseDatabase.instance.ref('incidents').push();
      await newReportRef.set(incident);
      
      debugPrint('✅ Incident saved successfully with ID: ${newReportRef.key}');

      // Notify all supervisors about the new report
      await _notificationService.notifySupervisorsOnNewReport(
        reportId: newReportRef.key ?? 'unknown',
        reportType: _typeController.text.trim(),
        reportTitle: _typeController.text.trim(),
        reporterName: widget.user.displayName ?? widget.user.email ?? 'Unknown Reporter',
        severity: 'Not Set',
      );

      // Notify all reporters about the new report
      await _notificationService.notifyAllReportersOnNewReport(
        reportId: newReportRef.key ?? 'unknown',
        reportType: _typeController.text.trim(),
        reportTitle: _typeController.text.trim(),
        reporterName: widget.user.displayName ?? widget.user.email ?? 'Unknown Reporter',
        severity: 'Not Set',
        reporterUid: widget.user.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incident reported successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('❌ Error submitting incident: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // Default to today if no date selected yet
    final initialDate = _incidentDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: now, // Prevent selecting future dates
    );
    if (picked != null) {
      setState(() => _incidentDate = picked);
      debugPrint('📅 Incident date selected: ${picked.toIso8601String()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'Report an Incident',
        gradientColors: [Colors.red.shade400, Colors.red.shade600],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form title with description
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Incident Details',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Provide comprehensive information about the incident',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Incident Type
              Text(
                'Incident Type',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ModernTextField(
                label: 'Incident Type',
                hint: 'e.g., Theft, Fire, Accident',
                controller: _typeController,
                prefixIcon: Icons.category_outlined,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter incident type'
                    : null,
              ),
              const SizedBox(height: 20),

              // Description
              Text(
                'Description',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ModernTextField(
                label: 'Detailed Description',
                hint: 'Describe what happened in detail...',
                controller: _descriptionController,
                prefixIcon: Icons.description_outlined,
                maxLines: 5,
                minLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter a description'
                    : null,
              ),
              const SizedBox(height: 20),

              // Location
              Text(
                'Location',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ModernTextField(
                          label: 'Incident Location',
                          hint: 'Where did this happen?',
                          controller: _locationController,
                          prefixIcon: Icons.location_on_outlined,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter location'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _gettingLocation ? null : _getCurrentLocation,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _gettingLocation
                                ? Colors.grey.withOpacity(0.2)
                                : Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.purple.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: _gettingLocation
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.purple.shade400,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.my_location,
                                  color: Colors.purple.shade600,
                                  size: 24,
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (_currentPosition != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Location auto-tagged: $_autoLocationName',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Date Picker
              Text(
                'Incident Date',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.calendar_today_outlined,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'When did this occur?',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _incidentDate != null
                                  ? _incidentDate!
                                      .toLocal()
                                      .toString()
                                      .split(' ')[0]
                                  : 'Select a date',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Image Section
              Text(
                'Evidence (Optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_imageFiles.isEmpty)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.blue.shade300,
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.blue.withOpacity(0.05),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 28,
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'From Gallery',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _takePhoto,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.green.shade300,
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.green.withOpacity(0.05),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.camera_alt_outlined,
                                size: 28,
                                color: Colors.green,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Take Photo',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _imageFiles.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            ModernCard(
                              padding: EdgeInsets.zero,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _imageFiles[index],
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _imageFiles.removeAt(index);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        InkWell(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.shade300,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 18,
                                  color: Colors.blue.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Add More',
                                  style: TextStyle(
                                    color: Colors.blue.shade600,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_imageFiles.length} image${_imageFiles.length != 1 ? 's' : ''} selected',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // Video Section
              Text(
                'Video Evidence (Optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_videoFile == null)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickVideo,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.orange.shade300,
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.orange.withOpacity(0.05),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.video_library_outlined,
                                size: 28,
                                color: Colors.orange,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'From Gallery',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _recordVideo,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.red.shade300,
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.red.withOpacity(0.05),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.videocam_outlined,
                                size: 28,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Record Video',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                ModernCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.video_library,
                              size: 64,
                              color: Colors.orange.shade300,
                            ),
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.8),
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
                                      'Video Ready',
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
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Video recorded',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Video evidence for the incident',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _videoFile = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.red.shade600,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              ModernButton(
                label: _submitting ? 'Submitting...' : 'Submit Report',
                onPressed: _submitting ? () {} : _submitIncident,
                isLoading: _submitting,
                icon: Icons.send_rounded,
                width: double.infinity,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// Legacy ReporterPage - kept for backward compatibility
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
                builder: (context) => ReportIncidentForm(user: widget.user),
              ),
            );
          },
          child: const Text('Report an incident'),
        ),
      ),
    );
  }
}
