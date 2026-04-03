import { Router } from 'express';
import { AdCreative } from '../models/AdCreative.js';
import { authRequired, loadUser, adminOnly } from '../middleware/auth.js';
import { uploadAdImage, uploadAdImageMemory } from '../middleware/upload.js';
import {
  uploadBufferToGridFS,
  deleteGridFile,
  BUCKET_AD_IMAGES,
} from '../gridfsStorage.js';
import { uploadImageBuffer, destroyCloudinaryAsset } from '../cloudinaryStorage.js';
import { useCloudinary, useGridfs } from '../uploadDriver.js';

const adUpload = () => (useCloudinary() || useGridfs() ? uploadAdImageMemory : uploadAdImage);

async function wipeImage(ad) {
  if (ad.imageFileId) await deleteGridFile(BUCKET_AD_IMAGES, ad.imageFileId);
  if (ad.imageRemotePublicId) await destroyCloudinaryAsset(ad.imageRemotePublicId, 'image');
}

function clearImageFields(ad) {
  ad.imageFilename = null;
  ad.imageFileId = null;
  ad.imageRemoteUrl = null;
  ad.imageRemotePublicId = null;
}

export function adRoutes(baseUrl) {
  const router = Router();

  router.get('/ads/interstitial', async (_req, res, next) => {
    try {
      const list = await AdCreative.find({ active: true }).sort({ sortOrder: 1 });
      if (list.length === 0) return res.json({ ad: null });
      const pick = list[Math.floor(Math.random() * list.length)];
      const j = pick.toClientJSON(baseUrl);
      res.json({
        ad: {
          imageUrl: j.imageUrl,
          title: j.title,
        },
      });
    } catch (e) {
      next(e);
    }
  });

  const admin = Router();
  admin.use(authRequired, loadUser, adminOnly);

  admin.get('/admin/ads', async (_req, res, next) => {
    try {
      const ads = await AdCreative.find().sort({ sortOrder: 1, createdAt: -1 });
      res.json({ ads: ads.map((a) => a.toClientJSON(baseUrl)) });
    } catch (e) {
      next(e);
    }
  });

  admin.post('/admin/ads', adUpload(), async (req, res, next) => {
    try {
      const file = req.file;
      if (!file) return res.status(400).json({ error: 'Image file is required' });
      const { title, sortOrder, active } = req.body || {};

      let imageFilename = null;
      let imageFileId = null;
      let imageRemoteUrl = null;
      let imageRemotePublicId = null;

      if (useCloudinary()) {
        const up = await uploadImageBuffer(file.buffer, file.originalname);
        imageRemoteUrl = up.secureUrl;
        imageRemotePublicId = up.publicId;
      } else if (useGridfs()) {
        imageFileId = await uploadBufferToGridFS(
          BUCKET_AD_IMAGES,
          file.buffer,
          file.originalname,
          file.mimetype || 'image/jpeg'
        );
      } else {
        imageFilename = file.filename;
      }

      const ad = await AdCreative.create({
        title: String(title || '').trim(),
        sortOrder: sortOrder != null ? Number(sortOrder) : 0,
        active: active === 'true' || active === true || active === undefined,
        imageFilename,
        imageFileId,
        imageRemoteUrl,
        imageRemotePublicId,
      });
      res.status(201).json({ ad: ad.toClientJSON(baseUrl) });
    } catch (e) {
      next(e);
    }
  });

  admin.patch('/admin/ads/:id', async (req, res, next) => {
    try {
      const ad = await AdCreative.findById(req.params.id);
      if (!ad) return res.status(404).json({ error: 'Ad not found' });
      const { title, sortOrder, active } = req.body || {};
      if (title != null) ad.title = String(title).trim();
      if (sortOrder != null) ad.sortOrder = Number(sortOrder);
      if (active != null) ad.active = active !== false && active !== 'false';
      await ad.save();
      res.json({ ad: ad.toClientJSON(baseUrl) });
    } catch (e) {
      next(e);
    }
  });

  admin.post('/admin/ads/:id/image', adUpload(), async (req, res, next) => {
    try {
      const ad = await AdCreative.findById(req.params.id);
      if (!ad) return res.status(404).json({ error: 'Ad not found' });
      const file = req.file;
      if (!file) return res.status(400).json({ error: 'Image file is required' });
      await wipeImage(ad);
      clearImageFields(ad);
      if (useCloudinary()) {
        const up = await uploadImageBuffer(file.buffer, file.originalname);
        ad.imageRemoteUrl = up.secureUrl;
        ad.imageRemotePublicId = up.publicId;
      } else if (useGridfs()) {
        ad.imageFileId = await uploadBufferToGridFS(
          BUCKET_AD_IMAGES,
          file.buffer,
          file.originalname,
          file.mimetype || 'image/jpeg'
        );
      } else {
        ad.imageFilename = file.filename;
      }
      await ad.save();
      res.json({ ad: ad.toClientJSON(baseUrl) });
    } catch (e) {
      next(e);
    }
  });

  admin.delete('/admin/ads/:id', async (req, res, next) => {
    try {
      const ad = await AdCreative.findById(req.params.id);
      if (!ad) return res.status(404).json({ error: 'Ad not found' });
      await wipeImage(ad);
      await ad.deleteOne();
      res.status(204).send();
    } catch (e) {
      next(e);
    }
  });

  router.use(admin);
  return router;
}
