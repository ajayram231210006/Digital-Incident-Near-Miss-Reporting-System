import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'app_features.dart';
import 'incident_service.dart';

class IncidentAiService {
  IncidentAiService({DatabaseReference? rootRef, FirebaseAuth? auth})
    : _rootRef = rootRef,
      _auth = auth;

  final DatabaseReference? _rootRef;
  final FirebaseAuth? _auth;

  DatabaseReference get _databaseRoot => _rootRef ?? FirebaseDatabase.instance.ref();
  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;

  GenerativeModel _buildModel() {
    return FirebaseAI.googleAI(auth: _firebaseAuth).generativeModel(
      model: kAiModel,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        maxOutputTokens: 600,
        responseMimeType: 'application/json',
        responseJsonSchema: {
          'type': 'object',
          'properties': {
            'category': {
              'type': 'string',
              'enum': [
                'injury',
                'fire',
                'theft',
                'equipment',
                'unsafe_condition',
                'near_miss',
                'other',
              ],
            },
            'severity': {
              'type': 'string',
              'enum': ['low', 'medium', 'high', 'critical'],
            },
            'summary': {'type': 'string'},
            'recommendedActions': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'missingFields': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'riskFactors': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'confidence': {'type': 'number'},
          },
          'required': [
            'category',
            'severity',
            'summary',
            'recommendedActions',
            'missingFields',
            'riskFactors',
            'confidence',
          ],
        },
      ),
      systemInstruction: Content.text(
        'You analyze workplace incident reports. '
        'Return strict JSON only. '
        'Do not invent facts. '
        'Use only the details supplied in the report. '
        'Keep the summary under 80 words. '
        'Provide up to 4 practical recommended actions, up to 4 missing fields, '
        'and up to 4 risk factors.',
      ),
    );
  }

  Future<void> analyzeIncident({
    required String incidentId,
    required IncidentDraft draft,
  }) async {
    final incidentRef = _databaseRoot.child('incidents').child(incidentId);

    if (!kAiAnalysisEnabled) {
      await incidentRef.child('aiAnalysis').set(buildAiAnalysisPlaceholder());
      return;
    }

    await incidentRef.child('aiAnalysis').set({
      'status': 'processing',
      'model': kAiModel,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    try {
      final model = _buildModel();
      final response = await model.generateContent([
        Content.text(jsonEncode(_buildAnalysisInput(draft))),
      ]);

      final responseText = response.text?.trim();
      if (responseText == null || responseText.isEmpty) {
        throw StateError('The AI model returned an empty response.');
      }

      final parsed = jsonDecode(responseText);
      if (parsed is! Map) {
        throw const FormatException('The AI response was not a JSON object.');
      }

      final analysis = Map<String, dynamic>.from(parsed);
      await incidentRef.child('aiAnalysis').set({
        'status': 'completed',
        'model': kAiModel,
        'analyzedAt': DateTime.now().toIso8601String(),
        'category': _asString(analysis['category']),
        'suggestedSeverity': _asSeverity(analysis['severity']),
        'summary': _asString(analysis['summary']),
        'recommendedActions': _asStringList(analysis['recommendedActions']),
        'missingFields': _asStringList(analysis['missingFields']),
        'riskFactors': _asStringList(analysis['riskFactors']),
        'confidence': _asConfidence(analysis['confidence']),
      });
    } catch (error) {
      await incidentRef.child('aiAnalysis').set({
        'status': 'failed',
        'model': kAiModel,
        'analyzedAt': DateTime.now().toIso8601String(),
        'error': _friendlyError(error),
      });
    }
  }

  Map<String, dynamic> _buildAnalysisInput(IncidentDraft draft) {
    return {
      'type': draft.type.trim(),
      'description': draft.description.trim(),
      'location': draft.location.trim(),
      'incidentDate': draft.incidentDate.toIso8601String(),
      'reporterEmail': draft.reporterEmail ?? '',
      'imageCount': draft.imageUrls.length,
      'hasVideo': draft.videoUrl?.isNotEmpty ?? false,
      'coordinates': {
        'latitude': draft.latitude,
        'longitude': draft.longitude,
      },
    };
  }

  String _asString(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  String _asSeverity(dynamic value) {
    const allowed = {'low', 'medium', 'high', 'critical'};
    final normalized = _asString(value).toLowerCase();
    return allowed.contains(normalized) ? normalized : '';
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map(_asString)
          .where((item) => item.isNotEmpty)
          .take(4)
          .toList();
    }
    return const [];
  }

  double _asConfidence(dynamic value) {
    if (value is num) {
      final confidence = value.toDouble();
      if (confidence < 0) {
        return 0;
      }
      if (confidence > 1) {
        return 1;
      }
      return confidence;
    }
    return 0;
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('ServiceApiNotEnabled')) {
      return 'Firebase AI Logic is not enabled for this project yet.';
    }
    if (message.contains('QuotaExceeded')) {
      return 'The Firebase AI Logic quota was exceeded. Please try again later.';
    }
    if (message.contains('UnsupportedUserLocation')) {
      return 'Firebase AI Logic is not available in this location.';
    }
    return message;
  }
}
