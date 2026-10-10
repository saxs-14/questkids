import "./setup/firebaseAdmin";

const mockSendMail = jest.fn();

// There is no SMTP emulator -- nodemailer is mocked so this suite can
// verify the real logic (template selection, HTML-escaping of untrusted
// Firestore data, and the sent/error status fields) without sending a
// real email through the app's own Gmail identity.
jest.mock("nodemailer", () => ({
  createTransport: jest.fn().mockImplementation(() => ({
    sendMail: mockSendMail,
  })),
}));

process.env.MAIL_PASSWORD = "test-mail-password-not-real";

import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "./setup/firestoreEmulator";
import { sendEmail, cleanupOldEmails } from "../src/index";

function createdEventForRealDoc(data: Record<string, unknown>) {
  return async () => {
    const ref = getFirestore().collection("emails").doc();
    await ref.set(data);
    return {
      event: { data: { data: () => data, ref }, params: { emailId: ref.id } } as never,
      ref,
    };
  };
}

describe("sendEmail", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
    mockSendMail.mockReset();
    mockSendMail.mockResolvedValue({ messageId: "fake-id" });
  });

  it("does nothing when the document has no data", async () => {
    await sendEmail.run({ data: undefined, params: { emailId: "x" } } as never);
    expect(mockSendMail).not.toHaveBeenCalled();
  });

  it("sends a known template and marks the email sent", async () => {
    const { event, ref } = await createdEventForRealDoc({
      to: "parent@example.com",
      subject: "Welcome!",
      template: "welcome",
      data: { displayName: "Thandi", verificationLink: "abc123" },
    })();
    await sendEmail.run(event);

    expect(mockSendMail).toHaveBeenCalledTimes(1);
    const call = mockSendMail.mock.calls[0][0] as { to: string; html: string };
    expect(call.to).toBe("parent@example.com");
    expect(call.html).toContain("Thandi");

    const updated = await ref.get();
    expect(updated.data()?.sent).toBe(true);
  });

  it("HTML-escapes untrusted template data to prevent injection into the email body", async () => {
    const { event } = await createdEventForRealDoc({
      to: "parent@example.com",
      subject: "Welcome!",
      template: "welcome",
      data: { displayName: '<script>alert(1)</script>', verificationLink: "abc" },
    })();
    await sendEmail.run(event);

    const call = mockSendMail.mock.calls[0][0] as { html: string };
    expect(call.html).not.toContain("<script>");
    expect(call.html).toContain("&lt;script&gt;");
  });

  it("falls back to a not-found message for an unknown template", async () => {
    const { event } = await createdEventForRealDoc({
      to: "parent@example.com",
      subject: "Hi",
      template: "does_not_exist",
      data: {},
    })();
    await sendEmail.run(event);
    const call = mockSendMail.mock.calls[0][0] as { html: string };
    expect(call.html).toContain("Email template not found");
  });

  it("marks the email sent:false with the error when sendMail throws", async () => {
    mockSendMail.mockRejectedValue(new Error("SMTP is down"));
    const { event, ref } = await createdEventForRealDoc({
      to: "parent@example.com",
      subject: "Welcome!",
      template: "welcome",
      data: { displayName: "Thandi" },
    })();
    await sendEmail.run(event);

    const updated = await ref.get();
    expect(updated.data()?.sent).toBe(false);
    expect(updated.data()?.error).toContain("SMTP is down");
  });
});

describe("cleanupOldEmails", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("deletes only emails older than 30 days", async () => {
    const db = getFirestore();
    const now = Date.now();
    await db.collection("emails").doc("old").set({
      createdAt: Timestamp.fromMillis(now - 31 * 24 * 60 * 60 * 1000),
    });
    await db.collection("emails").doc("recent").set({
      createdAt: Timestamp.fromMillis(now - 1 * 24 * 60 * 60 * 1000),
    });

    await cleanupOldEmails.run({} as never);

    const old = await db.collection("emails").doc("old").get();
    const recent = await db.collection("emails").doc("recent").get();
    expect(old.exists).toBe(false);
    expect(recent.exists).toBe(true);
  });

  it("does nothing (no crash) when there are no old emails", async () => {
    await expect(cleanupOldEmails.run({} as never)).resolves.toBeUndefined();
  });
});
