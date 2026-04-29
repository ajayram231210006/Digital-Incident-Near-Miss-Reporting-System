import 'package:flutter_test/flutter_test.dart';
import 'package:incitrack/review_notification_formatter.dart';

void main() {
  group('ReviewNotificationFormatter', () {
    test('combines status, severity, and notes into one reporter message', () {
      final bundle = ReviewNotificationFormatter.build(
        reportId: 'report-123',
        reportType: 'Incident',
        supervisorName: 'Alex',
        statusChanged: true,
        status: 'active',
        severityChanged: true,
        severity: 'high',
        notesAdded: true,
        notePreview: 'Follow-up inspection scheduled',
      );

      expect(bundle, isNotNull);
      expect(bundle!.reporterMessage.title, 'Report Review Updated');
      expect(
        bundle.reporterMessage.body,
        contains('status to ACTIVE, severity to HIGH, and added notes'),
      );
      expect(
        bundle.reporterMessage.body,
        contains('Notes: "Follow-up inspection scheduled"'),
      );
      expect(bundle.broadcastMessage.title, 'Report Updated');
      expect(bundle.reporterMessage.dedupeKey, contains('report-123'));
      expect(bundle.includesNotes, isTrue);
    });

    test('creates a status-only message when only status changed', () {
      final bundle = ReviewNotificationFormatter.build(
        reportId: 'report-456',
        reportType: 'Near Miss',
        supervisorName: 'Jordan',
        statusChanged: true,
        status: 'closed',
        severityChanged: false,
        severity: '',
        notesAdded: false,
      );

      expect(bundle, isNotNull);
      expect(bundle!.reporterMessage.title, 'Status Updated: CLOSED');
      expect(bundle.reporterMessage.body, contains('status to CLOSED'));
      expect(bundle.reporterMessage.body, isNot(contains('Notes:')));
    });

    test('returns null when nothing meaningful changed', () {
      final bundle = ReviewNotificationFormatter.build(
        reportId: 'report-789',
        reportType: 'Incident',
        supervisorName: 'Taylor',
        statusChanged: false,
        status: 'open',
        severityChanged: false,
        severity: '',
        notesAdded: false,
      );

      expect(bundle, isNull);
    });
  });
}
