import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';
import { connectDb } from './db.js';
import { authRouter } from './routes/authRoutes.js';
import { topicRoutes } from './routes/topicRoutes.js';
import { paymentRouter, paystackWebhookHandler } from './routes/paymentRoutes.js';
import { ensureUploadsDir } from './middleware/upload.js';
import { runSeed } from './seed.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT) || 5000;
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/medical_students';
const CLIENT_ORIGIN = process.env.CLIENT_ORIGIN || 'http://localhost:5173';
const API_PUBLIC_URL = (process.env.API_PUBLIC_URL || `http://localhost:${PORT}`).replace(/\/$/, '');

async function main() {
  if (!process.env.JWT_SECRET) {
    console.warn('Warning: JWT_SECRET is not set. Using insecure default for development only.');
    process.env.JWT_SECRET = 'dev-only-change-me';
  }

  await connectDb(MONGODB_URI);
  await runSeed();
  ensureUploadsDir();

  const app = express();
  const corsOrigin =
    process.env.CORS_ORIGIN === '*' ? true : process.env.CORS_ORIGIN?.split(',').map((s) => s.trim()) || CLIENT_ORIGIN;
  app.use(
    cors({
      origin: corsOrigin,
      credentials: true,
    })
  );

  app.post('/api/payments/webhook', express.raw({ type: 'application/json' }), paystackWebhookHandler);

  app.use(express.json({ limit: '2mb' }));

  const uploadsPath = path.join(__dirname, '../uploads');
  app.use(
    '/uploads',
    (_req, res, next) => {
      res.setHeader('Access-Control-Allow-Origin', '*');
      next();
    },
    express.static(uploadsPath)
  );

  app.use('/api/auth', authRouter);
  app.use('/api', topicRoutes(API_PUBLIC_URL));
  app.use('/api', paymentRouter(CLIENT_ORIGIN));

  app.get('/api/health', (_req, res) => res.json({ ok: true }));

  app.use((err, _req, res, _next) => {
    if (err?.message === 'Only PDF files are allowed' || err?.message === 'Only audio files are allowed (mp3, wav, m4a, etc.)') {
      return res.status(400).json({ error: err.message });
    }
    if (err?.name === 'MulterError') {
      return res.status(400).json({ error: err.message || 'Upload error' });
    }
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  });

  app.listen(PORT, () => {
    console.log(`API listening on http://localhost:${PORT}`);
    console.log(`Public base URL for files: ${API_PUBLIC_URL}`);
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
