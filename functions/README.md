## InciTrack Firebase Functions

This folder contains the Firebase Cloud Function that turns database
notifications into real push notifications.

### What it does

Whenever a new record is created under:

`/userNotifications/{uid}/{notificationId}`

the function:

1. reads the notification payload from Realtime Database
2. looks up the user's FCM token from:
   - `users/{uid}/fcmToken`
   - or `notificationTokens/{uid}/token`
3. sends a push notification through Firebase Cloud Messaging

### Deploy

1. Install the Firebase CLI if needed:
   `npm install -g firebase-tools`
2. Login:
   `firebase login`
3. Install function dependencies:
   `cd functions && npm install`
4. Deploy:
   `firebase deploy --only functions`

### Trigger path

`/userNotifications/{uid}/{notificationId}`

### Expected client flow

The Flutter app writes the in-app notification row first. This function then
sends the real device push notification automatically.
