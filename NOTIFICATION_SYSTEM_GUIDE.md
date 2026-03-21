# Notification System Implementation Guide

## Overview
A complete notification system has been implemented that allows supervisors to notify reporters when their incident reports are updated. The system includes:

- **Firebase Cloud Messaging (FCM)** integration
- **Real-time notifications** stored in Firebase Database
- **Notification preferences** management
- **Rich UI** for viewing and managing notifications
- **Unread notification badges** on the reporter dashboard

## What Was Implemented

### 1. Core Service: NotificationService (`lib/notification_service.dart`)
The centralized service handles all notification operations:

**Key Methods:**
- `initializeNotifications()` - Initialize FCM on app startup
- `notifyReporterOnUpdate()` - Send notification to a reporter when their report is updated
- `notifyReportersOnMassUpdate()` - Send bulk notifications to multiple reporters
- `getUserNotifications()` - Stream all notifications for a user
- `getUnreadNotificationCount()` - Stream unread notification count
- `markNotificationAsRead()` - Mark a notification as read
- `deleteNotification()` - Delete a notification
- `updateNotificationPreferences()` - Save user preferences
- `getNotificationPreferences()` - Retrieve user preferences

### 2. Supervisor Features

#### Notification Settings Screen (`lib/notification_settings.dart`)
Accessible from the supervisor dashboard AppBar (bell icon):

- **Report Updates**: Enable/disable status update notifications
- **Severe Alerts**: Get notified for critical/high severity reports
- **Daily Digest**: Optional daily summary (configurable)
- **Sound Notifications**: Toggle notification sounds
- **Email Notifications**: Placeholder for future feature
- **Test Notification**: Send a test notification to verify settings

#### Automatic Notifications on Report Update
When supervisors update a report's status or severity in the report detail screen:
1. The new status/severity is saved to database
2. Reporter is automatically notified
3. Notification shows:
   - Status change details
   - Report type
   - Supervisor name
   - Timestamp

### 3. Reporter Features

#### Notifications Viewer (`lib/notifications_viewer.dart`)
Available from reporter dashboard AppBar (bell icon):

**Features:**
- View all notifications with rich formatting
- Filter for unread only
- Mark notifications as read (click on notification)
- Delete notifications (swipe left and delete)
- See supervisor name and timestamp on each notification
- Status-based color coding:
  - Green for closed reports
  - Orange for active reports
  - Amber for open reports

#### Unread Badge
- Real-time badge showing unread notification count
- Appears on the notifications button in AppBar
- Updates automatically when new notifications arrive

## Database Structure

```
Firebase Realtime Database:
├── users/
│   └── {uid}/
│       ├── fcmToken        (string)  - Firebase Cloud Messaging token
│       └── notificationPreferences
│
├── notificationTokens/
│   └── {uid}/
│       ├── token           (string)  - FCM token
│       └── updatedAt       (string)  - Last update timestamp
│
├── userNotifications/
│   └── {uid}/
│       └── {notificationId}/
│           ├── title       (string)  - Notification title
│           ├── body        (string)  - Notification message
│           ├── reportId    (string)  - Related report ID
│           ├── status      (string)  - Report status
│           ├── supervisorName (string) - Supervisor's name
│           ├── timestamp   (string)  - ISO format date
│           └── read        (boolean) - Read status
│
└── notificationPreferences/
    └── {uid}/
        ├── statusUpdates      (boolean) - Default: true
        ├── severeAlerts       (boolean) - Default: true
        ├── dailyDigest        (boolean) - Default: false
        ├── soundEnabled       (boolean) - Default: true
        └── emailNotifications (boolean) - Default: false
```

## How It Works

### Flow 1: Supervisor Updates Report
1. Supervisor opens report detail screen
2. Changes status and/or severity
3. Clicks "Save Changes" button
4. System detects if status/severity changed
5. If changed, notification is stored in Firebase
6. Reporter receives notification with update details

### Flow 2: Reporter Receives Notification
1. Reporter opens app (notification service initializes)
2. FCM token is retrieved and stored
3. Reporter can see unread badge on dashboard
4. Click notification bell to view all notifications
5. Click notification to mark as read
6. Swipe left to delete notification

## How to Use

### For Supervisors:
1. **Configure Notification Preferences:**
   - Tap the bell icon (🔔) in supervisor dashboard AppBar
   - Toggle options as needed (status updates, severe alerts, etc.)
   - Tap "Send Test Notification" to verify settings

