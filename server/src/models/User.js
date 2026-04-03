import mongoose from 'mongoose';

const userSchema = new mongoose.Schema(
  {
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true },
    role: { type: String, enum: ['admin', 'student'], default: 'student' },
    isPremium: { type: Boolean, default: false },
    premiumExpiresAt: { type: Date, default: null },
    /** Last Paystack transaction reference we applied premium for (idempotency for webhook + verify). */
    premiumLastAppliedReference: { type: String, default: null },
    paystackCustomerCode: { type: String, default: null },
  },
  { timestamps: true }
);

userSchema.methods.toPublicJSON = function toPublicJSON() {
  return {
    id: this._id.toString(),
    email: this.email,
    role: this.role,
    isPremium: this.isPremium,
    premiumExpiresAt: this.premiumExpiresAt,
  };
};

export const User = mongoose.model('User', userSchema);
