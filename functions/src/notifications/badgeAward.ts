import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

interface BadgeMap {
  id?: string;
  name?: string;
  icon?: string;
}

/**
 * Cloud Function: whenever a rewards/{uid} document gains a new badge
 * (RewardRepository.awardBadge's arrayUnion write, used by both the main
 * quiz flow and the grade4 legacy feature), notify the learner and every
 * linked parent server-side. This is the "Achievement notifications" +
 * "Parent notifications" delivery point for badge awards -- client code
 * cannot write a notification for someone else (the parent) directly,
 * since that would require loosening the Firestore create rule.
 */
export const onBadgeAwarded = onDocumentUpdated(
  "rewards/{uid}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const beforeIds = new Set(
      (before.badges ?? []).map((b: BadgeMap) => b.id).filter(Boolean)
    );
    const newBadges: BadgeMap[] = (after.badges ?? []).filter(
      (b: BadgeMap) => b.id && !beforeIds.has(b.id)
    );
    if (newBadges.length === 0) return;

    const uid = event.params.uid;
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const learner = userDoc.data();
    if (!learner) return;

    const learnerName: string = learner.name ?? "Your child";
    const linkedParentUids: string[] = learner.linkedParentUids ?? [];

    const batch = admin.firestore().batch();
    for (const badge of newBadges) {
      // Notify the learner themselves.
      const learnerRef = admin.firestore().collection("notifications").doc();
      batch.set(learnerRef, {
        title: "Badge earned! 🏅",
        body: `You earned the ${badge.name ?? "a new"} badge!`,
        type: "achievement",
        recipientUid: uid,
        read: false,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Notify each linked parent.
      for (const parentUid of linkedParentUids) {
        const parentRef = admin.firestore().collection("notifications").doc();
        batch.set(parentRef, {
          title: `${learnerName} earned a badge! 🏅`,
          body: `${learnerName} just earned the ${badge.name ?? "a new"} badge.`,
          type: "parent_update",
          recipientUid: parentUid,
          read: false,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  });
