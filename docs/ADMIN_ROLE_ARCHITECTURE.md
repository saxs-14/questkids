# QuestKids Role Architecture

## Roles

QuestKids has three roles:
- Child (learner) — the primary learner and game player.
- Parent (parent) — the child's trusted adult account and family dashboard.
- Admin (admin) — a protected platform-management account.

Teacher accounts are no longer part of the product model.

## Admin responsibilities

Admins manage the platform rather than teaching classes. The admin portal provides:
1. Platform overview — users, parents, children, admins, activities and AI reports.
2. User management — list users, change roles through a protected callable, and disable/enable accounts.
3. Content management — manage approved activities and CAPS curriculum data.
4. Child safety and AI moderation — review AI reports and resolve reports.
5. Gamification operations — monitor missions, rewards and leaderboards.
6. System operations — monitor account health and application-level configuration.

## Admin authentication

There is no public admin registration.

Admins enter through the dedicated Admin Portal. The Flutter client performs normal Firebase email/password authentication and then loginAdmin verifies the Firebase ID-token custom claim role=admin. The Firestore role field is not trusted for authorization.

The first admin must be bootstrapped using scripts/bootstrap-admin.ts. After that, an existing admin can provision another admin using the protected setUserRole callable.

The dedicated portal is a product boundary, not a security boundary by itself. The security boundary is the server-issued Firebase custom claim plus Firestore and Cloud Function authorization.
