import mongoose from 'mongoose';

const topicSchema = new mongoose.Schema(
  {
    /** 1–6 = year of study; used for grouping in the app. */
    yearOfStudy: { type: Number, default: 1, min: 1, max: 6 },
    /** Subject / module name (middle level: Year → this → subtopic title). */
    topicGroup: { type: String, default: 'General', trim: true },
    /** Subtopic / lesson title (leaf). */
    title: { type: String, required: true, trim: true },
    description: { type: String, default: '' },
    slug: { type: String, required: true, unique: true, lowercase: true, trim: true },
    pdfFilename: { type: String, default: null },
    /** GridFS file id (hex) when UPLOAD_DRIVER=gridfs */
    pdfFileId: { type: String, default: null },
    /** Cloudinary `secure_url` when UPLOAD_DRIVER=cloudinary */
    pdfRemoteUrl: { type: String, default: null },
    pdfRemotePublicId: { type: String, default: null },
    audioFilename: { type: String, default: null },
    audioFileId: { type: String, default: null },
    audioRemoteUrl: { type: String, default: null },
    audioRemotePublicId: { type: String, default: null },
    /** Cloudinary resource_type used for delete (video vs raw) */
    audioRemoteResourceType: { type: String, enum: ['video', 'raw'], default: undefined },
    sortOrder: { type: Number, default: 0 },
    isPublished: { type: Boolean, default: false },
  },
  { timestamps: true }
);

topicSchema.methods.toListJSON = function toListJSON(baseUrl) {
  const y = Number.isFinite(this.yearOfStudy) ? this.yearOfStudy : 1;
  const grp = (this.topicGroup && String(this.topicGroup).trim()) || 'General';
  return {
    id: this._id.toString(),
    yearOfStudy: y,
    topic: grp,
    title: this.title,
    description: this.description,
    slug: this.slug,
    sortOrder: this.sortOrder,
    isPublished: this.isPublished,
    hasPdf: Boolean(this.pdfFilename || this.pdfFileId || this.pdfRemoteUrl),
    hasAudio: Boolean(this.audioFilename || this.audioFileId || this.audioRemoteUrl),
    updatedAt: this.updatedAt,
  };
};

topicSchema.methods.toDetailJSON = function toDetailJSON(baseUrl) {
  const pdfUrl = this.pdfRemoteUrl
    ? this.pdfRemoteUrl
    : this.pdfFileId
      ? `${baseUrl}/api/files/pdfs/${this.pdfFileId}`
      : this.pdfFilename
        ? `${baseUrl}/uploads/${this.pdfFilename}`
        : null;
  const audioUrl = this.audioRemoteUrl
    ? this.audioRemoteUrl
    : this.audioFileId
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
