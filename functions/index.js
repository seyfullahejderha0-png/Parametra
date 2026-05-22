const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

exports.onFamilyNotificationCreate = functions.firestore
  .document("family_notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const event = snap.data();
    if (!event) return null;

    const { id, spaceId, ownerId, actorId, module, action, title, body } = event;

    if (!spaceId || !ownerId || !actorId || !module) {
      console.log("Missing required fields in notification event: ", event);
      return null;
    }

    const db = admin.firestore();

    try {
      // 1. Spam protection: Same user, same module, within 30 seconds -> only 1 notification
      const thirtySecondsAgoMs = Date.now() - 30 * 1000;
      const recentEvents = await db.collection("family_notifications")
        .where("actorId", "==", actorId)
        .where("module", "==", module)
        .get();

      let recentCount = 0;
      recentEvents.forEach((docSnap) => {
        if (docSnap.id === id) return;
        const data = docSnap.data();
        if (data.timestamp) {
          const timeMs = data.timestamp.toDate().getTime();
          if (timeMs >= thirtySecondsAgoMs) {
            recentCount++;
          }
        }
      });

      if (recentCount > 0) {
        console.log(`Spam protected: User ${actorId} already sent a notification for module ${module} within the last 30 seconds.`);
        return null;
      }

      // 2. Fetch the shared space
      const spaceSnap = await db.doc(`users/${ownerId}/shared_spaces/${spaceId}`).get();
      if (!spaceSnap.exists) {
        console.log(`Shared space ${spaceId} not found under users/${ownerId}`);
        return null;
      }

      const spaceData = spaceSnap.data();
      const members = spaceData.members || [];
      const spaceName = spaceData.name || "Ortak Alan";

      // 3. Filter targets: other members who enabled notifications for this module
      const targetUids = [];

      for (const member of members) {
        const memberUid = member.uid;
        if (memberUid === actorId) continue; // Skip the actor

        // Fetch member profile for notification preference
        const profileSnap = await db.doc(`users/${memberUid}`).get();
        if (!profileSnap.exists) continue;

        const profile = profileSnap.data() || {};
        let isEnabled = true;

        switch (module) {
          case "finance":
            isEnabled = profile.notifyFinance !== false; // default true
            break;
          case "goals":
            isEnabled = profile.notifyGoals !== false; // default true
            break;
          case "notes":
            isEnabled = profile.notifyNotes !== false; // default true
            break;
          case "reminders":
            isEnabled = profile.notifyReminders !== false; // default true
            break;
          case "health":
            isEnabled = profile.notifyHealth === true; // default false
            break;
          default:
            isEnabled = true;
        }

        if (isEnabled) {
          targetUids.push(memberUid);
        }
      }

      if (targetUids.length === 0) {
        console.log("No notification targets found (either all skipped or preferences disabled).");
        return null;
      }

      // 4. Retrieve OneSignal configuration from functions config
      const onesignalConfig = functions.config().onesignal || {};
      const onesignalKey = onesignalConfig.key;
      const onesignalAppId = onesignalConfig.appid || "8d2d2357-e051-4e81-8f92-dc5e4dbeff4b";

      if (!onesignalKey) {
        console.error("OneSignal REST API key is not configured. Please set it using: firebase functions:config:set onesignal.key=\"YOUR_KEY\"");
        return null;
      }

      console.log(`Sending OneSignal notification to users: ${JSON.stringify(targetUids)}`);

      // 5. Send push notification via OneSignal API
      const response = await axios.post(
        "https://onesignal.com/api/v1/notifications",
        {
          app_id: onesignalAppId,
          include_aliases: {
            external_id: targetUids
          },
          target_channel: "push",
          headings: {
            en: `👨‍👩‍👧 ${spaceName}`,
            tr: `👨‍👩‍👧 ${spaceName}`
          },
          contents: {
            en: body,
            tr: body
          },
          data: {
            spaceId: spaceId,
            module: module
          }
        },
        {
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Key ${onesignalKey}`
          }
        }
      );

      console.log("OneSignal response status:", response.status, "data:", response.data);
    } catch (error) {
      console.error("Error processing family notification:", error.response ? error.response.data : error.message);
    }

    return null;
  });
