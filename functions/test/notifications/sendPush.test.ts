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
      expect.objectContaining({ tokens: ["token-a", "token-b"] })
    );
    const updated = await ref.get();
    expect(updated.data()?.pushSent).toBe(true);
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

  it("marks the notification pushSent:false with an error when FCM throws", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      fcmTokens: ["token-a"],
    });
    mockSendEachForMulticast.mockRejectedValue(new Error("FCM is down"));
    const ref = getFirestore().collection("notifications").doc();
    const data = { recipientUid: "child-1", title: "Hi" };
    await ref.set(data);
    await sendPushOnNotificationCreate.run({
      data: { data: () => data, ref },
      params: { notificationId: ref.id },
    } as never);

    const updated = await ref.get();
    expect(updated.data()?.pushSent).toBe(false);
    expect(updated.data()?.pushError).toContain("FCM is down");
  });
});
