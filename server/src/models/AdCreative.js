import mongoose from 'mongoose';

const adCreativeSchema = new mongoose.Schema(
  {
    title: { type: String, default: '' },
    sortOrder: { type: Number, default: 0 },
    active: { type: Boolean, default: true },
    imageFilename: { type: String, default: null },
    imageFileId: { type: String, default: null },
    imageRemoteUrl: { type: String, default: null },
    imageRemotePublicId: { type: String, default: null },
  },
  { timestamps: true }
);

adCreativeSchema.methods.toClientJSON = function toClientJSON(baseUrl) {
  const imageUrl = this.imageRemoteUrl
    ? this.imageRemoteUrl
    : this.imageFileId
      ? `${baseUrl}/api/files/ad-images/${this.imageFileId}`
      : this.imageFilename
        ? `${baseUrl}/uploads/${this.imageFilename}`
        : null;
  return {
    id: this._id.toString(),
    title: this.title || '',
    imageUrl,
    sortOrder: this.sortOrder,
    active: this.active,
  };
};

export const AdCreative = mongoose.model('AdCreative', adCreativeSchema);
