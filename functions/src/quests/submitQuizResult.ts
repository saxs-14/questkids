import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { ENFORCE_APP_CHECK } from "../config";

function validNumber(value: unknown, name: string, max: number): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0 || value > max) {
    throw new HttpsError("invalid-argument", `Invalid ${name}.`);
  }
  return Math.floor(value);
}

function pointsFor(score: number, basePoints: number, seconds: number): number {
  let multiplier = 1;
  if (score === 100) multiplier = 2;
  else if (score >= 80) multiplier = 1.5;
  else if (score >= 60) multiplier = 1.2;
  if (seconds < 30) multiplier += 0.3;
  else if (seconds < 60) multiplier += 0.1;
  return Math.round(basePoints * multiplier * (score / 100));
}

export const submitQuizResult = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to save quiz results.");
    }
    if (request.auth.token.role !== "learner") {
      throw new HttpsError("permission-denied", "Only learners can submit quiz results.");
    }

    const data = request.data ?? {};
    const submissionId =
      typeof data.submissionId === "string" ? data.submissionId.trim() : "";
    const activityId =
      typeof data.activityId === "string" ? data.activityId.trim() : "";
    if (!submissionId || submissionId.length > 100 || submissionId.includes("/") ||
        !activityId || activityId.length > 150 || activityId.includes("/")) {
      throw new HttpsError("invalid-argument", "A valid quiz submission is required.");
    }
    if (!Array.isArray(data.answers) || data.answers.length === 0 ||
        data.answers.length > 100 ||
        !data.answers.every((answer: unknown) => typeof answer === "string")) {
      throw new HttpsError("invalid-argument", "Quiz answers are missing or invalid.");
    }
    const timeTakenSeconds = validNumber(data.timeTakenSeconds, "time taken", 7200);

    const db = getFirestore();
    const uid = request.auth.uid;
    const submissionRef = db.collection("progress").doc(submissionId);
    const activityRef = db.collection("activities").doc(activityId);
    const userRef = db.collection("users").doc(uid);
    const rewardsRef = db.collection("rewards").doc(uid);
    const existing = await submissionRef.get();
    if (existing.exists) {
      if (existing.data()?.uid !== uid) {
        throw new HttpsError("permission-denied", "This submission ID is already in use.");
      }
      return { recorded: false, submissionId };
    }

    const activitySnap = await activityRef.get();
    if (!activitySnap.exists) {
      throw new HttpsError("not-found", "This quiz is no longer available.");
    }
    const activity = activitySnap.data()!;
    const questions = activity.questions;
    if (!Array.isArray(questions) || questions.length !== data.answers.length ||
        questions.length === 0) {
      throw new HttpsError("failed-precondition", "The quiz questions have changed.");
    }
    let correctAnswers = 0;
    for (let i = 0; i < questions.length; i++) {
      const question = questions[i] as Record<string, unknown>;
      const options = question.options;
      const correctIndex = question.correctIndex;
      if (!Array.isArray(options) || typeof correctIndex !== "number" ||
          !Number.isInteger(correctIndex) || correctIndex < 0 ||
          correctIndex >= options.length || typeof options[correctIndex] !== "string") {
        throw new HttpsError("failed-precondition", "The quiz contains invalid question data.");
      }
      if (data.answers[i] === options[correctIndex]) correctAnswers++;
    }

    const score = Math.round((correctAnswers / questions.length) * 100);
    const basePoints = validNumber(activity.rewardPoints, "quiz reward", 10000);
    const pointsEarned = pointsFor(score, basePoints, timeTakenSeconds);
    const completedAt = Timestamp.now();

    const result = await db.runTransaction(async (tx) => {
      const [submissionSnap, userSnap, rewardsSnap] = await Promise.all([
        tx.get(submissionRef),
        tx.get(userRef),
        tx.get(rewardsRef),
      ]);
      if (submissionSnap.exists) {
        if (submissionSnap.data()?.uid !== uid) {
          throw new HttpsError("permission-denied", "This submission ID is already in use.");
        }
        return false;
      }
      if (!userSnap.exists || userSnap.data()?.role !== "learner") {
        throw new HttpsError("permission-denied", "The account is not an active learner.");
      }

      const currentPoints =
        (rewardsSnap.data()?.totalPoints as number | undefined) ?? 0;
      const newTotal = currentPoints + pointsEarned;
      tx.set(submissionRef, {
        uid,
        activityId,
        activityTitle: String(activity.title ?? "Quiz"),
        subject: String(activity.subject ?? "General"),
        score,
        pointsEarned,
        completed: true,
        verified: false,
        proofUrl: null,
        completedAt,
        timeTakenSeconds,
      });
      tx.set(rewardsRef, {
        uid,
        totalPoints: newTotal,
        level: Math.floor(newTotal / 100) + 1,
        lastActiveDate: Date.now(),
        streakDays: Number(rewardsSnap.data()?.streakDays ?? 0),
        badges: Array.isArray(rewardsSnap.data()?.badges) ? rewardsSnap.data()?.badges : [],
        achievements: Array.isArray(rewardsSnap.data()?.achievements) ?
          rewardsSnap.data()?.achievements : [],
      }, { merge: true });
      tx.update(userRef, {
        totalPoints: FieldValue.increment(pointsEarned),
      });
      return true;
    });

    return { recorded: result, submissionId, score, pointsEarned };
  }
);
