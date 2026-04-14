# Notification System Issues - Root Cause Analysis

## Issue #1: Notifications Not Showing When App is Open or Closed ❌

### Root Cause
The `_handleForegroundMessage()` in `notification_service.dart` only prints debug messages and doesn't actually display notifications to the user.

**Current Code (Line ~76)**:
```dart
void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground message: ${message.notification?.title}');
    // You can display a dialog, snackbar, or local notification here
}
```

### Problem
- When app is in foreground: No UI notification displayed
- When app is terminated: Notifications aren't being shown (need local notifications)
- Users don't see visual/audio feedback

### Solution Needed
1. Integrate `flutter_local_notifications` package
2. Implement proper notification display in foreground
3. Configure notification channels for Android
4. Setup local notification handling for terminated state

---

## Issue #2: No Sound When Notifications Arrive 🔇

### Root Cause
Sound is requested in permissions but:
1. FCM might not be sending actual push notifications (using database only)
2. No sound configuration in local notifications
3. No audio file setup for notification sounds

**Current Setup**:
```dart
await _messaging.requestPermission(
    sound: true, // Requested but not used
    ...
);
```

### Problem
- App only stores notifications in database
- Doesn't send FCM push notifications from backend
- Even if FCM sent notifications, no local notification setup to play sound
- No notification channels configured with sound

### Solution Needed
1. Configure notification channels with sound
2. Add audio asset for notification sound
3. Ensure firebase functions are actually sending FCM messages
4. Verify backend is configured to send push notifications

---

## Issue #3: Bell Icon Shows 2 Even When All Marked as Read 🔔

### Root Cause
The unread count logic is correct, but notifications aren't being properly marked as read:

**Current Code (Line 102-104 in `reporter_dashboard.dart`)**:
```dart
stream: _notificationService.getUnreadNotificationCount(widget.user.uid),
builder: (context, snapshot) {
    final unreadCount = snapshot.data ?? 0;
```

**Unread Count Logic (Line 319-337 in `notification_service.dart`)**:
```dart
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
```

### Problems Identified

#### Problem A: Mark as Read Only Works for Unread
In `notifications_viewer.dart` (Line ~283):
```dart
onTap: !isRead  // ← Only marks as read if currently unread
    ? () {
        _notificationService.markNotificationAsRead(
          widget.user.uid,
          notificationId,
        );
    }
    : null,  // ← Does nothing if already read
```

#### Problem B: No "Mark All as Read" Function
- Users can only mark individual unread notifications
- No bulk "Mark all as read" action

#### Problem C: Orphaned Notifications
- Possible orphaned notifications with `read: false` in database
- Could be from incomplete transactions
- No cleanup mechanism

---

## Summary of Fixes Needed

| Issue | Component | Fix |
|-------|-----------|-----|
| Not showing when open | `notification_service.dart` | Implement `flutter_local_notifications` |
| Not showing when closed | Android/iOS config | Setup notification channels |
| No sound | Local notifications config | Add sound asset + channel setup |
| Bell icon stuck at 2 | `notifications_viewer.dart` | Verify all notifications marked as read OR add cleanup |
| Need to check DB | Firebase Console | Query `userNotifications/{uid}` for orphaned entries |

---

## Next Steps

1. **Immediate**: Check Firebase for orphaned `read: false` notifications
   - Go to Firebase Console → Realtime Database
   - Navigate to `userNotifications/{your_uid}`
   - Look for any entries with `read: false`
   - Delete these manually if found (temporary fix)

2. **Short Term**: Add "Mark All as Read" button
   - Allows bulk clearing of unread count
   - Temporary workaround while implementing full fix

3. **Long Term**: Implement proper notification display
   - Add `flutter_local_notifications` dependency
   - Configure for Android and iOS
   - Implement sound/vibration preferences
   - Add visual in-app notifications

