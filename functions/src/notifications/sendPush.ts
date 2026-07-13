import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

/**
 * Cloud Function: send an FCM push whenever a document is created in the
 * 'notifications' collection, regardless of which function or client wrote
 * it. This is the single delivery point so future notification-creation
 * call sites don't each need their own push-sending code.
 */
export const sendPushOnNotificationCreate = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) {
      console.error("No notification data found");
      return;
    }

    const recipientUid: string | undefined = data.recipientUid;
    if (!recipientUid) {
      console.error("Notification has no recipientUid, skipping push");
      return;
    }

    try {
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(recipientUid)
        .get();
      const tokens: string[] = userDoc.data()?.fcmTokens ?? [];

      if (tokens.length === 0) {
        console.log(`No FCM tokens for ${recipientUid}, skipping push`);
        return;
      }

      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: data.title ?? "QuestKids",
          body: data.body ?? "",
        },
        data: { type: data.type ?? "general", notificationId: event.params.notificationId },
      });

      // Drop tokens FCM reports as no-longer-registered so the array
      // doesn't grow unboundedly with dead devices.
      const staleTokens: string[] = [];
      response.responses.forEach((r, i) => {
        if (!r.success && r.error?.code === "messaging/registration-token-not-registered") {
          staleTokens.push(tokens[i]);
        }
      });
      if (staleTokens.length > 0) {
        await admin
          .firestore()
          .collection("users")
          .doc(recipientUid)
          .update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...staleTokens) });
      }

      await event.data?.ref.update({
        pushSent: true,
        pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error("Error sending push notification:", error);
      await event.data?.ref.update({ pushSent: false, pushError: String(error) });
    }
  });
