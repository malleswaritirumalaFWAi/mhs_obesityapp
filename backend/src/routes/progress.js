import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

router.get('/photos', async (req, res) => {
  // Ensure comment column exists (idempotent migration)
  await q(`ALTER TABLE progress_photos ADD COLUMN IF NOT EXISTS comment TEXT`).catch(() => {});
  // Migrate old label-based rows: copy label → comment for rows that have a label but no comment
  await q(
    `UPDATE progress_photos SET comment = label WHERE comment IS NULL AND label IS NOT NULL AND label <> ''`
  ).catch(() => {});
  const photos = (await q(
    `SELECT id, photo_url, comment, label, week, created_at FROM progress_photos
     WHERE user_id=$1 ORDER BY created_at DESC`,
    [uid(req)]
  )).rows;
  res.json({ photos });
});

// POST /progress/photos/upload — accepts base64 image from the mobile app
router.post('/photos/upload', async (req, res) => {
  await q(`ALTER TABLE progress_photos ADD COLUMN IF NOT EXISTS comment TEXT`).catch(() => {});
  const { image_base64, mime, comment } = req.body || {};
  if (!image_base64) return res.status(400).json({ message: 'image_base64 required' });
  const mimeType = mime || 'image/jpeg';
  // Store as a data URL — works without a CDN for MVP
  const photo_url = `data:${mimeType};base64,${image_base64}`;
  const r = await q(
    `INSERT INTO progress_photos (user_id, photo_url, comment) VALUES ($1, $2, $3) RETURNING *`,
    [uid(req), photo_url, comment || null]
  );
  res.json({ photo: r.rows[0] });
});

router.post('/photos', async (req, res) => {
  await q(`ALTER TABLE progress_photos ADD COLUMN IF NOT EXISTS comment TEXT`).catch(() => {});
  const { photo_url, comment } = req.body || {};
  if (!photo_url) return res.status(400).json({ message: 'photo_url required' });
  const r = await q(
    `INSERT INTO progress_photos (user_id, photo_url, comment) VALUES ($1, $2, $3) RETURNING *`,
    [uid(req), photo_url, comment || null]
  );
  res.json({ photo: r.rows[0] });
});

router.get('/weight-trend', async (req, res) => {
  const rows = (await q(
    `SELECT weight, checked_at FROM checkins WHERE user_id=$1 AND weight IS NOT NULL
     ORDER BY checked_at ASC`,
    [uid(req)]
  )).rows;
  res.json({ trend: rows });
});

router.get('/compliance', async (req, res) => {
  const rows = (await q(
    `SELECT date_trunc('week', completed_at) AS week,
            COUNT(*) AS completed,
            (SELECT COUNT(*) FROM tasks WHERE user_id=$1) AS total
     FROM tasks WHERE user_id=$1 AND done=TRUE
     GROUP BY 1 ORDER BY 1 DESC LIMIT 12`,
    [uid(req)]
  )).rows;
  const latest = rows[0] ? Math.round((rows[0].completed / (rows[0].total || 1)) * 100) : 0;
  res.json({ weekly: rows, latest_score: latest });
});

export default router;
