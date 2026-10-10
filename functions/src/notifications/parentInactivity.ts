import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";

const DAY_MS = 24 * 60 * 60 * 1000;
const INACTIVITY_THRESHOLDS = [3, 7] as const;

/**
 * Sends each inactivity threshold once (3 and 7 days), including both alerts
 * if a scheduled run was missed and the learner has already reached day 7.
 * A recorded game resets inactivityNotificationLevel. Never-played accounts
 * are excluded so registration-only accounts are not nagged.
 */
export const notifyParentsOfLearnerInactivity = onSchedule(
  { schedule: "every day 10:00", timeZone: "Africa/Johannesburg" },
  async () => {
    const db = getFirestore();
    const learners = await db.collection("users").where("role", "==", "learner").get();
    const now = Date.now();
    let created = 0;

    for (const learnerDoc of learners.docs) {
      const statsRef = db.collection("player_stats").doc(learnerDoc.id);
      const statsSnap = await statsRef.get();
      const stats = statsSnap.data();
      const lastPlayedAt = stats?.lastPlayedAt;
      if (!lastPlayedAt || typeof lastPlayedAt.toMillis !== "function") continue;

      const daysInactive = Math.floor((now - lastPlayedAt.toMillis()) / DAY_MS);
      const previousLevel = Number(stats?.inactivityNotificationLevel ?? 0);
      const pendingThresholds = INACTIVITY_THRESHOLDS.filter(
        (threshold) => daysInactive >= threshold && previousLevel < threshold
      );
      if (pendingThresholds.length === 0) continue;

      const learner = learnerDoc.data();
      const learnerName = typeof learner.name === "string" && learner.name.trim() ?
        learner.name.trim() : "Your child";
      const parentUids: string[] = Array.isArray(learner.linkedParentUids) ?
        learner.linkedParentUids.filter((uid: unknown): uid is string =>
          typeof uid === "string" && uid.length > 0) : [];
      if (parentUids.length === 0) {
        // Do not mark a threshold sent; a parent may link later.
        continue;
      }

      const batch = db.batch();
      let parentCount = 0;
      for (const parentUid of parentUids) {
        const parentSnap = await db.collection("users").doc(parentUid).get();
        const parent = parentSnap.data();
        const linkedChildren: unknown = parent?.linkedChildrenUids;
        if (
          !parentSnap.exists ||
          parent?.role !== "parent" ||
          !Array.isArray(linkedChildren) ||
          !linkedChildren.includes(learnerDoc.id)
        ) continue;

        for (const threshold of pendingThresholds) {
          const ref = db.collection("notifications").doc();
          batch.set(ref, {
            title: threshold === 7 ?
              `${learnerName} may need a little encouragement 💛` :
              `Check in with ${learnerName} 💛`,
            body: threshold === 7 ?
              `${learnerName} has not played QuestKids for 7 days. ` +
              "A little encouragement could help them get back to learning." :
              `${learnerName} has not played QuestKids for 3 days. Consider encouraging them to try a learning game.`,
            type: "parent_inactivity",
            recipientUid: parentUid,
            childUid: learnerDoc.id,
            inactivityDays: threshold,
            read: false,
            isRead: false,
            createdAt: FieldValue.serverTimestamp(),
          });
          parentCount++;
        }
      }

      if (parentCount > 0) {
        // Advance state only after at least one valid linked parent is found.
        batch.set(statsRef, {
          inactivityNotificationLevel: Math.max(...pendingThresholds),
          inactivityNotificationUpdatedAt: Timestamp.now(),
        }, { merge: true });
        await batch.commit();
        created += parentCount;
      }
    }

    console.log(`Created ${created} parent inactivity notifications`);
  }
);
