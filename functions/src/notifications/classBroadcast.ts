import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

export const onClassBroadcast = onDocumentCreated(
  "class_broadcasts/{broadcastId}",
  async (event) => {
    const broadcast = event.data?.data();
    if (!broadcast) return;

    const teacherUid: string = broadcast.teacherUid;
    const title: string = broadcast.title;
    const body: string = broadcast.body;

    const learnersSnap = await admin.firestore()
      .collection("users")
      .where("linkedTeacherUids", "array-contains", teacherUid)
      .get();
    if (learnersSnap.empty) return;

    const batch = admin.firestore().batch();
    for (const learnerDoc of learnersSnap.docs) {
      const ref = admin.firestore().collection("notifications").doc();
      batch.set(ref, {
        title,
        body,
        type: "class_broadcast",
        recipientUid: learnerDoc.id,
        read: false,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  });
