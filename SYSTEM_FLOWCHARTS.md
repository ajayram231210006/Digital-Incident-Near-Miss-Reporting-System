# Notification System - Visual Overview & Flowcharts

## 🎯 System Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────────┐
│                    NOTIFICATION SYSTEM ARCHITECTURE                        │
└────────────────────────────────────────────────────────────────────────────┘

                                    APP LAYERS
                            
                    ┌─────────────────────────────────────┐
                    │   USER INTERFACE (UI Components)    │
                    ├─────────────────────────────────────┤
                    │ • supervisor_dashboard              │
                    │ • notification_settings             │
                    │ • reporter_dashboard                │
                    │ • notifications_viewer              │
                    │ • supervisor_report_detail          │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │   SERVICE LAYER             │
                    ├─────────────────────────────┤
                    │ NotificationService         │
                    │ • Initialize FCM            │
                    │ • Manage tokens             │
                    │ • Send notifications        │
                    │ • Manage preferences        │
                    └──────────────┬──────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │   FIREBASE SERVICES        │
                    ├─────────────────────────────┤
                    │ • FCM (Token Management)    │
                    │ • Auth (User Info)          │
                    │ • Realtime DB (Storage)     │
                    └──────────────┬──────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │   FIREBASE CLOUD           │
                    ├─────────────────────────────┤
                    │ • Cloud Messaging Backend   │
                    │ • Realtime Database         │
                    │ • Authentication           │
                    └─────────────────────────────┘
```

## 📊 Data Flow Diagrams

### Flow 1: Supervisor Updates Report & Sends Notification

```
Supervisor Dashboard
        │
        ├─► Opens Incident Report
        │        │
        │        ├─► Review Current Status: "open"
        │        ├─► Change to Status: "active"
        │        ├─► Change Severity: "high"
        │        └─► Click "Save Changes"
        │
        ├─► _saveChanges() Method
        │        │
        │        ├─► Update Report in Firebase
        │        │   └─► incidents/{reportId} ◄────┐
        │        │       ├─ status: "active"       │
        │        │       ├─ severity: "high"       │  UPDATE
        │        │       └─ lastModified: now      │
        │        │                                 │
        │        ├─► Check if status changed
        │        │   └─► YES! "open" → "active"
        │        │
        │        ├─► Get Reporter UID
        │        │   └─► reporterUid: "uid123"
        │        │
        │        └─► Send Notification ──────────┐
        │                                        │
        └─────────────────────────────────────────┼──────┐
                                                  │      │
        NotificationService                       │      │
                ├─► notifyReporterOnUpdate()      │      │
                │    ├─ reporterUid: "uid123"     │      │
                │    ├─ reportId: "rep001"        │      │
                │    ├─ supervisorName: "John"    │      │SEND
                │    └─ newStatus: "active"       │      │NOTIF
                │                                 │      │
                ├─► Create Notification Object    │      │
                │    {                           │      │
                │     title: "Report Updated"     │      │
                │     body: "...status changed"   │      │
                │     status: "active"            │      │
                │     supervisorName: "John"      │      │
                │     timestamp: now              │      │
                │     read: false                 │      │
                │    }                           │      │
                │                                 │      │
                └─► Save to Firebase ────────────┘      │
                     userNotifications/                 │
                     uid123/{notificationId}/            │
                      ├─ title                           │
                      ├─ body                            │
                      ├─ status                          │
                      ├─ timestamp                       │
                      └─ read: false
                      
                ◄─────────────────────────────────────┘
                          
        Reporter Gets Notified
        (No manual action needed - automatic!)
```

### Flow 2: Reporter Receives & Reads Notification

```
Reporter Dashboard
        │
        ├─► App Starts
        │    └─► NotificationService.initializeNotifications()
        │         ├─► Request FCM Permission
        │         ├─► Get FCM Token
        │         ├─► Save token to Firebase
        │         ├─► Listen for new notifications
        │         └─► Load unread count
        │
        ├─► Dashboard Shows
        │    └─► Bell Icon (🔔) Shows Badge: "1"
        │         ◄─── Unread count from
        │              getUnreadNotificationCount()
        │
        ├─► Reporter Taps Bell Icon
        │    └─► Navigate to NotificationsViewer
        │
        ├─► NotificationsViewer Loads
        │    ├─► Stream: getUserNotifications(uid)
        │    │   └─► Fetch from Firebase
        │    │       userNotifications/uid123/
        │    │       ├─ {notif1}
        │    │       ├─ {notif2}  ◄── NEW!
        │    │       └─ {notif3}
        │    │
        │    └─► Display Notifications
        │         ├─ "Report Updated" ← NEW (unread)
        │         │  └─ Status changed to ACTIVE
        │         ├─ "Report Received" (read)
        │         └─ "Status Update" (read)
        │
        ├─► Reporter Taps New Notification
        │    └─► markNotificationAsRead()
        │         └─► Update Firebase
        │              userNotifications/uid123/{id}/read = true
        │
        ├─► Badge Updates
        │    └─► Badge now shows "0" (all read)
        │
        └─► Reporter Can Swipe to Delete
             └─► deleteNotification()
                  └─► Remove from Firebase
