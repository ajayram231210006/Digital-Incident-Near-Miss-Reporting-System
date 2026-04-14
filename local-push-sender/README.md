# InciTrack Local Push Sender

This is a free workaround for outside-app notifications on the Firebase Spark plan.

It runs on your own machine and:

1. polls `userNotifications/{uid}`
2. finds new notification records
3. reads each user's FCM token
4. sends a real FCM push notification

## Important limitation

This works only while your machine and this script are running.

## Setup

### 1. Create a Firebase service account key

Open Firebase Console / Google Cloud Console for project `users-3f3bd` and create
a service account JSON key.

Save it somewhere on your machine, for example:

`C:\Users\ajayram_231210006\Digital-Incident-Near-Miss-Reporting-System\local-push-sender\service-account.json`

### 2. Install dependencies

```powershell
cd C:\Users\ajayram_231210006\Digital-Incident-Near-Miss-Reporting-System\local-push-sender
npm.cmd install
```

### 3. Set the service account path

If your key is saved as `local-push-sender\service-account.json`, the script now
finds it automatically and you can skip this step.

If your key is stored somewhere else, set the path for the current PowerShell session:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\Users\ajayram_231210006\Digital-Incident-Near-Miss-Reporting-System\local-push-sender\service-account.json"
```

### 4. Start the sender

```powershell
cd C:\Users\ajayram_231210006\Digital-Incident-Near-Miss-Reporting-System\local-push-sender
node index.js
```

## Optional environment variables

```powershell
$env:FIREBASE_PROJECT_ID="users-3f3bd"
$env:FIREBASE_DATABASE_URL="https://users-3f3bd-default-rtdb.firebaseio.com"
$env:POLL_INTERVAL_MS="5000"
```

## How to test

1. Start this script
2. Open the app and log in on a real device
3. Confirm `users/{uid}/fcmToken` exists in Realtime Database
4. Trigger a new app notification, for example:
   - submit an incident
   - update report status
   - add supervisor notes
5. The script should detect the new DB notification and send a real push

## Notes

- Existing notifications are skipped on startup to avoid resending old ones.
- New notifications created after the script starts will be pushed.
- If the token is invalid, the script removes the stale token from the database.
