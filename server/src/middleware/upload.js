import fs from 'fs';
import multer from 'multer';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const uploadsDir = path.join(__dirname, '../../uploads');

export function ensureUploadsDir() {
  if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
  }
  return uploadsDir;
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, ensureUploadsDir());
  },
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname) || '';
    const safe = `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`;
    cb(null, safe);
  },
});

function pdfFilter(_req, file, cb) {
  if (file.mimetype === 'application/pdf' || file.originalname?.toLowerCase().endsWith('.pdf')) {
    cb(null, true);
  } else {
    cb(new Error('Only PDF files are allowed'));
  }
}

const audioMimes = new Set([
  'audio/mpeg',
  'audio/mp3',
  'audio/wav',
  'audio/x-wav',
  'audio/mp4',
  'audio/m4a',
  'audio/aac',
  'audio/ogg',
]);

function audioFilter(_req, file, cb) {
  const ext = path.extname(file.originalname || '').toLowerCase();
  if (audioMimes.has(file.mimetype) || ['.mp3', '.wav', '.m4a', '.aac', '.ogg'].includes(ext)) {
    cb(null, true);
  } else {
    cb(new Error('Only audio files are allowed (mp3, wav, m4a, etc.)'));
  }
}

const multerFields = [
  { name: 'pdf', maxCount: 1 },
  { name: 'audio', maxCount: 1 },
];

const fileFilter = (req, file, cb) => {
  if (file.fieldname === 'pdf') return pdfFilter(req, file, cb);
  if (file.fieldname === 'audio') return audioFilter(req, file, cb);
  cb(new Error('Unexpected field'));
};

export const uploadTopicFiles = multer({
  storage,
  limits: { fileSize: 80 * 1024 * 1024 },
  fileFilter,
}).fields(multerFields);

/** For UPLOAD_DRIVER=gridfs — files in memory then stored in MongoDB GridFS */
export const uploadTopicFilesMemory = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 80 * 1024 * 1024 },
  fileFilter,
}).fields(multerFields);
