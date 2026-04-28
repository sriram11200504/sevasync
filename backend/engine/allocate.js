import fs from 'fs';
import path from 'path';
import { GoogleGenAI } from '@google/genai';

const DATA_DIR = path.join(process.cwd(), 'data');
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR);
const VOL_FILE = path.join(DATA_DIR, 'volunteers.json');

if (!fs.existsSync(VOL_FILE)) {
  fs.writeFileSync(VOL_FILE, JSON.stringify([
    { id: 'v1', name: 'Dr. Sarah Smith', skills: ['medical', 'general'], location: 'GUNTUR', trust_score: 9.5, available: true, active_task: null, tasks_completed: 12 },
    { id: 'v2', name: 'Ravi Kumar', skills: ['food', 'shelter'], location: 'VIJAYWADA', trust_score: 8.8, available: true, active_task: null, tasks_completed: 5 },
    { id: 'v3', name: 'Alisha P.', skills: ['water', 'food'], location: 'ELURU', trust_score: 9.9, available: true, active_task: null, tasks_completed: 24 },
    { id: 'v4', name: 'John Driver', skills: ['shelter', 'general'], location: 'VIZAG', trust_score: 8.0, available: true, active_task: null, tasks_completed: 3 },
    { id: 'v5', name: 'Priya Mehta', skills: ['medical', 'water'], location: 'KURNOOL', trust_score: 9.2, available: true, active_task: null, tasks_completed: 8 },
  ], null, 2));
}

// Memory-loaded array
export const VOLUNTEERS = JSON.parse(fs.readFileSync(VOL_FILE, 'utf8'));

export function saveVolunteers() {
  fs.writeFileSync(VOL_FILE, JSON.stringify(VOLUNTEERS, null, 2));
}

/**
 * Score a volunteer for a given request.
 * Higher = better match.
 */
function scoreVolunteer(volunteer, request) {
  let score = 0;

  // 1. Skill match — highest priority (+20)
  if (volunteer.skills.includes(request.need_type)) score += 20;
  if (volunteer.skills.includes('general')) score += 5;

  // 2. Urgency multiplier
  const urgencyBoost = { high: 10, medium: 5, low: 2 };
  score += urgencyBoost[request.urgency] || 0;

  // 3. Trust score (normalised to 0-10)
  score += volunteer.trust_score;

  // 4. Availability — hard gate
  if (!volunteer.available) score = -1;

  return score;
}

/**
 * Find the best available volunteer for a request.
 * Returns null if no volunteer qualifies.
 */
export function allocateBestVolunteer(request) {
  let best = null;
  let bestScore = -1;

  for (const vol of VOLUNTEERS) {
    const s = scoreVolunteer(vol, request);
    if (s > bestScore) {
      bestScore = s;
      best = vol;
    }
  }

  if (!best || bestScore <= 0) return null;

  // Mark volunteer as occupied
  const idx = VOLUNTEERS.findIndex(v => v.id === best.id);
  VOLUNTEERS[idx].available = false;
  VOLUNTEERS[idx].active_task = request.id;

  saveVolunteers();

  return best;
}

/**
 * Free up a volunteer when their task completes.
 */
export function freeVolunteer(taskId, success = false) {
  const idx = VOLUNTEERS.findIndex(v => v.active_task === taskId);
  if (idx !== -1) {
    VOLUNTEERS[idx].available = true;
    VOLUNTEERS[idx].active_task = null;

    // Performance impact tracking
    if (success) {
      VOLUNTEERS[idx].tasks_completed = (VOLUNTEERS[idx].tasks_completed || 0) + 1;
      VOLUNTEERS[idx].trust_score = Math.min(10, VOLUNTEERS[idx].trust_score + 0.2); // slight boost for completing
    } else {
      VOLUNTEERS[idx].trust_score = Math.max(0, VOLUNTEERS[idx].trust_score - 0.5); // penalty for decline
    }

    saveVolunteers();
  }
}

/**
 * Advanced AI-Driven Allocation
 * Uses Gemini to reason through the best volunteer match.
 */
export async function allocateWithAI(request) {
  const apiKey = (process.env.GEMINI_API_KEY || '').trim();
  if (!apiKey) return allocateBestVolunteer(request); // Fallback

  const availableVols = VOLUNTEERS.filter(v => v.available);
  if (availableVols.length === 0) return null;

  const ai = new GoogleGenAI({ apiKey });

  const prompt = `You are a Crisis Dispatch Manager. Pick the SINGLE BEST volunteer for this request.
  
REQUEST:
Type: ${request.need_type}
Location: ${request.location}
Urgency: ${request.urgency}
Description: ${request.description}

CANDIDATES:
${availableVols.map(v => `- ID: ${v.id}, Name: ${v.name}, Skills: [${v.skills.join(', ')}], Location: ${v.location}, TrustScore: ${v.trust_score}, ProjectsCompleted: ${v.tasks_completed}`).join('\n')}

RULES:
1. Priority 1: Skill Match. (e.g. if request is "medical", pick a volunteer with "medical" skill).
2. Priority 2: Proximity. (Pick someone in the same location if possible).
3. Priority 3: Reliability. (Higher TrustScore is better).
4. Respond ONLY with the JSON: {"selected_id": "vX", "reasoning": "brief explanation"}
`;

  try {
    const result = await ai.models.generateContent({
      model: 'gemini-1.5-flash',
      contents: prompt,
      config: { responseMimeType: 'application/json' }
    });
    const response = await result.response;
    const text = response.text().trim().replace(/^```json\s*/, '').replace(/```$/, '').trim();
    const parsed = JSON.parse(text);

    const winner = availableVols.find(v => v.id === parsed.selected_id);
    if (winner) {
      const idx = VOLUNTEERS.findIndex(v => v.id === winner.id);
      VOLUNTEERS[idx].available = false;
      VOLUNTEERS[idx].active_task = request.id;
      saveVolunteers();
      console.log(`🤖 AI Selected ${winner.name}: ${parsed.reasoning}`);
      return winner;
    }
  } catch (err) {
    console.error('AI Allocation Failed:', err.message);
  }

  return allocateBestVolunteer(request); // Ultimate fallback
}
