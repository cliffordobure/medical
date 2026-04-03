import mongoose from 'mongoose';

const subscriptionPackageSchema = new mongoose.Schema(
  {
    key: { type: String, required: true, unique: true },
    displayName: { type: String, required: true },
    description: { type: String, default: '' },
    amountKobo: { type: Number, required: true },
    intervalMonths: { type: Number, required: true },
    paystackPlanCode: { type: String, default: null },
    active: { type: Boolean, default: true },
  },
  { timestamps: true }
);

export const SubscriptionPackage = mongoose.model('SubscriptionPackage', subscriptionPackageSchema);
