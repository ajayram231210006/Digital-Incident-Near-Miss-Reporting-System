import 'package:firebase_database/firebase_database.dart';

class IncidentAnalyticsRecord {
  final String id;
  final String reporterUid;
  final String reporterEmail;
  final String type;
  final String description;
  final String location;
  final String department;
  final String status;
  final String severity;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;
  final String? lastReviewedByUid;
  final String? lastReviewedByName;
  final DateTime? lastReviewedAt;

  const IncidentAnalyticsRecord({
    required this.id,
    required this.reporterUid,
    required this.reporterEmail,
    required this.type,
    required this.description,
    required this.location,
    required this.department,
    required this.status,
    required this.severity,
    required this.createdAt,
    this.updatedAt,
    this.closedAt,
    this.lastReviewedByUid,
    this.lastReviewedByName,
    this.lastReviewedAt,
  });

  bool get isClosed => status == 'closed';
  bool get isActive => status == 'active';
  bool get isOpen => !isClosed && !isActive;
  bool get hasReviewer => (lastReviewedByUid ?? '').isNotEmpty;
  bool get isCritical => severity == 'critical';
  bool get isHighRisk => severity == 'critical' || severity == 'high';
  Duration? get resolutionDuration => closedAt?.difference(createdAt);

  factory IncidentAnalyticsRecord.fromMap(String id, Map value) {
    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      if (raw is int) {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      }

      final text = raw.toString().trim();
      if (text.isEmpty) return null;

      final parsedInt = int.tryParse(text);
      if (parsedInt != null) {
        return DateTime.fromMillisecondsSinceEpoch(parsedInt);
      }

      return DateTime.tryParse(text);
    }

    final createdAt =
        parseDate(value['createdAt']) ??
        parseDate(value['timestamp']) ??
        parseDate(value['date']) ??
        DateTime.now();

    return IncidentAnalyticsRecord(
      id: id,
      reporterUid: value['reporterUid']?.toString() ?? '',
      reporterEmail: value['reporterEmail']?.toString() ?? '',
      type: (value['type'] ?? value['incidentType'] ?? 'Incident').toString(),
      description: value['description']?.toString() ?? '',
      location: value['location']?.toString() ?? 'Unknown',
      department: value['department']?.toString() ?? 'General',
      status: (value['status'] ?? 'open').toString().toLowerCase(),
      severity: (value['severity'] ?? '').toString().toLowerCase(),
      createdAt: createdAt,
      updatedAt: parseDate(value['updatedAt']) ?? parseDate(value['lastModified']),
      closedAt: parseDate(value['closedAt']),
      lastReviewedByUid: value['lastReviewedByUid']?.toString(),
      lastReviewedByName: value['lastReviewedByName']?.toString(),
      lastReviewedAt: parseDate(value['lastReviewedAt']),
    );
  }
}

class AnalyticsCountItem {
  final String label;
  final int count;

  const AnalyticsCountItem({required this.label, required this.count});
}

class SupervisorLeaderboardEntry {
  final String uid;
  final String name;
  final int totalReviewed;
  final int openReviewed;
  final int closedReviewed;
  final int criticalReviewed;

  const SupervisorLeaderboardEntry({
    required this.uid,
    required this.name,
    required this.totalReviewed,
    required this.openReviewed,
    required this.closedReviewed,
    required this.criticalReviewed,
  });
}

class SupervisorAnalyticsSummary {
  final int totalReviewed;
  final int openOwned;
  final int closedReviewed;
  final int criticalOpen;
  final double closureRate;
  final double averageResolutionDays;
  final Map<String, int> dailyReviewTrend;
  final List<AnalyticsCountItem> severityBreakdown;
  final List<AnalyticsCountItem> hotspotLocations;
  final List<IncidentAnalyticsRecord> recentReviews;
  final List<IncidentAnalyticsRecord> attentionReports;

  const SupervisorAnalyticsSummary({
    required this.totalReviewed,
    required this.openOwned,
    required this.closedReviewed,
    required this.criticalOpen,
    required this.closureRate,
    required this.averageResolutionDays,
    required this.dailyReviewTrend,
    required this.severityBreakdown,
    required this.hotspotLocations,
    required this.recentReviews,
    required this.attentionReports,
  });
}

class OrganizationAnalyticsSummary {
  final int totalReports;
  final int openReports;
  final int activeReports;
  final int closedReports;
  final int criticalReports;
  final int unreviewedReports;
  final double closureRate;
  final double averageResolutionDays;
  final Map<String, int> dailyTrend;
  final List<AnalyticsCountItem> severityBreakdown;
  final List<AnalyticsCountItem> topLocations;
  final List<AnalyticsCountItem> topDepartments;
  final List<AnalyticsCountItem> topTypes;
  final List<SupervisorLeaderboardEntry> supervisorLeaderboard;
  final List<IncidentAnalyticsRecord> urgentReports;

