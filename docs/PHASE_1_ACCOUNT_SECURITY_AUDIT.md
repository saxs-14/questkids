# Phase 1 Account Security Audit

Branch: `security/phase-1-account-hardening`
Base: `main` at `6c0de931c5eaa20457e9da32eed83a61f649d96e`

## Findings from the current source

- The public registration screen creates a parent account and can optionally create a child in the same flow. The parent dashboard also contains an authenticated add-child flow. The login screen has child and parent login modes; no standalone child registration screen was found in the auth screens directory.
- Child account creation currently happens in `AuthService.registerWithEmail` (optional child) and `AuthService.createChildForParent` / the parent-child setup screen. Both use a temporary Firebase app to create the child's Auth account and then write/link the child profile. Do not add an Auth blocking function until this client-side child creation is moved server-side, or it would block legitimate parent-created child accounts too.
- Child login uses the callable `loginChild`, which validates name and date of birth and then calls Firebase Admin `createCustomToken`. The previously reported `iam.serviceAccounts.signBlob` 403 is an IAM/runtime configuration issue, not something a repository-only code change can grant. Verify the deployed function runtime service account and grant Token Creator on the exact service account used to sign tokens before redeploying.
- Parent email/password sign-in already maps Firebase invalid credentials to a friendly combined message. Registration form validation was weak: email only checked for emptiness and password required only six characters.
- Email verification is requested after parent signup, but errors are swallowed. There is no complete email-OTP challenge flow visible in the inspected auth service. A `twoFactorEnabled` profile field exists but is not proof that OTP is implemented.
- `bootstrapAdmin` bootstraps the configured email and writes `system/adminBootstrap`; however, `setUserRole` previously allowed an admin to promote another user to admin. The role endpoint now refuses new admin grants to any UID other than the bootstrap-authorized administrator. This does not automatically demote any existing additional admins.

## Changes in this branch

- Add shared registration validators for email format and a 12-character minimum password requiring uppercase, lowercase, number, and symbol.
- Update the parent registration form to use the validators and avoid trimming password input before sending it to Firebase.
- Add unit tests for valid/invalid email and password cases.
- Restrict the general role-management callable from creating additional admin accounts, using the UID recorded by the one-time bootstrap flow.

## Remaining Phase 1 work before deployment

1. Implement and test an OTP challenge with short expiry, single use, attempt limits, resend cooldown, and server-side verification. Prefer OTP for parent verification/recovery or step-up authentication; do not force it on every child's login.
2. Harden email verification error reporting and decide whether unverified parent accounts may access parent data.
3. Move child account creation into a trusted callable before using Firebase Auth blocking rules to prevent direct learner sign-up. Until then, the app has no standalone child sign-up UI, but client-side UI removal alone is not a complete server-side restriction.
4. Audit current Firebase Auth users/custom claims and safely demote any existing extra admins after confirming the intended admin UID. Preserve all account and learning data.
5. Fix and verify the deployed runtime service-account IAM permission for `loginChild`; repository changes alone cannot grant IAM permissions.
6. Run Flutter analyze/tests and Functions build/lint in CI. Do not deploy until those checks pass and the IAM issue is resolved.
