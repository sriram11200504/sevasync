import { Router } from 'express';
import multer from 'multer';
import * as XLSX from 'xlsx';
import { GoogleGenAI } from '@google/genai';
import { DB } from '../db/firebase.js';
import dotenv from 'dotenv';
dotenv.config();

const router = Router();

// Store files in memory (no disk writes needed)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB max
});

function getAI() {
  const apiKey = (process.env.GEMINI_API_KEY || '').trim().replace(/^["']|["']$/g, '');
  if (!apiKey || apiKey.length < 10) throw new Error('GEMINI_API_KEY not set');
  return new GoogleGenAI({ apiKey });
}

const GEMINI_SYSTEM_PROMPT = `You are an AI for SevaSync, a humanitarian coordination platform.
Extract this EXACT JSON from the input:
{
  "need_type": "<food|medical|shelter|water|other>",
  "location": "<place name>",
  "people_count": <integer>,
  "urgency": "<low|medium|high>",
  "description": "<one sentence summary>",
  "confidence_score": <0-1>,
  "missing_fields": ["<missing field names>"]
}
Rules: Extract ANY location name. Estimate people_count if missing. Respond ONLY with valid JSON.`;

// ── IMAGE UPLOAD → Gemini Vision ───────────────────────────────────────────
router.post('/image', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No image file uploaded' });

    const source = req.body.source || 'ngo';
    const mimeType = req.file.mimetype;
    const base64Image = req.file.buffer.toString('base64');

    // Geospatial tagging — optional lat/lng from mobile device
    const lat = parseFloat(req.body.lat) || null;
    const lng = parseFloat(req.body.lng) || null;
    const geo = (lat && lng) ? { lat, lng } : null;
    if (geo) console.log(`📍 Geotagged: ${lat}, ${lng}`);

    const ai = getAI();

    console.log(`🖼️  Processing image via Gemini Vision (${req.file.originalname}, ${Math.round(req.file.size/1024)}KB)...`);

    const result = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: [
        {
          parts: [
            {
              text: `Analyze this image. It may be a photo of a crisis scene, a handwritten survey, a printed form, or a document.
${geo ? `IMPORTANT: This photo was taken at GPS coordinates: ${lat}, ${lng}. Use this as the location if no other location is mentioned.` : ''}
${GEMINI_SYSTEM_PROMPT}`
            },
            {
              inlineData: {
                mimeType,
                data: base64Image
              }
            }
          ]
        }
      ]
    });

    const rawText = result.text.trim().replace(/^```json\s*/, '').replace(/```$/, '').trim();
    const parsed = JSON.parse(rawText);
    console.log('✅ Gemini Vision result:', parsed);

    const saved = await DB.addRequest({
      ...parsed,
      need_type: ['food','medical','shelter','water','other'].includes(parsed.need_type) ? parsed.need_type : 'other',
      location: parsed.location || 'Not Specified',
      people_count: Math.max(1, parseInt(parsed.people_count) || 5),
      urgency: ['low','medium','high'].includes(parsed.urgency) ? parsed.urgency : 'medium',
      source,
      status: 'pending',
      input_type: 'image',
      ...(geo ? { coordinates: geo } : {}),
      createdAt: new Date().toISOString()
    });

    res.json({ success: true, data: saved });
  } catch (err) {
    console.error('Image upload error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── EXCEL / CSV UPLOAD ─────────────────────────────────────────────────────
router.post('/excel', upload.single('excel'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' });

    const source = req.body.source || 'ngo';
    const workbook = XLSX.read(req.file.buffer, { type: 'buffer' });
    const sheetName = workbook.SheetNames[0];
    const sheet = workbook.Sheets[sheetName];
    const rows = XLSX.utils.sheet_to_json(sheet, { header: 1 });

    if (rows.length < 2) return res.status(400).json({ error: 'Sheet has no data rows' });

    // Row 0 = headers, rows 1+ = data
    const headers = rows[0].map(h => String(h).toLowerCase().trim());
    const dataRows = rows.slice(1).filter(row => row.some(cell => cell !== null && cell !== ''));

    console.log(`📊 Processing Excel: ${dataRows.length} rows from "${sheetName}"`);

    const ai = getAI();
    const results = [];

    for (const row of dataRows) {
      // Build text representation of this row
      const rowText = headers.map((h, i) => `${h}: ${row[i] ?? ''}`).join(', ');

      try {
        const result = await ai.models.generateContent({
          model: 'gemini-2.5-flash',
          contents: `${GEMINI_SYSTEM_PROMPT}\n\nData row: "${rowText}"`,
          config: { responseMimeType: 'application/json' }
        });
        const rawText = result.text.trim().replace(/^```json\s*/, '').replace(/```$/, '').trim();
        const parsed = JSON.parse(rawText);

        const saved = await DB.addRequest({
          ...parsed,
          need_type: ['food','medical','shelter','water','other'].includes(parsed.need_type) ? parsed.need_type : 'other',
          location: parsed.location || 'Not Specified',
          people_count: Math.max(1, parseInt(parsed.people_count) || 5),
          urgency: ['low','medium','high'].includes(parsed.urgency) ? parsed.urgency : 'medium',
          source,
          status: 'pending',
          input_type: 'excel',
          rawRow: rowText,
          createdAt: new Date().toISOString()
        });
        results.push(saved);
        console.log(`  ✅ Row parsed: ${parsed.need_type} @ ${parsed.location}`);
      } catch (rowErr) {
        console.warn(`  ⚠️  Skipped row (${rowErr.message}): ${rowText.substring(0, 60)}`);
      }
    }

    res.json({ success: true, count: results.length, data: results });
  } catch (err) {
    console.error('Excel upload error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

export default router;
