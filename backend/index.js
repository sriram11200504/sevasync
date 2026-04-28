import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { rateLimit } from 'express-rate-limit';
dotenv.config();

import authRouter      from './routes/auth.js';
import ingestRouter    from './routes/ingest.js';
import requestsRouter  from './routes/requests.js';
import volunteersRouter from './routes/volunteers.js';
import uploadRouter    from './routes/upload.js';

const app = express();
const PORT = process.env.PORT || 5000;

// Global rate limiter — 120 requests per minute per IP
app.use(rateLimit({
  windowMs: 60 * 1000,
  max: 120,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Rate limit exceeded. Slow down.' }
}));

app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Health check
app.get('/', (req, res) => res.json({ status: 'SevaSync API running', version: '2.0.0' }));

// Mount routes
app.use('/api/auth',       authRouter);
app.use('/api/ingest',     ingestRouter);
app.use('/api/requests',   requestsRouter);
app.use('/api/volunteers', volunteersRouter);
app.use('/api/upload',     uploadRouter);

// Global error handler
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`\n🚀 SevaSync API v2 running at http://localhost:${PORT}`);
  console.log(`   POST /api/auth/admin/login  — Admin email login`);
  console.log(`   POST /api/ingest            — Submit field report (public)`);
  console.log(`   GET  /api/requests          — Fetch all requests [admin]`);
  console.log(`   POST /api/requests/:id/allocate — Dispatch volunteer [admin]`);
  console.log(`   PUT  /api/requests/:id/status   — Update task status [volunteer]`);
  console.log(`   GET  /api/volunteers        — View volunteer pool [admin]\n`);
});
