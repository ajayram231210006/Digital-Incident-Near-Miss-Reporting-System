import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'incident_ai_service.dart';
import 'incident_media_service.dart';
import 'incident_service.dart';
import 'notification_service.dart';
import 'reporter_identity.dart';

class QueuedIncidentDraft {
  final String localId;
  final String reporterUid;
  final String? reporterEmail;
  final String reporterName;
  final String type;
  final String description;
  final DateTime incidentDate;
  final String location;
  final String department;
  final List<String> localImagePaths;
  final String? localVideoPath;
  final double? latitude;
  final double? longitude;
  final String? autoLocationName;
  final DateTime queuedAt;

  const QueuedIncidentDraft({
    required this.localId,
    required this.reporterUid,
    required this.reporterName,
    required this.type,
    required this.description,
    required this.incidentDate,
    required this.location,
    required this.department,
    required this.queuedAt,
    this.reporterEmail,
    this.localImagePaths = const [],
    this.localVideoPath,
    this.latitude,
    this.longitude,
    this.autoLocationName,
  });

  Map<String, dynamic> toJson() {
    return {
      'localId': localId,
      'reporterUid': reporterUid,
      'reporterEmail': reporterEmail,
      'reporterName': reporterName,
      'type': type,
      'description': description,
      'incidentDate': incidentDate.toIso8601String(),
      'location': location,
      'department': department,
      'localImagePaths': localImagePaths,
      'localVideoPath': localVideoPath,
      'latitude': latitude,
      'longitude': longitude,
      'autoLocationName': autoLocationName,
      'queuedAt': queuedAt.toIso8601String(),
    };
  }

