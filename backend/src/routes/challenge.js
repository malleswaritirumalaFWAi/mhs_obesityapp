import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

// Auto-compute challenge progress from actual user data for the current week date range.
async function computeProgress(userId, challenge, weekStart, weekEnd) {
  const s = weekStart.toISOString().slice(0, 10); // 'YYYY-MM-DD'
  const e = weekEnd.toISOString().slice(0, 10);
  const { type, target } = challenge;

  try {
    if (type === 'steps') {
      if (target <= 30) {
        // Count days this week where user logged >= 8000 steps
        const r = await q(
          `SELECT COUNT(*) FROM daily_stats
           WHERE user_id=$1 AND date>=$2 AND date<$3 AND steps>=8000`,
          [userId, s, e]
        );
        return Math.min(Number(r.rows[0].count), target);
      } else {
        // Total accumulated steps this week (e.g. 60,000 target)
        const r = await q(
          `SELECT COALESCE(SUM(steps),0) AS total FROM daily_stats
           WHERE user_id=$1 AND date>=$2 AND date<$3`,
          [userId, s, e]
        );
        return Math.min(Number(r.rows[0].total), target);
      }
    }

    if (type === 'sleep') {
      const r = await q(
        `SELECT COUNT(*) FROM daily_stats
         WHERE user_id=$1 AND date>=$2 AND date<$3 AND sleep>=7`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'water') {
      const r = await q(
        `SELECT COUNT(*) FROM daily_stats
         WHERE user_id=$1 AND date>=$2 AND date<$3 AND water>=8`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'meals') {
      // Count days where all 4 meal types were logged
      const r = await q(
        `SELECT COUNT(*) FROM (
           SELECT DATE(created_at) AS day
           FROM meals WHERE user_id=$1
             AND DATE(created_at)>=$2 AND DATE(created_at)<$3
           GROUP BY day HAVING COUNT(DISTINCT meal_type)>=4
         ) x`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'fasting') {
      // Count completed fasting sessions >= 14 hours this week
      const r = await q(
        `SELECT COUNT(*) FROM fasting_sessions
         WHERE user_id=$1 AND completed=true
           AND target_hours>=14
           AND DATE(started_at)>=$2 AND DATE(started_at)<$3`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'streak') {
      // Count distinct active days (any steps logged, any checkin, any meal)
      const r = await q(
        `SELECT COUNT(DISTINCT d) FROM (
           SELECT date AS d FROM daily_stats
             WHERE user_id=$1 AND date>=$2 AND date<$3 AND (steps>0 OR water>0 OR sleep>0)
           UNION
           SELECT DATE(created_at) FROM checkins
             WHERE user_id=$1 AND DATE(created_at)>=$2 AND DATE(created_at)<$3
           UNION
           SELECT DATE(created_at) FROM meals
             WHERE user_id=$1 AND DATE(created_at)>=$2 AND DATE(created_at)<$3
         ) x`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'tasks') {
      // Count days where at least 4 tasks were completed
      const r = await q(
        `SELECT COUNT(*) FROM (
           SELECT DATE(completed_at) AS day
           FROM tasks WHERE user_id=$1 AND completed=true
             AND DATE(completed_at)>=$2 AND DATE(completed_at)<$3
           GROUP BY day HAVING COUNT(*)>=4
         ) x`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }
  } catch (err) {
    console.warn('[computeProgress]', err.message);
  }
  return 0;
}

router.get('/current', async (req, res) => {
  try {
    // Determine current program week from users.created_at
    const row = (await q(`SELECT created_at FROM users WHERE id=$1`, [uid(req)])).rows[0];
    const createdAt = row?.created_at ? new Date(row.created_at) : new Date();
    const today = new Date(); today.setHours(0, 0, 0, 0);
    const diffDays = Math.floor((today - new Date(createdAt).setHours(0, 0, 0, 0)) / 86400000);
    const weekNum = Math.min(12, Math.max(1, Math.floor(diffDays / 7) + 1));

    // Week date range for auto-progress computation
    const weekStart = new Date(createdAt);
    weekStart.setHours(0, 0, 0, 0);
    weekStart.setDate(weekStart.getDate() + (weekNum - 1) * 7);
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekEnd.getDate() + 7);

    // Load all 12 challenges
    const allChallenges = (await q(`SELECT * FROM weekly_challenges ORDER BY week_number`)).rows;

    // Get current week's challenge
    let challenge = allChallenges.find(c => c.week_number === weekNum) || allChallenges[0] || null;

    let entry = null;
    if (challenge) {
      // Auto-compute progress from actual data
      const autoProgress = await computeProgress(uid(req), challenge, weekStart, weekEnd);
      const completed = autoProgress >= challenge.target;

      // Upsert the entry with computed progress
      const ins = await q(
        `INSERT INTO challenge_entries (user_id,challenge_id,progress,completed,completed_at)
         VALUES ($1,$2,$3,$4,$5)
         ON CONFLICT (user_id,challenge_id) DO UPDATE
           SET progress=GREATEST(challenge_entries.progress, EXCLUDED.progress),
               completed=EXCLUDED.completed,
               completed_at=COALESCE(challenge_entries.completed_at, EXCLUDED.completed_at)
         RETURNING *`,
        [uid(req), challenge.id, autoProgress, completed, completed ? new Date() : null]
      );
      entry = ins.rows[0] || null;

      // Award XP if newly completed
      if (completed && entry?.completed) {
        const prev = await q(
          `SELECT id FROM notifications WHERE user_id=$1 AND type='challenge' AND data->>'challenge_id'=$2`,
          [uid(req), String(challenge.id)]
        );
        if (!prev.rows[0]) {
          await q(`UPDATE users SET xp=xp+$2, total_xp=total_xp+$2 WHERE id=$1`, [uid(req), challenge.xp_reward]);
          await q(`UPDATE group_members SET weekly_xp=weekly_xp+$2 WHERE user_id=$1`, [uid(req), challenge.xp_reward]);
          await q(
            `INSERT INTO notifications (user_id,type,title,body,data)
             VALUES ($1,'challenge','Challenge complete! 🎉','You completed Week ${weekNum}: ${challenge.title}! +${challenge.xp_reward} XP',$3)`,
            [uid(req), JSON.stringify({ challenge_id: String(challenge.id) })]
          ).catch(() => {});
        }
      }
    }

    // Load all user entries so Flutter can show completion status for each week
    const allEntries = (await q(
      `SELECT ce.challenge_id, ce.progress, ce.completed
       FROM challenge_entries ce
       WHERE ce.user_id=$1`,
      [uid(req)]
    )).rows;

    res.json({
      challenge,
      entry,
      current_week: weekNum,
      all_challenges: allChallenges,
      all_entries: allEntries,  // keyed by challenge_id
    });
  } catch (e) {
    console.error('[challenge/current]', e.message);
    res.status(500).json({ message: e.message });
  }
});

router.post('/:id/progress', async (req, res) => {
  const { progress } = req.body || {};
  const challengeId = req.params.id;
  const challenge = (await q(`SELECT * FROM weekly_challenges WHERE id=$1`, [challengeId])).rows[0];
  if (!challenge) return res.status(404).json({ message: 'Challenge not found' });

  const entry = (await q(
    `SELECT * FROM challenge_entries WHERE user_id=$1 AND challenge_id=$2 LIMIT 1`,
    [uid(req), challengeId]
  )).rows[0];

  const alreadyCompleted = entry?.completed;
  const newProgress = Math.max(entry?.progress ?? 0, Number(progress) || 0);
  const completed = newProgress >= challenge.target;

  await q(
    `INSERT INTO challenge_entries (user_id,challenge_id,progress,completed,completed_at)
     VALUES ($1,$2,$3,$4,$5)
     ON CONFLICT (user_id,challenge_id) DO UPDATE
       SET progress=EXCLUDED.progress, completed=EXCLUDED.completed,
           completed_at=COALESCE(challenge_entries.completed_at,EXCLUDED.completed_at)`,
    [uid(req), challengeId, newProgress, completed, completed ? new Date() : null]
  );

  let xpEarned = 0;
  if (completed && !alreadyCompleted) {
    xpEarned = challenge.xp_reward;
    await q(`UPDATE users SET xp=xp+$2, total_xp=total_xp+$2 WHERE id=$1`, [uid(req), xpEarned]);
    await q(`UPDATE group_members SET weekly_xp=weekly_xp+$2 WHERE user_id=$1`, [uid(req), xpEarned]);
    await q(
      `INSERT INTO notifications (user_id,type,title,body) VALUES ($1,'challenge','Challenge complete!','You completed this week''s challenge! +${xpEarned} XP')`,
      [uid(req)]
    ).catch(() => {});
  }
  res.json({ progress: newProgress, completed, xp_earned: xpEarned });
});

export default router;
