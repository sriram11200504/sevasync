import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
dotenv.config();

import ingestRouter    from './routes/ingest.js';
import requestsRouter  from './routes/requests.js';
import volunteersRouter from './routes/volunteers.js';
import uploadRouter    from './routes/upload.js';

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Health check
app.get('/', (req, res) => res.json({ status: 'SevaSync API running', version: '2.0.0' }));

// Mount routes
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
  console.log(`   POST /api/ingest     — Submit field report`);
  console.log(`   GET  /api/requests   — Fetch all requests`);
  console.log(`   POST /api/requests/:id/allocate — Dispatch volunteer`);
  console.log(`   PUT  /api/requests/:id/status   — Update task status`);
  console.log(`   GET  /api/volunteers — View volunteer pool\n`);
});