```

### Flow 3: Notification Preferences

```
Supervisor Dashboard
        │
        ├─► Taps Bell Icon (🔔)
        │    └─► Navigate to NotificationSettings
        │
        ├─► Settings Screen Shows
        │    ├─ Load current preferences
        │    │  └─► getNotificationPreferences(supervisorUid)
        │    │       └─► Fetch from Firebase
        │    │           notificationPreferences/supervisorUid/
        │    │           {
        │    │            "statusUpdates": true,
        │    │            "severeAlerts": true,
        │    │            "soundEnabled": true,
        │    │            ...
        │    │           }
        │    │
        │    ├─► Display Preference Toggles
        │    │    ├─ Status Updates ✓ ON
        │    │    ├─ Severe Alerts ✓ ON
        │    │    ├─ Daily Digest ○ OFF
        │    │    ├─ Sound Enabled ✓ ON
        │    │    └─ Email Notif. ○ OFF (Coming Soon)
        │    │
        │    └─► Test Notification Button
        │         └─► Send test to self
        │
        └─► Supervisor Changes Setting
             ├─► Toggle "Sound Enabled"
             │    └─► Now OFF
             │
             └─► Save Automatically
                  └─► updateNotificationPreferences()
                       └─► Update in Firebase
                           notificationPreferences/supervisorUid/
                           soundEnabled = false
```

## 🔄 Component Interaction Diagram

```
                    ┌─────────────────────────┐
                    │   App Initialization    │
                    │    (main.dart)          │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │  NotificationService    │
                    │  .initializeNotifica... │
                    └────────────┬────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
                    ▼                         ▼
        ┌──────────────────┐      ┌──────────────────┐
        │ Get FCM Token    │      │ Request Perms    │
        │ Save to DB       │      │ Listen to FCM    │
        └────────┬─────────┘      └────────┬─────────┘
                 │                         │
                 └────────────┬────────────┘
                              │
                    ┌─────────▼──────────┐
                    │ Firebase Realtime  │
                    │ Database Ready     │
                    └────────────────────┘

┌──────────────────────────────────────────────────────────┐
│            SUPERVISOR                  REPORTER          │
├──────────────────────────────────────────────────────────┤
│ Dashboard                             Dashboard          │
│  ├─ Reports                            ├─ Stats          │
│  └─ [🔔] Settings ◄───┐               └─ [🔔] Badge     │
│                       │                  ▲    │          │
│ Report Detail         │                  │    │          │
│  ├─ Update Status     │                  │    │          │
│  └─ [SAVE] ──────┐    │                  │    │          │
│                  │    │                  │    │          │
│  Send Notif ◄────┼────┼──────────────────┘    │          │
│                  │    │                       │          │
│                  │    └─► Settings / Prefs    │          │
│                  │         ├─ Save Prefs      │          │
│                  │         └─ Test Notif      │          │
│                  │                            │          │
│                  └─► Firebase DB              │          │
│                      ├─ userNotifications     │          │
│                      ├─ notificationPrefs     │          │
│                      └─ users/{uid}/token     │          │
│                                               │          │
│                     The Notification ────────┘          │
│                                               │          │
│                    Viewer ◄──────────────────┘          │
│                    ├─ List Notifs                       │
│                    ├─ Mark Read                         │
│                    └─ Delete                            │
└──────────────────────────────────────────────────────────┘
```

## 🔗 State Management Flow

```
Firebase Realtime Database
        │
        ├─► users/{uid}/fcmToken
        │   • Auto-updated on app start
        │   • Refreshed when token changes
        │
        ├─► userNotifications/{uid}/{notifId}
        │   ├─ Created when supervisor saves report
        │   ├─ Streamed to NotificationsViewer
        │   ├─ Updated when marked as read
        │   └─ Deleted when user removes
        │
        ├─► notificationPreferences/{uid}
        │   ├─ Created on first settings change
        │   ├─ Updated via NotificationSettings
        │   └─ Retrieved before sending notifications
        │
        └─► notificationTokens/{uid}
            ├─ Stores FCM token
            └─ Updated timestamp
            