2. **Send Notifications:**
   - Notifications are sent automatically when you update report status/severity
   - No manual action needed - it's automatic!

### For Reporters:
1. **View Notifications:**
   - Tap the bell icon (🔔) in reporter dashboard AppBar
   - See all received notifications with timestamps
   - Unread count badge appears automatically

2. **Manage Notifications:**
   - Click a notification to mark it as read
   - Swipe left and delete to remove notifications
   - Filter for unread only using the filter chip

## Firebase Setup Required

To use this notification system, ensure:

1. **Firebase Cloud Messaging** is enabled in your Firebase project
2. **Android Setup** - Already configured via google-services.json
3. **iOS Setup** - May require additional APNs certificate configuration (if using iOS)
4. **FCM Credentials** - Should be in your Firebase Console

## Testing

### Send Test Notification:
1. Go to Notification Settings (supervisor dashboard)
2. Tap "Send Test Notification" button
3. Switch to reporter account/device
4. Open notifications to see the test notification

### Test Successful If:
- ✅ Test notification appears in reporter's notification list
- ✅ Unread badge shows "1"
- ✅ Notification can be marked as read
- ✅ Notification can be deleted

## Future Enhancements

Possible improvements:
- Email notifications for daily digest
- Push notifications to device (requires native platform setup)
- Notification templates/categories
- Scheduled bulk notifications
- Notification history/analytics
- Read receipts on supervisor side
- Real-time delivery status

## Troubleshooting

### Notifications Not Appearing?
- Verify FCM token is saved: Check Firebase Database → users → {uid} → fcmToken
- Check notification preferences are enabled
- Ensure reporter is logged in (FCM requires auth)

### FCM Token Not Saving?
- Check Firebase Authentication is working
- Verify Firebase Database rules allow write access
- Check console logs for errors

### Unread Badge Not Showing?
- Force close and reopen the app
- Check internet connection
- Verify unread notifications exist in database

## Code Examples

### Send Notification to Reporter (in your code):
```dart
NotificationService().notifyReporterOnUpdate(
  reporterUid: 'reporter-uid',
  reportId: 'report-id',
  reportType: 'Safety Hazard',
  newStatus: 'active',
  supervisorName: 'John Smith',
);
```

### Get User Notifications (Stream):
```dart
NotificationService().getUserNotifications(userId).listen((notifications) {
  print('Total notifications: ${notifications.length}');
  notifications.forEach((n) => print(n['title']));
});
```

### Update Preferences:
```dart
NotificationService().updateNotificationPreferences(userId, {
  'statusUpdates': true,
  'severeAlerts': true,
  'soundEnabled': false,
});
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Main App (main.dart)                 │
│        Initialize NotificationService on startup        │
└───────────────────────┬─────────────────────────────────┘
                        │
        ┌───────────────┴───────────────┐
        │                               │
┌───────▼──────────────┐    ┌──────────▼─────────────┐
│  Supervisor Flow     │    │   Reporter Flow       │
├──────────────────────┤    ├──────────────────────┤
│ Dashboard            │    │ Dashboard            │
│ ├─ Report List      │    │ ├─ Report Stats     │
│ └─ Notification     │    │ └─ Notifications ◄──┘
│    Settings         │    │
│                     │    │ Receive & View       │
│ Report Detail       │    │ ├─ Mark as Read      │
│ ├─ Update Status   ─┼────│ ├─ Delete           │
│ └─ Send Notify     ─┼────│ └─ Unread Badge     │
└──────────────────────┘    └────────────────────┘
        │                              │
        └──────────┬──────────────────┘
                   │
        ┌──────────▼──────────┐
        │ Firebase Realtime   │
        │ Database            │
        ├────────────────────┤
        │ • Users FCM Tokens │
        │ • Notifications    │
        │ • Preferences      │
        └────────────────────┘
```

## Notes

- Notifications are stored in Firebase Realtime Database for reliability
- FCM tokens are automatically refreshed and updated
- All notification preferences are persistent across sessions
- The system is scalable for large numbers of reporters
- Supervisor names are captured from Firebase Auth display name or email

## Support

For issues or questions:
1. Check Firebase Console for any errors
2. Verify database structure matches the specification above
3. Check Dart console logs for detailed error messages
4. Ensure all imports are correct in modified files
