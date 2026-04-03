import { Router } from 'express';
import { SubscriptionPackage } from '../models/SubscriptionPackage.js';
import { authRequired, loadUser, adminOnly } from '../middleware/auth.js';

export function adminPackageRoutes() {
  const router = Router();
  const admin = Router();
  admin.use(authRequired, loadUser, adminOnly);

  admin.get('/packages', async (_req, res, next) => {
    try {
      const packages = await SubscriptionPackage.find().sort({ intervalMonths: 1, displayName: 1 });
      res.json({
        packages: packages.map((p) => ({
          id: p._id.toString(),
          key: p.key,
          displayName: p.displayName,
          description: p.description,
          amountKobo: p.amountKobo,
          intervalMonths: p.intervalMonths,
          paystackPlanCode: p.paystackPlanCode,
          active: p.active,
        })),
      });
    } catch (e) {
      next(e);
    }
  });

  admin.post('/packages', async (req, res, next) => {
    try {
      const { key, displayName, description, amountKobo, intervalMonths, active, paystackPlanCode } =
        req.body || {};
      if (!key || !displayName || amountKobo == null || intervalMonths == null) {
        return res.status(400).json({ error: 'key, displayName, amountKobo, intervalMonths required' });
      }
      const existing = await SubscriptionPackage.findOne({ key: String(key).trim() });
      if (existing) return res.status(409).json({ error: 'Package key already exists' });
      const pkg = await SubscriptionPackage.create({
        key: String(key).trim(),
        displayName: String(displayName).trim(),
        description: String(description || ''),
        amountKobo: Number(amountKobo),
        intervalMonths: Number(intervalMonths),
        paystackPlanCode: paystackPlanCode ? String(paystackPlanCode).trim() : null,
        active: active !== false && active !== 'false',
      });
      res.status(201).json({
        package: {
          id: pkg._id.toString(),
          key: pkg.key,
          displayName: pkg.displayName,
          description: pkg.description,
          amountKobo: pkg.amountKobo,
          intervalMonths: pkg.intervalMonths,
          paystackPlanCode: pkg.paystackPlanCode,
          active: pkg.active,
        },
      });
    } catch (e) {
      next(e);
    }
  });

  admin.patch('/packages/:id', async (req, res, next) => {
    try {
      const pkg = await SubscriptionPackage.findById(req.params.id);
      if (!pkg) return res.status(404).json({ error: 'Package not found' });
      const { key, displayName, description, amountKobo, intervalMonths, active, paystackPlanCode } =
        req.body || {};
      if (key != null) {
        const k = String(key).trim();
        const clash = await SubscriptionPackage.findOne({ key: k, _id: { $ne: pkg._id } });
        if (clash) return res.status(409).json({ error: 'Package key already exists' });
        pkg.key = k;
      }
      if (displayName != null) pkg.displayName = String(displayName).trim();
      if (description != null) pkg.description = String(description);
      if (amountKobo != null) pkg.amountKobo = Number(amountKobo);
      if (intervalMonths != null) pkg.intervalMonths = Number(intervalMonths);
      if (paystackPlanCode !== undefined) {
        pkg.paystackPlanCode = paystackPlanCode ? String(paystackPlanCode).trim() : null;
      }
      if (active != null) pkg.active = active !== false && active !== 'false';
      await pkg.save();
      res.json({
        package: {
          id: pkg._id.toString(),
          key: pkg.key,
          displayName: pkg.displayName,
          description: pkg.description,
          amountKobo: pkg.amountKobo,
          intervalMonths: pkg.intervalMonths,
          paystackPlanCode: pkg.paystackPlanCode,
          active: pkg.active,
        },
      });
    } catch (e) {
      next(e);
    }
  });

  admin.delete('/packages/:id', async (req, res, next) => {
    try {
      const pkg = await SubscriptionPackage.findById(req.params.id);
      if (!pkg) return res.status(404).json({ error: 'Package not found' });
      await pkg.deleteOne();
      res.status(204).send();
    } catch (e) {
      next(e);
    }
  });

  router.use('/admin', admin);
  return router;
}
