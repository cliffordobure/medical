import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';
import mongoose from 'mongoose';
import { connectDb } from './db.js';
import { openDownloadStream, BUCKET_PDFS, BUCKET_AUDIO, BUCKET_AD_IMAGES } from './gridfsStorage.js';
import { authRouter } from './routes/authRoutes.js';
import { topicRoutes } from './routes/topicRoutes.js';
import { adRoutes } from './routes/adRoutes.js';
import { adminPackageRoutes } from './routes/adminPackageRoutes.js';
import { paymentRouter, paystackWebhookHandler } from './routes/paymentRoutes.js';
import { ensureUploadsDir } from './middleware/upload.js';
import { runSeed } from './seed.js';
import { configureCloudinary } from './cloudinaryStorage.js';
import { getUploadDriver } from './uploadDriver.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT) || 5000;
/** Bind to all interfaces so Android emulator (10.0.2.2) and phones on LAN can reach the API. */
const LISTEN_HOST = process.env.LISTEN_HOST || '0.0.0.0';
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/medical_students';
const CLIENT_ORIGIN = process.env.CLIENT_ORIGIN || 'http://localhost:5173';
const DEFAULT_API_PUBLIC_URL = 'https://medical-rgb5.onrender.com';
const API_PUBLIC_URL = (process.env.API_PUBLIC_URL || DEFAULT_API_PUBLIC_URL).replace(/\/$/, '');

