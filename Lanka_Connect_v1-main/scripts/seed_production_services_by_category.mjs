import { readFileSync, writeFileSync } from 'fs';
import { homedir } from 'os';
import { join } from 'path';
import { createRequire } from 'module';
import { execSync } from 'child_process';

const PROD = 'new-lanka-connect-app';
const BASE = 'https://firestore.googleapis.com/v1';
const PROVIDER_UID = 'demo_provider';

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
    console.error('No Firebase OAuth token found. Run: firebase login');
    process.exit(1);
  }
  return stored;
}

const TOKEN = await getFreshToken();

const headers = () => ({
  Authorization: `Bearer ${TOKEN}`,
  'Content-Type': 'application/json',
});

async function patch(collection, docId, fields) {
  const url = `${BASE}/projects/${PROD}/databases/(default)/documents/${collection}/${docId}`;
  const response = await fetch(url, {
    method: 'PATCH',
    headers: headers(),
    body: JSON.stringify({ fields }),
  });
  if (!response.ok) {
    throw new Error(
      `PATCH ${collection}/${docId} -> ${response.status} ${await response.text()}`,
    );
  }
}

const s = (value) => ({ stringValue: String(value) });
const n = (value) => ({ doubleValue: Number(value) });
const i = (value) => ({ integerValue: String(Math.round(value)) });
const b = (value) => ({ booleanValue: Boolean(value) });
const arr = (values) => ({ arrayValue: { values } });
const now = () => ({ timestampValue: new Date().toISOString() });
const ts = (value) => ({ timestampValue: new Date(value).toISOString() });

const providerDoc = {
  role: s('provider'),
  name: s('Kasun Perera'),
  email: s('kasun.perera@lankaconnect.app'),
  contact: s('+94771234567'),
  district: s('Colombo'),
  city: s('Maharagama'),
  bio: s('Production demo provider for seeker/service catalogue testing.'),
  skills: arr([
    s('Cleaning'),
    s('Plumbing'),
    s('Electrical'),
    s('Carpentry'),
    s('Painting'),
    s('Gardening'),
    s('Moving'),
    s('Beauty'),
    s('Tutoring'),
  ]),
  averageRating: n(4.8),
  reviewCount: i(26),
  imageUrl: s(''),
  createdAt: ts('2024-01-15'),
  updatedAt: now(),
};

