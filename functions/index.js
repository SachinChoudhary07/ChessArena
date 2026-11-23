/**
 * Chess Arena Cloud Functions.
 *
 * Push notifications are sent from here, never from the app. The app only
 * writes a challenge document; this function runs with the project's own
 * service account (no key file needed) and sends the FCM message.
 */
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

/**
 * When a player creates a challenge, notify the opponent.
 * Mirrors the payload the app used to build on-device.
 */
exports.notifyOnChallengeCreated = onDocumentCreated(
  "challenges/{challengeId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const challenge = snap.data();
    const challengeId = event.params.challengeId;
    const challengerUid = challenge.challenger;
    const opponentUid = challenge.opponent;

    if (!challengerUid || !opponentUid || challenge.status !== "pending") {
      return;
    }

    const [challengerDoc, opponentDoc] = await Promise.all([
      db.collection("users").doc(challengerUid).get(),
      db.collection("users").doc(opponentUid).get(),
    ]);

    const token = opponentDoc.get("fcmToken");
    if (!token) {
      logger.info("Opponent has no FCM token", { challengeId, opponentUid });
      return;
    }

    const challengerName = challengerDoc.get("username") || "A player";
    const timeControl = challenge.timeControl || "";

    try {
      await getMessaging().send({
        token,
        notification: {
          title: "New Chess Challenge!",
          body: `${challengerName} challenged you to a ${timeControl} game.`,
        },
        android: {
          notification: {
            icon: "ic_launcher",
            color: "#e3ac3b",
            tag: `challenge_${challengerUid}`,
          },
        },
        data: {
          type: "challenge",
          challengerUid,
          challengeId,
        },
      });
    } catch (err) {
      // A stale token is common (app uninstalled / reinstalled). Clear it so
      // we stop trying; the app writes a fresh one on next sign-in.
      if (err.code === "messaging/registration-token-not-registered") {
        await opponentDoc.ref.update({ fcmToken: "" });
      }
      logger.error("FCM send failed", { challengeId, code: err.code });
    }
  }
);
