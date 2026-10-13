import { createHash } from "crypto";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getMessaging, SendResponse } from "firebase-admin/messaging";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const TOKEN_BATCH_SIZE = 500;

function tokenFingerprint(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

/**
 * Deliver notification documents through FCM. Successful tokens are recorded
 * before proceeding so a retry only targets tokens that have not succeeded.
 */
export const sendPushOnNotificationCreate = onDocumentCreated(
  { document: "notifications/{notificationId}", retry: true },
  async (event) => {
    if (!event.data) throw new Error("Notification event did not include a document.");

    const notificationRef = event.data.ref;
    const notificationSnap = await notificationRef.get();
    const data = notificationSnap.data();
    if (!data) throw new Error("Notification document disappeared before delivery.");
    if (data.pushSent === true) return;

    const recipientUid = data.recipientUid ?? data.targetUid;
    if (typeof recipientUid !== "string" || recipientUid.length === 0) {
      await notificationRef.update({
        pushSent: false,
        pushError: "Notification is missing a valid recipientUid.",
      });
      return;
    }

    const userSnap = await getFirestore().collection("users").doc(recipientUid).get();
    const tokens = Array.isArray(userSnap.data()?.fcmTokens) ?
      [...new Set((userSnap.data()?.fcmTokens as unknown[])
        .filter((token): token is string => typeof token === "string" && token.length > 0))] :
      [];
    if (tokens.length === 0) {
      await notificationRef.update({
        pushSent: false,
        pushError: "Recipient has no registered FCM tokens.",
      });
      return;
    }

    const delivered = new Set(
      Array.isArray(data.pushDeliveredTokenHashes) ?
        data.pushDeliveredTokenHashes.filter((token: unknown): token is string =>
          typeof token === "string") :
        []
    );
    const pending = tokens.filter((token) => !delivered.has(tokenFingerprint(token)));
    const staleTokens: string[] = [];
    const retryErrors: string[] = [];

    for (let start = 0; start < pending.length; start += TOKEN_BATCH_SIZE) {
      const batch = pending.slice(start, start + TOKEN_BATCH_SIZE);
      let response;
      try {
        response = await getMessaging().sendEachForMulticast({
          tokens: batch,
          notification: {
            title: typeof data.title === "string" ? data.title : "QuestKids",
            body: typeof data.body === "string" ? data.body : "",
          },
          data: {
            type: typeof data.type === "string" ? data.type : "general",
            notificationId: event.params.notificationId,
          },
          android: {
            priority: "high",
            notification: {
              channelId: "questkids_notifications",
              sound: "default",
            },
          },
          apns: {
            payload: { aps: { sound: "default", contentAvailable: true } },
          },
        });
      } catch (error) {
        console.error("FCM multicast request failed; delivery will be retried.", error);
        await notificationRef.update({
          pushSent: false,
          pushError: "FCM delivery request failed; an automatic retry is scheduled.",
          pushAttemptedAt: FieldValue.serverTimestamp(),
        });
        throw error;
      }

      const deliveredBatch: string[] = [];
      response.responses.forEach((result: SendResponse, index: number) => {
        if (result.success) {
          deliveredBatch.push(tokenFingerprint(batch[index]));
        } else if (
          result.error?.code === "messaging/registration-token-not-registered" ||
          result.error?.code === "messaging/invalid-registration-token"
        ) {
          staleTokens.push(batch[index]);
        } else {
          retryErrors.push(
            `${tokenFingerprint(batch[index])}: ${result.error?.code ?? "unknown-error"}`
          );
        }
      });

      if (deliveredBatch.length > 0) {
        await notificationRef.update({
          pushDeliveredTokenHashes: FieldValue.arrayUnion(...deliveredBatch),
        });
      }
    }

    if (staleTokens.length > 0) {
      await getFirestore()
        .collection("users")
        .doc(recipientUid)
        .update({ fcmTokens: FieldValue.arrayRemove(...staleTokens) });
    }

    if (retryErrors.length > 0) {
      const error = new Error(`FCM could not deliver to ${retryErrors.length} token(s).`);
      await notificationRef.update({
        pushSent: false,
        pushError: `${error.message} ${retryErrors.slice(0, 5).join("; ")}`,
        pushAttemptedAt: FieldValue.serverTimestamp(),
      });
      throw error;
    }

    await notificationRef.update({
      pushSent: true,
      pushSentAt: FieldValue.serverTimestamp(),
      pushError: FieldValue.delete(),
    });
  }
);
