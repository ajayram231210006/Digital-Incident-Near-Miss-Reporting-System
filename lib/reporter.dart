import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class ReporterPage extends StatefulWidget {
  final User user;
  const ReporterPage({super.key, required this.user});

  @override
  State<ReporterPage> createState() => _ReporterPageState();
}

class _ReporterPageState extends State<ReporterPage> {
  final _formKey = GlobalKey<FormState>();
  final _typeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _incidentDate;
  File? _imageFile;
  bool _submitting = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _typeController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
    );
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImageToCloudinary(File file) async {
    final cloudinary = CloudinaryPublic(
      'djosnccv7',
      'incident_image',
      cache: false,
    );
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      return null;
    }
  }

  Future<void> _submitIncident() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImageToCloudinary(_imageFile!);
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
        'imageUrl': imageUrl,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await FirebaseDatabase.instance.ref('incidents').push().set(incident);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incident reported')));
        // Reset form
        _formKey.currentState!.reset();
        setState(() {
          _incidentDate = null;
          _imageFile = null;
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _incidentDate = picked);
  }

  void _openReportForm() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(title: const Text('Report an Incident')),
            body: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Report an Incident',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _typeController,
                        decoration: const InputDecoration(
                          labelText: 'Type (e.g., Theft, Fire, Accident)',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter type'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                        maxLines: 4,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter description'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _locationController,
                              decoration: const InputDecoration(
                                labelText: 'Location',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter location'
                                  : null,
                            ),
                          ),
                          IconButton(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today),
                          ),
                        ],
                      ),
                      if (_incidentDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Date: ${_incidentDate!.toLocal().toString().split(' ')[0]}',
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo),
                            label: const Text('Upload Image'),
                          ),
                          const SizedBox(width: 12),
                          if (_imageFile != null) const Text('Image selected'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submitIncident,
                          child: _submitting
                              ? const CircularProgressIndicator()
                              : const Text('Submit Incident'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

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
          onPressed: _openReportForm,
          child: const Text('Report an incident'),
        ),
      ),
    );
  }
}
