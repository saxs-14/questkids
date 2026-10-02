import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK } from "../config";
import { ADMIN_BOOTSTRAP_TOKEN } from "../secrets";

const ADMIN_EMAIL = "questkid.game@gmail.com";

export const bootstrapAdmin = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    secrets: [ADMIN_BOOTSTRAP_TOKEN],
  },
  async (request) => {
    const suppliedToken = request.data?.bootstrapToken;

    if (typeof suppliedToken !== "string" ||
        suppliedToken.length < 32 ||
        suppliedToken !== ADMIN_BOOTSTRAP_TOKEN.value()) {
      throw new HttpsError("permission-denied", "Invalid bootstrap credentials.");
    }

    const auth = getAuth();
    const db = getFirestore();
    const bootstrapRef = db.collection("system").doc("adminBootstrap");
    const bootstrapState = await bootstrapRef.get();

    if (bootstrapState.data()?.completed === true) {
      throw new HttpsError(
        "failed-precondition",
        "The QuestKids first-admin bootstrap has already been completed."
      );
    }

    let user;
    try {
      user = await auth.getUserByEmail(ADMIN_EMAIL);
    } catch (error) {
      console.error("QuestKids admin bootstrap could not find the account.", error);
      throw new HttpsError(
        "failed-precondition",
        "The configured admin Authentication account does not exist yet."
      );
    }

    if (user.disabled) {
      throw new HttpsError(
        "failed-precondition",
        "The configured admin Authentication account is disabled."
      );
    }

    await auth.setCustomUserClaims(user.uid, {
      ...(user.customClaims ?? {}),
      role: "admin",
    });

    await db.collection("users").doc(user.uid).set(
      {
        uid: user.uid,
        name: "QuestKids Administrator",
        surname: null,
        email: ADMIN_EMAIL,
        role: "admin",
        grade: "N/A",
        gender: null,
        title: null,
        birthDate: null,
        relationToChild: null,
        parentUid: null,
        avatarUrl: null,
        childLinkCode: null,
        linkedParentUids: [],
        emailVerified: user.emailVerified,
        twoFactorEnabled: false,
        profileImageBase64: null,
        lastActiveDate: null,
        totalPoints: 0,
        streakDays: 0,
        linkedChildrenUids: [],
        preferredLanguage: "English",
        fcmToken: null,
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    await db.collection("system").doc("adminBootstrap").set(
      {
        completed: true,
        adminUid: user.uid,
        adminEmail: ADMIN_EMAIL,
        completedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      success: true,
      uid: user.uid,
      email: ADMIN_EMAIL,
      role: "admin",
    };
  }
);
