#!/usr/bin/env node
/**
 * One-off: grant the FIRST admin custom claim.
 *
 * functions/src/admin/setUserRole.ts's setUserRole callable requires an
 * existing admin claim to call it -- which means after the teacher role was
 * removed in favour of admin, there is no in-app way to create the very
 * first admin account. This script breaks that chicken-and-egg problem
 * exactly once, using the same gcloud-application-default-credentials
 * pattern as init-firestore-rest.ts (no service account key needed).
 *
 * Usage:
 *   gcloud auth application-default login
 *   npx ts-node bootstrap-admin.ts <email>
 *
 * After this runs, that account can use the setUserRole callable to grant
 * admin to anyone else -- this script should never need to run again.
 */

import axios from 'axios';
import { execSync } from 'child_process';

const PROJECT_ID = 'questkids-mobile';
const DATABASE_ID = '(default)';
const FIRESTORE_BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/${DATABASE_ID}/documents`;
const IDENTITY_BASE_URL = `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}`;

const getAccessToken = (): string => {
  try {
    return execSync('gcloud auth application-default print-access-token', {
      encoding: 'utf-8',
    }).trim();
  } catch {
    throw new Error(
      'Failed to get Google Cloud credentials. Please run:\n' +
        '  gcloud auth application-default login'
    );
  }
};

async function main() {
  const email = process.argv[2];
  if (!email) {
    console.error('Usage: npx ts-node bootstrap-admin.ts <email>');
    process.exit(1);
  }

  const token = getAccessToken();
  const headers = { Authorization: `Bearer ${token}` };

  console.log(`\nLooking up account for ${email}...`);
  const lookup = await axios.post(
    `${IDENTITY_BASE_URL}/accounts:lookup`,
    { email: [email] },
    { headers }
  );
  const user = lookup.data.users?.[0];
  if (!user) {
    console.error(`No Firebase Auth account found for ${email}.`);
    process.exit(1);
  }
  const uid: string = user.localId;
  console.log(`Found uid ${uid}.`);

  const existingClaims = user.customAttributes
    ? JSON.parse(user.customAttributes)
    : {};
  if (existingClaims.role === 'admin') {
    console.log('Account already has the admin claim -- nothing to do.');
    process.exit(0);
  }

  console.log('Setting the admin custom claim...');
  await axios.post(
    `${IDENTITY_BASE_URL}/accounts:update`,
    {
      localId: uid,
      customAttributes: JSON.stringify({ ...existingClaims, role: 'admin' }),
    },
    { headers }
  );

  console.log('Mirroring role=admin onto the Firestore user doc...');
  await axios.patch(
    `${FIRESTORE_BASE_URL}/users/${uid}?updateMask.fieldPaths=role`,
    { fields: { role: { stringValue: 'admin' } } },
    { headers }
  );

  console.log(`\nDone. ${email} (${uid}) is now an admin.`);
  console.log(
    'They must sign out and back in (or wait for their next token refresh) ' +
      'for the new claim to take effect.'
  );
}

main().catch((error) => {
  console.error('\nFailed:', error.response?.data ?? error.message ?? error);
  process.exit(1);
});
