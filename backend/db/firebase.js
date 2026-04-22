import admin from 'firebase-admin';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';
dotenv.config();

// --- Local JSON File Store Fallback ---
const DATA_DIR = path.join(process.cwd(), 'data');
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR);

const REQ_FILE = path.join(DATA_DIR, 'requests.json');

// Initialize with seeds if empty
if (!fs.existsSync(REQ_FILE)) {
  fs.writeFileSync(REQ_FILE, JSON.stringify([
    {
      id: 'seed-001',
      need_type: 'medical',
      location: 'Gandhi Road, Block C',
      people_count: 8,
      urgency: 'high',
      description: 'Several injured after building collapse. Need doctor immediately.',
      status: 'pending',
      source: 'ngo',
      confidence_score: 0.9,
      missing_fields: [],
      createdAt: new Date(Date.now() - 7200000).toISOString()
    },
    {
      id: 'seed-002',
      need_type: 'food',
      location: 'Relief Camp, Sector 14',
      people_count: 120,
      urgency: 'high',
      description: '120 flood-affected families without food since yesterday.',
      status: 'pending',
      source: 'public',
      confidence_score: 0.8,
      missing_fields: [],
      createdAt: new Date(Date.now() - 3600000).toISOString()
    },
    {
      id: 'seed-003',
      need_type: 'water',
      location: 'Riverside Colony',
      people_count: 45,
      urgency: 'medium',
      description: 'Clean drinking water needed. Supply has been contaminated.',
      status: 'allocated',
      assignedVolunteer: 'Alisha P.',
      source: 'volunteer',
      confidence_score: 0.85,
      missing_fields: [],
      createdAt: new Date(Date.now() - 1800000).toISOString()
    }
  ], null, 2));
}

export const localDb = {
  get requests() { return JSON.parse(fs.readFileSync(REQ_FILE, 'utf8')); },
  save(data) { fs.writeFileSync(REQ_FILE, JSON.stringify(data, null, 2)); }
};

// --- Firebase Init ---
let db = null;

try {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (raw && raw.trim().length > 10) {
    const serviceAccount = JSON.parse(raw);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    db = admin.firestore();
    console.log('✅ Firebase Firestore connected.');
  } else {
    console.warn('⚠️  No Firebase credentials. Running with in-memory store.');
  }
} catch (e) {
  console.warn('⚠️  Firebase init failed:', e.message, '— using in-memory store.');
}

// --- Unified DB Adapter ---
export const DB = {
  async getRequests() {
    if (db) {
      const snap = await db.collection('requests').orderBy('createdAt', 'desc').get();
      return snap.docs.map(d => ({ id: d.id, ...d.data() }));
    }
    return [...localDb.requests];
  },

  async addRequest(payload) {
    if (db) {
      const ref = await db.collection('requests').add(payload);
      return { id: ref.id, ...payload };
    }
    const reqs = localDb.requests;
    const record = { id: `req-${Date.now()}`, ...payload };
    reqs.unshift(record);
    localDb.save(reqs);
    return record;
  },

  async updateRequest(id, updates) {
    if (db) {
      await db.collection('requests').doc(id).update(updates);
      return true;
    }
    const reqs = localDb.requests;
    const idx = reqs.findIndex(r => r.id === id);
    if (idx === -1) return false;
    Object.assign(reqs[idx], updates);
    localDb.save(reqs);
    return true;
  },

  async getRequest(id) {
    if (db) {
      const doc = await db.collection('requests').doc(id).get();
      return doc.exists ? { id: doc.id, ...doc.data() } : null;
    }
    return localDb.requests.find(r => r.id === id) || null;
  }
};
