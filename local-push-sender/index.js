const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

const projectId = process.env.FIREBASE_PROJECT_ID || "users-3f3bd";
const databaseURL =
  process.env.FIREBASE_DATABASE_URL ||
  "https://users-3f3bd-default-rtdb.firebaseio.com";
const serviceAccountPath =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
const pollIntervalMs = Number(process.env.POLL_INTERVAL_MS || 5000);

if (!serviceAccountPath) {
  console.error(
    "Missing GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_SERVICE_ACCOUNT_PATH.",
  );
  process.exit(1);
}

const resolvedServiceAccountPath = path.resolve(serviceAccountPath);
if (!fs.existsSync(resolvedServiceAccountPath)) {
  console.error(`Service account file not found: ${resolvedServiceAccountPath}`);
  process.exit(1);
}

const serviceAccount = require(resolvedServiceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL,
  projectId,
});

const db = admin.database();
const processedNotificationIds = new Set();
const recentNotificationSignatures = new Map();
const duplicateWindowMs = Number(process.env.DUPLICATE_WINDOW_MS || 15000);

function asString(value, fallback = "") {
  if (value === undefined || value === null) {
    return fallback;
  }
  return String(value);
}

function buildMessage(uid, notificationId, notification, token, unreadCount) {
  const title = asString(notification.title, "InciTrack");
  const body = asString(notification.body, "You have a new notification.");

  return {
    token,
    notification: {
      title,
      body,
    },
    data: {
      uid: asString(uid),
      notificationId: asString(notificationId),
      title,
      body,
      reportId: asString(notification.reportId),
      status: asString(notification.status),
      severity: asString(notification.severity),
      supervisorName: asString(notification.supervisorName),
      reporterName: asString(notification.reporterName),
      unreadCount: asString(unreadCount, "0"),
      timestamp: asString(notification.timestamp, new Date().toISOString()),
    },
    android: {
      priority: "high",
      notification: {
        channelId: "high_importance_channel",
        priority: "max",
        tag: `notification-${notificationId}`,
        defaultSound: true,
        defaultVibrateTimings: true,
        notificationCount: unreadCount,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: unreadCount,
        },
      },
    },
  };
}

function buildDedupSignature(uid, notification) {
  return [
    uid,
    asString(notification.reportId),
    asString(notification.title),
    asString(notification.body),
    asString(notification.status),
    asString(notification.severity),
  ].join("|");
}

function cleanupOldSignatures() {
  const now = Date.now();
  for (const [signature, timestamp] of recentNotificationSignatures.entries()) {
    if (now - timestamp > duplicateWindowMs) {
      recentNotificationSignatures.delete(signature);
    }
  }
}

async function getUnreadCount(uid) {
  const snapshot = await db.ref(`userNotifications/${uid}`).get();
  const data = snapshot.val() || {};

  let count = 0;
  for (const notification of Object.values(data)) {
    if (!notification || typeof notification !== "object") {
      continue;
    }

    if (notification.read !== true) {
      count += 1;
    }
  }

  return count;
}

async function getUserToken(uid) {
  const primaryTokenSnapshot = await db.ref(`users/${uid}/fcmToken`).get();
  if (primaryTokenSnapshot.exists()) {
    return primaryTokenSnapshot.val();
  }

  const fallbackTokenSnapshot = await db.ref(`notificationTokens/${uid}/token`).get();
  if (fallbackTokenSnapshot.exists()) {
    return fallbackTokenSnapshot.val();
  }

  return null;
}

async function markStartupNotificationsAsProcessed() {
  const snapshot = await db.ref("userNotifications").get();
  const data = snapshot.val() || {};

  Object.entries(data).forEach(([uid, notifications]) => {
    if (!notifications || typeof notifications !== "object") {
      return;
    }

    Object.keys(notifications).forEach((notificationId) => {
      processedNotificationIds.add(`${uid}:${notificationId}`);
    });
  });

  console.log(
    `Initialized local sender with ${processedNotificationIds.size} existing notifications skipped.`,
  );
}

async function sendNotification(uid, notificationId, notification) {
  const token = await getUserToken(uid);
  if (!token) {
    console.warn(`No FCM token found for user ${uid}; skipping ${notificationId}.`);
    return;
  }

  cleanupOldSignatures();

  const signature = buildDedupSignature(uid, notification);
  if (recentNotificationSignatures.has(signature)) {
    console.log(`Skipped duplicate push for ${uid}:${notificationId}`);
    return;
  }

  recentNotificationSignatures.set(signature, Date.now());

  const unreadCount = await getUnreadCount(uid);
  const message = buildMessage(
    uid,
    notificationId,
    notification,
    token,
    unreadCount,
  );

  try {
    const response = await admin.messaging().send(message);
    console.log(`Sent push for ${uid}:${notificationId} -> ${response}`);
  } catch (error) {
    console.error(`Failed to send ${uid}:${notificationId}`, error);

    const code = error && error.code ? error.code : "";
    if (
      code === "messaging/invalid-registration-token" ||
      code === "messaging/registration-token-not-registered"
    ) {
      await db.ref(`users/${uid}/fcmToken`).remove();
      await db.ref(`notificationTokens/${uid}`).remove();
      console.warn(`Removed stale token for user ${uid}.`);
    }
  }
}

async function scanForNewNotifications() {
  const snapshot = await db.ref("userNotifications").get();
  const data = snapshot.val() || {};

  for (const [uid, notifications] of Object.entries(data)) {
    if (!notifications || typeof notifications !== "object") {
      continue;
    }

    for (const [notificationId, notification] of Object.entries(notifications)) {
      const uniqueId = `${uid}:${notificationId}`;
      if (processedNotificationIds.has(uniqueId)) {
        continue;
      }

      processedNotificationIds.add(uniqueId);
      await sendNotification(uid, notificationId, notification || {});
    }
  }
}

async function start() {
  console.log("Starting InciTrack local push sender...");
  console.log(`Project: ${projectId}`);
  console.log(`Database: ${databaseURL}`);
  console.log(`Polling every ${pollIntervalMs} ms`);

  await markStartupNotificationsAsProcessed();
  await scanForNewNotifications();

  setInterval(() => {
    scanForNewNotifications().catch((error) => {
      console.error("Polling error:", error);
    });
  }, pollIntervalMs);
}

start().catch((error) => {
  console.error("Startup failed:", error);
  process.exit(1);
});