  const OrganizationAnalyticsSummary({
    required this.totalReports,
    required this.openReports,
    required this.activeReports,
    required this.closedReports,
    required this.criticalReports,
    required this.unreviewedReports,
    required this.closureRate,
    required this.averageResolutionDays,
    required this.dailyTrend,
    required this.severityBreakdown,
    required this.topLocations,
    required this.topDepartments,
    required this.topTypes,
    required this.supervisorLeaderboard,
    required this.urgentReports,
  });
}

class IncidentAnalyticsService {
  IncidentAnalyticsService({DatabaseReference? rootRef})
    : _rootRef = rootRef;

  final DatabaseReference? _rootRef;

  DatabaseReference get _dbRef => _rootRef ?? FirebaseDatabase.instance.ref();

  Stream<List<IncidentAnalyticsRecord>> watchIncidents() {
    return _dbRef.child('incidents').onValue.map((event) {
      final incidents = <IncidentAnalyticsRecord>[];
      final data = event.snapshot.value as Map?;
      data?.forEach((key, value) {
        if (value is Map) {
          incidents.add(IncidentAnalyticsRecord.fromMap(key.toString(), value));
        }
      });
      incidents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return incidents;
    });
  }

  SupervisorAnalyticsSummary buildSupervisorSummary({
    required List<IncidentAnalyticsRecord> incidents,
    required String supervisorUid,
  }) {
    final reviewed = incidents.where((incident) {
      return (incident.lastReviewedByUid ?? '') == supervisorUid;
    }).toList()
      ..sort((a, b) {
        final aDate = a.lastReviewedAt ?? a.updatedAt ?? a.createdAt;
        final bDate = b.lastReviewedAt ?? b.updatedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });

    final openOwned = reviewed.where((incident) => !incident.isClosed).length;
    final closedReviewed =
        reviewed.where((incident) => incident.isClosed).length;
    final criticalOpen = reviewed
        .where((incident) => !incident.isClosed && incident.isCritical)
        .length;
    final closureRate = reviewed.isEmpty
        ? 0.0
        : (closedReviewed / reviewed.length) * 100;

    var totalResolutionHours = 0.0;
    var resolvedCount = 0;
    for (final incident in reviewed) {
      final duration = incident.resolutionDuration;
      if (duration == null) continue;
      totalResolutionHours += duration.inMinutes / 60;
      resolvedCount++;
    }

    final severityBreakdown = _sortedBreakdown({
      'Critical': reviewed.where((incident) => incident.severity == 'critical').length,
      'High': reviewed.where((incident) => incident.severity == 'high').length,
      'Medium': reviewed.where((incident) => incident.severity == 'medium').length,
      'Low': reviewed.where((incident) => incident.severity == 'low').length,
      'Not set': reviewed
          .where(
            (incident) =>
                incident.severity.isEmpty || incident.severity == 'not set',
          )
          .length,
    });

    final hotspotLocations = _sortedBreakdown(_countBy(
      reviewed,
      (incident) => _normalizeLocation(incident.location),
    )).take(5).toList();

    final attentionReports = reviewed
        .where((incident) => !incident.isClosed && incident.isHighRisk)
        .take(5)
        .toList();

    return SupervisorAnalyticsSummary(
      totalReviewed: reviewed.length,
      openOwned: openOwned,
      closedReviewed: closedReviewed,
      criticalOpen: criticalOpen,
      closureRate: closureRate,
      averageResolutionDays:
          resolvedCount == 0 ? 0.0 : (totalResolutionHours / 24) / resolvedCount,
      dailyReviewTrend: _buildDailyTrend(
        reviewed.map((incident) => incident.lastReviewedAt ?? incident.createdAt),
      ),
      severityBreakdown: severityBreakdown,
      hotspotLocations: hotspotLocations,
      recentReviews: reviewed.take(6).toList(),
      attentionReports: attentionReports,
    );
  }

