# Notification System Debug Guide

## What Was Fixed

### ✅ New Features Added
1. **Supervisor Note Notifications** - When a supervisor adds/edits notes, all supervisors get notified
2. **Enhanced Reporter Notifications** - Reporters get notified both when:
   - Supervisor changes report status/severity
   - Supervisor adds notes to the report

### ✅ Improvements Made
- **Debug logging** with emoji indicators (📢, ✅, ❌, 🔍, 📝)
- **Better error detection** - Catches missing reporter UIDs
- **Improved notification tracking** - Console will show exactly what's happening

---

## Step-by-Step Debug Guide

### Step 1: Run the App with Logs
```bash
flutter run
```

Look for debug messages in the console output. They will start with these emojis:
- 📢 = Attempting notification
- ✅ = Success
- ❌ = Error/Failure
- 🔍 = Checking something
- 📝 = Processing notes

---

### Step 2: Test Supervisor Status Change

**Action**: Login as **supervisor**, go to a report, change status, click Save

**Expected Console Output**:
```
📝 Saving changes - Status: open→resolved, Severity: high→high, Notes changed: false
📋 Report Details - ReporterUID: ca5cpP31wUembD0j3vAgAgMpK512, Type: Hazard Report, Supervisor: John
🔔 Notifying reporter of status/severity change
📢 Attempting to notify reporter - UID: ca5cpP31wUembD0j3vAgAgMpK512, Report: report_xyz
✅ Notification stored for reporter: ca5cpP31wUembD0j3vAgAgMpK512 at path: userNotifications/ca5cpP31wUembD0j3vAgAgMpK512
```

**If you see** ❌ Reporter UID is empty → Go to Step 5

---

### Step 3: Test Supervisor Adds Notes

**Action**: Login as **supervisor**, go to a report, add/edit notes, click Save

**Expected Console Output**:
```
📝 Saving changes - Status: open→open, Severity: high→high, Notes changed: true
📋 Report Details - ReporterUID: ca5cpP31wUembD0j3vAgAgMpK512, Type: Hazard Report, Supervisor: John
📝 Notes changed - notifying reporter and supervisors
✅ Reporter notified about notes
Note notification sent to 2 supervisors for report: report_xyz
```

---

### Step 4: Verify Reporter Receives Notifications

**Action**: Login as **reporter**, tap the notification bell icon on dashboard

**What to see**:
- Unread badge with number
- Click bell → Notifications list
- Should see notifications from supervisor about status changes or notes

---

### Step 5: Diagnose Missing Reporter UID

If logs show: `❌ Reporter UID is null or empty!`

**Problem**: When reporter submits incident, the `reporterUid` isn't being saved.

**Fix Check**:
1. Open [reporter.dart](reporter.dart#L91)
2. Verify this line exists in `_submitIncident()`:
   ```dart
   'reporterUid': widget.user.uid,
   ```

3. If missing, you need to add it to the incident data structure

---

### Step 6: Check Firebase Database Structure

Go to Firebase Console → Realtime Database

**Look for these paths**:

```
/incidents/
  report_id_123/
    reporterUid: "ca5cpP31wUembD0j3vAgAgMpK512"  ← Must exist
    type: "Hazard Report"
    status: "open"
    notes: "..."
    
/userNotifications/
  reporter_uid_123/
    notification_1/
      title: "Report Updated"
      body: "..."
      timestamp: "..."
      read: false
      
  supervisor_uid_456/
    notification_2/
      title: "New Incident Report"
      body: "..."
```

---

### Step 7: Check Firebase Security Rules

**Problem**: Notifications stored but not showing = Permission issue

**Solution**: Update your Firebase Realtime Database Rules:

```json
{
  "rules": {
    "userNotifications": {
      "$uid": {
        ".read": "auth.uid === $uid",
        ".write": "auth.uid !== null"
      }
    }
  }
}
```

---

## Common Issues & Fixes

| Issue | Symptom | Solution |
|-------|---------|----------|
| No notifications at all | Nothing appears in Notifications tab | Check Step 5 - reporterUid missing |
| Reporter gets status change but not notes | Status works, notes don't | Check notes changed logic in console output |
| Supervisors don't get note notifications | Only reporters notified | Verify `getAllSupervisors()` returns UIDs |
| Notifications appear then disappear | They show briefly | Check `read` flag logic in notifications_viewer.dart |

---

## Production Deployment Notes

### ⚠️ Current Limitation
This system uses **database storage** only, not actual FCM push notifications. 

**What works**:
- ✅ In-app notifications (when app is open)
- ✅ Persistent notification storage
- ✅ Unread badge counts

**What needs backend**:
- ❌ Push notifications to device lock screen
- ❌ Sound/vibration alerts
- ❌ Notifications when app is closed

### To Enable Push Notifications
You need a backend server (Node.js/Python/Firebase Functions) to:
1. Receive notification requests
2. Call FCM API with device tokens
3. Send actual push notifications

---

## Quick Log Reference

```
Success indicators (✅):
📢 Attempting to notify reporter
✅ Notification stored for reporter
✅ Reporter notified about notes
Note notification sent to X supervisors

Error indicators (❌):
❌ Reporter UID is null or empty
❌ Error notifying reporter
❌ Error notifying supervisors on note added
❌ Error during save
```

---

## Next Actions

1. **Test the system**: Follow Steps 1-4 above
2. **Check logs**: Look for success/error indicators
3. **Verify database**: Confirm notifications are stored
4. **Monitor**: Watch console during real user interactions

If notifications still don't appear after these steps, the issue is likely in permissions or the notification display logic in `notifications_viewer.dart`.
