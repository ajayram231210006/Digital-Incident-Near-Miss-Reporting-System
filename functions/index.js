const admin = require("firebase-admin");
const {onValueCreated} = require("firebase-functions/v2/database");
const {logger} = require("firebase-functions");
const {defineSecret} = require("firebase-functions/params");

admin.initializeApp();

const openAiApiKey = defineSecret("OPENAI_API_KEY");
const AI_MODEL = "gpt-4.1-mini";

function asString(value) {
  if (value === null || value === undefined) {
    return "";
  }
  return String(value);
}

function asArray(value) {
  if (Array.isArray(value)) {
    return value.map((item) => asString(item)).filter(Boolean);
  }
  if (value && typeof value === "object") {
    return Object.values(value).map((item) => asString(item)).filter(Boolean);
  }
  return [];
}

function parseIncidentAnalysis(responseBody) {
  if (typeof responseBody.output_text === "string" && responseBody.output_text) {
    return JSON.parse(responseBody.output_text);
  }

  const firstOutput = Array.isArray(responseBody.output) ? responseBody.output[0] : null;
  const firstContent = firstOutput && Array.isArray(firstOutput.content) ? firstOutput.content[0] : null;
  if (firstContent && typeof firstContent.text === "string" && firstContent.text) {
    return JSON.parse(firstContent.text);
  }

  throw new Error("AI response did not contain structured output text.");
}

function getNotificationPreferenceKeys(type, audience) {
  switch (type) {
    case "new_report_created":
      return audience === "broadcast" ?
        ["broadcastEnabled", "newReports"] :
        ["newReports"];
    case "report_status_changed":
      return ["reportUpdates"];
    case "report_note_added":
      return ["noteAdded"];
    default:
      return [];
  }
}

async function getNotificationPreferences(uid) {
  if (!uid) {
    return {};
  }

  const snapshot = await admin
    .database()
    .ref(`notificationPreferences/${uid}`)
    .get();

  return snapshot.exists() ? snapshot.val() || {} : {};
}

function isNotificationEnabledForUser(preferences, type, audience) {
  if (preferences.inAppEnabled === false) {
    return false;
  }

  const keys = getNotificationPreferenceKeys(type, audience);
  return keys.every((key) => preferences[key] !== false);
}

function isPushEnabledForUser(preferences, type, audience) {
  if (preferences.pushEnabled === false) {
    return false;
  }

  const keys = getNotificationPreferenceKeys(type, audience);
  return keys.every((key) => preferences[key] !== false);
}

async function getUnreadCount(uid) {
  const snapshot = await admin.database().ref(`userNotifications/${uid}`).get();
  const value = snapshot.val();

  if (!value || typeof value !== "object") {
    return 0;
  }

  return Object.values(value).reduce((count, item) => {
    if (!item || typeof item !== "object") {
      return count;
    }

    return item.read === true ? count : count + 1;
  }, 0);
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
    const type = asString(notification.type);
    const audience = asString(notification.audience || "direct");
    const timestamp = asString(
      notification.timestamp || new Date().toISOString(),
    );
    const preferences = await getNotificationPreferences(uid);

    if (!isPushEnabledForUser(preferences, type, audience)) {
      logger.info("Push skipped due to notification preferences.", {
        uid,
        notificationId,
        type,
        audience,
      });
      return;
    }

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

    const unreadCount = await getUnreadCount(uid);

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
        type,
        audience,
        unreadCount: asString(unreadCount),
        timestamp,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
          priority: "max",
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

exports.analyzeIncidentWithAi = onValueCreated(
  {
    ref: "/incidents/{incidentId}",
    secrets: [openAiApiKey],
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("AI analysis trigger fired without snapshot data.");
      return;
    }

    const incidentId = event.params.incidentId;
    const incident = snapshot.val() || {};
    const incidentRef = admin.database().ref(`incidents/${incidentId}`);
    const description = asString(incident.description).trim();
    const type = asString(incident.type).trim();
    const location = asString(incident.location).trim();

    if (!description || !type) {
      await incidentRef.child("aiAnalysis").set({
        status: "skipped",
        reason: "Incident type or description was missing.",
        analyzedAt: new Date().toISOString(),
      });
      return;
    }

    await incidentRef.child("aiAnalysis").set({
      status: "processing",
      analyzedAt: new Date().toISOString(),
    });

    const analysisInput = {
      type,
      description,
      location,
      incidentDate: asString(incident.date),
      reporterEmail: asString(incident.reporterEmail),
      imageCount: asArray(incident.imageUrls).length,
      hasVideo: Boolean(asString(incident.videoUrl)),
      coordinates: {
        latitude: incident.latitude ?? null,
        longitude: incident.longitude ?? null,
      },
    };

    const schema = {
      type: "object",
      additionalProperties: false,
      properties: {
        category: {
          type: "string",
          enum: [
            "injury",
            "fire",
            "theft",
            "equipment",
            "unsafe_condition",
            "near_miss",
            "other",
          ],
        },
        severity: {
          type: "string",
          enum: ["low", "medium", "high", "critical"],
        },
        summary: {
          type: "string",
        },
        recommendedActions: {
          type: "array",
          items: {
            type: "string",
          },
          maxItems: 4,
        },
        missingFields: {
          type: "array",
          items: {
            type: "string",
          },
          maxItems: 4,
        },
        riskFactors: {
          type: "array",
          items: {
            type: "string",
          },
          maxItems: 4,
        },
        confidence: {
          type: "number",
          minimum: 0,
          maximum: 1,
        },
      },
      required: [
        "category",
        "severity",
        "summary",
        "recommendedActions",
        "missingFields",
        "riskFactors",
        "confidence",
      ],
    };

    try {
      const response = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${openAiApiKey.value()}`,
        },
        body: JSON.stringify({
          model: AI_MODEL,
          input: [
            {
              role: "system",
              content: [
                {
                  type: "input_text",
                  text:
                    "You analyze workplace incident reports. Return strict JSON only. " +
                    "Do not invent facts. Base the result only on the provided report. " +
                    "Keep the summary under 80 words and recommended actions practical.",
                },
              ],
            },
            {
              role: "user",
              content: [
                {
                  type: "input_text",
                  text: JSON.stringify(analysisInput),
                },
              ],
            },
          ],
          text: {
            format: {
              type: "json_schema",
              name: "incident_analysis",
              strict: true,
              schema,
            },
          },
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`OpenAI API ${response.status}: ${errorText}`);
      }

      const responseBody = await response.json();
      const analysis = parseIncidentAnalysis(responseBody);

      await incidentRef.child("aiAnalysis").set({
        status: "completed",
        model: AI_MODEL,
        analyzedAt: new Date().toISOString(),
        category: asString(analysis.category),
        suggestedSeverity: asString(analysis.severity),
        summary: asString(analysis.summary),
        recommendedActions: asArray(analysis.recommendedActions),
        missingFields: asArray(analysis.missingFields),
        riskFactors: asArray(analysis.riskFactors),
        confidence:
          typeof analysis.confidence === "number" ? analysis.confidence : 0,
      });

      logger.info("Incident AI analysis completed.", {
        incidentId,
        model: AI_MODEL,
      });
    } catch (error) {
      logger.error("Failed to analyze incident with AI.", {
        incidentId,
        error,
      });

      await incidentRef.child("aiAnalysis").set({
        status: "failed",
        analyzedAt: new Date().toISOString(),
        error: asString(error && error.message ? error.message : error),
      });
    }
  },
);
