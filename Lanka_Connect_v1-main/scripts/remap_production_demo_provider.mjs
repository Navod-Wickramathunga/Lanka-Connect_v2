import { readFileSync, writeFileSync } from 'fs';
import { homedir } from 'os';
import { join } from 'path';
import { createRequire } from 'module';
import { execSync } from 'child_process';

const PROJECT_ID = 'new-lanka-connect-app';
const BASE_URL = 'https://firestore.googleapis.com/v1';
const FROM_PROVIDER_UID = 'demo_provider';
const TO_PROVIDER_UID = 'DaEEU3TLwwOMdkAanWINCYmxiJn1';
const TO_PROVIDER_NAME = 'Navod Wickramathunga';
const TO_PROVIDER_EMAIL = 'navod.wickramathunga@gmail.com';

const cfgPath = join(homedir(), '.config', 'configstore', 'firebase-tools.json');

async function getFreshToken() {
  const cfg = JSON.parse(readFileSync(cfgPath, 'utf8'));
  try {
    const require = createRequire(import.meta.url);
    const npmRoot = execSync('npm root -g', {
      stdio: ['pipe', 'pipe', 'pipe'],
    }).toString().trim();
    const api = require(join(npmRoot, 'firebase-tools', 'lib', 'api'));
    const refreshToken = cfg.tokens?.refresh_token;
    if (refreshToken) {
      const response = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'refresh_token',
          refresh_token: refreshToken,
          client_id: api.clientId(),
          client_secret: api.clientSecret(),
        }),
      });
      const data = await response.json();
      if (data.access_token) {
        cfg.tokens.access_token = data.access_token;
        writeFileSync(cfgPath, JSON.stringify(cfg, null, 2));
        return data.access_token;
      }
    }
  } catch {
    // Fall back to the cached token below.
  }

  const stored = cfg.tokens?.access_token;
  if (!stored) {
    throw new Error('No Firebase OAuth token found. Run: firebase login');
  }
  return stored;
}

const TOKEN = await getFreshToken();

function headers() {
  return {
    Authorization: `Bearer ${TOKEN}`,
    'Content-Type': 'application/json',
  };
}

function documentUrl(collection, docId) {
  return `${BASE_URL}/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${docId}`;
}

async function listDocuments(collection, pageSize = 500) {
  const url = `${BASE_URL}/projects/${PROJECT_ID}/databases/(default)/documents/${collection}?pageSize=${pageSize}`;
  const response = await fetch(url, { headers: headers() });
  if (!response.ok) {
    throw new Error(`List ${collection} failed: ${response.status} ${await response.text()}`);
  }
  const data = await response.json();
  return data.documents ?? [];
}

async function patchDocument(collection, docId, fields, updateMask) {
  const params = new URLSearchParams();
  for (const field of updateMask) {
    params.append('updateMask.fieldPaths', field);
  }
  const url = `${documentUrl(collection, docId)}?${params.toString()}`;
  const response = await fetch(url, {
    method: 'PATCH',
    headers: headers(),
    body: JSON.stringify({ fields }),
  });
  if (!response.ok) {
    throw new Error(
      `Patch ${collection}/${docId} failed: ${response.status} ${await response.text()}`,
    );
  }
}

function fieldString(fields, key) {
  return fields?.[key]?.stringValue ?? '';
}

function stringValue(value) {
  return { stringValue: String(value) };
}

function timestampNow() {
  return { timestampValue: new Date().toISOString() };
}

async function remapByProviderId(collection) {
  const docs = await listDocuments(collection);
  const matches = docs.filter(
    (doc) => fieldString(doc.fields, 'providerId') === FROM_PROVIDER_UID,
  );

  for (const doc of matches) {
    const docId = doc.name.split('/').pop();
    const fields = {
      providerId: stringValue(TO_PROVIDER_UID),
      updatedAt: timestampNow(),
    };
    const updateMask = ['providerId', 'updatedAt'];

    if (collection === 'services') {
      fields.providerName = stringValue(TO_PROVIDER_NAME);
      fields.providerEmail = stringValue(TO_PROVIDER_EMAIL);
      updateMask.push('providerName', 'providerEmail');
    }

    await patchDocument(collection, docId, fields, updateMask);
    console.log(`Updated ${collection}/${docId}`);
  }

  return matches.length;
}

async function remapNotifications() {
  const docs = await listDocuments('notifications');
  let updated = 0;

  for (const doc of docs) {
    const docId = doc.name.split('/').pop();
    const recipientId = fieldString(doc.fields, 'recipientId');
    const senderId = fieldString(doc.fields, 'senderId');
    const fields = {};
    const updateMask = [];

    if (recipientId === FROM_PROVIDER_UID) {
      fields.recipientId = stringValue(TO_PROVIDER_UID);
      updateMask.push('recipientId');
    }
    if (senderId === FROM_PROVIDER_UID) {
      fields.senderId = stringValue(TO_PROVIDER_UID);
      updateMask.push('senderId');
    }
    if (updateMask.length == 0) {
      continue;
    }

    fields.updatedAt = timestampNow();
    updateMask.push('updatedAt');
    await patchDocument('notifications', docId, fields, updateMask);
    console.log(`Updated notifications/${docId}`);
    updated += 1;
  }

  return updated;
}

async function main() {
  console.log(`Remapping production demo provider in ${PROJECT_ID}`);
  console.log(`From: ${FROM_PROVIDER_UID}`);
  console.log(`To:   ${TO_PROVIDER_UID}`);
  console.log('');

  const results = {};
  for (const collection of ['services', 'requests', 'bookings', 'reviews', 'payments']) {
    results[collection] = await remapByProviderId(collection);
  }
  results.notifications = await remapNotifications();

  console.log('\nDone.');
  for (const [collection, count] of Object.entries(results)) {
    console.log(`${collection}: ${count}`);
  }
}

await main();