  factory QueuedIncidentDraft.fromJson(Map<String, dynamic> json) {
    return QueuedIncidentDraft(
      localId: json['localId']?.toString() ?? '',
      reporterUid: json['reporterUid']?.toString() ?? '',
      reporterEmail: json['reporterEmail']?.toString(),
      reporterName: json['reporterName']?.toString() ?? 'Unknown Reporter',
      type: json['type']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      incidentDate:
          DateTime.tryParse(json['incidentDate']?.toString() ?? '') ??
          DateTime.now(),
      location: json['location']?.toString() ?? '',
      department: json['department']?.toString() ?? 'General',
      localImagePaths: (json['localImagePaths'] as List<dynamic>? ?? const [])
          .map((path) => path.toString())
          .toList(),
      localVideoPath: json['localVideoPath']?.toString(),
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      autoLocationName: json['autoLocationName']?.toString(),
      queuedAt:
          DateTime.tryParse(json['queuedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class OfflineIncidentQueueService {
  OfflineIncidentQueueService({
    SharedPreferences? preferences,
    Connectivity? connectivity,
    IncidentService? incidentService,
    IncidentAiService? incidentAiService,
    NotificationService? notificationService,
    IncidentMediaService? mediaService,
  }) : _preferencesFuture = preferences != null
           ? Future.value(preferences)
           : SharedPreferences.getInstance(),
       _connectivity = connectivity ?? Connectivity(),
       _incidentService = incidentService ?? IncidentService(),
       _incidentAiService = incidentAiService ?? IncidentAiService(),
       _notificationService = notificationService ?? NotificationService(),
       _mediaService = mediaService ?? const IncidentMediaService();

  static const String _storageKey = 'offline_incident_queue_v1';

  final Future<SharedPreferences> _preferencesFuture;
  final Connectivity _connectivity;
  final IncidentService _incidentService;
  final IncidentAiService _incidentAiService;
  final NotificationService _notificationService;
  final IncidentMediaService _mediaService;
  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();

  Stream<bool> get onlineStatusStream => _connectivity.onConnectivityChanged
      .map((result) => _hasConnection(result));

  Stream<int> watchPendingCount(String reporterUid) {
    unawaited(_emitPendingCount(reporterUid));
    return _pendingCountController.stream;
  }

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return _hasConnection(result);
  }

  Future<int> queueIncidentDraft({
    required ReporterIdentity reporter,
    required IncidentDraft draft,
    required List<File> imageFiles,
    File? videoFile,
  }) async {
    final queue = await _loadQueue();
    final localId = _generateLocalId(reporter.uid);
    final localImagePaths = await _copyFilesSafely(
      files: imageFiles,
      localId: localId,
      folderName: 'images',
    );
    final localVideoPath = await _copySingleFileSafely(
      file: videoFile,
      localId: localId,
      folderName: 'videos',
    );

    queue.add(
      QueuedIncidentDraft(
        localId: localId,
        reporterUid: draft.reporterUid,
        reporterEmail: draft.reporterEmail,
        reporterName: reporter.displayName,
        type: draft.type,
        description: draft.description,
        incidentDate: draft.incidentDate,
        location: draft.location,
        department: draft.department,
        localImagePaths: localImagePaths,
        localVideoPath: localVideoPath,
        latitude: draft.latitude,
        longitude: draft.longitude,
        autoLocationName: draft.autoLocationName,
        queuedAt: DateTime.now(),
      ),
    );

    await _saveQueue(queue);
    await _emitPendingCount(reporter.uid);
    return queue.where((item) => item.reporterUid == reporter.uid).length;
  }

  Future<int> getPendingCount(String reporterUid) async {
    final queue = await _loadQueue();
    return queue.where((item) => item.reporterUid == reporterUid).length;
  }

  Future<int> syncPendingReportsForUser(String reporterUid) async {
    if (!await isOnline()) return 0;

    final queue = await _loadQueue();
    if (queue.isEmpty) return 0;

    final remaining = <QueuedIncidentDraft>[];
    var syncedCount = 0;

    for (final item in queue) {
      if (item.reporterUid != reporterUid) {
        remaining.add(item);
        continue;
      }

      try {
        final imageUrls = <String>[];
        for (final imagePath in item.localImagePaths) {
          final imageFile = File(imagePath);
          if (!await imageFile.exists()) continue;
          final imageUrl = await _mediaService.uploadImage(imageFile);
          if (imageUrl != null) {
            imageUrls.add(imageUrl);
          }
        }

        String? videoUrl;
        if (item.localVideoPath != null && item.localVideoPath!.isNotEmpty) {
          final videoFile = File(item.localVideoPath!);
          if (await videoFile.exists()) {
            videoUrl = await _mediaService.uploadVideo(videoFile);
          }
        }

        final draft = IncidentDraft(
          reporterUid: item.reporterUid,
          reporterEmail: item.reporterEmail,
          type: item.type,
          description: item.description,
          incidentDate: item.incidentDate,
          location: item.location,
          department: item.department,
          imageUrls: imageUrls,
          videoUrl: videoUrl,
          latitude: item.latitude,
          longitude: item.longitude,
          autoLocationName: item.autoLocationName,
        );

        final newReportRef = await _incidentService.createIncident(draft);
        final incidentId = newReportRef.key;
        if (incidentId != null) {
          unawaited(
            _incidentAiService.analyzeIncident(
              incidentId: incidentId,
              draft: draft,
            ),
          );
        }

        await _sendNotifications(
          reportId: newReportRef.key ?? 'unknown',
          reportType: item.type,
          reportTitle: item.type,
          reporterName: item.reporterName,
          reporterUid: item.reporterUid,
        );

        await _deleteCopiedFiles(item);
        syncedCount++;
      } catch (error, stackTrace) {
        debugPrint('Offline incident sync failed for ${item.localId}: $error');
        debugPrintStack(stackTrace: stackTrace);
        remaining.add(item);
      }
    }

    await _saveQueue(remaining);
    await _emitPendingCount(reporterUid);
    return syncedCount;
  }

  Future<void> _sendNotifications({
    required String reportId,
    required String reportType,
    required String reportTitle,
    required String reporterName,
    required String reporterUid,
  }) async {
    try {
      await _notificationService.notifySupervisorsOnNewReport(
        reportId: reportId,
        reportType: reportType,
        reportTitle: reportTitle,
        reporterName: reporterName,
        severity: '',
      );

      await _notificationService.notifyAllReportersOnNewReport(
        reportId: reportId,
        reportType: reportType,
        reportTitle: reportTitle,
        reporterName: reporterName,
        severity: '',
        reporterUid: reporterUid,
      );
    } catch (error, stackTrace) {
      debugPrint('Offline sync notification warning: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _emitPendingCount(String reporterUid) async {
    if (_pendingCountController.isClosed) return;
    _pendingCountController.add(await getPendingCount(reporterUid));
  }

  Future<List<QueuedIncidentDraft>> _loadQueue() async {
    final preferences = await _preferencesFuture;
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <QueuedIncidentDraft>[];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map(
            (item) => QueuedIncidentDraft.fromJson(
              Map<String, dynamic>.from(item.cast<String, dynamic>()),
            ),
          )
          .toList();
    } catch (error, stackTrace) {
      debugPrint('Failed to read offline queue: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <QueuedIncidentDraft>[];
    }
  }

  Future<void> _saveQueue(List<QueuedIncidentDraft> queue) async {
    final preferences = await _preferencesFuture;
    await preferences.setString(
      _storageKey,
      jsonEncode(queue.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<String>> _copyFiles({
    required List<File> files,
    required String localId,
    required String folderName,
  }) async {
    final copiedPaths = <String>[];
    for (var index = 0; index < files.length; index++) {
      final copiedPath = await _copyToQueueDirectory(
        file: files[index],
        localId: localId,
        folderName: folderName,
        fileNamePrefix: 'attachment_$index',
      );
      if (copiedPath != null) {
        copiedPaths.add(copiedPath);
      }
    }
    return copiedPaths;
  }

  Future<List<String>> _copyFilesSafely({
    required List<File> files,
    required String localId,
    required String folderName,
  }) async {
    try {
      return await _copyFiles(
        files: files,
        localId: localId,
        folderName: folderName,
      );
    } catch (error, stackTrace) {
      debugPrint('Offline image copy failed, using original paths: $error');
      debugPrintStack(stackTrace: stackTrace);
      final existingPaths = <String>[];
      for (final file in files) {
        if (await file.exists()) {
          existingPaths.add(file.path);
        }
      }
      return existingPaths;
    }
  }

  Future<String?> _copySingleFile({
    required File? file,
    required String localId,
    required String folderName,
  }) async {
    if (file == null) return null;
    return _copyToQueueDirectory(
      file: file,
      localId: localId,
      folderName: folderName,
      fileNamePrefix: 'attachment',
    );
  }

  Future<String?> _copySingleFileSafely({
    required File? file,
    required String localId,
    required String folderName,
  }) async {
    try {
      return await _copySingleFile(
        file: file,
        localId: localId,
        folderName: folderName,
      );
    } catch (error, stackTrace) {
      debugPrint('Offline video copy failed, using original path: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (file != null && await file.exists()) {
        return file.path;
      }
      return null;
    }
  }

  Future<String?> _copyToQueueDirectory({
    required File file,
    required String localId,
    required String folderName,
    required String fileNamePrefix,
  }) async {
    if (!await file.exists()) return null;

    final root = await _queueRootDirectory();
    final targetDirectory = Directory(p.join(root.path, localId, folderName));
    if (!await targetDirectory.exists()) {
      await targetDirectory.create(recursive: true);
    }

    final extension = p.extension(file.path);
    final targetPath = p.join(
      targetDirectory.path,
      '$fileNamePrefix$extension',
    );
    final copiedFile = await file.copy(targetPath);
    return copiedFile.path;
  }

  Future<Directory> _queueRootDirectory() async {
    try {
      final baseDirectory = await getApplicationSupportDirectory();
      final directory = Directory(
        p.join(baseDirectory.path, 'offline_incident_queue'),
      );
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } catch (error, stackTrace) {
      debugPrint('Application support directory unavailable: $error');
      debugPrintStack(stackTrace: stackTrace);
      final fallbackDirectory = await getTemporaryDirectory();
      final directory = Directory(
        p.join(fallbackDirectory.path, 'offline_incident_queue'),
      );
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    }
  }

  Future<void> _deleteCopiedFiles(QueuedIncidentDraft item) async {
    final directory = Directory(
      p.join((await _queueRootDirectory()).path, item.localId),
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  bool _hasConnection(Object? result) {
    if (result is List<ConnectivityResult>) {
      return result.any((item) => item != ConnectivityResult.none);
    }
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    return false;
  }

  String _generateLocalId(String reporterUid) {
    return '${reporterUid}_${DateTime.now().microsecondsSinceEpoch}';
  }

  void dispose() {
    _pendingCountController.close();
  }
}
