# QuestKids First Admin Bootstrap

The first QuestKids administrator is provisioned server-side. The admin password is stored only in Firebase Authentication and is never written to Firestore or source control.

## 1. Set the bootstrap secret

From the QuestKids repository root:

```bash
firebase functions:secrets:set QUESTKIDS_ADMIN_BOOTSTRAP_TOKEN
```

Use a new random value of at least 32 characters. Do not commit it or place it in the Flutter app.

## 2. Deploy the bootstrap function

```bash
firebase deploy --only functions:bootstrapAdmin
```

The normal functions predeploy build and lint checks must pass.

## 3. Invoke the bootstrap once

The deployed function is an HTTPS callable named `bootstrapAdmin`. The callable protocol accepts a POST body containing a `data` object.

For the default `us-central1` region and the QuestKids production project:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"data":{"bootstrapToken":"YOUR_BOOTSTRAP_TOKEN"}}' \
  "https://us-central1-questkids-mobile.cloudfunctions.net/bootstrapAdmin"
```

Replace `YOUR_BOOTSTRAP_TOKEN` with the value entered when the Secret Manager secret was created.

A successful response confirms that the fixed QuestKids admin Authentication account received the `admin` custom claim and that `users/{uid}` was created/merged with `role: "admin"`.

## 4. Verify

Sign out of any existing QuestKids session and use the Admin Portal with the administrator's Firebase Authentication credentials.

The login path requires both:

- Firebase Authentication custom claim: `role == "admin"`
- Firestore profile: `users/{uid}.role == "admin"`

The bootstrap function is guarded by Secret Manager and becomes unavailable after the `system/adminBootstrap` completion record is written.

## Security rules

- Never store the admin password in Firestore.
- Never put the admin password or bootstrap token in GitHub.
- Never put the bootstrap token in Flutter client code.
- The bootstrap token is stored in Firebase/Google Cloud Secret Manager and is bound only to the bootstrap function.
