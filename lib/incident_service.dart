import 'package:firebase_database/firebase_database.dart';
import 'app_features.dart';

class IncidentDraft {
  final String reporterUid;
  final String? reporterEmail;
  final String type;
  final String description;
  final DateTime incidentDate;
  final String location;
  final String department;
  final List<String> imageUrls;
  final String? videoUrl;
  final double? latitude;
  final double? longitude;
  final String? autoLocationName;

  const IncidentDraft({
    required this.reporterUid,
    required this.type,
    required this.description,
    required this.incidentDate,
    required this.location,
    required this.department,
    this.reporterEmail,
    this.imageUrls = const [],
    this.videoUrl,
    this.latitude,
    this.longitude,
    this.autoLocationName,
  });

  Map<String, dynamic> toCreatePayload() {
    final now = DateTime.now().toIso8601String();
    return {
      'reporterUid': reporterUid,
      'reporterEmail': reporterEmail,
      'type': type,
      'description': description,
      'date': incidentDate.toIso8601String(),
      'location': location,
      'department': department,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'autoLocationName': autoLocationName,
      'status': 'open',
      'createdAt': now,
      'updatedAt': now,
      'aiAnalysis': buildAiAnalysisPlaceholder(),
    };
  }
}

class IncidentReviewUpdate {
  final String status;
  final String severity;
  final String notes;
  final String? reviewerUid;
  final String? reviewerName;

  const IncidentReviewUpdate({
    required this.status,
    required this.severity,
    required this.notes,
    this.reviewerUid,
    this.reviewerName,
  });

  Map<String, dynamic> toUpdatePayload() {
    final now = DateTime.now().toIso8601String();
    final normalizedReviewerUid = reviewerUid?.trim() ?? '';
    final normalizedReviewerName = reviewerName?.trim() ?? '';
    return {
      'status': status,
      'severity': severity,
      'notes': notes,
      'lastModified': now,
      'updatedAt': now,
      'statusChangedAt': now,
      if (normalizedReviewerUid.isNotEmpty)
        'lastReviewedByUid': normalizedReviewerUid,
      if (normalizedReviewerName.isNotEmpty)
        'lastReviewedByName': normalizedReviewerName,
      if (normalizedReviewerUid.isNotEmpty || normalizedReviewerName.isNotEmpty)
        'lastReviewedAt': now,
      if (status == 'closed') 'closedAt': now,
    };
  }
}

class IncidentService {
  IncidentService({DatabaseReference? rootRef})
    : _rootRef = rootRef;

  final DatabaseReference? _rootRef;

  DatabaseReference get _databaseRoot => _rootRef ?? FirebaseDatabase.instance.ref();

  Future<DatabaseReference> createIncident(IncidentDraft draft) async {
    final incidentRef = _databaseRoot.child('incidents').push();
    await incidentRef.set(draft.toCreatePayload());
    return incidentRef;
  }

  Future<void> updateIncidentReview({
    required String incidentId,
    required IncidentReviewUpdate update,
  }) async {
    await _databaseRoot
        .child('incidents')
        .child(incidentId)
        .update(update.toUpdatePayload());
  }
}
