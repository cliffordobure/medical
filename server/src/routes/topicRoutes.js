import { Router } from 'express';
import { slugify } from '../utils/slugify.js';
import { Topic } from '../models/Topic.js';
import { authRequired, loadUser, adminOnly } from '../middleware/auth.js';
import { uploadTopicFiles, uploadTopicFilesMemory } from '../middleware/upload.js';
import {
  uploadBufferToGridFS,
  deleteGridFile,
  BUCKET_PDFS,
  BUCKET_AUDIO,
} from '../gridfsStorage.js';
import {
  uploadPdfBuffer,
  uploadAudioBuffer,
  destroyCloudinaryAsset,
} from '../cloudinaryStorage.js';
import { useCloudinary, useGridfs } from '../uploadDriver.js';

const topicUpload = () =>
  useCloudinary() || useGridfs() ? uploadTopicFilesMemory : uploadTopicFiles;

async function wipePdf(topic) {
  if (topic.pdfFileId) await deleteGridFile(BUCKET_PDFS, topic.pdfFileId);
  if (topic.pdfRemotePublicId) await destroyCloudinaryAsset(topic.pdfRemotePublicId, 'raw');
}

async function wipeAudio(topic) {
  if (topic.audioFileId) await deleteGridFile(BUCKET_AUDIO, topic.audioFileId);
  if (topic.audioRemotePublicId) {
    await destroyCloudinaryAsset(
      topic.audioRemotePublicId,
      topic.audioRemoteResourceType === 'raw' ? 'raw' : 'video'
    );
  }
}

function clearPdfFields(topic) {
  topic.pdfFilename = null;
  topic.pdfFileId = null;
  topic.pdfRemoteUrl = null;
  topic.pdfRemotePublicId = null;
}

function clearAudioFields(topic) {
  topic.audioFilename = null;
  topic.audioFileId = null;
  topic.audioRemoteUrl = null;
  topic.audioRemotePublicId = null;
  topic.audioRemoteResourceType = null;
}

