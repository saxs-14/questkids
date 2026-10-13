import "../setup/firebaseAdmin";

jest.mock("firebase-admin/messaging", () => ({
  getMessaging: jest.fn(),
}));

import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { sendPushOnNotificationCreate } from "../../src/notifications/sendPush";

// There is no FCM emulator -- firebase-admin/messaging is mocked so this
// suite can verify the surrounding Firestore logic (token lookup, stale
// token cleanup, status field writes) without making a real FCM call.
const mockSendEachForMulticast = jest.fn();
(getMessaging as jest.Mock).mockReturnValue({
  sendEachForMulticast: mockSendEachForMulticast,
});

async function createdEventForRealDoc(data: Record<string, unknown>) {
  const ref = getFirestore().collection("notifications").doc();
  await ref.set(data);
  return {
    data: { data: () => data, ref },
    params: { notificationId: ref.id },
  } as never;
}

describe("sendPushOnNotificationCreate", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
    mockSendEachForMulticast.mockReset();
    mockSendEachForMulticast.mockResolvedValue({ responses: [] });
  });

  it("skips (and does not call FCM) when the notification has no recipientUid", async () => {
    const event = await createdEventForRealDoc({ title: "Hi", body: "There" });
    await sendPushOnNotificationCreate.run(event);
    expect(mockSendEachForMulticast).not.toHaveBeenCalled();
  });

  it("skips (and does not call FCM) when the recipient has no FCM tokens", async () => {
    await getFirestore().collection("users").doc("child-1").set({ fcmTokens: [] });
    const event = await createdEventForRealDoc({ recipientUid: "child-1", title: "Hi" });
    await sendPushOnNotificationCreate.run(event);
    expect(mockSendEachForMulticast).not.toHaveBeenCalled();
  });

  it("sends to every registered token and marks the notification pushSent", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      fcmTokens: ["token-a", "token-b"],
    });
    mockSendEachForMulticast.mockResolvedValue({
      responses: [{ success: true }, { success: true }],
    });
    const ref = getFirestore().collection("notifications").doc();
    const data = { recipientUid: "child-1", title: "Hi", body: "There", type: "reminder" };
    await ref.set(data);
    await sendPushOnNotificationCreate.run({
      data: { data: () => data, ref },
      params: { notificationId: ref.id },
    } as never);

    expect(mockSendEachForMulticast).toHaveBeenCalledWith(
      expect.objectContaining({
        tokens: ["token-a", "token-b"],
        android: {
          priority: "high",
          notification: {
            channelId: "questkids_notifications",
            sound: "default",
          },
        },
      })
    );
    const updated = await ref.get();
    expect(updated.data()?.pushSent).toBe(true);
  });

  it("supports notifications that use the legacy targetUid field", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      fcmTokens: ["token-a"],
    });
    mockSendEachForMulticast.mockResolvedValue({
      responses: [{ success: true }],
    });
    const event = await createdEventForRealDoc({
      targetUid: "child-1",
      title: "Legacy notification",
      body: "Still delivered",
    });

    await sendPushOnNotificationCreate.run(event);

    expect(mockSendEachForMulticast).toHaveBeenCalledTimes(1);
  });

  it("removes a token FCM reports as no-longer-registered", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      fcmTokens: ["stale-token", "good-token"],
    });
    mockSendEachForMulticast.mockResolvedValue({
      responses: [
        { success: false, error: { code: "messaging/registration-token-not-registered" } },
        { success: true },
      ],
    });
    const ref = getFirestore().collection("notifications").doc();
    const data = { recipientUid: "child-1", title: "Hi" };
    await ref.set(data);
    await sendPushOnNotificationCreate.run({
      data: { data: () => data, ref },
      params: { notificationId: ref.id },
    } as never);

    const user = await getFirestore().collection("users").doc("child-1").get();
    expect(user.data()?.fcmTokens).toEqual(["good-token"]);
  });

  it("records the failure and throws so transient FCM errors are retried", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      fcmTokens: ["token-a"],
    });
    mockSendEachForMulticast.mockRejectedValue(new Error("FCM is down"));
    const ref = getFirestore().collection("notifications").doc();
    const data = { recipientUid: "child-1", title: "Hi" };
    await ref.set(data);
    await expect(sendPushOnNotificationCreate.run({
      data: { data: () => data, ref },
      params: { notificationId: ref.id },
    } as never)).rejects.toThrow("FCM is down");

    const updated = await ref.get();
    expect(updated.data()?.pushSent).toBe(false);
    expect(updated.data()?.pushError).toBe(
      "FCM delivery request failed; an automatic retry is scheduled.",
    );
  });

  it("retries only tokens that did not succeed on the previous attempt", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      fcmTokens: ["token-a", "token-b"],
    });
    mockSendEachForMulticast
      .mockResolvedValueOnce({
        responses: [
          { success: true },
          { success: false, error: { code: "messaging/server-unavailable", message: "retry" } },
        ],
      })
      .mockResolvedValueOnce({ responses: [{ success: true }] });
    const ref = getFirestore().collection("notifications").doc();
    const data = { recipientUid: "child-1", title: "Hi" };
    await ref.set(data);
    const event = {
      data: { data: () => data, ref },
      params: { notificationId: ref.id },
    } as never;

    await expect(sendPushOnNotificationCreate.run(event)).rejects.toThrow(
      "could not deliver",
    );
    await sendPushOnNotificationCreate.run(event);

    expect(mockSendEachForMulticast.mock.calls[0][0].tokens).toEqual([
      "token-a",
      "token-b",
    ]);
    expect(mockSendEachForMulticast.mock.calls[1][0].tokens).toEqual(["token-b"]);
    expect((await ref.get()).data()?.pushSent).toBe(true);
  });
});
