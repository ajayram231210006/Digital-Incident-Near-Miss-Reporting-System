import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  /// Initialize Firebase Cloud Messaging
  Future<void> initializeNotifications() async {
    try {
      // Request permission for notifications
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('User notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus.index >= 1) {
        // Permission granted (authorized or provisional)
        print('User granted notification permission');

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

        // Handle token refresh
        _messaging.onTokenRefresh.listen((_) {
          _saveFCMToken();
        });
      } else {
        print('User declined or has not yet granted notification permission');
      }
    } catch (e) {
      print('Error initializing notifications: $e');
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
          print('FCM token saved: $token');
        }
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground message: ${message.notification?.title}');
    // You can display a dialog, snackbar, or local notification here
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.messageId}');
    // Handle navigation based on notification data
  }

  /// Get count of new/unread reports for supervisors
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
    } catch (e) {
      print('Error marking notification as read: $e');
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
            if (value is Map && (value['read'] ?? false) == false) {
              count++;
            }
          });
        }
      }
      return count;
    });
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

  /// Notify all supervisors about a new incident report
  Future<void> notifySupervisorsOnNewReport({
    required String reportId,
    required String reportType,
    required String reporterEmail,
    required String location,
  }) async {
    try {
      print('📢 Fetching supervisors to notify about new report...');
      final supervisors = await getAllSupervisors();
      
      if (supervisors.isEmpty) {
        print('❌ No supervisors found to notify');
        return;
      }

      print('🔍 Supervisor UIDs: $supervisors');
      int successCount = 0;
      int skippedCount = 0;

      for (String supervisorUid in supervisors) {
        try {
          // Check if supervisor has enabled new report notifications
          final prefs = await getNotificationPreferences(supervisorUid);
          final newReportsEnabled = prefs['newReports'] ?? true;
          
          if (!newReportsEnabled) {
            print('⏭️ New report notifications disabled for supervisor: $supervisorUid');
            skippedCount++;
            continue;
          }

          final notificationData = {
            'title': 'New Incident Report',
            'body': '$reportType reported at $location by $reporterEmail',
            'reportId': reportId,
            'reportType': reportType,
            'reporterEmail': reporterEmail,
            'location': location,
            'timestamp': DateTime.now().toIso8601String(),
            'read': false,
          };

          await _dbRef
              .child('userNotifications')
              .child(supervisorUid)
              .push()
              .set(notificationData);
          print('✅ Notification saved for supervisor: $supervisorUid');
          successCount++;
        } catch (e) {
          print('⚠️ Failed to notify supervisor $supervisorUid: $e');
        }
      }

      print('✅ New report notification sent to $successCount supervisors (skipped: $skippedCount)');
    } catch (e) {
      print('❌ Error notifying supervisors: $e');
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

