import "../setup/firebaseAdmin";
import { assignDefaultRole } from "../../src/admin/setUserRole";

/**
 * assignDefaultRole is exported as a firebase-functions v2 `BlockingFunction`,
 * whose public TypeScript type has no `.run()` -- but the compiled runtime
 * (firebase-functions/lib/v2/providers/identity.js, `beforeOperation()`)
 * attaches `func.run = handler` exactly like every other v2 trigger type.
 * Verified directly against the compiled lib/ output before relying on it:
 * `require("../../lib/admin/setUserRole.js").assignDefaultRole.run({})`
 * really does invoke the raw handler at runtime. The cast below exists only
 * because the public .d.ts doesn't declare `.run` on `BlockingFunction` --
 * not because the call itself doesn't work.
 */
function runAssignDefaultRole(): unknown {
  return (assignDefaultRole as unknown as { run: (event: unknown) => unknown }).run(
    {}
  );
}

describe("assignDefaultRole", () => {
  it("grants every newly-created Auth user the learner role by default", () => {
    const result = runAssignDefaultRole();
    expect(result).toEqual({ customClaims: { role: "learner" } });
  });

  it("ignores its event argument entirely (same result regardless of signup details)", () => {
    const fakeEvent = {
      data: { email: "someone@example.com", uid: "whoever" },
    };
    const result = (assignDefaultRole as unknown as { run: (event: unknown) => unknown }).run(
      fakeEvent
    );
    expect(result).toEqual({ customClaims: { role: "learner" } });
  });
});
