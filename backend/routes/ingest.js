import { Router } from 'express';
import { GoogleGenAI } from '@google/genai';
import dotenv from 'dotenv';
dotenv.config();

const router = Router();

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
    if (!text || !text.trim()) {
      return res.status(400).json({ error: 'text is required' });
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

        const prompt = `You are an AI assistant for SevaSync, a humanitarian crisis coordination system.
${needsTranslation ? `IMPORTANT: The following text may be in a non-English language${original_language ? ` (${original_language})` : ''}. First translate it to English, then extract the structured data.` : ''}
Analyze the following field report text and extract EXACTLY this JSON structure:
{
  "need_type": "<one of: food, medical, shelter, water, other>",
  "location": "<exact location/city/area name from the text>",
  "people_count": <integer, estimate 5 if not mentioned>,
  "urgency": "<one of: low, medium, high>",
  "description": "<one clear sentence IN ENGLISH summarizing the need>",
  "confidence_score": <float 0.0 to 1.0>,
  "missing_fields": ["<fields not mentioned in text>"]
}

Field report: "${text}"

Rules:
- For location: extract ANY place name (city, village, colony, area, district) even if phrased as "people of X" or "residents of X"
- For urgency: high if words like urgent/emergency/critical/dying/immediately, low if calm/stable
- The description field MUST always be in English regardless of input language
- Respond ONLY with valid JSON. No markdown. No explanation.`;

        const result = await ai.models.generateContent({
          model: 'gemini-2.5-flash',
          contents: prompt,
          config: { responseMimeType: 'application/json' }
        });

        const rawText = result.text.trim().replace(/^```json\s*/, '').replace(/```$/, '').trim();
        parsed = JSON.parse(rawText);
        console.log('✅ Gemini parsed successfully:', JSON.stringify(parsed, null, 2));
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

    const { DB } = await import('../db/firebase.js');
    const saved = await DB.addRequest(sanitized);
    res.json({ success: true, data: saved });
  } catch (err) {
    console.error('Ingest error:', err);
    res.status(500).json({ error: 'Server error during ingestion' });
  }
});

export default router;
