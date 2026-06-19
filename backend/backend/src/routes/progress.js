import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

// GET /progress/photos
router.get('/photos', async (req, res) => {
  const r = await q(
    `SELECT id, photo_url, label, week, created_at FROM progress_photos
     WHERE user_id=$1 ORDER BY created_at ASC`,
    [uid(req)]
  );
  res.json({ photos: r.rows });
});

// POST /progress/photos { photo_url, label, week }
router.post('/photos', async (req, res) => {
  const { photo_url, label, week } = req.body || {};
  if (!photo_url) return res.status(400).json({ message: 'photo_url required' });
  const r = await q(
    `INSERT INTO progress_photos (user_id, photo_url, label, week) VALUES ($1,$2,$3,$4) RETURNING id`,
    [uid(req), photo_url, label || null, week || null]
  );

  // Award snapshot badge on first photo
  const count = await q(`SELECT COUNT(*) FROM progress_photos WHERE user_id=$1`, [uid(req)]);
  if (Number(count.rows[0].count) === 1) {
    const b = await q(`SELECT id FROM badges WHERE code='snapshot'`);
    if (b.rows[0]) {
      await q(`INSERT INTO user_badges (user_id, badge_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
        [uid(req), b.rows[0].id]);
    }
  }

  res.json({ id: r.rows[0].id, xp_awarded: 5 });
});

// GET /progress/weight-trend — full weight history for graph
router.get('/weight-trend', async (req, res) => {
  const u = (await q(`SELECT start_weight, target_weight FROM users WHERE id=$1`, [uid(req)])).rows[0] || {};
  const checkins = await q(
    `SELECT weight, created_at FROM checkins WHERE user_id=$1 AND weight IS NOT NULL
     ORDER BY created_at ASC`,
    [uid(req)]
  );
  res.json({ entries: checkins.rows, start_weight: u.start_weight, target_weight: u.target_weight });
});

// GET /progress/compliance — weekly compliance score
router.get('/compliance', async (req, res) => {
  const gid = (await q(`SELECT group_id FROM group_members WHERE user_id=$1 LIMIT 1`, [uid(req)])).rows[0]?.group_id;
  const g = gid ? (await q(`SELECT starts_on FROM groups WHERE id=$1`, [gid])).rows[0] : null;
  const startsOn = g?.starts_on ? new Date(g.starts_on) : new Date();
  const diffMs = Date.now() - startsOn.setHours(0,0,0,0);
  const currentDay = Math.min(Math.max(Math.floor(diffMs / 86400000) + 1, 1), 84);
  const weekStart = currentDay - ((currentDay - 1) % 7);

  const r = await q(
    `SELECT COUNT(*) FILTER (WHERE done) AS done, COUNT(*) AS total
     FROM tasks WHERE user_id=$1 AND day_index BETWEEN $2 AND $3`,
    [uid(req), weekStart, weekStart + 6]
  );
  const done = Number(r.rows[0]?.done ?? 0);
  const total = Number(r.rows[0]?.total ?? 0);
  const score = total > 0 ? Math.round((done / total) * 100) : 0;
  res.json({ compliance_score: score, done, total, current_week: Math.ceil(currentDay / 7) });
});

export default router;
