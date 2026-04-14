# Notification System End-to-End Testing Guide

## Setup
- **Reporter 1**: ani@gmail.com (H26M1Xf7bPcOBwxpX92ojuaiUmE2)
- **Reporter 2**: akhil@gmail.com (j4fB4RmU99SCiMM0uAW0DWsyPDD2)  
- **Supervisor**: aniket@gmail.com (ca5cpP31wUembD0j3vAgAgMpK512)

You'll need **2-3 devices/emulators** to see notifications arriving in real-time.

---

## TEST 1: Reporter Creates Report → Supervisors & Other Reporters Get Notified

### Steps:
1. **Device 1 (Reporter 1 - ani@gmail.com):**
   - Login
   - Go to "Report Incident" 
   - Fill in: Type = "Safety Issue", Description = "Test notification 1"
   - Submit
   - **Watch logs for:**
     ```
     📢 Fetching reporters to notify about new report...
     ✅ Found X reporters
     🔍 Reporter UIDs: [list]
     ✅ New report notification sent to X reporters
     ```

2. **Device 2 (Supervisor - aniket@gmail.com):**
   - Should receive notification: "New System Report"
   - Check `userNotifications/ca5cpP31wUembD0j3vAgAgMpK512`

3. **Device 3 (Reporter 2 - akhil@gmail.com):**
   - Should receive notification: "New System Report"
   - Check `userNotifications/j4fB4RmU99SCiMM0uAW0DWsyPDD2`

### Expected Log Output:
```
✅ Found 2 reporters
🔍 Reporter UIDs: [j4fB4RmU99SCiMM0uAW0DWsyPDD2, H26M1Xf7bPcOBwxpX92ojuaiUmE2]
✅ Notification saved for reporter: j4fB4RmU99SCiMM0uAW0DWsyPDD2
✅ New report notification sent to 1 reporters
```

### Verify in Firebase:
- `/users/ca5cpP31wUembD0j3vAgAgMpK512` - Supervisor should have new notification
- `/users/j4fB4RmU99SCiMM0uAW0DWsyPDD2` - Reporter 2 should have new notification
- `/users/H26M1Xf7bPcOBwxpX92ojuaiUmE2` - Reporter 1 should NOT have new notification (creator)

---

## TEST 2: Supervisor Updates Status/Severity → All Reporters Get Notified

### Steps:
1. **Device 2 (Supervisor - aniket@gmail.com):**
   - Go to Supervisor Dashboard
   - Click on the report created in TEST 1
   - Change Status from "open" → "active"
   - Change Severity from "Not Set" → "high"
   - Click Save
   - **Watch logs for:**
     ```
     🔍 Reporter UID extracted: [uid]
     📢 Fetching reporters to notify about update...
     ✅ Found X reporters
     ✅ Update notification sent to X reporters
     ```

2. **Device 1 (Reporter 1 - ani@gmail.com):**
   - Should receive notification: "Status Updated" or "Status & Severity Updated"

3. **Device 3 (Reporter 2 - akhil@gmail.com):**
   - Should receive notification: "Status Updated" or "Status & Severity Updated"

### Expected Log Output:
```
🔍 Reporter UID extracted: H26M1Xf7bPcOBwxpX92ojuaiUmE2 (length: 28)
✅ Update notification sent to 2 reporters
✅ Notification saved for reporter: H26M1Xf7bPcOBwxpX92ojuaiUmE2
```

### Verify in Firebase:
- Check `/userNotifications/H26M1Xf7bPcOBwxpX92ojuaiUmE2` - Should have update notification
- Check `/userNotifications/j4fB4RmU99SCiMM0uAW0DWsyPDD2` - Should have update notification

---

## TEST 3: Supervisor Adds Notes → Reporter & Other Reporters Get Notified

### Steps:
1. **Device 2 (Supervisor - aniket@gmail.com):**
   - Still on the report detail page
   - Scroll to "Notes" section
   - Add: "Reviewed the incident. No immediate action needed."
   - Click Save
   - **Watch logs for:**
     ```
     📢 Fetching reporters to notify about update...
     ✅ Found X reporters
     ✅ Update notification sent to X reporters
     ```

2. **Device 1 (Reporter 1 - ani@gmail.com):**
   - Should receive notification: "Notes Added"

3. **Device 3 (Reporter 2 - akhil@gmail.com):**
   - Should receive notification: "Notes Added"

### Expected Log Output:
```
✅ Notification saved for supervisor
✅ Update notification sent to 2 reporters
Notification data will show: "title": "Notes Added"
```

---

## What to Look For in Logs

### ✅ SUCCESS INDICATORS:
```
✅ Found X reporters
✅ Found X supervisors
✅ Notification saved for [uid]
✅ Notification sent to X [reporters/supervisors]
✅ Reporter UID extracted: [uid]
```

### ❌ ERROR INDICATORS (These should NOT appear after fixes):
```
❌ Error getting reporters: type 'String' is not a subtype
❌ Error getting supervisors: type 'String' is not a subtype
! Reporter UID is null or empty
Fetched 0 reporters
```

---

## Firebase Database Path to Check Notifications

Navigate to: `userNotifications/{userId}/{notificationId}`

You should see:
```json
{
  "title": "New System Report",
  "body": "Safety Issue - Test notification 1 by ani (Severity: Not Set)",
  "reportId": "-OpR9p5If7qFPG21c6UT",
  "reportType": "Safety Issue",
  "timestamp": "2026-04-05T11:20:05.000Z",
  "read": false
}
```

---

## Troubleshooting

### If No Notifications:
1. Check if Firebase has users in `/users` with `role` field set correctly
2. Verify `notifyAllReportersOnNewReport()` is being called
3. Check logs for "Found 0 reporters" - means database retrieval failed
4. Verify report object has `reporterUid` field saved

### If Type Conversion Errors Still Appear:
1. The users node might have stored invalid data
2. Try clearing Firebase `/users` and re-adding users
3. Ensure all users have `role` field as String (not nested object)

### If Reporter UID is Null:
1. Report might not have `reporterUid` saved during creation
2. Firebase fallback query should help, check logs for actual UIDs retrieved
3. Verify report structure in Firebase matches expected schema
