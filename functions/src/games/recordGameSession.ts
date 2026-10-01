import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { ENFORCE_APP_CHECK } from "../config";

const GRADE_ONE_CATALOG = /^(math_g1_|eng_g1_|ls_g1_)/;

function numberInRange(value: unknown, min: number, max: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError("invalid-argument", "Invalid numeric game result.");
  }
  return Math.min(max, Math.max(min, value));
}

export const recordGameSession = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in to save game progress.");
    }
    if (request.auth.token.role !== "learner") {
      throw new HttpsError("permission-denied", "Only child accounts can submit game sessions.");
    }

    const data = request.data ?? {};
    const sessionId = typeof data.id === "string" ? data.id.trim() : "";
    const engineType = typeof data.engineType === "string" ? data.engineType.trim() : "";
    const subject = typeof data.subject === "string" ? data.subject.trim() : "";
    const grade = typeof data.grade === "string" ? data.grade.trim() : "";
    const catalogId = typeof data.catalogId === "string" ? data.catalogId.trim() : "";
    const metadata = data.metadata && typeof data.metadata === "object" ? data.metadata : {};

    if (!sessionId || sessionId.length > 100 || !engineType || !subject || !grade) {
      throw new HttpsError("invalid-argument", "A valid game session is required.");
    }

    const score = Math.round(numberInRange(data.score, 0, 100));
    const accuracy = numberInRange(data.accuracy, 0, 1);
    const timeTakenSeconds = Math.round(numberInRange(data.timeTakenSeconds, 0, 7200));

    const levelRaw = (metadata as Record<string, unknown>).level;
    const level = levelRaw === undefined ? null : Math.round(numberInRange(levelRaw, 1, 10));

    if (level !== null && (!catalogId || !GRADE_ONE_CATALOG.test(catalogId))) {
      throw new HttpsError("invalid-argument", "Level progression is only valid for Grade 1 game sessions.");
    }
    if (catalogId && GRADE_ONE_CATALOG.test(catalogId) && level === null) {
      throw new HttpsError("invalid-argument", "Grade 1 game sessions must include a level.");
    }

    const uid = request.auth.uid;
    const db = getFirestore();
    const sessionRef = db.collection("game_sessions").doc(sessionId);
    const userRef = db.collection("users").doc(uid);
    const statsRef = db.collection("player_stats").doc(uid);
    const rewardsRef = db.collection("rewards").doc(uid);
    const engineRef = db.collection("game_progress").doc(uid).collection("engines").doc(engineType);
    const progressRef = db.collection("progress").doc(sessionId);

    let result = "loss";
    let xpEarned = Math.max(10, Math.round(score * 1.2));
    let coinsEarned = Math.max(1, Math.floor(xpEarned / 10));
    let levelAdvanced = false;
    let currentLevel = level ?? 0;
    let completedAllLevels = false;

    await db.runTransaction(async (tx) => {
      const existing = await tx.get(sessionRef);
      if (existing.exists) {
        const saved = existing.data()!;
        result = typeof saved.result === "string" ? saved.result : "complete";
        xpEarned = typeof saved.xpEarned === "number" ? saved.xpEarned : 0;
        coinsEarned = typeof saved.coinsEarned === "number" ? saved.coinsEarned : 0;
        currentLevel = typeof saved.currentLevel === "number" ? saved.currentLevel : currentLevel;
        completedAllLevels = saved.completedAllLevels === true;
        return;
      }

      const userSnap = await tx.get(userRef);
      const statsSnap = await tx.get(statsRef);
      const engineSnap = await tx.get(engineRef);
      const rewardsSnap = await tx.get(rewardsRef);
      const levelRef = level !== null
        ? db.collection("game_level_progress").doc(uid).collection("games").doc(catalogId)
        : null;
      const levelSnap = levelRef == null ? null : await tx.get(levelRef);

      if (!userSnap.exists || userSnap.data()?.role !== "learner") {
        throw new HttpsError("permission-denied", "The account is not an active child account.");
      }

      let storedLevel = 1;
      if (levelSnap != null) {
        storedLevel = Math.max(1, Math.min(10, Number(levelSnap.data()?.currentLevel ?? 1)));
        if (level !== storedLevel) {
          throw new HttpsError(
            "failed-precondition",
            `Play level ${storedLevel} next. Completed levels cannot be skipped.`
          );
        }
      }

      if (level !== null) {
        result = score >= 50 ? "complete" : "loss";
        xpEarned = Math.max(10, Math.round(score * 1.2) + (score >= 80 ? 10 : 0));
        coinsEarned = Math.max(1, Math.floor(xpEarned / 10));
        const nextLevel = score >= 50 ? Math.min(10, storedLevel + 1) : storedLevel;
        levelAdvanced = score >= 50 && nextLevel > storedLevel;
        completedAllLevels = score >= 50 && storedLevel === 10;
        currentLevel = nextLevel;
      } else {
        result = score >= 50 ? "win" : "loss";
      }

      const isWin = result === "win" || result === "complete";
      const sessionData = {
        uid,
        grade,
        subject,
        engineType,
        catalogId: catalogId || null,
        score,
        accuracy,
        timeTakenSeconds,
        xpEarned,
        coinsEarned,
        result,
        metadata,
        currentLevel,
        completedAllLevels,
        completedAt: Timestamp.now(),
        recordedBy: "server",
      };

      tx.create(sessionRef, sessionData);
      if (levelRef != null && levelSnap != null) {
        tx.set(levelRef, {
          catalogId,
          currentLevel,
          highestCompletedLevel: completedAllLevels ? 10 : Math.max(0, currentLevel - 1),
          lastScore: score,
          bestScore: Math.max(Number(levelSnap.data()?.bestScore ?? 0), score),
          completed: completedAllLevels,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      tx.set(progressRef, {
        uid,
        activityId: sessionId,
        activityTitle: `${subject} – ${engineType}`,
        subject,
        score,
        pointsEarned: xpEarned,
        completed: isWin,
        verified: false,
        proofUrl: null,
        completedAt: Timestamp.now(),
        timeTakenSeconds,
      });

      const stats = statsSnap.data() ?? {};
      const newXp = Number(stats.xp ?? 0) + xpEarned;
      tx.set(statsRef, {
        uid,
        xp: newXp,
        coins: Number(stats.coins ?? 0) + coinsEarned,
        level: Math.floor(newXp / 100) + 1,
        gamesPlayed: Number(stats.gamesPlayed ?? 0) + 1,
        wins: Number(stats.wins ?? 0) + (isWin ? 1 : 0),
        losses: Number(stats.losses ?? 0) + (isWin ? 0 : 1),
        favoriteEngine: engineType,
        lastPlayedAt: FieldValue.serverTimestamp(),
        achievements: Array.isArray(stats.achievements) ? stats.achievements : [],
        unlockedWorlds: Array.isArray(stats.unlockedWorlds) ? stats.unlockedWorlds : [],
      }, { merge: true });

      const engine = engineSnap.data() ?? {};
      const previousGames = Number(engine.totalGames ?? 0);
      const newGames = previousGames + 1;
      const averageAccuracy = ((Number(engine.averageAccuracy ?? 0) * previousGames) + accuracy) / newGames;
      tx.set(engineRef, {
        engineType,
        subject,
        grade,
        totalGames: newGames,
        wins: Number(engine.wins ?? 0) + (isWin ? 1 : 0),
        losses: Number(engine.losses ?? 0) + (isWin ? 0 : 1),
        bestScore: Math.max(Number(engine.bestScore ?? 0), score),
        totalXP: Number(engine.totalXP ?? 0) + xpEarned,
        averageAccuracy,
        lastPlayedAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      const rewards = rewardsSnap.data() ?? {};
      const totalPoints = Number(rewards.totalPoints ?? 0) + xpEarned;
      const gamesPlayed = Number(stats.gamesPlayed ?? 0) + 1;
      const badges = Array.isArray(rewards.badges) ? rewards.badges : [];
      const badgeIds = new Set(
        badges.map((b) => (b && typeof b === "object" ? (b as Record<string, unknown>).id : null))
      );
      const addBadge = (id: string, name: string, icon: string, description: string) => {
        if (!badgeIds.has(id)) {
          badges.push({ id, name, icon, description, category: "milestone", earnedAt: new Date().toISOString() });
          badgeIds.add(id);
        }
      };
      if (gamesPlayed >= 1) addBadge("first_quest", "First Quest", "🌟", "Complete your first quest");
      if (score === 100) addBadge("perfect_score", "Perfect Score", "🎯", "Get 100% in any game");
      if (gamesPlayed >= 50) addBadge("quest_master", "Quest Master", "👑", "Complete 50 games");
      if (Math.floor(totalPoints / 100) + 1 >= 10) addBadge("legend", "Legend", "🦁", "Reach Level 10");

      tx.set(rewardsRef, {
        uid,
        totalPoints,
        level: Math.floor(totalPoints / 100) + 1,
        goldBalance: Number(rewards.goldBalance ?? 0) + coinsEarned,
        lastActiveDate: Date.now(),
        streakDays: Number(rewards.streakDays ?? 0),
        badges,
        ownedItemIds: Array.isArray(rewards.ownedItemIds) ? rewards.ownedItemIds : [],
        equippedItemId: rewards.equippedItemId ?? null,
      }, { merge: true });

      tx.update(userRef, {
        totalPoints: FieldValue.increment(xpEarned),
      });
    });

    return {
      recorded: true,
      sessionId,
      xpEarned,
      coinsEarned,
      currentLevel,
      levelAdvanced,
      completedAllLevels,
      result,
    };
  }
);
