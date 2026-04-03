import { Router } from 'express';
import { slugify } from '../utils/slugify.js';
import { Topic } from '../models/Topic.js';
import { authRequired, loadUser, adminOnly } from '../middleware/auth.js';
import { uploadTopicFiles } from '../middleware/upload.js';

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

  admin.post('/admin/topics', uploadTopicFiles, async (req, res, next) => {
    try {
      const { title, description, isPublished, sortOrder } = req.body || {};
      if (!title) return res.status(400).json({ error: 'Title is required' });
      const files = req.files || {};
      const pdfFile = files.pdf?.[0];
      if (!pdfFile) return res.status(400).json({ error: 'PDF file is required' });
      const audioFile = files.audio?.[0];
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
        pdfFilename: pdfFile.filename,
        audioFilename: audioFile?.filename || null,
        sortOrder: sortOrder != null ? Number(sortOrder) : 0,
        isPublished: isPublished === 'true' || isPublished === true,
      });
      res.status(201).json({ topic: topic.toDetailJSON(baseUrl) });
    } catch (e) {
      next(e);
    }
  });

  admin.patch('/admin/topics/:id', uploadTopicFiles, async (req, res, next) => {
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
      if (files.pdf?.[0]) topic.pdfFilename = files.pdf[0].filename;
      if (files.audio?.[0]) topic.audioFilename = files.audio[0].filename;
      if (title != null) {
        let slug = slugify(topic.title);
        const existing = await Topic.findOne({ slug, _id: { $ne: topic._id } });
        if (!existing) topic.slug = slug;
      }
      await topic.save();
      res.json({ topic: topic.toDetailJSON(baseUrl) });
    } catch (e) {
      next(e);
    }
  });

  admin.delete('/admin/topics/:id', async (req, res, next) => {
    try {
      const topic = await Topic.findByIdAndDelete(req.params.id);
      if (!topic) return res.status(404).json({ error: 'Topic not found' });
      res.status(204).send();
    } catch (e) {
      next(e);
    }
  });

  router.use(admin);
  return router;
}