export function topicRoutes(baseUrl) {
  const router = Router();

  router.get('/topics', async (_req, res, next) => {
    try {
      const topics = await Topic.find({ isPublished: true }).sort({ sortOrder: 1, title: 1 });
      res.json({ topics: topics.map((t) => t.toListJSON(baseUrl)) });
    } catch (e) {
      next(e);
    }
  });

  router.get('/topics/:slug', async (req, res, next) => {
    try {
      const topic = await Topic.findOne({ slug: req.params.slug, isPublished: true });
      if (!topic) return res.status(404).json({ error: 'Topic not found' });
      res.json({ topic: topic.toDetailJSON(baseUrl) });
    } catch (e) {
      next(e);
    }
  });

  const admin = Router();
  admin.use(authRequired, loadUser, adminOnly);

  admin.get('/admin/topics', async (_req, res, next) => {
    try {
      const topics = await Topic.find().sort({ sortOrder: 1, title: 1 });
      res.json({ topics: topics.map((t) => t.toDetailJSON(baseUrl)) });
    } catch (e) {
      next(e);
    }
  });

  admin.post('/admin/topics', topicUpload(), async (req, res, next) => {
    try {
      const { title, description, isPublished, sortOrder } = req.body || {};
      if (!title) return res.status(400).json({ error: 'Title is required' });
      const files = req.files || {};
      const pdfFile = files.pdf?.[0];
      if (!pdfFile) return res.status(400).json({ error: 'PDF file is required' });
      const audioFile = files.audio?.[0];

      let pdfFilename = null;
      let pdfFileId = null;
      let pdfRemoteUrl = null;
      let pdfRemotePublicId = null;
      let audioFilename = null;
      let audioFileId = null;
      let audioRemoteUrl = null;
      let audioRemotePublicId = null;
      let audioRemoteResourceType = null;

      if (useCloudinary()) {
        const pdfUp = await uploadPdfBuffer(pdfFile.buffer, pdfFile.originalname);
        pdfRemoteUrl = pdfUp.secureUrl;
        pdfRemotePublicId = pdfUp.publicId;
        if (audioFile) {
          const aUp = await uploadAudioBuffer(audioFile.buffer, audioFile.originalname);
          audioRemoteUrl = aUp.secureUrl;
          audioRemotePublicId = aUp.publicId;
          audioRemoteResourceType = aUp.resourceType;
        }
      } else if (useGridfs()) {
        pdfFileId = await uploadBufferToGridFS(
          BUCKET_PDFS,
          pdfFile.buffer,
          pdfFile.originalname,
          pdfFile.mimetype || 'application/pdf'
        );
        if (audioFile) {
          audioFileId = await uploadBufferToGridFS(
            BUCKET_AUDIO,
            audioFile.buffer,
            audioFile.originalname,
            audioFile.mimetype || 'audio/mpeg'
          );
        }
      } else {
        pdfFilename = pdfFile.filename;
        if (audioFile) audioFilename = audioFile.filename;
      }

      let slug = slugify(title);
      let n = 0;
      while (await Topic.findOne({ slug })) {
        n += 1;
        slug = `${slugify(title)}-${n}`;
      }
      const topic = await Topic.create({
        title: String(title).trim(),
        description: String(description || ''),
        slug,
        pdfFilename,
        pdfFileId,
        pdfRemoteUrl,
        pdfRemotePublicId,
        audioFilename,
        audioFileId,
        audioRemoteUrl,
        audioRemotePublicId,
        audioRemoteResourceType,
        sortOrder: sortOrder != null ? Number(sortOrder) : 0,
        isPublished: isPublished === 'true' || isPublished === true,
      });
      res.status(201).json({ topic: topic.toDetailJSON(baseUrl) });
    } catch (e) {
      next(e);
    }
  });

  admin.patch('/admin/topics/:id', topicUpload(), async (req, res, next) => {
    try {
      const topic = await Topic.findById(req.params.id);
      if (!topic) return res.status(404).json({ error: 'Topic not found' });
      const { title, description, isPublished, sortOrder } = req.body || {};
      if (title != null) topic.title = String(title).trim();
      if (description != null) topic.description = String(description);
      if (sortOrder != null) topic.sortOrder = Number(sortOrder);
      if (isPublished != null) {
        topic.isPublished = isPublished === 'true' || isPublished === true;
      }
      const files = req.files || {};

      if (files.pdf?.[0]) {
        const p = files.pdf[0];
        await wipePdf(topic);
        clearPdfFields(topic);
        if (useCloudinary()) {
          const up = await uploadPdfBuffer(p.buffer, p.originalname);
          topic.pdfRemoteUrl = up.secureUrl;
          topic.pdfRemotePublicId = up.publicId;
        } else if (useGridfs()) {
          topic.pdfFileId = await uploadBufferToGridFS(
            BUCKET_PDFS,
            p.buffer,
            p.originalname,
            p.mimetype || 'application/pdf'
          );
        } else {
          topic.pdfFilename = p.filename;
        }
      }
      if (files.audio?.[0]) {
        const a = files.audio[0];
        await wipeAudio(topic);
        clearAudioFields(topic);
        if (useCloudinary()) {
          const up = await uploadAudioBuffer(a.buffer, a.originalname);
          topic.audioRemoteUrl = up.secureUrl;
          topic.audioRemotePublicId = up.publicId;
          topic.audioRemoteResourceType = up.resourceType;
        } else if (useGridfs()) {
          topic.audioFileId = await uploadBufferToGridFS(
            BUCKET_AUDIO,
            a.buffer,
            a.originalname,
            a.mimetype || 'audio/mpeg'
          );
        } else {
          topic.audioFilename = a.filename;
        }
      }

      if (title != null) {
        const newSlug = slugify(topic.title);
        const existing = await Topic.findOne({ slug: newSlug, _id: { $ne: topic._id } });
        if (!existing) topic.slug = newSlug;
      }
      await topic.save();
      res.json({ topic: topic.toDetailJSON(baseUrl) });
    } catch (e) {
      next(e);
    }
  });

  admin.delete('/admin/topics/:id', async (req, res, next) => {
    try {
      const topic = await Topic.findById(req.params.id);
      if (!topic) return res.status(404).json({ error: 'Topic not found' });
      await wipePdf(topic);
      await wipeAudio(topic);
      await topic.deleteOne();
      res.status(204).send();
    } catch (e) {
      next(e);
    }
  });

  router.use(admin);
  return router;
}
