import mongoose from 'mongoose';

const topicSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true },
    description: { type: String, default: '' },
    slug: { type: String, required: true, unique: true, lowercase: true, trim: true },
    pdfFilename: { type: String, default: null },
    /** GridFS file id (hex) when UPLOAD_DRIVER=gridfs */
    pdfFileId: { type: String, default: null },
    audioFilename: { type: String, default: null },
    audioFileId: { type: String, default: null },
    sortOrder: { type: Number, default: 0 },
    isPublished: { type: Boolean, default: false },
  },
  { timestamps: true }
);

topicSchema.methods.toListJSON = function toListJSON(baseUrl) {
  return {
    id: this._id.toString(),
    title: this.title,
    description: this.description,
    slug: this.slug,
    sortOrder: this.sortOrder,
    isPublished: this.isPublished,
    hasPdf: Boolean(this.pdfFilename || this.pdfFileId),
    hasAudio: Boolean(this.audioFilename || this.audioFileId),
    updatedAt: this.updatedAt,
  };
};

topicSchema.methods.toDetailJSON = function toDetailJSON(baseUrl) {
  const pdfUrl = this.pdfFileId
    ? `${baseUrl}/api/files/pdfs/${this.pdfFileId}`
    : this.pdfFilename
      ? `${baseUrl}/uploads/${this.pdfFilename}`
      : null;
  const audioUrl = this.audioFileId
    ? `${baseUrl}/api/files/audio/${this.audioFileId}`
    : this.audioFilename
      ? `${baseUrl}/uploads/${this.audioFilename}`
      : null;
  return {
    ...this.toListJSON(baseUrl),
    pdfUrl,
    audioUrl,
  };
};

export const Topic = mongoose.model('Topic', topicSchema);
