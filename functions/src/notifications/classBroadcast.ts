import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export const onClassBroadcast = onDocumentCreated(
  "class_broadcasts/{broadcastId}",
  async (event) => {
    const broadcast = event.data?.data();
    if (!broadcast) return;

    const teacherUid: string = broadcast.teacherUid;
    const title: string = broadcast.title;
    const body: string = broadcast.body;

    // UserModel.linkedTeacherUid is a single string field (a learner has
    // one class), not an array -- this previously queried a field
    // ("linkedTeacherUids", array-contains) that no learner doc has ever
    // had, so class broadcasts silently reached nobody.
    const learnersSnap = await getFirestore()
      .collection("users")
      .where("linkedTeacherUid", "==", teacherUid)
      .get();
    if (learnersSnap.empty) return;

    const batch = getFirestore().batch();
    for (const learnerDoc of learnersSnap.docs) {
      const ref = getFirestore().collection("notifications").doc();
      batch.set(ref, {
        title,
        body,
        type: "class_broadcast",
        recipientUid: learnerDoc.id,
        read: false,
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  });
