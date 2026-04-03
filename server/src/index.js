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
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
