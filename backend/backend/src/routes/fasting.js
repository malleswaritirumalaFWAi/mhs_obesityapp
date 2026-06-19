import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';
import { markTasksDoneByIcon } from '../tasks.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

// GET /fasting — current active session + history
router.get('/', async (req, res) => {
  const active = await q(
    `SELECT id, started_at, target_hours FROM fasting_sessions
     WHERE user_id=$1 AND ended_at IS NULL ORDER BY started_at DESC LIMIT 1`,
    [uid(req)]
  );
  const history = await q(
    `SELECT id, started_at, ended_at, target_hours, completed
     FROM fasting_sessions WHERE user_id=$1 AND ended_at IS NOT NULL
     ORDER BY started_at DESC LIMIT 14`,
    [uid(req)]
  );
  res.json({ active: active.rows[0] || null, history: history.rows });
});

// POST /fasting/start { target_hours }
router.post('/start', async (req, res) => {
  const target = Number(req.body?.target_hours ?? 16);
  // End any existing active session first
  await q(`UPDATE fasting_sessions SET ended_at=NOW(), completed=FALSE
           WHERE user_id=$1 AND ended_at IS NULL`, [uid(req)]);
  const r = await q(
    `INSERT INTO fasting_sessions (user_id, target_hours) VALUES ($1,$2) RETURNING id, started_at`,
    [uid(req), target]
  );
  res.json({ session: r.rows[0] });
});

// POST /fasting/stop
router.post('/stop', async (req, res) => {
  const active = await q(
    `SELECT id, started_at, target_hours FROM fasting_sessions
     WHERE user_id=$1 AND ended_at IS NULL ORDER BY started_at DESC LIMIT 1`,
    [uid(req)]
  );
  if (!active.rows[0]) return res.status(400).json({ message: 'No active session' });

  const session = active.rows[0];
  const hoursElapsed = (Date.now() - new Date(session.started_at).getTime()) / 3600000;
  const completed = hoursElapsed >= session.target_hours;

  await q(
    `UPDATE fasting_sessions SET ended_at=NOW(), completed=$2 WHERE id=$1`,
    [session.id, completed]
  );

  let xpAwarded = 0;
  if (completed) {
    xpAwarded = 15;
    await q(`UPDATE users SET xp=xp+15, total_xp=total_xp+15 WHERE id=$1`, [uid(req)]);
    await q(`UPDATE group_members SET weekly_xp=weekly_xp+15
             WHERE user_id=$1`, [uid(req)]);
    markTasksDoneByIcon(uid(req), ['timer', 'fastfood']).catch(() => {});

    // Award fasting_pro badge after 30 completed sessions
    const count = await q(
      `SELECT COUNT(*) FROM fasting_sessions WHERE user_id=$1 AND completed=TRUE`,
      [uid(req)]
    );
    if (Number(count.rows[0].count) >= 30) {
      const b = await q(`SELECT id FROM badges WHERE code='fasting_pro'`);
      if (b.rows[0]) {
        await q(
          `INSERT INTO user_badges (user_id, badge_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
          [uid(req), b.rows[0].id]
        );
      }
    }
  }

  res.json({ completed, hours_elapsed: Math.round(hoursElapsed * 10) / 10, xp_awarded: xpAwarded });
});

export default router;