async function main() {
  if (!process.env.JWT_SECRET) {
    console.warn('Warning: JWT_SECRET is not set. Using insecure default for development only.');
    process.env.JWT_SECRET = 'dev-only-change-me';
  }

  await connectDb(MONGODB_URI);
  await runSeed();
  ensureUploadsDir();

  const uploadDriver = getUploadDriver();
  console.log(`[uploads] UPLOAD_DRIVER=${uploadDriver}`);
  if (uploadDriver === 'cloudinary') {
    configureCloudinary();
    console.log('[uploads] Cloudinary active — new admin uploads use pdfRemoteUrl / audioRemoteUrl in MongoDB.');
  } else if (uploadDriver === 'gridfs') {
    console.log('[uploads] GridFS — pdfFileId / audioFileId in MongoDB.');
  } else {
    console.warn(
      '[uploads] Local disk (default). Cloudinary API keys alone do not enable CDN — set UPLOAD_DRIVER=cloudinary on Render and redeploy.'
    );
  }

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
  const staticFileCors = (req, res, next) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Accept-Ranges');
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    next();
  };
  app.use('/uploads', staticFileCors, express.static(uploadsPath));

  async function streamGridFile(res, bucketName, id, contentType) {
    if (!mongoose.Types.ObjectId.isValid(id)) {
      res.status(400).send('Invalid file id');
      return;
    }
    try {
      const oid = new mongoose.Types.ObjectId(id);
      const filesColl = mongoose.connection.db.collection(`${bucketName}.files`);
      const meta = await filesColl.findOne({ _id: oid });
      if (!meta) {
        res.status(404).send('File not found');
        return;
      }
      if (Number.isFinite(meta.length)) {
        res.setHeader('Content-Length', String(meta.length));
      }
      const stream = openDownloadStream(bucketName, id);
      const ct = meta.contentType || contentType;
      res.setHeader('Content-Type', typeof ct === 'string' && ct ? ct : contentType);
      res.setHeader('Accept-Ranges', 'bytes');
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Accept-Ranges');
      stream.on('error', () => {
        if (!res.headersSent) res.status(404).send('File not found');
      });
      stream.pipe(res);
    } catch {
      if (!res.headersSent) res.status(404).send('File not found');
    }
  }

  app.options('/api/files/pdfs/:id', staticFileCors, (_req, res) => res.sendStatus(204));
  app.options('/api/files/audio/:id', staticFileCors, (_req, res) => res.sendStatus(204));
  app.get('/api/files/pdfs/:id', staticFileCors, (req, res, next) => {
    streamGridFile(res, BUCKET_PDFS, req.params.id, 'application/pdf').catch(next);
  });
  app.get('/api/files/audio/:id', staticFileCors, (req, res, next) => {
    streamGridFile(res, BUCKET_AUDIO, req.params.id, 'application/octet-stream').catch(next);
  });

  app.options('/api/files/ad-images/:id', staticFileCors, (_req, res) => res.sendStatus(204));
  app.get('/api/files/ad-images/:id', staticFileCors, (req, res, next) => {
    streamGridFile(res, BUCKET_AD_IMAGES, req.params.id, 'image/jpeg').catch(next);
  });

  app.use('/api/auth', authRouter);
  app.use('/api', topicRoutes(API_PUBLIC_URL));
  app.use('/api', adRoutes(API_PUBLIC_URL));
  app.use('/api', adminPackageRoutes());
  app.use('/api', paymentRouter(CLIENT_ORIGIN));

  /**
   * Paystack browser redirect after payment (mobile app opens Chrome here).
   * Must be HTTPS + public — never localhost. Override with PAYSTACK_CALLBACK_URL if you host the SPA elsewhere.
   */
  app.get('/payment/return', (req, res) => {
    const refRaw = req.query.reference || req.query.trxref || '';
    const ref = String(refRaw).slice(0, 200);
    const safe = ref.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.setHeader('Cache-Control', 'no-store');
    res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Payment — Medical Audios</title>
  <style>
    * { box-sizing: border-box; }
    body { margin: 0; min-height: 100vh; font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif;
      background: #121212; color: #e8e8e8; display: flex; align-items: center; justify-content: center; padding: 24px; }
    .card { max-width: 420px; width: 100%; background: #1e1e1e; border-radius: 16px; padding: 28px 24px;
      box-shadow: 0 8px 32px rgba(0,0,0,.4); text-align: center; }
    h1 { font-size: 1.35rem; margin: 0 0 12px; color: #fff; }
    p { margin: 0 0 16px; line-height: 1.5; color: #b3b3b3; font-size: 0.95rem; }
    .ok { color: #1db954; font-weight: 700; margin-bottom: 8px; }
    code { display: block; margin-top: 12px; padding: 12px; background: #2a2a2a; border-radius: 10px;
      font-size: 0.8rem; word-break: break-all; color: #ddd; }
    .hint { font-size: 0.85rem; margin-top: 20px; color: #888; }
  </style>
</head>
<body>
  <div class="card">
    <p class="ok">Payment completed</p>
    <h1>Return to Medical Audios</h1>
    <p>You can close this browser tab. Premium usually activates within a minute. If ads are still on, open the app → Premium → paste your reference below.</p>
    ${ref ? `<p style="margin-bottom:8px;font-size:0.8rem;color:#888;">Reference</p><code>${safe}</code>` : '<p>No reference in the URL — check your Paystack email or app.</p>'}
    <p class="hint">This page is served from your API so it works on real phones (not localhost).</p>
  </div>
</body>
</html>`);
  });

  app.get('/api/health', (_req, res) =>
    res.json({
      ok: true,
      /** Present only on current API builds — use to confirm Render deployed latest `server/`. */
      features: { adminAds: true, adminPackages: true },
    })
  );

  app.use((err, _req, res, _next) => {
    if (
      err?.message === 'Only PDF files are allowed' ||
      err?.message === 'Only audio files are allowed (mp3, wav, m4a, etc.)' ||
      err?.message?.startsWith?.('Only image files are allowed')
    ) {
      return res.status(400).json({ error: err.message });
    }
    if (err?.name === 'MulterError') {
      return res.status(400).json({ error: err.message || 'Upload error' });
    }
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  });

  app.listen(PORT, LISTEN_HOST, () => {
    console.log(`API listening on ${LISTEN_HOST}:${PORT}`);
    console.log(`Public base URL for PDF/audio/ad links: ${API_PUBLIC_URL}`);
    console.log(`Paystack redirect (default if PAYSTACK_CALLBACK_URL unset): ${API_PUBLIC_URL}/payment/return`);
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
