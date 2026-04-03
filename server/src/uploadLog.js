import { getUploadDriver } from './uploadDriver.js';

/**
 * Structured logs for file storage debugging (Render logs, local terminal).
 * Set UPLOAD_DEBUG_LOGS=1 for extra Cloudinary byte sizes / full error details.
 */
const debug = () =>
  process.env.UPLOAD_DEBUG_LOGS === '1' || process.env.UPLOAD_DEBUG_LOGS === 'true';

export function logTopicUpload(event, fields) {
  const line = { event, ...fields, t: new Date().toISOString() };
  console.log('[topic-upload]', JSON.stringify(line));
}

export function logCloudinary(phase, message, extra = {}) {
  const parts = { phase, message, ...extra, t: new Date().toISOString() };
  console.log('[cloudinary]', JSON.stringify(parts));
}

export function isUploadDebug() {
  return debug();
}

/** Set TOPIC_FETCH_LOGS=1 on Render to see what URLs students receive (helps debug mobile). */
export function logTopicFetchIfEnabled(slug, pdfUrl, audioUrl) {
  if (process.env.TOPIC_FETCH_LOGS !== '1' && process.env.TOPIC_FETCH_LOGS !== 'true') return;
  const host = (u) => {
    if (!u) return null;
    try {
      return new URL(u).host;
    } catch {
      return 'invalid-url';
    }
  };
  console.log(
    '[topic-fetch]',
    JSON.stringify({
      slug,
      pdfUrlHost: host(pdfUrl),
      audioUrlHost: host(audioUrl),
      t: new Date().toISOString(),
    })
  );
}

function storageSnapshot(topic) {
  return {
    hasPdfRemote: Boolean(topic.pdfRemoteUrl),
    hasPdfGridfs: Boolean(topic.pdfFileId),
    hasPdfDisk: Boolean(topic.pdfFilename),
    hasAudioRemote: Boolean(topic.audioRemoteUrl),
    hasAudioGridfs: Boolean(topic.audioFileId),
    hasAudioDisk: Boolean(topic.audioFilename),
  };
}

export function logTopicSaved(action, topic) {
  logTopicUpload(action, {
    envUploadDriver: process.env.UPLOAD_DRIVER ? String(process.env.UPLOAD_DRIVER).trim() : '(unset)',
    resolvedDriver: getUploadDriver(),
    topicId: topic._id?.toString(),
    slug: topic.slug,
    ...storageSnapshot(topic),
  });
}
