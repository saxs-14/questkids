import { readFileSync } from "fs";
import { join } from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run tests via `npm test`, which " +
      "wraps Jest in `firebase emulators:exec` -- never run this suite " +
      "directly against production Firestore/Storage."
  );
}

export const RULES_TEST_PROJECT_ID = "questkids-mobile";

const REPO_ROOT = join(__dirname, "../../../");

export function createRulesTestEnv(): Promise<RulesTestEnvironment> {
  return initializeTestEnvironment({
    projectId: RULES_TEST_PROJECT_ID,
    firestore: {
      rules: readFileSync(join(REPO_ROOT, "firestore.rules"), "utf8"),
    },
    storage: {
      rules: readFileSync(join(REPO_ROOT, "storage.rules"), "utf8"),
    },
  });
}
