import 'dart:async';
import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'notification_service.dart';

class OfflineReportQueueService {
  OfflineReportQueueService._();

  static final OfflineReportQueueService _instance =
      OfflineReportQueueService._();
  factory OfflineReportQueueService() => _instance;

  static const String _boxName = 'offline_report_queue';
  static const String _reporterStatsBoxName = 'reporter_stats_cache';
  static const String _supervisorStatsBoxName = 'supervisor_stats_cache';

  final Uuid _uuid = const Uuid();
  final NotificationService _notificationService = NotificationService();

  Box<dynamic>? _box;
  Box<dynamic>? _reporterStatsBox;
  Box<dynamic>? _supervisorStatsBox;
  Timer? _syncTimer;
  bool _initialized = false;
  bool _syncInProgress = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    await Hive.initFlutter();
    _box = await Hive.openBox<dynamic>(_boxName);
    _reporterStatsBox = await Hive.openBox<dynamic>(_reporterStatsBoxName);
    _supervisorStatsBox = await Hive.openBox<dynamic>(_supervisorStatsBoxName);
    _initialized = true;

    await syncPendingReports();
    _startAutoSync();
  }

  Future<String> queueIncident({
    required Map<String, dynamic> incident,
    required List<String> localImagePaths,
    String? localVideoPath,
  }) async {
    await _ensureInitialized();

    final localId = _uuid.v4();
    final reportId =
        FirebaseDatabase.instance.ref('incidents').push().key ??
        'offline_$localId';

    final payload = <String, dynamic>{
      'localId': localId,
      'reportId': reportId,
      'status': 'queued',
      'retryCount': 0,
      'lastError': '',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'localImagePaths': localImagePaths,
      'localVideoPath': localVideoPath,
      'incident': incident,
    };

    await _box!.put(localId, payload);
    return localId;
  }

  Future<void> syncPendingReports() async {
    await _ensureInitialized();

    if (_syncInProgress) {
      return;
    }

    _syncInProgress = true;
    final entries = _box!.toMap().entries.toList();

    try {
      for (final entry in entries) {
        final dynamic value = entry.value;
        if (value is! Map) {
          continue;
        }

        final report = Map<String, dynamic>.from(value.cast<String, dynamic>());
        final status = report['status']?.toString() ?? 'queued';

        if (status == 'synced' || status == 'syncing') {
          continue;
        }

        final key = entry.key.toString();
        await _markStatus(key, 'syncing');

        try {
          final incident = Map<String, dynamic>.from(
            (report['incident'] as Map).cast<String, dynamic>(),
          );

          final localImagePaths = List<String>.from(
            (report['localImagePaths'] as List?) ?? const <String>[],
          );

          final uploadedImageUrls = <String>[];
          for (final path in localImagePaths) {
            final file = File(path);
            if (!file.existsSync()) {
              continue;
            }

            try {
              final uploadedUrl = await _uploadImageToCloudinary(file);
              if (uploadedUrl != null) {
                uploadedImageUrls.add(uploadedUrl);
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Image upload skipped for queued report $key: $e');
              }
            }
          }

          String? uploadedVideoUrl;
          final localVideoPath = report['localVideoPath']?.toString();
          if (localVideoPath != null && localVideoPath.isNotEmpty) {
            final videoFile = File(localVideoPath);
            if (videoFile.existsSync()) {
              try {
                uploadedVideoUrl = await _uploadVideoToCloudinary(videoFile);
              } catch (e) {
                if (kDebugMode) {
                  debugPrint('Video upload skipped for queued report $key: $e');
                }
              }
            }
          }

          incident['imageUrls'] = uploadedImageUrls;
          incident['videoUrl'] = uploadedVideoUrl;
          incident['syncedFromOffline'] = true;
          incident['syncedAt'] = DateTime.now().toIso8601String();

          final reportId = report['reportId']?.toString() ?? key;
          await FirebaseDatabase.instance
              .ref('incidents/$reportId')
              .set(incident);

          // Mark synced immediately after DB write succeeds.
          await _markStatus(key, 'synced', clearError: true);

          final type = incident['type']?.toString() ?? 'Incident';
          final reporterName =
              incident['reporterEmail']?.toString() ?? 'Unknown Reporter';

          try {
            await _notificationService.notifySupervisorsOnNewReport(
              reportId: reportId,
              reportType: type,
              reportTitle: type,
              reporterName: reporterName,
              severity: 'Not Set',
            );
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Supervisor notification failed for $reportId: $e');
            }
          }

          final reporterUid = incident['reporterUid']?.toString() ?? '';
          if (reporterUid.isNotEmpty) {
            try {
              await _notificationService.notifyAllReportersOnNewReport(
                reportId: reportId,
                reportType: type,
                reportTitle: type,
                reporterName: reporterName,
                severity: 'Not Set',
                reporterUid: reporterUid,
              );
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Reporter notification failed for $reportId: $e');
              }
            }
          }
        } catch (e) {
          final retryCount = (report['retryCount'] as int? ?? 0) + 1;
          await _box!.put(key, {
            ...report,
            'status': 'failed',
            'retryCount': retryCount,
            'lastError': e.toString(),
            'updatedAt': DateTime.now().toIso8601String(),
          });

          if (kDebugMode) {
            debugPrint('Offline sync failed for $key: $e');
          }
        }
      }
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> dispose() async {
    _syncTimer?.cancel();
  }

  Future<void> cacheReporterStats(
    String reporterUid,
    Map<String, int> stats,
  ) async {
    await _ensureInitialized();
    await _reporterStatsBox!.put(reporterUid, {
      'total': stats['total'] ?? 0,
      'open': stats['open'] ?? 0,
      'active': stats['active'] ?? 0,
      'approved': stats['approved'] ?? 0,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, int>> getCachedReporterStats(String reporterUid) async {
    await _ensureInitialized();
    final cached = _reporterStatsBox!.get(reporterUid);
    if (cached is! Map) {
      return {'total': 0, 'open': 0, 'active': 0, 'approved': 0};
    }

    final map = Map<String, dynamic>.from(cached.cast<String, dynamic>());
    return {
      'total': map['total'] as int? ?? 0,
      'open': map['open'] as int? ?? 0,
      'active': map['active'] as int? ?? 0,
      'approved': map['approved'] as int? ?? 0,
    };
  }

  Future<int> getPendingCountForReporter(String reporterUid) async {
    await _ensureInitialized();

    int pendingCount = 0;
    final entries = _box!.toMap().entries;
    for (final entry in entries) {
      final dynamic value = entry.value;
      if (value is! Map) {
        continue;
      }

      final report = Map<String, dynamic>.from(value.cast<String, dynamic>());
      final status = report['status']?.toString() ?? 'queued';
      if (status == 'synced') {
        continue;
      }

      final incidentRaw = report['incident'];
      if (incidentRaw is! Map) {
        continue;
      }

      final incident = Map<String, dynamic>.from(
        incidentRaw.cast<String, dynamic>(),
      );
      if (incident['reporterUid']?.toString() == reporterUid) {
        pendingCount++;
      }
    }

    return pendingCount;
  }

  Stream<int> watchPendingCountForReporter(String reporterUid) async* {
    await _ensureInitialized();

    yield await getPendingCountForReporter(reporterUid);
    yield* _box!.watch().asyncMap(
      (_) => getPendingCountForReporter(reporterUid),
    );
  }

  Future<void> cacheSupervisorStats(Map<String, dynamic> stats) async {
    await _ensureInitialized();
    await _supervisorStatsBox!.put('summary', {
      'total': stats['total'] ?? 0,
      'open': stats['open'] ?? 0,
      'active': stats['active'] ?? 0,
      'closed': stats['closed'] ?? 0,
      'high': stats['high'] ?? 0,
      'medium': stats['medium'] ?? 0,
      'low': stats['low'] ?? 0,
      'critical': stats['critical'] ?? 0,
      'notSet': stats['notSet'] ?? 0,
      'overdue': stats['overdue'] ?? <dynamic>[],
      'recent': stats['recent'] ?? <dynamic>[],
      'dailyTrends': stats['dailyTrends'] ?? <String, int>{},
      'resolutionRate': stats['resolutionRate'] ?? 0.0,
      'openIncidentRate': stats['openIncidentRate'] ?? 0.0,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> getCachedSupervisorStats() async {
    await _ensureInitialized();
    final cached = _supervisorStatsBox!.get('summary');
    if (cached is! Map) {
      return _defaultSupervisorStats();
    }

    final map = Map<String, dynamic>.from(cached.cast<String, dynamic>());

    final rawDailyTrends = map['dailyTrends'];
    final Map<String, int> dailyTrends = {};
    if (rawDailyTrends is Map) {
      rawDailyTrends.forEach((key, value) {
        final parsed = value is num
            ? value.toInt()
            : int.tryParse(value?.toString() ?? '0') ?? 0;
        dailyTrends[key.toString()] = parsed;
      });
    }

    List<Map<String, dynamic>> normalizeList(dynamic raw) {
      if (raw is! List) {
        return <Map<String, dynamic>>[];
      }

      final normalized = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is Map) {
          normalized.add(
            Map<String, dynamic>.from(item.cast<String, dynamic>()),
          );
        }
      }
      return normalized;
    }

    return {
      'total': map['total'] as int? ?? 0,
      'open': map['open'] as int? ?? 0,
      'active': map['active'] as int? ?? 0,
      'closed': map['closed'] as int? ?? 0,
      'high': map['high'] as int? ?? 0,
      'medium': map['medium'] as int? ?? 0,
      'low': map['low'] as int? ?? 0,
      'critical': map['critical'] as int? ?? 0,
      'notSet': map['notSet'] as int? ?? 0,
      'overdue': normalizeList(map['overdue']),
      'recent': normalizeList(map['recent']),
      'dailyTrends': dailyTrends,
      'resolutionRate': (map['resolutionRate'] as num?)?.toDouble() ?? 0.0,
      'openIncidentRate': (map['openIncidentRate'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<int> getPendingCountGlobal() async {
    await _ensureInitialized();
    return _countPendingIncidents();
  }

  Stream<int> watchPendingCountGlobal() async* {
    await _ensureInitialized();

    yield await getPendingCountGlobal();
    yield* _box!.watch().asyncMap((_) => getPendingCountGlobal());
  }

  int _countPendingIncidents({String? reporterUid}) {
    int pendingCount = 0;
    final entries = _box!.toMap().entries;
    for (final entry in entries) {
      final dynamic value = entry.value;
      if (value is! Map) {
        continue;
      }

      final report = Map<String, dynamic>.from(value.cast<String, dynamic>());
      final status = report['status']?.toString() ?? 'queued';
      if (status == 'synced') {
        continue;
      }

      final incidentRaw = report['incident'];
      if (incidentRaw is! Map) {
        continue;
      }

      final incident = Map<String, dynamic>.from(
        incidentRaw.cast<String, dynamic>(),
      );
      final incidentReporterUid = incident['reporterUid']?.toString();
      if (reporterUid == null || incidentReporterUid == reporterUid) {
        pendingCount++;
      }
    }

    return pendingCount;
  }

  Map<String, dynamic> _defaultSupervisorStats() {
    return {
      'total': 0,
      'open': 0,
      'active': 0,
      'closed': 0,
      'high': 0,
      'medium': 0,
      'low': 0,
      'critical': 0,
      'notSet': 0,
      'overdue': <dynamic>[],
      'recent': <dynamic>[],
      'dailyTrends': <String, int>{},
      'resolutionRate': 0.0,
      'openIncidentRate': 0.0,
    };
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  void _startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => syncPendingReports(),
    );
  }

  Future<void> _markStatus(
    String key,
    String status, {
    bool clearError = false,
  }) async {
    final current = _box!.get(key);
    if (current is! Map) {
      return;
    }

    final currentMap = Map<String, dynamic>.from(
      current.cast<String, dynamic>(),
    );
    await _box!.put(key, {
      ...currentMap,
      'status': status,
      'lastError': clearError ? '' : currentMap['lastError'],
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<String?> _uploadImageToCloudinary(File file) async {
    final cloudinary = CloudinaryPublic(
      'djosnccv7',
      'incident_image',
      cache: false,
    );

    final response = await cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        resourceType: CloudinaryResourceType.Image,
      ),
    );

    return response.secureUrl;
  }

  Future<String?> _uploadVideoToCloudinary(File file) async {
    final cloudinary = CloudinaryPublic(
      'djosnccv7',
      'incident_image',
      cache: false,
    );

    final response = await cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        resourceType: CloudinaryResourceType.Video,
        folder: 'incident_videos',
      ),
    );

    return response.secureUrl;
  }
}