const categoryConfigs = [
  {
    key: 'cleaning',
    category: 'Cleaning',
    titles: [
      'Home Deep Cleaning',
      'Move-Out Cleaning Team',
      'Office Cleaning Service',
      'Apartment Weekly Cleaning',
      'Post-Renovation Cleaning',
    ],
    district: 'Colombo',
    city: 'Nugegoda',
    lat: 6.865,
    lng: 79.9,
    basePrice: 3200,
  },
  {
    key: 'plumbing',
    category: 'Plumbing',
    titles: [
      'Quick Plumbing Fix',
      'Bathroom Pipe Repair',
      'Kitchen Leak Repair',
      'Water Tank Plumbing Check',
      'Tap and Shower Replacement',
    ],
    district: 'Gampaha',
    city: 'Kadawatha',
    lat: 7.001,
    lng: 79.964,
    basePrice: 2400,
  },
  {
    key: 'electrical',
    category: 'Electrical',
    titles: [
      'Home Electrical Work',
      'Wiring and Socket Repairs',
      'Fan Installation Service',
      'Breaker Panel Safety Check',
      'Lighting Installation Service',
    ],
    district: 'Kandy',
    city: 'Kandy',
    lat: 7.291,
    lng: 80.634,
    basePrice: 2800,
  },
  {
    key: 'carpentry',
    category: 'Carpentry',
    titles: [
      'Carpenter and Woodwork',
      'Custom Cupboard Repair',
      'Door and Window Fitting',
      'Furniture Assembly Service',
      'Wooden Shelf Installation',
    ],
    district: 'Colombo',
    city: 'Colombo 07',
    lat: 6.914,
    lng: 79.861,
    basePrice: 2600,
  },
  {
    key: 'painting',
    category: 'Painting',
    titles: [
      'Interior Wall Painting',
      'Exterior House Painting',
      'Office Accent Painting',
      'Room Repaint Service',
      'Weather Shield Painting',
    ],
    district: 'Galle',
    city: 'Galle',
    lat: 6.053,
    lng: 80.221,
    basePrice: 4200,
  },
  {
    key: 'gardening',
    category: 'Gardening',
    titles: [
      'Garden Cleanup Service',
      'Lawn Trimming and Care',
      'Home Plant Maintenance',
      'Landscape Refresh Service',
      'Hedge and Tree Trimming',
    ],
    district: 'Kalutara',
    city: 'Panadura',
    lat: 6.713,
    lng: 79.907,
    basePrice: 2300,
  },
  {
    key: 'moving',
    category: 'Moving',
    titles: [
      'House Moving Team',
      'Furniture Moving Van',
      'Apartment Relocation Help',
      'Office Item Transport',
      'Packing and Moving Service',
    ],
    district: 'Colombo',
    city: 'Maharagama',
    lat: 6.849,
    lng: 79.926,
    basePrice: 5000,
  },
  {
    key: 'beauty',
    category: 'Beauty',
    titles: [
      'Bridal Makeup Session',
      'Home Salon Beauty Care',
      'Party Makeup Artist',
      'Hair Styling at Home',
      'Facial and Glow Care',
    ],
    district: 'Colombo',
    city: 'Dehiwala',
    lat: 6.852,
    lng: 79.875,
    basePrice: 3500,
  },
  {
    key: 'tutoring',
    category: 'Tutoring',
    titles: [
      'Math Tutoring O/L',
      'Advanced Math Home Tutoring',
      'Science Home Tutoring',
      'English Exam Preparation',
      'Primary Grade Learning Support',
    ],
    district: 'Colombo',
    city: 'Rajagiriya',
    lat: 6.906,
    lng: 79.895,
    basePrice: 1800,
  },
];

function serviceDoc(config, index) {
  const title = config.titles[index];
  const price = config.basePrice + index * 250;
  const createdAt = new Date(Date.UTC(2025, 0, 1 + index)).toISOString();
  return {
    providerId: s(PROVIDER_UID),
    title: s(title),
    category: s(config.category),
    description: s(
      `${title} in ${config.city}. Production demo service for seeker catalogue and category testing.`,
    ),
    price: n(price),
    district: s(config.district),
    city: s(config.city),
    location: s(`${config.city}, ${config.district}`),
    lat: n(config.lat + index * 0.002),
    lng: n(config.lng + index * 0.002),
    status: s('approved'),
    averageRating: n(4.2 + (index % 3) * 0.2),
    reviewCount: i(6 + index * 3),
    imageUrls: arr([]),
    createdAt: ts(createdAt),
    updatedAt: now(),
    providerName: s('Kasun Perera'),
    providerEmail: s('kasun.perera@lankaconnect.app'),
    featured: b(index === 0),
  };
}

async function main() {
  console.log('Seeding production services: 5 per category');
  console.log(`Project: ${PROD}\n`);

  await patch('users', PROVIDER_UID, providerDoc);
  console.log(`Seeded provider doc: ${PROVIDER_UID}`);

  let total = 0;
  for (const config of categoryConfigs) {
    for (let index = 0; index < 5; index += 1) {
      const docId = `prod_demo_${config.key}_${String(index + 1).padStart(2, '0')}`;
      await patch('services', docId, serviceDoc(config, index));
      total += 1;
      console.log(`  ✓ ${docId} (${config.category})`);
    }
  }

  console.log(`\nDone. Seeded ${total} approved services across 9 categories.`);
}

await main();
