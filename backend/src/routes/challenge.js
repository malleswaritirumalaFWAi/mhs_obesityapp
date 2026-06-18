import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

// ── computeProgress: total qualifying units for the week ─────────────────────

async function computeProgress(userId, challenge, weekStart, weekEnd) {
  const s = weekStart.toISOString().slice(0, 10);
  const e = weekEnd.toISOString().slice(0, 10);
  const { type, target } = challenge;
  const minVal = challenge.min_value ?? 0;

  try {
    // New challenge types
    if (type === 'weight_daily') {
      const r = await q(
        `SELECT COUNT(DISTINCT DATE(created_at)) FROM checkins
         WHERE user_id=$1 AND created_at>=$2 AND created_at<$3 AND weight>0`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'weight_and_meals') {
      const r = await q(
        `SELECT COUNT(*) FROM (
          SELECT DATE(c.created_at) AS day FROM checkins c
          WHERE c.user_id=$1 AND DATE(c.created_at)>=$2 AND DATE(c.created_at)<$3 AND c.weight>0
            AND (SELECT COUNT(DISTINCT meal_type) FROM meals m
                 WHERE m.user_id=$1 AND DATE(m.created_at)=DATE(c.created_at)) >= 3
          GROUP BY day
        ) x`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'steps_min_days') {
      const minSteps = minVal || 8000;
      const r = await q(
        `SELECT COUNT(*) FROM daily_stats
         WHERE user_id=$1 AND date>=$2 AND date<$3 AND steps>=$4`,
        [userId, s, e, minSteps]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'sleep_days') {
      const r = await q(
        `SELECT COUNT(*) FROM daily_stats
         WHERE user_id=$1 AND date>=$2 AND date<$3 AND sleep>=7`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'morning_checkin') {
      const r = await q(
        `SELECT COUNT(DISTINCT DATE(created_at)) FROM checkins
         WHERE user_id=$1 AND created_at>=$2 AND created_at<$3 AND mood IS NOT NULL`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'steps_and_meals') {
      const minSteps = minVal || 5000;
      const r = await q(
        `SELECT COUNT(*) FROM (
          SELECT ds.date AS day FROM daily_stats ds
          WHERE ds.user_id=$1 AND ds.date>=$2 AND ds.date<$3 AND ds.steps>=$4
            AND (SELECT COUNT(DISTINCT meal_type) FROM meals m
                 WHERE m.user_id=$1 AND DATE(m.created_at)=ds.date) >= 3
        ) x`,
        [userId, s, e, minSteps]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'meal_all_days') {
      const r = await q(
        `SELECT COUNT(*) FROM (
           SELECT DATE(created_at) AS day FROM meals WHERE user_id=$1
             AND DATE(created_at)>=$2 AND DATE(created_at)<$3
           GROUP BY day HAVING COUNT(DISTINCT meal_type)>=3
         ) x`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'all_tasks') {
      const r = await q(
        `SELECT COUNT(*) FROM (
           SELECT DATE(completed_at) AS day FROM tasks
           WHERE user_id=$1 AND done=TRUE
             AND DATE(completed_at)>=$2 AND DATE(completed_at)<$3
           GROUP BY day HAVING COUNT(*)>=5
         ) x`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'transformation_proof') {
      const r = await q(
        `SELECT COUNT(*) FROM (
           SELECT DATE(created_at) AS day FROM checkins
           WHERE user_id=$1 AND DATE(created_at)>=$2 AND DATE(created_at)<$3
           GROUP BY day
           HAVING SUM(CASE WHEN weight > 0 THEN 1 ELSE 0 END) > 0
              AND SUM(CASE WHEN mood IS NOT NULL THEN 1 ELSE 0 END) > 0
         ) x`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    // Legacy types (backward compat)
    if (type === 'steps') {
      if (target <= 30) {
        const r = await q(
          `SELECT COUNT(*) FROM daily_stats WHERE user_id=$1 AND date>=$2 AND date<$3 AND steps>=8000`,
          [userId, s, e]
        );
        return Math.min(Number(r.rows[0].count), target);
      } else {
        const r = await q(
          `SELECT COALESCE(SUM(steps),0) AS total FROM daily_stats WHERE user_id=$1 AND date>=$2 AND date<$3`,
          [userId, s, e]
        );
        return Math.min(Number(r.rows[0].total), target);
      }
    }

    if (type === 'sleep') {
      const r = await q(
        `SELECT COUNT(*) FROM daily_stats WHERE user_id=$1 AND date>=$2 AND date<$3 AND sleep>=7`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'water') {
      const r = await q(
        `SELECT COUNT(*) FROM daily_stats WHERE user_id=$1 AND date>=$2 AND date<$3 AND water>=8`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'meals') {
      const r = await q(
        `SELECT COUNT(*) FROM (
           SELECT DATE(created_at) AS day FROM meals WHERE user_id=$1
             AND DATE(created_at)>=$2 AND DATE(created_at)<$3
           GROUP BY day HAVING COUNT(DISTINCT meal_type)>=4
         ) x`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'fasting') {
      const r = await q(
        `SELECT COUNT(*) FROM fasting_sessions WHERE user_id=$1 AND completed=true
           AND target_hours>=14 AND DATE(started_at)>=$2 AND DATE(started_at)<$3`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'streak') {
      const r = await q(
        `SELECT COUNT(DISTINCT d) FROM (
           SELECT date AS d FROM daily_stats
             WHERE user_id=$1 AND date>=$2 AND date<$3 AND (steps>0 OR water>0 OR sleep>0)
           UNION
           SELECT DATE(created_at) FROM checkins WHERE user_id=$1 AND DATE(created_at)>=$2 AND DATE(created_at)<$3
           UNION
           SELECT DATE(created_at) FROM meals WHERE user_id=$1 AND DATE(created_at)>=$2 AND DATE(created_at)<$3
         ) x`,
        [userId, s, e]
      );
      return Math.min(Number(r.rows[0].count), target);
    }

    if (type === 'tasks') {
      const r = await q(
        `SELECT COUNT(*) FROM (
           SELECT DATE(completed_at) AS day FROM tasks WHERE user_id=$1 AND done=TRUE
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

// ── computeDayProgress: per-day boolean array for the current 7-day week ─────

async function computeDayProgress(userId, challenge, weekStart) {
  const { type } = challenge;
  const minVal = challenge.min_value ?? 0;
  const days = [];

  for (let i = 0; i < 7; i++) {
    const day = new Date(weekStart);
    day.setDate(day.getDate() + i);
    const dayStr = day.toISOString().slice(0, 10);

    // Only check past/current days
    const today = new Date();
    today.setHours(23, 59, 59, 999);
    if (day > today) { days.push(false); continue; }

    try {
      let met = false;

      if (type === 'weight_daily') {
        const r = await q(`SELECT COUNT(*) FROM checkins WHERE user_id=$1 AND DATE(created_at)=$2 AND weight>0`, [userId, dayStr]);
        met = Number(r.rows[0].count) > 0;
      } else if (type === 'weight_and_meals') {
        const w = await q(`SELECT COUNT(*) FROM checkins WHERE user_id=$1 AND DATE(created_at)=$2 AND weight>0`, [userId, dayStr]);
        if (Number(w.rows[0].count) > 0) {
          const m = await q(`SELECT COUNT(DISTINCT meal_type) FROM meals WHERE user_id=$1 AND DATE(created_at)=$2`, [userId, dayStr]);
          met = Number(m.rows[0].count) >= 3;
        }
      } else if (type === 'steps_min_days') {
        const min = minVal || 8000;
        const r = await q(`SELECT steps FROM daily_stats WHERE user_id=$1 AND date=$2`, [userId, dayStr]);
        met = (r.rows[0]?.steps ?? 0) >= min;
      } else if (type === 'sleep_days') {
        const r = await q(`SELECT sleep FROM daily_stats WHERE user_id=$1 AND date=$2`, [userId, dayStr]);
        met = (r.rows[0]?.sleep ?? 0) >= 7;
      } else if (type === 'morning_checkin') {
        const r = await q(`SELECT COUNT(*) FROM checkins WHERE user_id=$1 AND DATE(created_at)=$2 AND mood IS NOT NULL`, [userId, dayStr]);
        met = Number(r.rows[0].count) > 0;
      } else if (type === 'steps_and_meals') {
        const min = minVal || 5000;
        const s = await q(`SELECT steps FROM daily_stats WHERE user_id=$1 AND date=$2`, [userId, dayStr]);
        if ((s.rows[0]?.steps ?? 0) >= min) {
          const m = await q(`SELECT COUNT(DISTINCT meal_type) FROM meals WHERE user_id=$1 AND DATE(created_at)=$2`, [userId, dayStr]);
          met = Number(m.rows[0].count) >= 3;
        }
      } else if (type === 'meal_all_days') {
        const r = await q(`SELECT COUNT(DISTINCT meal_type) FROM meals WHERE user_id=$1 AND DATE(created_at)=$2`, [userId, dayStr]);
        met = Number(r.rows[0].count) >= 3;
      } else if (type === 'all_tasks') {
        const r = await q(`SELECT COUNT(*) FROM tasks WHERE user_id=$1 AND DATE(completed_at)=$2 AND done=TRUE`, [userId, dayStr]);
        met = Number(r.rows[0].count) >= 5;
      } else if (type === 'transformation_proof') {
        const r = await q(
          `SELECT SUM(CASE WHEN weight>0 THEN 1 ELSE 0 END) AS w,
                  SUM(CASE WHEN mood IS NOT NULL THEN 1 ELSE 0 END) AS m
           FROM checkins WHERE user_id=$1 AND DATE(created_at)=$2`,
          [userId, dayStr]
        );
        met = Number(r.rows[0]?.w ?? 0) > 0 && Number(r.rows[0]?.m ?? 0) > 0;
      } else {
        // Legacy: any activity
        const r = await q(`SELECT COUNT(*) FROM daily_stats WHERE user_id=$1 AND date=$2 AND (steps>0 OR water>0 OR sleep>0)`, [userId, dayStr]);
        met = Number(r.rows[0].count) > 0;
      }

      days.push(met);
    } catch (err) {
      console.warn('[computeDayProgress day]', err.message);
      days.push(false);
    }
  }
  return days;
}

// ── GET /challenge/current ────────────────────────────────────────────────────

router.get('/current', async (req, res) => {
  try {
    const row = (await q(`SELECT created_at, start_weight, streak, COALESCE(total_xp,0) as total_xp FROM users WHERE id=$1`, [uid(req)])).rows[0];
    const createdAt = row?.created_at ? new Date(row.created_at) : new Date();
    const today = new Date(); today.setHours(0, 0, 0, 0);
    const diffDays = Math.floor((today - new Date(createdAt).setHours(0, 0, 0, 0)) / 86400000);
    const weekNum = Math.min(12, Math.max(1, Math.floor(diffDays / 7) + 1));

    const weekStart = new Date(createdAt);
    weekStart.setHours(0, 0, 0, 0);
    weekStart.setDate(weekStart.getDate() + (weekNum - 1) * 7);
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekEnd.getDate() + 7);

    const allChallenges = (await q(`SELECT * FROM weekly_challenges ORDER BY week_number`)).rows;
    let challenge = allChallenges.find(c => c.week_number === weekNum) || allChallenges[0] || null;

    let entry = null;
    let dayProgress = Array(7).fill(false);

    if (challenge) {
      const [autoProgress, dayProg] = await Promise.all([
        computeProgress(uid(req), challenge, weekStart, weekEnd),
        computeDayProgress(uid(req), challenge, weekStart),
      ]);
      dayProgress = dayProg;
      const completed = autoProgress >= challenge.target;

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

      if (completed && entry?.completed) {
        const prev = await q(
          `SELECT id FROM notifications WHERE user_id=$1 AND type='challenge' AND data->>'challenge_id'=$2`,
          [uid(req), String(challenge.id)]
        );
        if (!prev.rows[0]) {
          await q(`UPDATE users SET xp=xp+$2, total_xp=COALESCE(total_xp,0)+$2 WHERE id=$1`, [uid(req), challenge.xp_reward]);
          await q(`UPDATE group_members SET weekly_xp=weekly_xp+$2 WHERE user_id=$1`, [uid(req), challenge.xp_reward]);
          await q(
            `INSERT INTO notifications (user_id,type,title,body,data)
             VALUES ($1,'challenge','Challenge complete! 🎉',$2,$3)`,
            [uid(req), `You completed Week ${weekNum}: ${challenge.title}! +${challenge.xp_reward} XP`,
             JSON.stringify({ challenge_id: String(challenge.id) })]
          ).catch(() => {});
        }
      }
    }

    const allEntries = (await q(
      `SELECT ce.challenge_id, ce.progress, ce.completed, ce.completed_at FROM challenge_entries ce WHERE ce.user_id=$1`,
      [uid(req)]
    )).rows;

    // Weight history per program week for milestone charts
    const createdAtStr = createdAt.toISOString().slice(0, 10);
    const weightHistoryRows = (await q(
      `SELECT
         LEAST(12, GREATEST(1, FLOOR(DATE_PART('day', DATE(created_at) - $2::date) / 7) + 1))::int AS week_num,
         ROUND(AVG(weight)::numeric, 1) AS avg_weight
       FROM checkins
       WHERE user_id=$1 AND weight>0
       GROUP BY week_num ORDER BY week_num`,
      [uid(req), createdAtStr]
    ).catch(() => ({ rows: [] }))).rows;

    // Latest weight for milestone display
    const latestWeightRow = (await q(
      `SELECT weight FROM checkins WHERE user_id=$1 AND weight>0 ORDER BY created_at DESC LIMIT 1`,
      [uid(req)]
    )).rows[0];

    // Total steps ever
    const totalStepsRow = (await q(
      `SELECT COALESCE(SUM(steps),0) AS total FROM daily_stats WHERE user_id=$1`,
      [uid(req)]
    )).rows[0];

    res.json({
      challenge,
      entry,
      current_week: weekNum,
      all_challenges: allChallenges,
      all_entries: allEntries,
      day_progress: dayProgress,
      week_start: weekStart.toISOString().slice(0, 10),
      // Milestone data
      start_weight: row?.start_weight ?? null,
      current_weight: latestWeightRow?.weight ?? null,
      total_xp: row?.total_xp ?? 0,
      longest_streak: row?.streak ?? 0,
      total_steps: Number(totalStepsRow?.total ?? 0),
      weight_history: weightHistoryRows,
    });
  } catch (e) {
    console.error('[challenge/current]', e.message);
    res.status(500).json({ message: e.message });
  }
});

// ── POST /challenge/:id/progress ──────────────────────────────────────────────

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
    await q(`UPDATE users SET xp=xp+$2, total_xp=COALESCE(total_xp,0)+$2 WHERE id=$1`, [uid(req), xpEarned]);
    await q(`UPDATE group_members SET weekly_xp=weekly_xp+$2 WHERE user_id=$1`, [uid(req), xpEarned]);
  }
  res.json({ progress: newProgress, completed, xp_earned: xpEarned });
});

export default router;
