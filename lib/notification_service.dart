import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  // Stream controllers for notification events
  final _notificationTapStream = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get notificationTapStream => _notificationTapStream.stream;

  /// Initialize Firebase Cloud Messaging and Local Notifications
  Future<void> initializeNotifications() async {
    try {
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

      print('📋 User notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus.index >= 1) {
        // Permission granted (authorized or provisional)
        print('✅ User granted notification permission');

        // Get FCM token and store it
        await _saveFCMToken();

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _handleForegroundMessage(message);
        });

        // Handle notification taps (when app is in background/terminated)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _handleNotificationTap(message);
        });

        // Handle background messages (when app is terminated or in background)
        FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

        // Handle token refresh
        _messaging.onTokenRefresh.listen((_) {
          _saveFCMToken();
        });
      } else {
        print('❌ User declined or has not yet granted notification permission');
      }
    } catch (e) {
      print('❌ Error initializing notifications: $e');
    }
  }

  /// Static background message handler for Firebase Messaging
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('📬 Received background message: ${message.notification?.title}');
    // Background messages are handled by Firebase by default
    // This callback is triggered when app is terminated or in background
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
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
          print('📲 Local notification tapped: ${response.payload}');
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
        enableVibration: true,
        enableLights: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
        playSound: true,
      );

      // Default channel with system sound
      const AndroidNotificationChannel defaultChannel =
          AndroidNotificationChannel(
        'default_channel',
        'Default Notifications',
        description: 'Default notification channel.',
        importance: Importance.high,
        enableVibration: true,
        enableLights: true,
        playSound: true,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(highPriorityChannel);
        await androidPlugin.createNotificationChannel(defaultChannel);
        print('✅ Notification channels created for Android');
      }

      print('✅ Local notifications initialized');
    } catch (e) {
      print('❌ Error initializing local notifications: $e');
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
          await _dbRef
              .child('notificationTokens')
              .child(user.uid)
              .set({
                'token': token,
                'updatedAt': DateTime.now().toIso8601String(),
              });
          print('✅ FCM token saved successfully');
        }
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('📬 Received foreground message: ${message.notification?.title}');
    
    // Show local notification when message is received in foreground
    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? '';
    
    // Extract incident data if available
    Map<String, dynamic> notificationData = {
      'title': title,
      'body': body,
      'reportId': message.data['reportId'] ?? '',
      'status': message.data['status'] ?? '',
      'supervisorName': message.data['supervisorName'] ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // Emit to stream for in-app handling
    _notificationTapStream.add(notificationData);
    
    _showLocalNotification(
      title: title,
      body: body,
      payload: message.data.toString(),
      notificationData: notificationData,
    );
  }

  /// Show local notification with proper sound and visual
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    Map<String, dynamic>? notificationData,
  }) async {
    try {
      // Use system default sound and create visual notification with full visibility  
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        enableLights: true,
        vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
        ledColor: const Color.fromARGB(255, 255, 0, 0),
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        styleInformation: BigTextStyleInformation(body),
        autoCancel: true,
        tag: notificationData?['reportId'] ?? 'notification',
        showWhen: true,
        visibility: NotificationVisibility.public,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notification_sound.caf',
      );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Use a deterministic ID based on reportId to avoid duplicate notifications
      int notificationId = notificationData?['reportId']?.hashCode ?? DateTime.now().millisecond;
      
      await _localNotifications.show(
        notificationId.abs(),
        title,
        body,
        platformChannelSpecifics,
        payload: payload ?? notificationData.toString(),
      );
      print('🔔 Local notification displayed: $title');
    } catch (e) {
      print('❌ Error showing local notification: $e');
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('🔗 Notification tapped: ${message.messageId}');
    
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
    
    _notificationTapStream.add(tapData);
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
          .set({
            'read': true,
            'readAt': DateTime.now().toIso8601String(),
          });
      print('✅ Incident $incidentId marked as read by supervisor $supervisorUid');
    } catch (e) {
      print('❌ Error marking incident as read: $e');
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
      return snapshot.exists && (snapshot.value as Map?)?.containsKey('read') == true;
    } catch (e) {
      print('❌ Error checking if incident was read: $e');
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
            print('📊 Could not retrieve read status: $e');
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

  /// Send notification to supervisors when a new report is submitted
  Future<int> notifySupervisorsOnNewReport({
    required String reportId,
    required String reportType,
    required String reportTitle,
    required String reporterName,
    required String severity,
  }) async {
    int notifiedCount = 0;
    try {
      print('📢 Fetching supervisors to notify about new report...');
      
      // Get all supervisors
      final supervisorUids = await getAllSupervisors();
      print('Found ${supervisorUids.length} supervisors');
      print('🔍 Supervisor UIDs: $supervisorUids');

      for (String supervisorUid in supervisorUids) {
        final notificationData = {
          'title': 'New Incident Report',
          'body': '$reportType - $reportTitle by $reporterName (Severity: $severity)',
          'reportId': reportId,
          'severity': severity,
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
          
          print('✅ Notification saved for supervisor: $supervisorUid');
          notifiedCount++;
        } catch (e) {
          print('❌ Error notifying supervisor $supervisorUid: $e');
        }
      }
      
      print('✅ New report notification sent to $notifiedCount supervisors');
      return notifiedCount;
    } catch (e) {
      print('❌ Error notifying supervisors: $e');
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
      print('📢 Notifying supervisor about update - UID: $supervisorUid, Report: $reportId');
      
      if (supervisorUid.isEmpty) {
        print('❌ Supervisor UID is empty! Cannot send notification.');
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

      print('✅ Notification stored for supervisor: $supervisorUid');
      return true;
    } catch (e) {
      print('❌ Error notifying supervisor: $e');
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
      print('📢 Attempting to notify reporter - UID: $reporterUid, Report: $reportId');
      
      if (reporterUid.isEmpty) {
        print('❌ Reporter UID is empty! Cannot send notification.');
        return false;
      }

      // Get reporter's FCM token
      final tokenSnapshot = await _dbRef
          .child('users')
          .child(reporterUid)
          .child('fcmToken')
          .get();

      print('🔍 FCM Token check - Exists: ${tokenSnapshot.exists}, Value: ${tokenSnapshot.value}');

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

      print('✅ Notification stored for reporter: $reporterUid at path: userNotifications/$reporterUid');
      return true;
    } catch (e) {
      print('❌ Error notifying reporter: $e');
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
      print('Bulk notification sent to $successCount reporters');
      return successCount;
    } catch (e) {
      print('Error sending bulk notifications: $e');
      return successCount;
    }
  }

  /// Get all notifications for current user
  Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    return _dbRef
        .child('userNotifications')
        .child(userId)
        .onValue
        .map((event) {
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
                'timestamp': value['timestamp'] ?? '',
                'read': value['read'] ?? false,
              });
            }
          });
        }
      }
      // Sort by timestamp descending
      notifications.sort((a, b) {
        DateTime timeA = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(1970);
        DateTime timeB = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(1970);
        return timeB.compareTo(timeA);
      });
      return notifications;
    });
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String userId, String notificationId) async {
    try {
      await _dbRef
          .child('userNotifications')
          .child(userId)
          .child(notificationId)
          .update({'read': true});
      print('✅ Notification marked as read: $notificationId');
      // Ensure the stream gets updated by making a small delay
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      print('📋 Marking all notifications as read for user: $userId');
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
            await Future.delayed(const Duration(milliseconds: 200));
            print('✅ Marked $count notifications as read');
          }
        }
      }
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
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
    } catch (e) {
      print('Error deleting notification: $e');
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
        return {
          'newReports': true,
        };
      }
    } catch (e) {
      print('Error getting notification preferences: $e');
      return {
        'newReports': true,
      };
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
      print('Notification preferences updated for user: $userId');
    } catch (e) {
      print('Error updating notification preferences: $e');
    }
  }

  /// Get unread notification count
  Stream<int> getUnreadNotificationCount(String userId) {
    return _dbRef
        .child('userNotifications')
        .child(userId)
        .onValue
        .map((event) {
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
      print('📊 Unread notification count for $userId: $count');
      return count;
    });
  }

  /// Auto-mark all unread notifications as read for a user
  /// Call this when user opens the notifications viewer
  Future<void> autoMarkUnreadNotificationsAsRead(String userId) async {
    try {
      print('📋 Auto-marking all unread notifications as read for user: $userId');
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
            print('✅ Auto-marked $count notifications as read');
          }
        }
      }
    } catch (e) {
      print('❌ Error auto-marking notifications as read: $e');
    }
  }

  /// Get all supervisor UIDs from database
  Future<List<String>> getAllSupervisors() async {
    try {
      final snapshot = await _dbRef.child('users').get();
      final supervisors = <String>[];

      if (snapshot.exists) {
        final data = snapshot.value as Map?;
        if (data != null) {
          data.forEach((dynamic uid, dynamic userInfo) {
            if (userInfo is Map) {
              final role = (userInfo['role'] ?? '').toString().toLowerCase();
              if (role == 'supervisor') {
                supervisors.add(uid.toString());
              }
            }
          });
        }
      }
      print('Found ${supervisors.length} supervisors');
      return supervisors;
    } catch (e) {
      print('Error getting supervisors: $e');
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
  }) async {
    try {
      final supervisors = await getAllSupervisors();
      
      if (supervisors.isEmpty) {
        print('No supervisors found to notify about notes');
        return;
      }

      final notificationData = {
        'title': 'Note Added: $reportType',
        'body': '$supervisorName added notes to "$reportTitle" at $location: "$notePreview"',
        'reportId': reportId,
        'reportType': reportType,
        'reportTitle': reportTitle,
        'location': location,
        'supervisorName': supervisorName,
        'notePreview': notePreview,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      };

      int sentCount = 0;
      for (String supervisorUid in supervisors) {
        await _dbRef
            .child('userNotifications')
            .child(supervisorUid)
            .push()
            .set(notificationData);
        sentCount++;
      }

      print('✅ Note notification sent to $sentCount supervisors for report: $reportId');
    } catch (e) {
      print('❌ Error notifying supervisors on note added: $e');
    }
  }
}

