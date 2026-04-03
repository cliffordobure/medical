import crypto from 'crypto';
import { Router } from 'express';
import { SubscriptionPackage } from '../models/SubscriptionPackage.js';
import { User } from '../models/User.js';
import { authRequired, loadUser } from '../middleware/auth.js';
import { applyPremiumFromMetadata } from '../services/premium.js';

function paystackRequest(path, method, body) {
  const secret = process.env.PAYSTACK_SECRET_KEY;
  if (!secret) throw new Error('PAYSTACK_SECRET_KEY is not set');
  return fetch(`https://api.paystack.co${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${secret}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  }).then((r) => r.json());
}

export function paymentRouter(clientOrigin) {
  const router = Router();

  /** Public catalog — no JWT (mobile must not require login to list plans). */
  router.get('/packages', async (_req, res, next) => {
    try {
      const pk = process.env.PAYSTACK_PUBLIC_KEY || '';
      const list = await SubscriptionPackage.find({ active: true }).sort({ intervalMonths: 1 });
      res.json({
        paystackPublicKey: pk,
        packages: list.map((p) => ({
          id: p._id.toString(),
          key: p.key,
          displayName: p.displayName,
          description: p.description,
          amountKobo: p.amountKobo,
          intervalMonths: p.intervalMonths,
        })),
      });
    } catch (e) {
      next(e);
    }
  });

  router.post('/payments/initialize', authRequired, loadUser, async (req, res, next) => {
    try {
      const { packageId } = req.body || {};
      if (!packageId) return res.status(400).json({ error: 'packageId required' });
      const pkg = await SubscriptionPackage.findById(packageId);
      if (!pkg || !pkg.active) return res.status(404).json({ error: 'Package not found' });

      const email = req.user.email;
      const callbackUrl = `${clientOrigin}/subscribe/callback`;
      const reference = `ms_${req.user._id}_${Date.now()}`;

      const init = await paystackRequest('/transaction/initialize', 'POST', {
        email,
        amount: pkg.amountKobo,
        currency: 'NGN',
        reference,
        callback_url: callbackUrl,
        metadata: {
          userId: req.user._id.toString(),
          packageId: pkg._id.toString(),
          intervalMonths: String(pkg.intervalMonths),
        },
      });

      if (!init.status) {
        return res.status(502).json({ error: init.message || 'Paystack error' });
      }

      res.json({
        authorizationUrl: init.data.authorization_url,
        reference: init.data.reference,
        accessCode: init.data.access_code,
      });
    } catch (e) {
      next(e);
    }
  });

  router.get('/payments/verify/:reference', authRequired, loadUser, async (req, res, next) => {
    try {
      const { reference } = req.params;
      const data = await paystackRequest(`/transaction/verify/${encodeURIComponent(reference)}`, 'GET');
      if (!data.status || !data.data) {
        return res.status(400).json({ error: data.message || 'Verification failed' });
      }
      const d = data.data;
      if (d.status !== 'success') {
        return res.status(400).json({ error: 'Payment not successful' });
      }
      const meta = d.metadata || {};
      if (meta.userId !== req.user._id.toString()) {
        return res.status(403).json({ error: 'Reference does not belong to this user' });
      }
      await applyPremiumFromMetadata({
        userId: meta.userId,
        intervalMonths: meta.intervalMonths,
      });
      const user = await User.findById(req.user._id);
      res.json({ ok: true, user: user.toPublicJSON() });
    } catch (e) {
      next(e);
    }
  });

  return router;
}

/** Mount with: app.post('/api/payments/webhook', express.raw({ type: 'application/json' }), paystackWebhookHandler) */
export async function paystackWebhookHandler(req, res) {
  try {
    const secret = process.env.PAYSTACK_SECRET_KEY || '';
    const raw = req.body;
    const buf = Buffer.isBuffer(raw) ? raw : Buffer.from(String(raw || ''), 'utf8');
    const hash = req.headers['x-paystack-signature'];
    const expected = crypto.createHmac('sha512', secret).update(buf).digest('hex');
    if (hash !== expected) {
      return res.status(400).send('invalid signature');
    }
    const payload = JSON.parse(buf.toString('utf8'));
    const event = payload.event;
    const data = payload.data;
    if (event === 'charge.success' && data?.metadata) {
      const m = data.metadata;
      await applyPremiumFromMetadata({
        userId: m.userId,
        intervalMonths: m.intervalMonths,
      });
    }
    res.sendStatus(200);
  } catch {
    res.sendStatus(400);
  }
}