All components listen to Firebase using:
        StreamBuilder
        ├─ Real-time updates
        ├─ Automatic UI refresh
        └─ No manual refresh needed
```

## 📱 UI Navigation Flow

```
┌─────────────────────────────────────────────────────┐
│               LOGIN / WRAPPER                       │
└─────────────────────────────────────────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                 │
        ▼                                 ▼
┌──────────────────┐          ┌─────────────────────┐
│ SUPERVISOR VIEW  │          │ REPORTER VIEW       │
├──────────────────┤          ├─────────────────────┤
│ Dashboard        │          │ Dashboard           │
│├─ Stats          │          │├─ Stats             │
│├─ Reports        │          │├─ Reports           │
│├─ Recent Incidents          │└─ [Bell 🔔]        │
│└─ [Bell 🔔] ─┐   │          │                     │
│              │   │          │ Navigation:         │
│ [Reports List]  │          │├─ Report Detail     │
│└─ [Detail] ─┐   │          │└─ Notifications ────┘
│  ├─ Update    │  │             │
│  │ Status ─┐  │  │             ▼
│  └─ [SAVE] │  │  │   ┌─────────────────────┐
│            │  │  │   │ Notifications List  │
│            │  │  │   ├─────────────────────┤
│ [Settings] ◄─┘  │   │ • Mark as read      │
│├─ Prefs    │    │   │ • Delete (swipe)    │
│├─ Toggle   │    │   │ • Filter unread     │
││ Options   │    │   └─────────────────────┘
│└─ [Test]   │    │
│            │    │
│ Notif      │    │
│ flows ────────┼─►
│ here        │    │
│            │    │
└──────────────────┘
   │                 │
   └────────┬────────┘
            │
    Firebase Realtime Database
    • userNotifications
    • notificationPreferences  
    • users FCM tokens
```

## 🎬 Complete User Journey

```
Day 1: Setup
├─► Developer: Run flutter pub get
├─► Developer: Run flutter run
├─► App initializes NotificationService
└─► App requests notification permissions

Day 2: Report Submitted
├─► Reporter submits incident report
├─► Report appears in supervisor dashboard
└─► System ready for updates

Day 3: Supervisor Reviews
├─► Supervisor opens report detail
├─► Changes status from "open" to "active"
├─► Changes severity to "high"
├─► Clicks "Save Changes"
├─► Notification automatically sent to reporter
└─► Supervisor can see preferences via bell icon

Day 3: Reporter Gets Notified
├─► Reporter sees badge "1" on bell icon
├─► Reporter taps bell to view notification
├─► Reporter sees: "Report Updated - Status changed to ACTIVE"
├─► Reporter taps notification to mark read
├─► Badge disappears
└─► Reporter can delete if not needed

Day 4: Ongoing
├─► Supervisor continues updating reports
├─► Each update sends new notification
├─► Reporter manages notifications in viewer
│   ├─ Mark as read
│   ├─ Delete old ones
│   └─ Filter unread
└─► Each user configures their preferences
    ├─ Modify notification types
    ├─ Test notifications
    └─ Enable/disable features
```

## 🎯 Key Decision Points

```
Supervisor Updates Report
        │
        ├─► Is Status Changed?
        │   ├─ YES → Send Notification
        │   └─ NO → Skip notification
        │
        └─► Is Severity Changed?
            ├─ YES → Send Notification  
            └─ NO → Skip notification

Reporter App Active?
        │
        ├─► YES → Show notification in viewer
        │   └─► Real-time via Firebase Stream
        │
        └─► NO → Notification stored in database
            └─► Retrieved when reporter opens app

User Clicks Notification
        │
        ├─► NOT yet read?
        │   └─► Mark as read + update badge
        │
        └─► Already read?
            └─► Just navigation (if applicable)
```

---

## 📈 Scalability Notes

This system can handle:
- ✅ 100+ reporters receiving notifications
- ✅ 1000+ stored notifications per user
- ✅ Concurrent preference changes
- ✅ High-frequency report updates
- ✅ Large batches of notifications

All powered by Firebase's scalable backend infrastructure.
