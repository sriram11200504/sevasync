import { Router } from 'express';
import { GoogleGenAI } from '@google/genai';
import { rateLimit } from 'express-rate-limit';
import dotenv from 'dotenv';
dotenv.config();

const router = Router();

// Strict per-route rate limiter for beneficiary submissions: 5 per minute per IP
const ingestLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  message: { error: 'Too many submissions. Please wait a minute before trying again.' },
  standardHeaders: true,
  legacyHeaders: false
});

router.use(ingestLimiter);

// --- Intelligent Fallback Parser (used ONLY if no Gemini key) ---
function fallbackParse(text) {
  const t = text.toLowerCase();

  let need_type = 'other';
  if (t.includes('food') || t.includes('meal') || t.includes('hungry') || t.includes('packet') || t.includes('ration')) need_type = 'food';
  else if (t.includes('medical') || t.includes('doctor') || t.includes('injur') || t.includes('hospital') || t.includes('medic') || t.includes('ambulance') || t.includes('assist') || t.includes('health') || t.includes('treatment')) need_type = 'medical';
  else if (t.includes('shelter') || t.includes('tent') || t.includes('house') || t.includes('roof') || t.includes('accommodation')) need_type = 'shelter';
  else if (t.includes('water') || t.includes('drink') || t.includes('thirst') || t.includes('flood') || t.includes('dehydrat')) need_type = 'water';

  let location = null;
  const p1 = text.match(/\b(?:at|in|near|from|around)\s+([A-Za-z][a-zA-Z\s,\.]+?)(?=\s+(?:urgently|immediately|asap|now|please)|[.!?,]|$)/i);
  if (p1) location = p1[1].trim();

  if (!location) {
    const p2 = text.match(/\b(?:people|residents|families|victims|community|citizens|patients?)\s+(?:of|in|from|at)\s+([A-Za-z][a-zA-Z\s,]+?)(?=\s+(?:urgently|immediately|need|require)|[.!?,]|$)/i);
    if (p2) location = p2[1].trim();
  }

  if (!location) {
    const p3 = text.match(/\bfor\s+(?:people|residents|families|victims|community)\s+(?:of|in|from|at)\s+([A-Za-z][a-zA-Z\s,]+?)(?=\s+(?:urgently|immediately|asap)|[.!?,]|$)/i);
    if (p3) location = p3[1].trim();
  }

  if (!location) {
    const p4 = text.match(/\b(?:assistance|help|aid|support|relief|care)\s+(?:in|at|for|to|near|of)\s+([A-Za-z][a-zA-Z\s,]+?)(?=\s+(?:urgently|immediately|asap)|[.!?,]|$)/i);
    if (p4) location = p4[1].trim();
  }

  if (!location) {
    const stopWords = new Set(['Need', 'Medical', 'Food', 'Water', 'Shelter', 'Help', 'People', 'Urgent', 'Emergency', 'Please', 'They', 'Have', 'This', 'That', 'There', 'These', 'Families', 'Residents', 'Area', 'Zone', 'Immediate', 'Critical', 'Serious', 'Assistance', 'Support', 'Relief']);
    const words = text.replace(/[,!?.]/g, '').split(/\s+/);
    for (const word of words) {
      if (word.length >= 4 && /^[A-Z]/.test(word) && !stopWords.has(word)) {
        location = word;
        break;
      }
    }
  }

  const numMatch = text.match(/\b(\d+)\b/);
  const missing_fields = [];
  if (!location) missing_fields.push('location');
  if (!numMatch) missing_fields.push('people_count');

  return {
    need_type,
    location: location || 'Not Specified',
    people_count: numMatch ? parseInt(numMatch[1]) : 5,
    urgency: (t.includes('urgent') || t.includes('critical') || t.includes('emergency') || t.includes('asap') || t.includes('immediately')) ? 'high' : t.includes('soon') ? 'medium' : 'medium',
    description: text.substring(0, 150),
    confidence_score: location ? 0.65 : 0.4,
    missing_fields
  };
}

