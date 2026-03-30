import { readFileSync, writeFileSync } from 'fs';
import { homedir } from 'os';
import { join } from 'path';
import { createRequire } from 'module';
import { execSync } from 'child_process';

const DEFAULT_PROJECT_ID = 'lankaconnect-app';
const DEFAULT_FROM_PROVIDER_UID = 'demo_provider';
const BASE_URL = 'https://firestore.googleapis.com/v1';
const COLLECTIONS = [
  'services',
  'requests',
  'bookings',
  'reviews',
  'payments',
  'providerBankAccounts',
];

function parseArgs(argv) {
  const result = {
    projectId: DEFAULT_PROJECT_ID,
    fromProviderUid: DEFAULT_FROM_PROVIDER_UID,
    toProviderUid: '',
    toProviderName: '',
    toProviderEmail: '',
    dryRun: false,
    listUsers: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--project' && argv[i + 1]) {
      result.projectId = argv[++i];
    } else if (arg.startsWith('--project=')) {
      result.projectId = arg.split('=').slice(1).join('=');
    } else if (arg === '--from-provider-uid' && argv[i + 1]) {
      result.fromProviderUid = argv[++i];
    } else if (arg.startsWith('--from-provider-uid=')) {
      result.fromProviderUid = arg.split('=').slice(1).join('=');
    } else if (arg === '--to-provider-uid' && argv[i + 1]) {
      result.toProviderUid = argv[++i];
    } else if (arg.startsWith('--to-provider-uid=')) {
      result.toProviderUid = arg.split('=').slice(1).join('=');
    } else if (arg === '--to-provider-name' && argv[i + 1]) {
      result.toProviderName = argv[++i];
    } else if (arg.startsWith('--to-provider-name=')) {
      result.toProviderName = arg.split('=').slice(1).join('=');
    } else if (arg === '--to-provider-email' && argv[i + 1]) {
      result.toProviderEmail = argv[++i];
    } else if (arg.startsWith('--to-provider-email=')) {
      result.toProviderEmail = arg.split('=').slice(1).join('=');
    } else if (arg === '--dry-run') {
      result.dryRun = true;
    } else if (arg === '--list-users') {
      result.listUsers = true;
    } else if (arg === '--help' || arg === '-h') {
      printUsage();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (
    !result.listUsers &&
    !result.toProviderUid.trim() &&
    !result.toProviderEmail.trim()
  ) {
    printUsage();
    throw new Error(
      'Missing required argument: --to-provider-uid or --to-provider-email',
    );
  }

  return {
    ...result,
    projectId: result.projectId.trim(),
    fromProviderUid: result.fromProviderUid.trim(),
    toProviderUid: result.toProviderUid.trim(),
    toProviderName: result.toProviderName.trim(),
    toProviderEmail: result.toProviderEmail.trim(),
  };
}

function printUsage() {
  console.log(`
Usage:
  node scripts/remap_staging_demo_provider.mjs --to-provider-uid <uid> [options]

Options:
  --project <projectId>              Firebase project ID. Default: ${DEFAULT_PROJECT_ID}
  --from-provider-uid <uid>          Legacy provider UID to replace. Default: ${DEFAULT_FROM_PROVIDER_UID}
  --to-provider-uid <uid>            Real provider UID to remap data to.
  --to-provider-name <name>          Optional provider display name for services.
  --to-provider-email <email>        Provider email. Can also be used to resolve the UID.
  --dry-run                          Print matches without writing changes.
  --list-users                       Print candidate users from Firestore and exit.
  --help                             Show this help text.
`);
}

const options = parseArgs(process.argv.slice(2));
const cfgPath = join(
  homedir(),
  '.config',
  'configstore',
  'firebase-tools.json',
);

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
  return `${BASE_URL}/projects/${options.projectId}/databases/(default)/documents/${collection}/${docId}`;
}

