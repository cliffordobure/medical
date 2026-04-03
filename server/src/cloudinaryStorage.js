import { v2 as cloudinary } from 'cloudinary';

export function configureCloudinary() {
  const name = process.env.CLOUDINARY_CLOUD_NAME;
  const key = process.env.CLOUDINARY_API_KEY;
  const secret = process.env.CLOUDINARY_API_SECRET;
  if (!name || !key || !secret) {
    throw new Error('Cloudinary env vars missing: CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET');
  }
  cloudinary.config({ cloud_name: name, api_key: key, api_secret: secret });
}

/**
 * PDFs as raw files (correct MIME, direct download URL).
 * @returns {{ secureUrl: string, publicId: string }}
 */
export function uploadPdfBuffer(buffer, originalName) {
  const safeName = String(originalName || 'notes.pdf')
    .replace(/[^\w.-]/g, '_')
    .slice(0, 100);
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      {
        folder: 'medstudy/pdf',
        resource_type: 'raw',
        use_filename: true,
        unique_filename: true,
        filename_override: safeName,
      },
      (err, result) => {
        if (err) return reject(err);
        if (!result?.secure_url || !result.public_id) {
          return reject(new Error('Cloudinary PDF upload returned no URL'));
        }
        resolve({ secureUrl: result.secure_url, publicId: result.public_id });
      }
    );
    stream.end(buffer);
  });
}

/**
 * Audio: use `video` resource type so Cloudinary serves typical formats (mp3, m4a) with a CDN URL.
 * @returns {{ secureUrl: string, publicId: string }}
 */
export function uploadAudioBuffer(buffer, originalName) {
  const safeName = String(originalName || 'audio.mp3')
    .replace(/[^\w.-]/g, '_')
    .slice(0, 100);

  const uploadAs = (resourceType) =>
    new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          folder: 'medstudy/audio',
          resource_type: resourceType,
          use_filename: true,
          unique_filename: true,
          filename_override: safeName,
        },
        (err, result) => {
          if (err) return reject(err);
          if (!result?.secure_url || !result.public_id) {
            return reject(new Error('Cloudinary audio upload returned no URL'));
          }
          resolve({ secureUrl: result.secure_url, publicId: result.public_id, resourceType });
        }
      );
      stream.end(buffer);
    });

  return uploadAs('video').catch(() => uploadAs('raw'));
}

export async function destroyCloudinaryAsset(publicId, resourceType) {
  if (!publicId) return;
  const rt = resourceType === 'raw' ? 'raw' : 'video';
  try {
    await cloudinary.uploader.destroy(publicId, { resource_type: rt });
  } catch (e) {
    console.warn('Cloudinary destroy:', e.message);
    if (rt === 'video') {
      try {
        await cloudinary.uploader.destroy(publicId, { resource_type: 'raw' });
      } catch (e2) {
        console.warn('Cloudinary destroy raw retry:', e2.message);
      }
    }
  }
}
