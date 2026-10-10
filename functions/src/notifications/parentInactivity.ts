import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Sends at most one inactivity notification at each threshold (3 and 7 days).
 * A new recorded game resets inactivityNotificationLevel to 0, allowing a
 * future inactive period to generate its own alerts. Learners with no recorded
 * game activity are excluded so registration-only accounts are not nagged.
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
      const threshold = daysInactive >= 7 ? 7 : daysInactive >= 3 ? 3 : 0;
      const previousLevel = Number(stats?.inactivityNotificationLevel ?? 0);
      if (threshold === 0 || previousLevel >= threshold) continue;

      const learner = learnerDoc.data();
      const learnerName = typeof learner.name === "string" && learner.name.trim() ?
        learner.name.trim() : "Your child";
      const parentUids: string[] = Array.isArray(learner.linkedParentUids) ?
        learner.linkedParentUids.filter((uid: unknown): uid is string =>
          typeof uid === "string" && uid.length > 0) : [];
      if (parentUids.length === 0) {
        // Do not mark the threshold sent; a parent may link later.
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

      if (parentCount > 0) {
        // Mark the threshold only after preparing at least one valid recipient.
        batch.set(statsRef, {
          inactivityNotificationLevel: threshold,
          inactivityNotificationUpdatedAt: Timestamp.now(),
        }, { merge: true });
        await batch.commit();
        created += parentCount;
      }
    }

    console.log(`Created ${created} parent inactivity notifications`);
  }
);
