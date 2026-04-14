import 'package:flutter_test/flutter_test.dart';
import 'package:incitrack/incident_service.dart';

void main() {
  group('IncidentDraft', () {
    test('create payload contains reporter fields and default open status', () {
      final draft = IncidentDraft(
        reporterUid: 'user-123',
        reporterEmail: 'reporter@example.com',
        type: 'Fire',
        description: 'Minor fire in storage room',
        incidentDate: DateTime.parse('2026-04-06T10:30:00.000Z'),
        location: 'Warehouse A',
        imageUrls: const ['https://example.com/image-1.jpg'],
        videoUrl: 'https://example.com/video.mp4',
        latitude: 10.2,
        longitude: 20.4,
        autoLocationName: '10.2, 20.4',
      );

      final payload = draft.toCreatePayload();

      expect(payload['reporterUid'], 'user-123');
      expect(payload['reporterEmail'], 'reporter@example.com');
      expect(payload['type'], 'Fire');
      expect(payload['description'], 'Minor fire in storage room');
      expect(payload['location'], 'Warehouse A');
      expect(payload['status'], 'open');
      expect(payload['imageUrls'], ['https://example.com/image-1.jpg']);
      expect(payload['videoUrl'], 'https://example.com/video.mp4');
      expect(payload['severity'], isNull);
      expect(payload['createdAt'], isA<String>());
      expect(payload['updatedAt'], isA<String>());
    });
  });

  group('IncidentReviewUpdate', () {
    test('review payload contains supervisor-managed fields', () {
      final update = IncidentReviewUpdate(
        status: 'closed',
        severity: 'high',
        notes: 'Closed after supervisor review',
      );

      final payload = update.toUpdatePayload();

      expect(payload['status'], 'closed');
      expect(payload['severity'], 'high');
      expect(payload['notes'], 'Closed after supervisor review');
      expect(payload['lastModified'], isA<String>());
      expect(payload['updatedAt'], isA<String>());
      expect(payload['statusChangedAt'], isA<String>());
      expect(payload['closedAt'], isA<String>());
    });

    test('non-closed review payload does not include closedAt', () {
      final update = IncidentReviewUpdate(
        status: 'active',
        severity: 'medium',
        notes: 'Investigating',
      );

      final payload = update.toUpdatePayload();

      expect(payload['status'], 'active');
      expect(payload.containsKey('closedAt'), isFalse);
    });
  });
}
