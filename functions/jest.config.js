/** @type {import('jest').Config} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  rootDir: ".",
  testMatch: ["<rootDir>/test/**/*.test.ts"],
  transform: {
    "^.+\\.ts$": ["ts-jest", { tsconfig: "tsconfig.jest.json" }],
    "^.+\\.js$": "babel-jest",
  },
  // `jose` (firebase-admin/auth -> jwks-rsa -> jose) ships ESM-only with
  // no CommonJS build, so it must be the one node_modules package Jest
  // still transforms (via babel.config.js) instead of requiring as-is.
  transformIgnorePatterns: ["node_modules/(?!(jose)/)"],
  // These tests hit a real (local) Firestore emulator and mutate shared
  // collections via clearFirestoreEmulatorData() between tests -- running
  // files in parallel would race on that shared state.
  maxWorkers: 1,
  testTimeout: 20000,
};
