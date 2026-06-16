import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

async function awardXp(userId, amount) {
  await q(`UPDATE users SET xp=xp+$2, total_xp=total_xp+$2 WHERE id=$1`, [userId, amount]);
  await q(`UPDATE group_members SET weekly_xp=weekly_xp+$2 WHERE user_id=$1`, [userId, amount]);
}

router.get('/', async (req, res) => {
  const active = (await q(
    `SELECT id, started_at, target_hours, ended_at, completed
     FROM fasting_sessions WHERE user_id=$1 AND ended_at IS NULL ORDER BY started_at DESC LIMIT 1`,
    [uid(req)]
  )).rows[0] || null;
  const history = (await q(
    `SELECT id, started_at, ended_at, target_hours, completed
     FROM fasting_sessions WHERE user_id=$1 ORDER BY started_at DESC LIMIT 20`,
    [uid(req)]
  )).rows;
  res.json({ active, history });
});

router.post('/start', async (req, res) => {
  const { target_hours = 16 } = req.body || {};
  // End any active session first
  await q(`UPDATE fasting_sessions SET ended_at=now() WHERE user_id=$1 AND ended_at IS NULL`, [uid(req)]);
  const r = await q(
    `INSERT INTO fasting_sessions (user_id, target_hours) VALUES ($1,$2) RETURNING *`,
    [uid(req), target_hours]
  );
  res.json({ session: r.rows[0] });
});

router.post('/stop', async (req, res) => {
  const active = (await q(
    `SELECT id, started_at, target_hours FROM fasting_sessions WHERE user_id=$1 AND ended_at IS NULL LIMIT 1`,
    [uid(req)]
  )).rows[0];
  if (!active) return res.status(404).json({ message: 'No active session' });

  const elapsed = (Date.now() - new Date(active.started_at).getTime()) / 3600000;
  const completed = elapsed >= active.target_hours;
  await q(
    `UPDATE fasting_sessions SET ended_at=now(), completed=$2 WHERE id=$1`,
    [active.id, completed]
  );
  if (completed) {
    await awardXp(uid(req), 15);
    // Award fasting_pro badge after 30 sessions
    const count = (await q(
      `SELECT COUNT(*) AS c FROM fasting_sessions WHERE user_id=$1 AND completed=TRUE`, [uid(req)]
    )).rows[0]?.c ?? 0;
    if (Number(count) >= 30) {
      const badge = (await q(`SELECT id FROM badges WHERE code='fasting_pro'`)).rows[0];
      if (badge) {
        await q(
          `INSERT INTO user_badges (user_id, badge_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
          [uid(req), badge.id]
        );
      }
    }
  }
  res.json({ completed, elapsed_hours: Math.round(elapsed * 10) / 10, xp_earned: completed ? 15 : 0 });
});

export default router;
