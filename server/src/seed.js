import bcrypt from 'bcryptjs';
import { User } from './models/User.js';
import { SubscriptionPackage } from './models/SubscriptionPackage.js';

export async function runSeed() {
  const count = await SubscriptionPackage.countDocuments();
  if (count === 0) {
    await SubscriptionPackage.insertMany([
      {
        key: 'premium_monthly',
        displayName: 'Premium — Monthly',
        description: 'Unlimited study materials without ads.',
        amountKobo: 500000,
        intervalMonths: 1,
        active: true,
      },
      {
        key: 'premium_yearly',
        displayName: 'Premium — Yearly',
        description: 'Best value: full access for 12 months.',
        amountKobo: 5000000,
        intervalMonths: 12,
        active: true,
      },
    ]);
    console.log('Seeded subscription packages (adjust amounts in MongoDB if needed).');
  }

  const adminEmail = process.env.SEED_ADMIN_EMAIL;
  const adminPassword = process.env.SEED_ADMIN_PASSWORD;
  if (adminEmail && adminPassword) {
    const email = adminEmail.toLowerCase();
    const passwordHash = await bcrypt.hash(adminPassword, 10);
    const existing = await User.findOne({ email });
    if (!existing) {
      await User.create({
        email,
        passwordHash,
        role: 'admin',
      });
      console.log(`Seeded admin user: ${email}`);
    } else if (existing.role !== 'admin') {
      existing.role = 'admin';
      existing.passwordHash = passwordHash;
      await existing.save();
      console.log(`Promoted to admin and password updated: ${email}`);
    }
  }
}
