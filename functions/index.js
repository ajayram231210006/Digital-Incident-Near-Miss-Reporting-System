const admin = require("firebase-admin");
const {onValueCreated} = require("firebase-functions/v2/database");
const {logger} = require("firebase-functions");

admin.initializeApp();

function asString(value) {
  if (value === null || value === undefined) {
    return "";
  }
  return String(value);
}

exports.sendPushOnNotificationCreated = onValueCreated(
  {
    ref: "/userNotifications/{uid}/{notificationId}",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("Notification trigger fired without snapshot data.");
      return;
    }

    const uid = event.params.uid;
    const notificationId = event.params.notificationId;
    const notification = snapshot.val() || {};

    const title = asString(notification.title || "InciTrack");
    const body = asString(notification.body || "You have a new notification.");
    const reportId = asString(notification.reportId);
    const status = asString(notification.status);
    const severity = asString(notification.severity);
    const supervisorName = asString(notification.supervisorName);
    const reporterName = asString(notification.reporterName);
    const timestamp = asString(
      notification.timestamp || new Date().toISOString(),
    );

    const tokenSnapshot = await admin
      .database()
      .ref(`users/${uid}/fcmToken`)
      .get();

    let token = tokenSnapshot.exists() ? tokenSnapshot.val() : null;

    if (!token) {
      const fallbackTokenSnapshot = await admin
        .database()
        .ref(`notificationTokens/${uid}/token`)
        .get();
      token = fallbackTokenSnapshot.exists() ? fallbackTokenSnapshot.val() : null;
    }

    if (!token) {
      logger.warn(`No FCM token found for user ${uid}. Skipping push send.`, {
        uid,
        notificationId,
      });
      return;
    }

    const message = {
      token,
      notification: {
        title,
        body,
      },
      data: {
        notificationId: asString(notificationId),
        uid: asString(uid),
        title,
        body,
        reportId,
        status,
        severity,
        supervisorName,
        reporterName,
        timestamp,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
          priority: "max",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      logger.info("Push notification sent successfully.", {
        uid,
        notificationId,
        response,
      });
    } catch (error) {
      logger.error("Failed to send push notification.", {
        uid,
        notificationId,
        error,
      });

      const errorCode = error && error.code ? error.code : "";
      if (
        errorCode === "messaging/invalid-registration-token" ||
        errorCode === "messaging/registration-token-not-registered"
      ) {
        await admin.database().ref(`users/${uid}/fcmToken`).remove();
        await admin.database().ref(`notificationTokens/${uid}`).remove();
        logger.warn(`Removed stale FCM token for user ${uid}.`);
      }
    }
  },
);
