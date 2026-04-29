import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Stream controllers for notification events
  final _notificationTapStream =
      StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedAppSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<DatabaseEvent>? _databaseNotificationSubscription;
  bool _isInitialized = false;
  bool _isLocalNotificationsInitialized = false;
  String? _initializedUserId;
  Map<String, dynamic>? _pendingLaunchNotification;
  bool? _isAppBadgeSupported;
  final Map<String, int> _lastLoggedUnreadCounts = {};

  Stream<Map<String, dynamic>> get notificationTapStream =>
      _notificationTapStream.stream;
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  DatabaseReference get _dbRef => FirebaseDatabase.instance.ref();

  Future<void> ensureLocalNotificationsInitialized() async {
    await _initializeLocalNotifications();
  }

  Future<bool> _supportsAppBadge() async {
    if (_isAppBadgeSupported != null) {
      return _isAppBadgeSupported!;
    }

    try {
      _isAppBadgeSupported = await AppBadgePlus.isSupported();
    } catch (e) {
      debugPrint('⚠️ Error checking app badge support: $e');
      _isAppBadgeSupported = false;
    }
    return _isAppBadgeSupported!;
  }

  Future<void> updateAppBadgeCount(int unreadCount) async {
    final isSupported = await _supportsAppBadge();
    if (!isSupported) {
      return;
    }

    try {
      AppBadgePlus.updateBadge(unreadCount);
    } catch (e) {
      debugPrint('⚠️ Error updating app badge count: $e');
    }
  }

  /// Initialize Firebase Cloud Messaging and Local Notifications
  Future<void> initializeNotifications() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ Notification initialization skipped: no logged-in user');
        return;
      }

      if (_isInitialized && _initializedUserId == currentUser.uid) {
        await _saveFCMToken();
        await _startDatabaseNotificationSync(currentUser.uid);
        return;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Request permission for notifications
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
        '📋 User notification permission status: ${settings.authorizationStatus}',
      );

      final authorizationStatus = settings.authorizationStatus;
      final isPermissionGranted =
          authorizationStatus == AuthorizationStatus.authorized ||
          authorizationStatus == AuthorizationStatus.provisional;

      if (isPermissionGranted) {
        debugPrint('✅ User granted notification permission');

        await _saveFCMToken();
        await _startDatabaseNotificationSync(currentUser.uid);

        await _foregroundMessageSubscription?.cancel();
        _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
          _handleForegroundMessage,
        );

        await _messageOpenedAppSubscription?.cancel();
        _messageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp
            .listen(_handleNotificationTap);

        await _tokenRefreshSubscription?.cancel();
        _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((_) {
          _saveFCMToken();
        });

        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage, storeForLater: true);
        }

        _isInitialized = true;
        _initializedUserId = currentUser.uid;
      } else {
        debugPrint(
          '❌ User declined or has not yet granted notification permission',
        );
      }
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    if (_isLocalNotificationsInitialized) {
      return;
    }

    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('📲 Local notification tapped: ${response.payload}');
          final payloadData = _parsePayload(response.payload);
          if (payloadData.isNotEmpty) {
            _notificationTapStream.add(payloadData);
          }
        },
      );

      // Create notification channels for Android
      // High priority channel for important notifications
      const AndroidNotificationChannel highPriorityChannel =
          AndroidNotificationChannel(
            'high_importance_channel',
            'High Importance Notifications',
            description: 'This channel is used for important notifications.',
            importance: Importance.max,
            showBadge: true,
            enableVibration: true,
            enableLights: true,
            playSound: true,
          );

      // Default channel with system sound
      const AndroidNotificationChannel defaultChannel =
          AndroidNotificationChannel(
            'default_channel',
            'Default Notifications',
            description: 'Default notification channel.',
            importance: Importance.high,
            showBadge: true,
            enableVibration: true,
            enableLights: true,
            playSound: true,
          );

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(highPriorityChannel);
        await androidPlugin.createNotificationChannel(defaultChannel);
        debugPrint('✅ Notification channels created for Android');
      }

      _isLocalNotificationsInitialized = true;
      debugPrint('✅ Local notifications initialized');
    } catch (e) {
      debugPrint('❌ Error initializing local notifications: $e');
    }
  }

  /// Save FCM token to Firebase Database
  Future<void> _saveFCMToken() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String? token = await _messaging.getToken();
        if (token != null) {
          await _dbRef
              .child('users')
              .child(user.uid)
              .child('fcmToken')
              .set(token);

          // Also store in notificationTokens for easy querying
          await _dbRef.child('notificationTokens').child(user.uid).set({
            'token': token,
            'updatedAt': DateTime.now().toIso8601String(),
          });
          debugPrint('✅ FCM token saved successfully');
        }
      }
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
      '📬 Received foreground message: ${message.notification?.title}',
    );

    showNotificationFromRemoteMessage(message);
  }

  Future<void> showNotificationFromRemoteMessage(RemoteMessage message) async {
    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        'Notification';
    final body =
        message.notification?.body ?? message.data['body']?.toString() ?? '';

    final notificationData = <String, dynamic>{
      'title': title,
      'body': body,
      'reportId': message.data['reportId'] ?? '',
      'status': message.data['status'] ?? '',
      'supervisorName': message.data['supervisorName'] ?? '',
      'severity': message.data['severity'] ?? '',
      'unreadCount': message.data['unreadCount'] ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    };

    final unreadCount = int.tryParse(
      message.data['unreadCount']?.toString() ?? '',
    );

    await _showLocalNotification(
      title: title,
      body: body,
      payload: jsonEncode(notificationData),
      notificationData: notificationData,
      unreadCount: unreadCount,
    );
  }

  /// Show local notification with proper sound and visual
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    Map<String, dynamic>? notificationData,
    int? unreadCount,
  }) async {
    try {
      // Use system default sound and create visual notification with full visibility
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            channelShowBadge: true,
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            enableLights: true,
            vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
            ledColor: const Color.fromARGB(255, 255, 0, 0),
            playSound: true,
            styleInformation: BigTextStyleInformation(body),
            autoCancel: true,
            showWhen: true,
            visibility: NotificationVisibility.public,
            number: unreadCount,
            onlyAlertOnce: false,
          );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: unreadCount,
      );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Use a unique ID so Android keeps notifications separate in the tray.
      final notificationId = DateTime.now().microsecondsSinceEpoch.remainder(
        2147483647,
      );

      await _localNotifications.show(
        notificationId.abs(),
        title,
        body,
        platformChannelSpecifics,
        payload: payload ?? jsonEncode(notificationData ?? <String, dynamic>{}),
      );
      if (unreadCount != null) {
        await updateAppBadgeCount(unreadCount);
      }
      debugPrint('🔔 Local notification displayed: $title');
    } catch (e) {
      debugPrint('❌ Error showing local notification: $e');
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(
    RemoteMessage message, {
    bool storeForLater = false,
  }) {
    debugPrint('🔗 Notification tapped: ${message.messageId}');

    // Emit notification tap event with data for navigation
    Map<String, dynamic> tapData = {
      'reportId': message.data['reportId'] ?? '',
      'status': message.data['status'] ?? '',
      'supervisorName': message.data['supervisorName'] ?? '',
      'title': message.notification?.title ?? 'Notification',
      'body': message.notification?.body ?? '',
      'messageId': message.messageId ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (storeForLater) {
      _pendingLaunchNotification = tapData;
    }

    _notificationTapStream.add(tapData);
  }

  Map<String, dynamic>? consumePendingLaunchNotification() {
    final pendingLaunchNotification = _pendingLaunchNotification;
    _pendingLaunchNotification = null;
    return pendingLaunchNotification;
  }

  Map<String, dynamic> _parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (e) {
      debugPrint('⚠️ Unable to parse notification payload: $e');
    }

    return <String, dynamic>{'payload': payload};
  }

  Future<void> _startDatabaseNotificationSync(String userId) async {
    await _databaseNotificationSubscription?.cancel();

    _databaseNotificationSubscription = _dbRef
        .child('userNotifications')
        .child(userId)
        .onValue
        .listen((event) async {
          final unreadCount = await _getUnreadCountSnapshot(userId);
          await updateAppBadgeCount(unreadCount);
        });
  }

  Future<bool> saveNotificationForUser({
    required String userId,
    required Map<String, dynamic> notificationData,
    String? dedupeKey,
    Duration dedupeWindow = const Duration(minutes: 2),
  }) async {
    final normalizedDedupeKey = dedupeKey?.trim() ?? '';
    final payload = <String, dynamic>{
      ...notificationData,
      if (normalizedDedupeKey.isNotEmpty) 'dedupeKey': normalizedDedupeKey,
    };

    if (normalizedDedupeKey.isNotEmpty) {
      final dedupeId = base64Url
          .encode(utf8.encode(normalizedDedupeKey))
          .replaceAll('=', '');
      final dedupeRef = _dbRef
          .child('notificationDedupes')
          .child(userId)
          .child(dedupeId);
      final snapshot = await dedupeRef.get();
      final now = DateTime.now();

      if (snapshot.exists && snapshot.value is Map) {
        final dedupeData = Map<String, dynamic>.from(snapshot.value as Map);
        final timestamp = DateTime.tryParse(
          dedupeData['timestamp']?.toString() ?? '',
        );
        if (timestamp != null &&
            now.difference(timestamp).abs() <= dedupeWindow) {
          debugPrint(
            '⚠️ Skipping duplicate notification for $userId with key $normalizedDedupeKey',
          );
          return false;
        }
      }

      await dedupeRef.set({
        'dedupeKey': normalizedDedupeKey,
        'timestamp': now.toIso8601String(),
      });
    }

    await _dbRef.child('userNotifications').child(userId).push().set(payload);
    return true;
  }

  /// Mark an incident report as read by a supervisor
  Future<void> markIncidentAsReadBySupervisor(
    String supervisorUid,
    String incidentId,
  ) async {
    try {
      await _dbRef
          .child('incidentReadStatus')
          .child(supervisorUid)
          .child(incidentId)
          .set({'read': true, 'readAt': DateTime.now().toIso8601String()});
      debugPrint(
        '✅ Incident $incidentId marked as read by supervisor $supervisorUid',
      );
    } catch (e) {
      debugPrint('❌ Error marking incident as read: $e');
    }
  }

  /// Check if a supervisor has read an incident report
  Future<bool> hasIncidentBeenReadBySupervisor(
    String supervisorUid,
    String incidentId,
  ) async {
    try {
      final snapshot = await _dbRef
          .child('incidentReadStatus')
          .child(supervisorUid)
          .child(incidentId)
          .get();
      return snapshot.exists &&
          (snapshot.value as Map?)?.containsKey('read') == true;
    } catch (e) {
      debugPrint('❌ Error checking if incident was read: $e');
      return false;
    }
  }

  /// Get count of new/unread reports for supervisors
  Stream<int> getNewReportsCountForSupervisor(String supervisorUid) {
    return _dbRef.child('incidents').onValue.asyncMap((incidentsEvent) async {
      int newReportCount = 0;
      if (incidentsEvent.snapshot.exists) {
        final data = incidentsEvent.snapshot.value as Map?;
        if (data != null) {
          // Get all incidents this supervisor has read
          final readIncidents = <String>{};
          try {
            final readStatusSnapshot = await _dbRef
                .child('incidentReadStatus')
                .child(supervisorUid)
                .get();

            if (readStatusSnapshot.exists) {
              final readData = readStatusSnapshot.value as Map?;
              if (readData != null) {
                readData.forEach((key, value) {
                  if (value is Map && (value['read'] == true)) {
                    readIncidents.add(key.toString());
                  }
                });
              }
            }
          } catch (e) {
            // If we can't get read status, continue without it
            debugPrint('📊 Could not retrieve read status: $e');
          }

          // Count incidents that haven't been read yet
          final now = DateTime.now();
          data.forEach((key, value) {
            if (value is Map) {
              // Only count if supervisor hasn't read it yet
              if (!readIncidents.contains(key.toString())) {
                try {
                  var createdAtStr = value['createdAt'] ?? value['timestamp'];
                  if (createdAtStr != null) {
                    final createdAt = DateTime.parse(createdAtStr.toString());
                    final hoursDiff = now.difference(createdAt).inHours;
                    if (hoursDiff <= 24) {
                      newReportCount++;
                    }
                  }
                } catch (e) {
                  // Ignore date parsing errors
                }
              }
            }
          });
        }
      }
      return newReportCount;
    });
  }

  /// Get count of new/unread reports for supervisors (old method - deprecated)
  @Deprecated('Use getNewReportsCountForSupervisor instead')
  Stream<int> getNewReportsCount() {
    return _dbRef.child('incidents').onValue.map((event) {
      int newReportCount = 0;
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map?;
        if (data != null) {
          final now = DateTime.now();
          data.forEach((key, value) {
            if (value is Map) {
              // Count reports created in the last 24 hours
              try {
                var createdAtStr = value['createdAt'] ?? value['timestamp'];
                if (createdAtStr != null) {
                  final createdAt = DateTime.parse(createdAtStr.toString());
                  final hoursDiff = now.difference(createdAt).inHours;
                  if (hoursDiff <= 24) {
                    newReportCount++;
                  }
                }
              } catch (e) {
                // Ignore date parsing errors
              }
            }
          });
        }
      }
      return newReportCount;
    });
  }

  /// Notify supervisors on new report with fallback mechanism
  Future<int> notifySupervisorsOnNewReport({
    required String reportId,
    required String reportType,
    required String reportTitle,
    required String reporterName,
    required String severity,
  }) async {
    int notifiedCount = 0;
    try {
      debugPrint('📢 Fetching supervisors to notify about new report...');
      final normalizedSeverity = severity.trim();
      final hasVisibleSeverity =
          normalizedSeverity.isNotEmpty &&
          normalizedSeverity.toLowerCase() != 'not set';
      final notificationBody = hasVisibleSeverity
          ? '$reportType - $reportTitle by $reporterName (Severity: $normalizedSeverity)'
          : '$reportType - $reportTitle by $reporterName';

      // Get all supervisors
      var supervisorUids = await getAllSupervisors();
      debugPrint('Found ${supervisorUids.length} supervisors');
      debugPrint('🔍 Supervisor UIDs: $supervisorUids');

      // Fallback: if no supervisors found, notify ALL users
      if (supervisorUids.isEmpty) {
        debugPrint(
          '⚠️ No supervisors found! Attempting fallback: notifying all users',
        );
        try {
          final usersSnapshot = await _dbRef.child('users').get();
          if (usersSnapshot.exists && usersSnapshot.value is Map) {
            final usersMap = usersSnapshot.value as Map;
            supervisorUids = usersMap.keys.map((e) => e.toString()).toList();
            debugPrint(
              '📣 Fallback: Found ${supervisorUids.length} total users to notify',
            );
          }
        } catch (fallbackError) {
          debugPrint('⚠️ Fallback also failed: $fallbackError');
        }
      }

      for (String supervisorUid in supervisorUids) {
        final notificationData = {
          'title': 'New Incident Report',
          'body': notificationBody,
          'reportId': reportId,
          if (hasVisibleSeverity) 'severity': normalizedSeverity,
          'reporterName': reporterName,
          'timestamp': DateTime.now().toIso8601String(),
          'read': false,
        };

        try {
          await _dbRef
              .child('userNotifications')
              .child(supervisorUid)
              .push()
              .set(notificationData);

          debugPrint('✅ Notification saved for supervisor: $supervisorUid');
          notifiedCount++;
        } catch (e) {
          debugPrint('❌ Error notifying supervisor $supervisorUid: $e');
        }
      }

      debugPrint(
        '✅ New report notification sent to $notifiedCount supervisors',
      );
      return notifiedCount;
    } catch (e) {
      debugPrint('❌ Error notifying supervisors: $e');
      return notifiedCount;
    }
  }

  /// Send notification to a supervisor when they update a report status
  Future<bool> notifySupervisorOnUpdate({
    required String supervisorUid,
    required String reportId,
    required String reportType,
    required String newStatus,
  }) async {
    try {
      debugPrint(
        '📢 Notifying supervisor about update - UID: $supervisorUid, Report: $reportId',
      );

      if (supervisorUid.isEmpty) {
        debugPrint('❌ Supervisor UID is empty! Cannot send notification.');
        return false;
      }

      final notificationData = {
        'title': 'Report Updated',
        'body': '$reportType report status changed to $newStatus',
        'reportId': reportId,
        'status': newStatus,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      };

      // Store in database
      await _dbRef
          .child('userNotifications')
          .child(supervisorUid)
          .push()
          .set(notificationData);

      debugPrint('✅ Notification stored for supervisor: $supervisorUid');
      return true;
    } catch (e) {
      debugPrint('❌ Error notifying supervisor: $e');
      return false;
    }
  }

  /// Send notification to a reporter when their report is updated
  Future<bool> notifyReporterOnUpdate({
    required String reporterUid,
    required String reportId,
    required String reportType,
    required String newStatus,
    required String supervisorName,
  }) async {
    try {
      debugPrint(
        '📢 Attempting to notify reporter - UID: $reporterUid, Report: $reportId',
      );

      if (reporterUid.isEmpty) {
        debugPrint('❌ Reporter UID is empty! Cannot send notification.');
        return false;
      }

      // Get reporter's FCM token
      final tokenSnapshot = await _dbRef
          .child('users')
          .child(reporterUid)
          .child('fcmToken')
          .get();

      debugPrint(
        '🔍 FCM Token check - Exists: ${tokenSnapshot.exists}, Value: ${tokenSnapshot.value}',
      );

      final notificationData = {
        'title': 'Report Updated',
        'body': '$reportType report status changed to $newStatus',
        'reportId': reportId,
        'status': newStatus,
        'supervisorName': supervisorName,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      };

      // Store in database for the reporter to read
      await _dbRef
          .child('userNotifications')
          .child(reporterUid)
          .push()
          .set(notificationData);

      debugPrint(
        '✅ Notification stored for reporter: $reporterUid at path: userNotifications/$reporterUid',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Error notifying reporter: $e');
      return false;
    }
  }

  /// Send notification to multiple reporters (bulk notification)
  Future<int> notifyReportersOnMassUpdate({
    required List<String> reporterUids,
    required String title,
    required String message,
  }) async {
    int successCount = 0;
    try {
      for (String uid in reporterUids) {
        final notificationData = {
          'title': title,
          'body': message,
          'timestamp': DateTime.now().toIso8601String(),
          'read': false,
        };

        await _dbRef
            .child('userNotifications')
            .child(uid)
            .push()
            .set(notificationData);

        successCount++;
      }
      debugPrint('Bulk notification sent to $successCount reporters');
      return successCount;
    } catch (e) {
      debugPrint('Error sending bulk notifications: $e');
      return successCount;
    }
  }

  /// Get all notifications for current user
  Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    return _dbRef.child('userNotifications').child(userId).onValue.map((event) {
      final notifications = <Map<String, dynamic>>[];
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map?;
        if (data != null) {
          data.forEach((dynamic key, dynamic value) {
            if (value is Map) {
              notifications.add({
                'id': key,
                'title': value['title'] ?? 'Notification',
                'body': value['body'] ?? '',
                'reportId': value['reportId'],
                'status': value['status'],
                'supervisorName': value['supervisorName'],
                'severity': value['severity'],
                'reporterName': value['reporterName'] ?? 'Unknown',
                'timestamp': value['timestamp'] ?? '',
                'read': value['read'] ?? false,
              });
            }
          });
        }
      }
      // Sort by timestamp descending
      notifications.sort((a, b) {
        DateTime timeA =
            DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(1970);
        DateTime timeB =
            DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(1970);
        return timeB.compareTo(timeA);
      });
      return notifications;
    });
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(
    String userId,
    String notificationId,
  ) async {
    try {
      await _dbRef
          .child('userNotifications')
          .child(userId)
          .child(notificationId)
          .update({'read': true});
      final remainingUnreadCount = await _getUnreadCountSnapshot(userId);
      await updateAppBadgeCount(remainingUnreadCount);
      debugPrint('✅ Notification marked as read: $notificationId');
      // Ensure the stream gets updated by making a small delay
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      debugPrint('📋 Marking all notifications as read for user: $userId');
      final snapshot = await _dbRef
          .child('userNotifications')
          .child(userId)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map?;
        if (data != null) {
          int count = 0;
          final updateTasks = <Future>[];

          data.forEach((dynamic key, dynamic value) {
            if (value is Map) {
              final isRead = value['read'];
              if (isRead != true) {
                updateTasks.add(
                  _dbRef
                      .child('userNotifications')
                      .child(userId)
                      .child(key.toString())
                      .update({'read': true}),
                );
                count++;
              }
            }
          });

          if (updateTasks.isNotEmpty) {
            await Future.wait(updateTasks);
            await updateAppBadgeCount(0);
            await Future.delayed(const Duration(milliseconds: 200));
            debugPrint('✅ Marked $count notifications as read');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _dbRef
          .child('userNotifications')
          .child(userId)
          .child(notificationId)
          .remove();
      final remainingUnreadCount = await _getUnreadCountSnapshot(userId);
      await updateAppBadgeCount(remainingUnreadCount);
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  /// Get notification preferences for a user
  Future<Map<String, dynamic>> getNotificationPreferences(String userId) async {
    try {
      final snapshot = await _dbRef
          .child('notificationPreferences')
          .child(userId)
          .get();

      if (snapshot.exists && snapshot.value is Map) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      } else {
        // Return default preferences
        return {'newReports': true};
      }
    } catch (e) {
      debugPrint('Error getting notification preferences: $e');
      return {'newReports': true};
    }
  }

  /// Update notification preferences for a user
  Future<void> updateNotificationPreferences(
    String userId,
    Map<String, dynamic> preferences,
  ) async {
    try {
      await _dbRef
          .child('notificationPreferences')
          .child(userId)
          .set(preferences);
      debugPrint('Notification preferences updated for user: $userId');
    } catch (e) {
      debugPrint('Error updating notification preferences: $e');
    }
  }

  /// Get unread notification count
  Stream<int> getUnreadNotificationCount(String userId) {
    return _dbRef.child('userNotifications').child(userId).onValue.map((event) {
      int count = 0;
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map?;
        if (data != null) {
          data.forEach((dynamic key, dynamic value) {
            if (value is Map) {
              // Explicitly check if read is false or missing
              final isRead = value['read'];
              // If read field exists and is true, don't count it
              // If read field is missing or false, count it as unread
              if (isRead != true) {
                count++;
              }
            }
          });
        }
      }
      if (_lastLoggedUnreadCounts[userId] != count) {
        _lastLoggedUnreadCounts[userId] = count;
        debugPrint('📊 Unread notification count for $userId: $count');
      }
      return count;
    });
  }

  Future<int> _getUnreadCountSnapshot(String userId) async {
    try {
      final snapshot = await _dbRef
          .child('userNotifications')
          .child(userId)
          .get();

      int count = 0;
      if (snapshot.exists) {
        final data = snapshot.value as Map?;
        if (data != null) {
          data.forEach((key, value) {
            if (value is Map && value['read'] != true) {
              count++;
            }
          });
        }
      }

      return count;
    } catch (e) {
      debugPrint('⚠️ Error reading unread badge snapshot: $e');
      return 0;
    }
  }

  /// Auto-mark all unread notifications as read for a user
  /// Call this when user opens the notifications viewer
  Future<void> autoMarkUnreadNotificationsAsRead(String userId) async {
    try {
      debugPrint(
        '📋 Auto-marking all unread notifications as read for user: $userId',
      );
      final snapshot = await _dbRef
          .child('userNotifications')
          .child(userId)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map?;
        if (data != null) {
          int count = 0;
          final updateTasks = <Future>[];

          data.forEach((dynamic key, dynamic value) {
            if (value is Map) {
              // Mark as read if not already read
              final isRead = value['read'];
              if (isRead != true) {
                updateTasks.add(
                  _dbRef
                      .child('userNotifications')
                      .child(userId)
                      .child(key.toString())
                      .update({'read': true}),
                );
                count++;
              }
            }
          });

          // Wait for all updates to complete
          if (updateTasks.isNotEmpty) {
            await Future.wait(updateTasks);
            // Extra delay to ensure stream updates
            await Future.delayed(const Duration(milliseconds: 200));
            debugPrint('✅ Auto-marked $count notifications as read');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error auto-marking notifications as read: $e');
    }
  }

  /// Get all supervisor UIDs from database
  Future<List<String>> getAllSupervisors() async {
    try {
      debugPrint('🔍 Starting getAllSupervisors...');
      final snapshot = await _dbRef
          .child('roleDirectory')
          .child('supervisors')
          .get();
      final supervisors = <String>[];

      if (!snapshot.exists || snapshot.value == null) {
        debugPrint('ℹ️ No active supervisors found in role directory');
        return supervisors;
      }

      final data = snapshot.value;
      debugPrint('🔍 Supervisor directory type: ${data.runtimeType}');

      if (data is Map) {
        debugPrint(
          '📋 Processing supervisor directory as Map with ${data.length} entries',
        );
        data.forEach((uid, value) {
          if (value == true) {
            supervisors.add(uid.toString());
            debugPrint('✅ Found active supervisor: $uid');
          }
        });
      } else {
        debugPrint(
          '⚠️ Supervisor role directory is not a Map: ${data.runtimeType}',
        );
      }

      debugPrint('✅ Found ${supervisors.length} supervisors');
      return supervisors;
    } catch (e) {
      debugPrint('❌ Error getting supervisors: $e');
      return [];
    }
  }

  /// Notify all supervisors when notes are added to an incident
  Future<void> notifySupervisorsOnNoteAdded({
    required String reportId,
    required String reportType,
    required String supervisorName,
    required String reportTitle,
    required String location,
    required String notePreview,
    String? severity,
    String? excludeSupervisorUid,
  }) async {
    try {
      final supervisors = await getAllSupervisors();

      if (supervisors.isEmpty) {
        debugPrint('No supervisors found to notify about notes');
        return;
      }

      final notificationData = {
        'title': 'Note Added: $reportType',
        'body':
            '$supervisorName added notes to "$reportTitle" at $location: "$notePreview"',
        'reportId': reportId,
        'reportType': reportType,
        'reportTitle': reportTitle,
        'location': location,
        'supervisorName': supervisorName,
        'notePreview': notePreview,
        if ((severity ?? '').trim().isNotEmpty) 'severity': severity!.trim(),
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      };

      int sentCount = 0;
      for (String supervisorUid in supervisors) {
        if (excludeSupervisorUid != null &&
            excludeSupervisorUid == supervisorUid) {
          continue;
        }

        final saved = await saveNotificationForUser(
          userId: supervisorUid,
          notificationData: notificationData,
          dedupeKey: 'supervisor-note:$reportId:$supervisorUid:$notePreview',
        );
        if (saved) {
          sentCount++;
        }
      }

      debugPrint(
        '✅ Note notification sent to $sentCount supervisors for report: $reportId',
      );
    } catch (e) {
      debugPrint('❌ Error notifying supervisors on note added: $e');
    }
  }

  /// Get all reporter UIDs from database
  Future<List<String>> getAllReporters() async {
    try {
      debugPrint('🔍 Starting getAllReporters...');
      final snapshot = await _dbRef
          .child('roleDirectory')
          .child('reporters')
          .get();
      final reporters = <String>[];

      if (!snapshot.exists || snapshot.value == null) {
        debugPrint('ℹ️ No active reporters found in role directory');
        return reporters;
      }

      final data = snapshot.value;
      debugPrint('🔍 Reporter directory type: ${data.runtimeType}');

      if (data is Map) {
        debugPrint(
          '📋 Processing reporter directory as Map with ${data.length} entries',
        );
        data.forEach((uid, value) {
          if (value == true) {
            reporters.add(uid.toString());
            debugPrint('✅ Found reporter: $uid');
          }
        });
      } else {
        debugPrint(
          '⚠️ Reporter role directory is not a Map: ${data.runtimeType}',
        );
      }

      debugPrint('✅ Found ${reporters.length} reporters');
      return reporters;
    } catch (e) {
      debugPrint('❌ Error getting reporters: $e');
      return [];
    }
  }

  /// Send notification to all reporters when a new report is submitted
  Future<int> notifyAllReportersOnNewReport({
    required String reportId,
    required String reportType,
    required String reportTitle,
    required String reporterName,
    required String severity,
    required String? reporterUid, // UID of the person who created the report
  }) async {
    int notifiedCount = 0;
    try {
      debugPrint('📢 Fetching reporters to notify about new report...');
      debugPrint('🔍 Current reporter UID: $reporterUid');
      final normalizedSeverity = severity.trim();
      final hasVisibleSeverity =
          normalizedSeverity.isNotEmpty &&
          normalizedSeverity.toLowerCase() != 'not set';
      final notificationBody = hasVisibleSeverity
          ? '$reportType - $reportTitle by $reporterName (Severity: $normalizedSeverity)'
          : '$reportType - $reportTitle by $reporterName';

      // Get all reporters
      final reporterUids = await getAllReporters();
      debugPrint('Found ${reporterUids.length} reporters');
      if (reporterUids.isEmpty) {
        debugPrint('⚠️ No reporters found in database');
      } else {
        debugPrint('🔍 Reporter UIDs: $reporterUids');
      }

      for (String recipientUid in reporterUids) {
        // Don't send notification to the reporter who created the report
        if (recipientUid == reporterUid) {
          continue;
        }

        final notificationData = {
          'title': 'New System Report',
          'body': notificationBody,
          'reportId': reportId,
          'reportType': reportType,
          if (hasVisibleSeverity) 'severity': normalizedSeverity,
          'reporterName': reporterName,
          'timestamp': DateTime.now().toIso8601String(),
          'read': false,
        };

        try {
          await _dbRef
              .child('userNotifications')
              .child(recipientUid)
              .push()
              .set(notificationData);

          debugPrint('✅ Notification saved for reporter: $recipientUid');
          notifiedCount++;
        } catch (e) {
          debugPrint('❌ Error notifying reporter $recipientUid: $e');
        }
      }

      debugPrint('✅ New report notification sent to $notifiedCount reporters');
      return notifiedCount;
    } catch (e) {
      debugPrint('❌ Error notifying reporters of new report: $e');
      return notifiedCount;
    }
  }

  /// Send notification to all reporters when supervisor updates a report
  Future<int> notifyAllReportersOnUpdate({
    required String reportId,
    required String reportType,
    required String description,
    required String status,
    required String severity,
    required String supervisorName,
    String? notificationTitle,
    String? notificationBody,
    String? excludeReporterUid,
    String? dedupeKey,
  }) async {
    int notifiedCount = 0;
    try {
      debugPrint('📢 Fetching reporters to notify about update...');

      // Get all reporters
      final reporterUids = await getAllReporters();
      debugPrint(
        'Found ${reporterUids.length} reporters for update notification',
      );
      if (reporterUids.isEmpty) {
        debugPrint('⚠️ No reporters found to notify about update');
      } else {
        debugPrint('🔍 Reporter UIDs to notify: $reporterUids');
      }

      final resolvedTitle = notificationTitle ?? 'Report Updated';
      final resolvedBody =
          notificationBody ??
          'Supervisor $supervisorName updated $reportType report. Status: ${status.toUpperCase()}, Severity: ${severity.toUpperCase()}';

      final notificationData = {
        'title': resolvedTitle,
        'body': resolvedBody,
        'reportId': reportId,
        'reportType': reportType,
        'description': description,
        'status': status,
        'severity': severity,
        'supervisorName': supervisorName,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      };

      for (String reporterUid in reporterUids) {
        try {
          if (excludeReporterUid != null && reporterUid == excludeReporterUid) {
            continue;
          }

          final saved = await saveNotificationForUser(
            userId: reporterUid,
            notificationData: notificationData,
            dedupeKey: dedupeKey != null && dedupeKey.trim().isNotEmpty
                ? '${dedupeKey.trim()}:$reporterUid'
                : null,
          );

          if (saved) {
            debugPrint(
              '✅ Update notification saved for reporter: $reporterUid',
            );
            notifiedCount++;
          }
        } catch (e) {
          debugPrint('❌ Error notifying reporter $reporterUid of update: $e');
        }
      }

      debugPrint('✅ Update notification sent to $notifiedCount reporters');
      return notifiedCount;
    } catch (e) {
      debugPrint('❌ Error notifying reporters of update: $e');
      return notifiedCount;
    }
  }
}
