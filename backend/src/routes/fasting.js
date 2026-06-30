import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

// XP tiers — longer fasts earn more XP
const XP_BY_HOURS = { 10: 10, 12: 15, 14: 25, 16: 40, 18: 60, 20: 80 };
function fastingXp(targetHours) {
  return XP_BY_HOURS[targetHours] ?? Math.max(10, Math.floor(targetHours * 2.5));
}

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
    `SELECT id, started_at, ended_at, target_hours, completed, xp_awarded
     FROM fasting_sessions WHERE user_id=$1 ORDER BY started_at DESC LIMIT 20`,
    [uid(req)]
  )).rows;

  // Aggregate stats across all-time sessions
  const statsRow = (await q(
    `SELECT
       COUNT(*)                                         AS total_sessions,
       COUNT(*) FILTER (WHERE completed = TRUE)        AS total_completed,
       COALESCE(ROUND(
         SUM(EXTRACT(EPOCH FROM (ended_at - started_at)) / 3600)
         FILTER (WHERE completed = TRUE)
       , 1), 0)                                        AS total_hours,
       COUNT(*) FILTER (
         WHERE completed = TRUE
           AND started_at >= now() - INTERVAL '7 days'
       )                                               AS this_week
     FROM fasting_sessions WHERE user_id=$1`,
    [uid(req)]
  )).rows[0];

  res.json({ active, history, stats: statsRow });
});

router.post('/start', async (req, res) => {
  const { target_hours = 16 } = req.body || {};
  const hours = Math.max(10, Math.min(Number(target_hours), 24));
  // End any active session first
  await q(`UPDATE fasting_sessions SET ended_at=now() WHERE user_id=$1 AND ended_at IS NULL`, [uid(req)]);
  const r = await q(
    `INSERT INTO fasting_sessions (user_id, target_hours) VALUES ($1,$2) RETURNING *`,
    [uid(req), hours]
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
  const xpAwarded = completed ? fastingXp(active.target_hours) : 0;

  await q(
    `UPDATE fasting_sessions SET ended_at=now(), completed=$2, xp_awarded=$3 WHERE id=$1`,
    [active.id, completed, xpAwarded]
  );

  if (completed) {
    await awardXp(uid(req), xpAwarded);

    // Award fasting_pro badge after 5 completed sessions
    const count = (await q(
      `SELECT COUNT(*) AS c FROM fasting_sessions WHERE user_id=$1 AND completed=TRUE`, [uid(req)]
    )).rows[0]?.c ?? 0;
    if (Number(count) >= 5) {
      const badge = (await q(`SELECT id FROM badges WHERE code='fasting_pro'`)).rows[0];
      if (badge) {
        await q(
          `INSERT INTO user_badges (user_id, badge_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
          [uid(req), badge.id]
        );
      }
    }
  }

  res.json({
    completed,
    elapsed_hours: Math.round(elapsed * 10) / 10,
    xp_awarded: xpAwarded,
  });
});

// POST /fasting/resume — undo an accidental stop (within 5 minutes of stopping)
router.post('/resume', async (req, res) => {
  const r = await q(
    `UPDATE fasting_sessions
     SET ended_at = NULL, completed = FALSE, xp_awarded = 0
     WHERE id = (
       SELECT id FROM fasting_sessions
       WHERE user_id=$1 AND ended_at IS NOT NULL
       ORDER BY ended_at DESC LIMIT 1
     )
     AND ended_at > now() - INTERVAL '5 minutes'
     RETURNING id, started_at, target_hours`,
    [uid(req)]
  );
  if (!r.rows[0]) return res.status(400).json({ message: 'No recent fast to resume. You can start a new one.' });
  res.json({ session: r.rows[0] });
});

export default router;
