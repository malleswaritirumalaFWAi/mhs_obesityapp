import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

async function currentWeek(userId) {
  const gid = (await q(`SELECT group_id FROM group_members WHERE user_id=$1 LIMIT 1`, [userId])).rows[0]?.group_id;
  const g = gid ? (await q(`SELECT starts_on FROM groups WHERE id=$1`, [gid])).rows[0] : null;
  const startsOn = g?.starts_on ? new Date(g.starts_on) : new Date();
  const diff = Date.now() - startsOn.setHours(0, 0, 0, 0);
  return Math.min(Math.max(Math.ceil((diff / 86400000) / 7), 1), 12);
}

// GET /challenge/current — this week's challenge + user progress
router.get('/current', async (req, res) => {
  const week = await currentWeek(uid(req));
  const challenge = await q(
    `SELECT * FROM weekly_challenges WHERE week_number=$1 LIMIT 1`, [week]
  );
  if (!challenge.rows[0]) return res.json({ challenge: null });

  const entry = await q(
    `SELECT progress, completed, completed_at
     FROM challenge_entries WHERE user_id=$1 AND challenge_id=$2`,
    [uid(req), challenge.rows[0].id]
  );
  res.json({ challenge: challenge.rows[0], entry: entry.rows[0] || null, current_week: week });
});

// POST /challenge/:id/progress { progress } — update challenge progress
router.post('/:id/progress', async (req, res) => {
  const challengeId = req.params.id;
  const progress = Number(req.body?.progress ?? 0);
  const challenge = await q(`SELECT * FROM weekly_challenges WHERE id=$1`, [challengeId]);
  if (!challenge.rows[0]) return res.status(404).json({ message: 'Challenge not found' });

  const c = challenge.rows[0];
  const wasCompleted = progress >= c.target;

  const r = await q(
    `INSERT INTO challenge_entries (user_id, challenge_id, progress, completed, completed_at)
     VALUES ($1,$2,$3,$4,$5)
     ON CONFLICT (user_id, challenge_id) DO UPDATE
       SET progress=GREATEST(challenge_entries.progress,$3),
           completed=$4,
           completed_at=COALESCE(challenge_entries.completed_at,$5)
     RETURNING completed, (xacts_prevcommand IS NOT DISTINCT FROM 'INSERT') AS is_new`,
    [uid(req), challengeId, progress, wasCompleted, wasCompleted ? new Date() : null]
  );

  let xpAwarded = 0;
  const entry = (await q(`SELECT completed FROM challenge_entries WHERE user_id=$1 AND challenge_id=$2`,
    [uid(req), challengeId])).rows[0];

  if (wasCompleted && entry?.completed) {
    // Check if first time completing
    const justCompleted = (await q(
      `SELECT COUNT(*) FROM challenge_entries WHERE user_id=$1 AND challenge_id=$2 AND completed=TRUE`,
      [uid(req), challengeId]
    )).rows[0].count;

    if (Number(justCompleted) === 1) {
      xpAwarded = c.xp_reward;
      await q(`UPDATE users SET xp=xp+$2, total_xp=total_xp+$2 WHERE id=$1`, [uid(req), xpAwarded]);
      await q(`UPDATE group_members SET weekly_xp=weekly_xp+$2 WHERE user_id=$1`, [uid(req), xpAwarded]);
      await q(
        `INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'challenge_complete','🏆 Challenge Complete!','You completed the weekly challenge and earned ${xpAwarded} XP!')`,
        [uid(req)]
      );
    }
  }

  res.json({ progress, completed: wasCompleted, xp_awarded: xpAwarded });
});

export default router;
