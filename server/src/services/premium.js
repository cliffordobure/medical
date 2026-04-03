import { User } from '../models/User.js';

export async function applyPremiumFromMetadata(meta) {
  const userId = meta?.userId;
  const intervalMonths = Number(meta?.intervalMonths) || 1;
  const paystackReference = meta?.paystackReference ? String(meta.paystackReference) : '';
  if (!userId) return;
  const user = await User.findById(userId);
  if (!user) return;
  if (paystackReference && user.premiumLastAppliedReference === paystackReference) {
    return;
  }
  const now = new Date();
  const base = user.premiumExpiresAt && user.premiumExpiresAt > now ? user.premiumExpiresAt : now;
  const next = new Date(base);
  next.setMonth(next.getMonth() + intervalMonths);
  user.isPremium = true;
  user.premiumExpiresAt = next;
  if (paystackReference) user.premiumLastAppliedReference = paystackReference;
  await user.save();
}