async function listDocuments(collection, pageSize = 500) {
  const url =
    `${BASE_URL}/projects/${options.projectId}/databases/(default)/documents/` +
    `${collection}?pageSize=${pageSize}`;
  const response = await fetch(url, { headers: headers() });
  if (!response.ok) {
    throw new Error(
      `List ${collection} failed: ${response.status} ${await response.text()}`,
    );
  }
  const data = await response.json();
  return data.documents ?? [];
}

async function findUserUidByEmail(email) {
  const docs = await listDocuments('users');
  const normalizedEmail = email.trim().toLowerCase();
  const match = docs.find(
    (doc) => fieldString(doc.fields, 'email').trim().toLowerCase() === normalizedEmail,
  );
  if (!match) {
    if (normalizedEmail.includes('example.com')) {
      throw new Error(
        `No users document found for email: ${email}. Replace the example placeholder with your real staging provider email.`,
      );
    }
    throw new Error(`No users document found for email: ${email}`);
  }
  return match.name.split('/').pop();
}

function normalizeRole(value) {
  return String(value ?? '').trim().toLowerCase();
}

async function printCandidateUsers() {
  const docs = await listDocuments('users');
  const rows = docs
    .map((doc) => {
      const id = doc.name.split('/').pop();
      const fields = doc.fields ?? {};
      return {
        uid: id,
        role: fieldString(fields, 'role'),
        email: fieldString(fields, 'email'),
        name:
          fieldString(fields, 'displayName') ||
          fieldString(fields, 'name') ||
          '(no name)',
      };
    })
    .filter((row) => ['provider', 'service provider'].includes(normalizeRole(row.role)));

  if (rows.length === 0) {
    console.log('No provider users found in Firestore users collection.');
    return;
  }

  console.log(`Provider users in ${options.projectId}:`);
  for (const row of rows) {
    console.log(
      `- uid=${row.uid} | email=${row.email || '(no email)'} | name=${row.name} | role=${row.role || '(no role)'}`,
    );
  }
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
    (doc) =>
      fieldString(doc.fields, 'providerId') === options.fromProviderUid,
  );

  for (const doc of matches) {
    const docId = doc.name.split('/').pop();
    if (options.dryRun) {
      console.log(`[dry-run] Would update ${collection}/${docId}`);
      continue;
    }

    const fields = {
      providerId: stringValue(options.toProviderUid),
      updatedAt: timestampNow(),
    };
    const updateMask = ['providerId', 'updatedAt'];

    if (collection === 'services') {
      if (options.toProviderName) {
        fields.providerName = stringValue(options.toProviderName);
        updateMask.push('providerName');
      }
      if (options.toProviderEmail) {
        fields.providerEmail = stringValue(options.toProviderEmail);
        updateMask.push('providerEmail');
      }
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

    if (recipientId === options.fromProviderUid) {
      fields.recipientId = stringValue(options.toProviderUid);
      updateMask.push('recipientId');
    }
    if (senderId === options.fromProviderUid) {
      fields.senderId = stringValue(options.toProviderUid);
      updateMask.push('senderId');
    }
    if (updateMask.length === 0) {
      continue;
    }

    if (options.dryRun) {
      console.log(`[dry-run] Would update notifications/${docId}`);
      updated += 1;
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
  if (options.listUsers) {
    await printCandidateUsers();
    return;
  }

  if (!options.toProviderUid) {
    options.toProviderUid = await findUserUidByEmail(options.toProviderEmail);
  }

  console.log(`Remapping staging provider data in ${options.projectId}`);
  console.log(`From: ${options.fromProviderUid}`);
  console.log(`To:   ${options.toProviderUid}`);
  if (options.dryRun) {
    console.log('Mode: dry-run');
  }
  console.log('');

  const results = {};
  for (const collection of COLLECTIONS) {
    results[collection] = await remapByProviderId(collection);
  }
  results.notifications = await remapNotifications();

  console.log('\nDone.');
  for (const [collection, count] of Object.entries(results)) {
    console.log(`${collection}: ${count}`);
  }
}

await main();
