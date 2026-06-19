import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';
import { markTasksDoneByIcon } from '../tasks.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

// GET /reflection?type=evening|weekly — last 14 entries
router.get('/', async (req, res) => {
  const type = req.query.type || 'evening';
  const r = await q(
    `SELECT id, type, text, mood, created_at FROM reflections
     WHERE user_id=$1 AND type=$2 ORDER BY created_at DESC LIMIT 14`,
    [uid(req), type]
  );
  res.json({ reflections: r.rows });
});

// POST /reflection { type, text, mood }
router.post('/', async (req, res) => {
  const { type = 'evening', text, mood } = req.body || {};
  if (!text?.trim() && mood === undefined) {
    return res.status(400).json({ message: 'text or mood required' });
  }
  await q(
    `INSERT INTO reflections (user_id, type, text, mood) VALUES ($1,$2,$3,$4)`,
    [uid(req), type, text || null, mood ?? null]
  );

  let xpAwarded = 10;
  await q(`UPDATE users SET xp=xp+10, total_xp=total_xp+10 WHERE id=$1`, [uid(req)]);
  await q(`UPDATE group_members SET weekly_xp=weekly_xp+10 WHERE user_id=$1`, [uid(req)]);

  // Mark evening reflection task done
  if (type === 'evening') {
    markTasksDoneByIcon(uid(req), ['self_improvement', 'edit_note']).catch(() => {});
  }

  // Perfect day check: did user complete all core tasks today?
  const today = new Date().toISOString().slice(0, 10);
  const taskCheck = await q(
    `SELECT COUNT(*) FILTER (WHERE done) AS done, COUNT(*) AS total
     FROM tasks WHERE user_id=$1 AND DATE(COALESCE(completed_at, 'epoch')) = $2`,
    [uid(req), today]
  );
  const done = Number(taskCheck.rows[0]?.done ?? 0);
  const total = Number(taskCheck.rows[0]?.total ?? 0);
  let bonusXp = 0;
  if (total >= 5 && done >= total) {
    bonusXp = 30;
    await q(`UPDATE users SET xp=xp+30, total_xp=total_xp+30 WHERE id=$1`, [uid(req)]);
    await q(`UPDATE group_members SET weekly_xp=weekly_xp+30 WHERE user_id=$1`, [uid(req)]);
    await q(
      `INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'perfect_day','🌟 Perfect Day!','You completed every task today! +30 bonus XP')`,
      [uid(req)]
    );
  }

  res.json({ saved: true, xp_awarded: xpAwarded + bonusXp, bonus_xp: bonusXp });
});

export default router;
