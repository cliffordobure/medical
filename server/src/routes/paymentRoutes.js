import crypto from 'crypto';
import { Router } from 'express';
import { SubscriptionPackage } from '../models/SubscriptionPackage.js';
import { User } from '../models/User.js';
import { authRequired, loadUser } from '../middleware/auth.js';
import { applyPremiumFromMetadata } from '../services/premium.js';

/** ISO code sent to Paystack (e.g. KES Kenya, NGN Nigeria). Amounts in DB are minor units (cents/kobo). */
function paystackCurrency() {
  return (process.env.PAYSTACK_CURRENCY || 'KES').trim().toUpperCase();
}

/**
 * Paystack returns 200 + { status: false, message } for many errors; also non-JSON on bad keys.
 * Always resolves to a parsed object shape callers already handle.
 */
async function paystackRequest(path, method, body) {
  const secret = process.env.PAYSTACK_SECRET_KEY;
  if (!secret) {
    return { status: false, message: 'PAYSTACK_SECRET_KEY is not set on the server' };
  }
  try {
    const r = await fetch(`https://api.paystack.co${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${secret}`,
        'Content-Type': 'application/json',
      },
      body: body != null ? JSON.stringify(body) : undefined,
    });
    const text = await r.text();
    let json;
    try {
      json = text ? JSON.parse(text) : {};
    } catch {
      return {
        status: false,
        message: `Paystack returned invalid JSON (HTTP ${r.status}). Check PAYSTACK_SECRET_KEY and dashboard.`,
      };
    }
    if (!r.ok) {
      return {
        status: false,
        message: json.message || json.data?.message || `Paystack HTTP ${r.status}`,
      };
    }
    return json;
  } catch (e) {
    return { status: false, message: e?.message || 'Paystack request failed' };
  }
}

export function paymentRouter(clientOrigin) {
  const router = Router();

  /** Public catalog — no JWT (mobile must not require login to list plans). */
  router.get('/packages', async (_req, res, next) => {
    try {
      const pk = process.env.PAYSTACK_PUBLIC_KEY || '';
      const currency = paystackCurrency();
      const list = await SubscriptionPackage.find({ active: true }).sort({ intervalMonths: 1 });
      res.json({
        paystackPublicKey: pk,
        currency,
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
      if (req.user.role !== 'student') {
        return res.status(403).json({ error: 'Only student accounts can purchase Premium.' });
      }
      const { packageId } = req.body || {};
      if (!packageId) return res.status(400).json({ error: 'packageId required' });
      const pkg = await SubscriptionPackage.findById(packageId);
      if (!pkg || !pkg.active) return res.status(404).json({ error: 'Package not found' });

      const email = req.user.email;
      const currency = paystackCurrency();
      const callbackOverride = (process.env.PAYSTACK_CALLBACK_URL || '').trim();
      const callbackUrl = callbackOverride || `${String(clientOrigin).replace(/\/$/, '')}/subscribe/callback`;
      const reference = `ms_${req.user._id}_${Date.now()}`;

      const init = await paystackRequest('/transaction/initialize', 'POST', {
        email,
        amount: pkg.amountKobo,
        currency,
        reference,
        callback_url: callbackUrl,
        metadata: {
          userId: req.user._id.toString(),
          packageId: pkg._id.toString(),
          intervalMonths: String(pkg.intervalMonths),
        },
      });

      if (!init.status) {
        const hint =
          currency === 'KES'
            ? ' If your Paystack account is Nigeria-only, set PAYSTACK_CURRENCY=NGN on the server.'
            : '';
        return res.status(502).json({
          error: `${init.message || 'Paystack error'}${hint}`,
        });
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
      if (req.user.role !== 'student') {
        return res.status(403).json({ error: 'Only student accounts can verify Premium payments.' });
      }
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
