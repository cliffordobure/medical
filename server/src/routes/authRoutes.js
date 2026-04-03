import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { User } from '../models/User.js';
import { authRequired, loadUser, signToken } from '../middleware/auth.js';

export const authRouter = Router();

authRouter.post('/register', async (req, res, next) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }
    if (password.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters' });
    }
    const existing = await User.findOne({ email: String(email).toLowerCase() });
    if (existing) {
      return res.status(409).json({ error: 'Email already registered' });
    }
    const passwordHash = await bcrypt.hash(password, 10);
    const user = await User.create({
      email: String(email).toLowerCase(),
      passwordHash,
      role: 'student',
    });
    const token = signToken(user);
    res.status(201).json({ token, user: user.toPublicJSON() });
  } catch (e) {
    next(e);
  }
});

authRouter.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }
    const user = await User.findOne({ email: String(email).toLowerCase() });
    if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    if (user.premiumExpiresAt && user.premiumExpiresAt < new Date()) {
      user.isPremium = false;
      await user.save();
    }
    const token = signToken(user);
    res.json({ token, user: user.toPublicJSON() });
  } catch (e) {
    next(e);
  }
});

authRouter.get('/me', authRequired, loadUser, (req, res) => {
  res.json({ user: req.user.toPublicJSON() });
});
