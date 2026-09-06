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

    // linkedTeacherUids (plural, array) is the field the live "Add
    // Learner" flow actually writes (teacher_dashboard.dart, via
    // FieldValue.arrayUnion) and every other teacher-scoped query/rule in
    // the app reads (TeacherRepository, firestore.rules, storage.rules).
    // UserModel's singular linkedTeacherUid field is never written by any
    // live code path -- a prior "fix" here swapped to that dead field,
    // which meant class broadcasts silently reached nobody instead.
    const learnersSnap = await getFirestore()
      .collection("users")
      .where("linkedTeacherUids", "array-contains", teacherUid)
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