  OrganizationAnalyticsSummary buildOrganizationSummary(
    List<IncidentAnalyticsRecord> incidents,
  ) {
    final openReports = incidents.where((incident) => incident.isOpen).length;
    final activeReports = incidents.where((incident) => incident.isActive).length;
    final closedReports =
        incidents.where((incident) => incident.isClosed).length;
    final criticalReports =
        incidents.where((incident) => incident.isCritical).length;
    final unreviewedReports =
        incidents.where((incident) => !incident.hasReviewer).length;
    final closureRate = incidents.isEmpty
        ? 0.0
        : (closedReports / incidents.length) * 100;

    var totalResolutionHours = 0.0;
    var resolvedCount = 0;
    for (final incident in incidents) {
      final duration = incident.resolutionDuration;
      if (duration == null) continue;
      totalResolutionHours += duration.inMinutes / 60;
      resolvedCount++;
    }

    final severityBreakdown = _sortedBreakdown({
      'Critical': incidents.where((incident) => incident.severity == 'critical').length,
      'High': incidents.where((incident) => incident.severity == 'high').length,
      'Medium': incidents.where((incident) => incident.severity == 'medium').length,
      'Low': incidents.where((incident) => incident.severity == 'low').length,
      'Not set': incidents
          .where(
            (incident) =>
                incident.severity.isEmpty || incident.severity == 'not set',
          )
          .length,
    });

    final topLocations = _sortedBreakdown(_countBy(
      incidents,
      (incident) => _normalizeLocation(incident.location),
    )).take(6).toList();
    final topDepartments = _sortedBreakdown(_countBy(
      incidents,
      (incident) => _normalizeDepartment(incident.department),
    )).take(6).toList();

    final topTypes = _sortedBreakdown(_countBy(
      incidents,
      (incident) => incident.type.trim().isEmpty ? 'Unknown' : incident.type,
    )).take(6).toList();

    final leaderboardBuckets = <String, List<IncidentAnalyticsRecord>>{};
    for (final incident in incidents) {
      final uid = incident.lastReviewedByUid?.trim() ?? '';
      if (uid.isEmpty) continue;
      leaderboardBuckets.putIfAbsent(uid, () => <IncidentAnalyticsRecord>[]).add(incident);
    }

    final supervisorLeaderboard = leaderboardBuckets.entries.map((entry) {
      final reviewed = entry.value;
      final sample = reviewed.first;
      return SupervisorLeaderboardEntry(
        uid: entry.key,
        name: (sample.lastReviewedByName ?? '').trim().isEmpty
            ? 'Supervisor'
            : sample.lastReviewedByName!.trim(),
        totalReviewed: reviewed.length,
        openReviewed: reviewed.where((incident) => !incident.isClosed).length,
        closedReviewed: reviewed.where((incident) => incident.isClosed).length,
        criticalReviewed:
            reviewed.where((incident) => incident.isCritical).length,
      );
    }).toList()
      ..sort((a, b) => b.totalReviewed.compareTo(a.totalReviewed));

    final urgentReports = incidents
        .where((incident) => !incident.isClosed && incident.isHighRisk)
        .take(6)
        .toList();

    return OrganizationAnalyticsSummary(
      totalReports: incidents.length,
      openReports: openReports,
      activeReports: activeReports,
      closedReports: closedReports,
      criticalReports: criticalReports,
      unreviewedReports: unreviewedReports,
      closureRate: closureRate,
      averageResolutionDays:
          resolvedCount == 0 ? 0.0 : (totalResolutionHours / 24) / resolvedCount,
      dailyTrend: _buildDailyTrend(incidents.map((incident) => incident.createdAt)),
      severityBreakdown: severityBreakdown,
      topLocations: topLocations,
      topDepartments: topDepartments,
      topTypes: topTypes,
      supervisorLeaderboard: supervisorLeaderboard.take(6).toList(),
      urgentReports: urgentReports,
    );
  }

  List<IncidentAnalyticsRecord> filterByCreatedAtWindow({
    required List<IncidentAnalyticsRecord> incidents,
    DateTime? start,
  }) {
    if (start == null) return incidents;
    return incidents.where((incident) => !incident.createdAt.isBefore(start)).toList();
  }

  List<IncidentAnalyticsRecord> filterSupervisorWindow({
    required List<IncidentAnalyticsRecord> incidents,
    required String supervisorUid,
    DateTime? start,
  }) {
    return incidents.where((incident) {
      if ((incident.lastReviewedByUid ?? '') != supervisorUid) {
        return false;
      }
      if (start == null) {
        return true;
      }
      final reviewDate =
          incident.lastReviewedAt ?? incident.updatedAt ?? incident.createdAt;
      return !reviewDate.isBefore(start);
    }).toList();
  }

  Map<String, int> _buildDailyTrend(Iterable<DateTime> dates) {
    final trend = <String, int>{};
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      trend[_dateKey(date)] = 0;
    }

    for (final date in dates) {
      final key = _dateKey(date);
      if (trend.containsKey(key)) {
        trend[key] = (trend[key] ?? 0) + 1;
      }
    }
    return trend;
  }

  Map<String, int> _countBy(
    List<IncidentAnalyticsRecord> incidents,
    String Function(IncidentAnalyticsRecord incident) pickKey,
  ) {
    final counts = <String, int>{};
    for (final incident in incidents) {
      final key = pickKey(incident);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  List<AnalyticsCountItem> _sortedBreakdown(Map<String, int> counts) {
    final items = counts.entries
        .map((entry) => AnalyticsCountItem(label: entry.key, count: entry.value))
        .where((entry) => entry.count > 0)
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return items;
  }

  String _normalizeLocation(String rawLocation) {
    final normalized = rawLocation.trim();
    return normalized.isEmpty ? 'Unknown' : normalized;
  }

  String _normalizeDepartment(String rawDepartment) {
    final normalized = rawDepartment.trim();
    return normalized.isEmpty ? 'General' : normalized;
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
