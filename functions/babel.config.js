// Used only by Jest, only to downlevel the ESM-only `jose` package (a
// transitive dependency of firebase-admin/auth -> jwks-rsa -> jose) to
// CommonJS so it can be required from test files. Not used by `tsc`/the
// deployed build -- see tsconfig.jest.json and jest.config.js.
module.exports = {
  presets: [["@babel/preset-env", { targets: { node: "current" } }]],
};
