/**
 * Single source of truth for file storage mode (avoids typos / stray spaces in env).
 * Set on Render: UPLOAD_DRIVER=cloudinary (lowercase) + Cloudinary credentials.
 */
export function getUploadDriver() {
  const v = (process.env.UPLOAD_DRIVER || 'disk').trim().toLowerCase();
  if (v === 'cloudinary' || v === 'gridfs' || v === 'disk') return v;
  console.warn(`UPLOAD_DRIVER="${process.env.UPLOAD_DRIVER}" is invalid; using "disk". Use: disk | gridfs | cloudinary`);
  return 'disk';
}

export function useCloudinary() {
  return getUploadDriver() === 'cloudinary';
}

export function useGridfs() {
  return getUploadDriver() === 'gridfs';
}
