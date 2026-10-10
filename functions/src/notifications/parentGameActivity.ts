import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

/**
 * Notify verified linked parents after a game session is recorded.
 * Sessions are written by the trusted recordGameSession callable, not by the
 * client directly. This intentionally reports completed/recorded sessions;
 * QuestKids does not persist a separate game-start event today.
 */
export const notifyParentsOfGameSession = onDocumentCreated(
  "game_sessions/{sessionId}",
  async (event) => {
    const session = event.data?.data();
    if (!session || typeof session.uid !== "string") return;

    const db = getFirestore();
    const learnerSnap = await db.collection("users").doc(session.uid).get();
    if (!learnerSnap.exists) return;

    const learner = learnerSnap.data() ?? {};
    const learnerName = typeof learner.name === "string" && learner.name.trim() ?
      learner.name.trim() : "Your child";
    const candidateParentUids: string[] = Array.isArray(learner.linkedParentUids) ?
      learner.linkedParentUids.filter((uid: unknown): uid is string =>
        typeof uid === "string" && uid.length > 0) : [];

    if (candidateParentUids.length === 0) return;

    const sessionTitle = typeof session.catalogId === "string" && session.catalogId.trim() ?
      session.catalogId.trim().replace(/[_-]+/g, " ") :
      typeof session.engineType === "string" && session.engineType.trim() ?
        session.engineType.trim().replace(/[_-]+/g, " ") : "a learning game";
    const score = typeof session.score === "number" && Number.isFinite(session.score) ?
      Math.round(Math.max(0, Math.min(100, session.score))) : null;
    const result = session.result === "win" || session.result === "complete" ?
      "completed successfully" : "finished a game";

    const batch = db.batch();
    let count = 0;
    for (const parentUid of candidateParentUids) {
      const parentSnap = await db.collection("users").doc(parentUid).get();
      const parent = parentSnap.data();
      const linkedChildren: unknown = parent?.linkedChildrenUids;
      if (
        !parentSnap.exists ||
        parent?.role !== "parent" ||
        !Array.isArray(linkedChildren) ||
        !linkedChildren.includes(session.uid)
      ) {
        continue;
      }

      const ref = db.collection("notifications").doc();
      batch.set(ref, {
        title: `${learnerName} played a game 🎮`,
        body: `${learnerName} ${result}: ${sessionTitle}${score === null ? "" : ` — score ${score}%`}.`,
        type: "parent_update",
        recipientUid: parentUid,
        childUid: session.uid,
        gameSessionId: event.params.sessionId,
        read: false,
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
      count++;
    }
    if (count > 0) await batch.commit();
  }
);
