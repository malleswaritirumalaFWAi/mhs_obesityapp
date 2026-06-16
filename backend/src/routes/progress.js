import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

router.get('/photos', async (req, res) => {
  const photos = (await q(
    `SELECT * FROM progress_photos WHERE user_id=$1 ORDER BY created_at ASC`,
    [uid(req)]
  )).rows;
  res.json({ photos });
});

router.post('/photos', async (req, res) => {
  const { photo_url, label, week } = req.body || {};
  if (!photo_url) return res.status(400).json({ message: 'photo_url required' });
  const r = await q(
    `INSERT INTO progress_photos (user_id,photo_url,label,week) VALUES ($1,$2,$3,$4) RETURNING *`,
    [uid(req), photo_url, label || null, week || null]
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
