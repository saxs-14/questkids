import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

export const onNewMessage = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const conversationId = event.params.conversationId;
    const convoSnap = await admin.firestore()
      .collection("conversations").doc(conversationId).get();
    const convo = convoSnap.data();
    if (!convo) return;

    const senderUid: string = message.senderUid;
    const senderRole: string = message.senderRole;
    const recipientUid = senderUid === convo.teacherUid ?
      convo.parentUid :
      convo.teacherUid;
    if (!recipientUid || recipientUid === senderUid) return;

    const childName: string = convo.childName ?? "your child";
    const senderLabel = senderRole === "teacher" ? "Teacher" : "Parent";

    await admin.firestore().collection("notifications").add({
      title: `New message about ${childName}`,
      body: `${senderLabel}: ${String(message.text).slice(0, 100)}`,
      type: "message",
      recipientUid,
      read: false,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
