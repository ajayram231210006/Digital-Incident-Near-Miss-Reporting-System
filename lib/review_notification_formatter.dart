class ReviewNotificationMessage {
  final String title;
  final String body;
  final String dedupeKey;

  const ReviewNotificationMessage({
    required this.title,
    required this.body,
    required this.dedupeKey,
  });
}

class ReviewNotificationBundle {
  final ReviewNotificationMessage reporterMessage;
  final ReviewNotificationMessage broadcastMessage;
  final bool includesNotes;

  const ReviewNotificationBundle({
    required this.reporterMessage,
    required this.broadcastMessage,
    required this.includesNotes,
  });
}

class ReviewNotificationFormatter {
  static ReviewNotificationBundle? build({
    required String reportId,
    required String reportType,
    required String supervisorName,
    required bool statusChanged,
    required String status,
    required bool severityChanged,
    required String severity,
    required bool notesAdded,
    String? notePreview,
  }) {
    final normalizedReportType = reportType.trim().isEmpty ? 'Report' : reportType.trim();
    final changeParts = <String>[];
    final changeKeys = <String>[];

    if (statusChanged) {
      changeParts.add('status to ${status.toUpperCase()}');
      changeKeys.add('status:${status.toLowerCase()}');
    }

    if (severityChanged) {
      changeParts.add('severity to ${severity.toUpperCase()}');
      changeKeys.add('severity:${severity.toLowerCase()}');
    }

    if (notesAdded) {
      changeParts.add('added notes');
      changeKeys.add('notes:${(notePreview ?? '').trim()}');
    }

    if (changeParts.isEmpty) {
      return null;
    }

    final dedupeKey = 'review:$reportId:${changeKeys.join('|')}';
    final reporterTitle = _reporterTitle(
      statusChanged: statusChanged,
      severityChanged: severityChanged,
      notesAdded: notesAdded,
      status: status,
      severity: severity,
    );

    final reporterBody = _buildBody(
      subject: 'your $normalizedReportType report',
      actor: supervisorName,
      changeParts: changeParts,
      notePreview: notesAdded ? notePreview : null,
    );

    final broadcastBody = _buildBody(
      subject: '$normalizedReportType report',
      actor: 'Supervisor $supervisorName',
      changeParts: changeParts,
      notePreview: null,
    );

    return ReviewNotificationBundle(
      reporterMessage: ReviewNotificationMessage(
        title: reporterTitle,
        body: reporterBody,
        dedupeKey: '$dedupeKey:reporter',
      ),
      broadcastMessage: ReviewNotificationMessage(
        title: 'Report Updated',
        body: broadcastBody,
        dedupeKey: '$dedupeKey:broadcast',
      ),
      includesNotes: notesAdded,
    );
  }

  static String _reporterTitle({
    required bool statusChanged,
    required bool severityChanged,
    required bool notesAdded,
    required String status,
    required String severity,
  }) {
    final changeCount = [statusChanged, severityChanged, notesAdded]
        .where((changed) => changed)
        .length;

    if (changeCount > 1) {
      return 'Report Review Updated';
    }
    if (statusChanged) {
      return 'Status Updated: ${status.toUpperCase()}';
    }
    if (severityChanged) {
      return 'Severity Updated: ${severity.toUpperCase()}';
    }
    return 'Notes Added';
  }

  static String _buildBody({
    required String subject,
    required String actor,
    required List<String> changeParts,
    String? notePreview,
  }) {
    final summary = _joinChanges(changeParts);
    final buffer = StringBuffer('$actor updated $subject by $summary.');
    final trimmedPreview = notePreview?.trim() ?? '';
    if (trimmedPreview.isNotEmpty) {
      buffer.write(' Notes: "$trimmedPreview"');
    }
    return buffer.toString();
  }

  static String _joinChanges(List<String> changeParts) {
    if (changeParts.length == 1) {
      return changeParts.first;
    }
    if (changeParts.length == 2) {
      return '${changeParts.first} and ${changeParts.last}';
    }

    final allButLast = changeParts.sublist(0, changeParts.length - 1).join(', ');
    return '$allButLast, and ${changeParts.last}';
  }
}
