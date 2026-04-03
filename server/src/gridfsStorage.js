import mongoose from 'mongoose';

export const BUCKET_PDFS = 'topic_pdfs';
export const BUCKET_AUDIO = 'topic_audio';
export const BUCKET_AD_IMAGES = 'ad_images';

function bucket(name) {
  return new mongoose.mongo.GridFSBucket(mongoose.connection.db, { bucketName: name });
}

export function uploadBufferToGridFS(bucketName, buffer, originalName, contentType) {
  return new Promise((resolve, reject) => {
    const b = bucket(bucketName);
    const uploadStream = b.openUploadStream(originalName || 'file', {
      contentType: contentType || 'application/octet-stream',
    });
    uploadStream.on('finish', () => resolve(uploadStream.id.toString()));
    uploadStream.on('error', reject);
    uploadStream.end(buffer);
  });
}

export async function deleteGridFile(bucketName, fileId) {
  if (!fileId || !mongoose.Types.ObjectId.isValid(fileId)) return;
  try {
    await bucket(bucketName).delete(new mongoose.Types.ObjectId(fileId));
  } catch (e) {
    console.warn('GridFS delete:', e.message);
  }
}

export function openDownloadStream(bucketName, fileId) {
  return bucket(bucketName).openDownloadStream(new mongoose.Types.ObjectId(fileId));
}
