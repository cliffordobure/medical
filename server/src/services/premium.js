import { User } from '../models/User.js';

export async function applyPremiumFromMetadata(meta) {
  const userId = meta?.userId;
  const intervalMonths = Number(meta?.intervalMonths) || 1;
  if (!userId) return;
  const user = await User.findById(userId);
  if (!user) return;
  const now = new Date();
  const base = user.premiumExpiresAt && user.premiumExpiresAt > now ? user.premiumExpiresAt : now;
  const next = new Date(base);
  next.setMonth(next.getMonth() + intervalMonths);
  user.isPremium = true;
  user.premiumExpiresAt = next;
  await user.save();
}
