## InciTrack Firebase Functions

This folder contains the Firebase Cloud Functions used by the app backend.

### What it does

1. Push notifications
Whenever a new record is created under:

`/userNotifications/{uid}/{notificationId}`

the function:

1. reads the notification payload from Realtime Database
2. looks up the user's FCM token from:
   - `users/{uid}/fcmToken`
   - or `notificationTokens/{uid}/token`
3. checks push-related notification preferences
4. sends a push notification through Firebase Cloud Messaging

2. AI incident enrichment
Whenever a new record is created under:

`/incidents/{incidentId}`

the function:

1. sends the incident details to OpenAI
2. generates a structured summary, severity suggestion, category, and next actions
3. saves the result under `incidents/{incidentId}/aiAnalysis`

### Deploy

1. Install the Firebase CLI if needed:
   `npm install -g firebase-tools`
2. Login:
   `firebase login`
3. Install function dependencies:
   `cd functions && npm install`
4. Set the OpenAI secret:
   `firebase functions:secrets:set OPENAI_API_KEY`
5. Deploy:
   `firebase deploy --only functions`

### Trigger paths

- `/userNotifications/{uid}/{notificationId}`
- `/incidents/{incidentId}`

### Expected client flow

The Flutter app writes notification rows directly to `/userNotifications`.
Those rows can then be picked up by Cloud Functions on Blaze or by the local
push sender workaround on Spark.
