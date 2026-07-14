/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import { setGlobalOptions } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";
import { MAIL_PASSWORD } from "./secrets";
import { MAIL_SENDER } from "./config";

export { questyChat, analyzeImage, getRecommendation, explainAnswer, generateHint } from "./gemini/proxy";
export { refreshLeaderboards } from "./leaderboard/refresh";
export { generateDailyMissions } from "./missions/generate";
export { getTeacherInsight } from "./teacher/insights";
export { setUserRole, assignDefaultRole } from "./admin/setUserRole";
export { sendPushOnNotificationCreate } from "./notifications/sendPush";
export { onBadgeAwarded } from "./notifications/badgeAward";
export { sendQuestReminders } from "./notifications/reminders";
export { onNewMessage } from "./notifications/newMessage";

// Initialize Firebase Admin SDK
admin.initializeApp();

// Set global options for cost control
setGlobalOptions({ maxInstances: 10 });

// Built lazily (inside the function, not at module load) so it always
// reads MAIL_PASSWORD.value() after Secret Manager has injected it — see
// secrets.ts.
function getTransporter() {
  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: MAIL_SENDER,
      pass: MAIL_PASSWORD.value(),
    },
  });
}

/**
 * Cloud Function: Send email when document is created in 'emails' collection
 */
export const sendEmail = onDocumentCreated(
  {
    document: "emails/{emailId}",
    database: "(default)",
    secrets: [MAIL_PASSWORD],
  },
  async (event) => {
    const emailData = event.data?.data();

    if (!emailData) {
      console.error("No email data found");
      return;
    }

    try {
      const { to, subject, template, data } = emailData;

      // Get email template
      const htmlContent = getEmailTemplate(template, data);

      // Send email
      await getTransporter().sendMail({
        from: `QuestKids <${MAIL_SENDER}>`,
        to: to,
        subject: subject,
        html: htmlContent,
      });

      // Mark email as sent
      await event.data?.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`Email sent to ${to}`);
    } catch (error) {
      console.error("Error sending email:", error);

      // Mark email as failed
      await event.data?.ref.update({
        sent: false,
        error: String(error),
      });
    }
  });

// Cloud Function: Clean up old emails (daily at 2 AM)
export const cleanupOldEmails = onSchedule("every day 02:00", async () => {
  try {
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    const batch = admin.firestore().batch();
    const snapshot = await admin
      .firestore()
      .collection("emails")
      .where("createdAt", "<", thirtyDaysAgo)
      .get();

    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    console.log(`Deleted ${snapshot.docs.length} old email records`);
  } catch (error) {
    console.error("Error cleaning up old emails:", error);
  }
});

/**
 * Get email template by name and data.
 * @param {string} template - Template name.
 * @param {Record<string, string>} data - Template data.
 * @return {string} HTML email content.
 */
function getEmailTemplate(
  template: string,
  data: {[key: string]: string}
): string {
  const templates: {[key: string]: string} = {
    welcome: `
      <h2>Welcome to QuestKids 2.0! 🎮</h2>
      <p>Hi ${data.displayName},</p>
      <p>Your account has been created successfully!</p>
      <p>Let's start your learning adventure today.</p>
      <a href="https://questkids.com/verify/${data.verificationLink}">Verify Email</a>
    `,
    email_verification: `
      <h2>Verify Your Email Address</h2>
      <p>Hi ${data.displayName},</p>
      <p>Please verify your email to complete your registration.</p>
      <a href="https://questkids.com/verify/${data.verificationLink}">Verify Email</a>
      <p>Link expires in 24 hours.</p>
    `,
    password_reset: `
      <h2>Reset Your Password</h2>
      <p>Hi ${data.email},</p>
      <p>Click the link below to reset your password:</p>
      <a href="https://questkids.com/reset/${data.resetLink}">Reset Password</a>
      <p>Link expires in 24 hours.</p>
    `,
    achievement: `
      <h2>You Unlocked an Achievement! 🏆</h2>
      <p>Hi ${data.displayName},</p>
      <p>Congratulations! You earned: <strong>${data.achievement}</strong></p>
      <p>Points earned: ${data.points}</p>
      <p>Keep up the great work!</p>
    `,
    daily_challenge: `
      <h2>New Daily Challenge Available! ⭐</h2>
      <p>Hi ${data.displayName},</p>
      <p>A new challenge is waiting for you today!</p>
      <p>Challenge: ${data.challengeTitle}</p>
      <p>Open the app to start.</p>
    `,
    level_up: `
      <h2>Congratulations! You Leveled Up! 🎉</h2>
      <p>Hi ${data.displayName},</p>
      <p>You've reached <strong>Level ${data.level}</strong></p>
      <p>Keep grinding to unlock more features!</p>
    `,
  };

  return templates[template] || "<p>Email template not found</p>";
}