// POST /api/ingest
router.post('/', async (req, res) => {
  try {
    const { text, source = 'public', translate, original_language } = req.body;

    // --- Input Validation ---
    if (!text || !text.trim()) {
      return res.status(400).json({ error: 'text is required' });
    }
    if (text.trim().length < 10) {
      return res.status(400).json({ error: 'Report too short. Please provide more details (at least 10 characters).' });
    }
    if (text.trim().length > 5000) {
      return res.status(400).json({ error: 'Report too long (max 5000 characters).' });
    }

    // Detect if translation is needed
    const needsTranslation = translate === true || original_language;
    if (needsTranslation) console.log(`🌐 Multilingual input detected (${original_language || 'auto'})`);

    // Read the key fresh on every request (no caching issue)
    const apiKey = (process.env.GEMINI_API_KEY || '').trim().replace(/^["']|["']$/g, '');
    const useGemini = apiKey.length > 10;

    let parsed;

    if (useGemini) {
      console.log(`\n🤖 GEMINI AI ACTIVE — parsing: "${text.substring(0, 60)}..."`);
      try {
        // Instantiate fresh with current key — avoids module-load timing issue
        const ai = new GoogleGenAI({ apiKey });

        const prompt = `You are a Lead Dispatcher for SevaSync.
${needsTranslation ? `IMPORTANT: The input is in ${original_language || 'a foreign language'}. Translate it to English first.` : ''}
Analyze this report and output ONLY JSON:
{
  "need_type": "<food|medical|shelter|water|other>",
  "location": "<CITY or AREA name only. If no specific place is mentioned, return 'Not Specified'>",
  "people_count": <int, default 5>,
  "urgency": "<low|medium|high>",
  "description": "<One sentence summary of the NEED in English>",
  "confidence_score": <0.0 to 1.0>,
  "missing_fields": []
}

Report Text: "${text}"

STRICT RULES:
1. "location" must NOT contain descriptions of needs. It must only be a proper noun (City, District, Area).
2. If the text says "People of Vijayawada", the location is "Vijayawada".
3. Use high urgency ONLY for medical or life-threatening situations.
4. Respond ONLY with raw JSON.`;

        const result = await ai.models.generateContent({
          model: 'gemini-1.5-flash',
          contents: prompt,
          config: { responseMimeType: 'application/json' }
        });

        const response = await result.response;
        const rawText = response.text().trim().replace(/^```json\s*/, '').replace(/```$/, '').trim();
        parsed = JSON.parse(rawText);
        console.log('✅ Gemini parsed successfully');
      } catch (aiErr) {
        console.error('❌ Gemini call failed:', aiErr.message);
        console.log('↩️  Falling back to regex parser');
        parsed = fallbackParse(text);
      }
    } else {
      console.log(`\n⚙️  FALLBACK PARSER active (no Gemini key found — key length: ${apiKey.length})`);
      parsed = fallbackParse(text);
    }

    // Sanitize outputs
    const sanitized = {
      need_type: ['food', 'medical', 'shelter', 'water', 'other'].includes(parsed.need_type) ? parsed.need_type : 'other',
      location: (parsed.location && parsed.location.trim().length > 0) ? parsed.location.trim() : 'Not Specified',
      people_count: Math.max(1, parseInt(parsed.people_count) || 5),
      urgency: ['low', 'medium', 'high'].includes(parsed.urgency) ? parsed.urgency : 'medium',
      description: parsed.description || text.substring(0, 150),
      confidence_score: Math.min(1, Math.max(0, parseFloat(parsed.confidence_score) || 0.5)),
      missing_fields: Array.isArray(parsed.missing_fields) ? parsed.missing_fields : [],
      source,
      status: 'pending',
      createdAt: new Date().toISOString()
    };

    // Boost confidence based on source trust
    const trustBoost = { ngo: 0.15, volunteer: 0.10, public: 0 };
    sanitized.confidence_score = Math.min(1, sanitized.confidence_score + (trustBoost[source] || 0));

    // --- Duplicate Detection ---
    const { DB } = await import('../db/firebase.js');
    const existing = await DB.getRequests();
    const cutoff = Date.now() - 30 * 60 * 1000; // 30 minutes

    const duplicate = existing.find(r => {
      const sameType = r.need_type === sanitized.need_type;
      const sameLocation = r.location && sanitized.location &&
        r.location.toLowerCase().trim() === sanitized.location.toLowerCase().trim();
      const recent = new Date(r.createdAt).getTime() > cutoff;
      return sameType && sameLocation && recent && r.status !== 'completed';
    });

    if (duplicate) {
      // Merge: increment people count on the existing request instead of creating a new one
      const mergedCount = (duplicate.people_count || 0) + sanitized.people_count;
      await DB.updateRequest(duplicate.id, {
        people_count: mergedCount,
        updatedAt: new Date().toISOString()
      });
      const updated = await DB.getRequest(duplicate.id);
      console.log(`🔀 Duplicate merged into ${duplicate.id} — people_count now ${mergedCount}`);
      return res.json({ success: true, merged: true, data: updated });
    }

    const saved = await DB.addRequest(sanitized);
    res.json({ success: true, data: saved });
  } catch (err) {
    console.error('Ingest error:', err);
    res.status(500).json({ error: 'Server error during ingestion' });
  }
});

export default router;
