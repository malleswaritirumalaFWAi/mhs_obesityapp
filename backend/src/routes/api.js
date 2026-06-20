import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';
import { ensureTasksForDay, ensureTasksForToday, TASK_TEMPLATES, markTasksDoneByIcon } from '../tasks.js';
import { updateUserLevel } from './gamification.js';

const router = Router();
router.use(authMiddleware);

const uid = (req) => req.user.uid;

// Resolves the user's actual group. Falls back to the first existing group, or null.
async function groupId(userId) {
  const r = await q(`SELECT group_id FROM group_members WHERE user_id=$1 LIMIT 1`, [userId]);
  if (r.rows[0]?.group_id) return r.rows[0].group_id;
  // Not in any group — use first available group (group_id is nullable in posts/leaderboard)
  const g = await q(`SELECT id FROM groups ORDER BY id LIMIT 1`);
  return g.rows[0]?.id ?? null;
}


// ---- Profile + quiz ----
router.get('/profile', async (req, res) => {
  const u = await q(`SELECT id, phone, email, name, onboarded, xp, streak, start_weight, target_weight FROM users WHERE id=$1`, [uid(req)]);
  const p = await q(`SELECT gender, activity, goal, food_pref, challenge FROM profiles WHERE user_id=$1`, [uid(req)]);
  const badges = await q(
    `SELECT b.emoji, b.name FROM user_badges ub JOIN badges b ON b.id=ub.badge_id WHERE ub.user_id=$1 ORDER BY ub.earned_at DESC`,
    [uid(req)]
  );
  // Ensure today's tasks exist for this user (runs on every login — no-op if already seeded).
  ensureTasksForToday(uid(req)).catch((e) =>
    console.warn('[tasks] bootstrap failed:', e.message)
  );
  res.json({ user: u.rows[0] || null, profile: p.rows[0] || null, badges: badges.rows });
});

router.post('/profile/onboarded', async (req, res) => {
  await q(`UPDATE users SET onboarded=TRUE WHERE id=$1`, [uid(req)]);
  res.json({ onboarded: true });
});

router.post('/profile/quiz', async (req, res) => {
  const { gender, activity, goal, food_pref, challenge, name, medical_conditions, medications,
          dpdp_consent, medical_disclaimer_accepted, language, height, start_weight, target_weight } = req.body || {};
  await q(
    `INSERT INTO profiles (user_id, gender, activity, goal, food_pref, challenge, medical_conditions, medications, dpdp_consent, medical_disclaimer_accepted, language)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
     ON CONFLICT (user_id) DO UPDATE SET gender=$2, activity=$3, goal=$4, food_pref=$5, challenge=$6,
       medical_conditions=$7, medications=$8, dpdp_consent=$9, medical_disclaimer_accepted=$10, language=$11`,
    [uid(req), gender, activity, goal, food_pref, challenge,
     medical_conditions || null, medications || null,
     dpdp_consent ?? false, medical_disclaimer_accepted ?? false, language || 'en']
  );
  const updates = [];
  const vals = [uid(req)];
  if (name) { vals.push(name); updates.push(`name=$${vals.length}`); }
  if (height) { vals.push(Number(height)); updates.push(`height=$${vals.length}`); }
  if (start_weight) { vals.push(Number(start_weight)); updates.push(`start_weight=$${vals.length}`); }
  if (target_weight) { vals.push(Number(target_weight)); updates.push(`target_weight=$${vals.length}`); }
  if (language) { vals.push(language); updates.push(`language=$${vals.length}`); }
  if (updates.length > 0) {
    await q(`UPDATE users SET ${updates.join(',')} WHERE id=$1`, vals);
  }
  res.json({ saved: true });
});

// ---- Coach / plan info ----
router.get('/coach', async (req, res) => {
  const gid = await groupId(uid(req));
  const r = await q(
    `SELECT c.name, c.title, c.rating, c.avatar, g.name AS batch, g.starts_on
     FROM groups g JOIN coaches c ON c.id=g.coach_id WHERE g.id=$1`,
    [gid]
  );
  res.json(r.rows[0] || {});
});

// ---- Dashboard summary ----
router.get('/dashboard', async (req, res) => {
  try {
    const u = (await q(`SELECT name, xp, total_xp, streak, streak_freezes, level, created_at FROM users WHERE id=$1`, [uid(req)])).rows[0] || {};

    // Calculate current program day from users.created_at (authoritative registration date).
    // group_members.joined_at is unreliable — the ALTER TABLE migration backfills existing
    // rows with now(), so users registered before the migration get Day 1 every day.
    const createdAt = u.created_at ? new Date(u.created_at) : new Date();
    const today = new Date();
    const diffMs = today.setHours(0,0,0,0) - new Date(createdAt).setHours(0,0,0,0);
    const dayIndex = Math.min(Math.max(Math.floor(diffMs / 86400000) + 1, 1), 84);
    const gid = await groupId(uid(req));

    const done = (await q(
      `SELECT COUNT(*) FILTER (WHERE done) AS d, COUNT(*) AS t FROM tasks WHERE user_id=$1 AND day_index=$2`,
      [uid(req), dayIndex]
    )).rows[0];

    // Leaderboard rank for the user.
    const rankRow = (await q(
      `SELECT rank FROM (
         SELECT user_id, RANK() OVER (ORDER BY weekly_xp DESC) AS rank
         FROM group_members WHERE group_id=$1
       ) r WHERE user_id=$2`,
      [gid, uid(req)]
    )).rows[0];

    res.json({
      name: u.name || 'User',
      day: dayIndex,
      total_days: 84,
      done: Number(done?.d ?? 0),
      total: Number(done?.t ?? 0),
      steps: 0,
      water: '0/8',
      sleep: '0h',
      rank: Number(rankRow?.rank ?? 0),
      xp: u.xp ?? 0,
      total_xp: u.total_xp ?? 0,
      streak_freezes: u.streak_freezes ?? 0,
      level: u.level ?? 'bronze',
    });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ---- Today's plan ----
router.get('/today', async (req, res) => {
  try {
    // Use query param if provided, otherwise calculate from the user's own join date.
    let dayIndex = Number(req.query.day) || 0;
    if (!dayIndex) {
      const uRow = (await q(`SELECT created_at FROM users WHERE id=$1`, [uid(req)])).rows[0];
      const createdAt = uRow?.created_at ? new Date(uRow.created_at) : new Date();
      const today = new Date();
      const diffMs = today.setHours(0,0,0,0) - new Date(createdAt).setHours(0,0,0,0);
      dayIndex = Math.min(Math.max(Math.floor(diffMs / 86400000) + 1, 1), 84);
    }
    // Auto-seed tasks for this day if none exist yet.
    await ensureTasksForDay(uid(req), dayIndex);
    let r;
    try {
      r = await q(
        `SELECT id, slot, time, icon, title, subtitle, xp, done, completed_at FROM tasks WHERE user_id=$1 AND day_index=$2 ORDER BY time`,
        [uid(req), dayIndex]
      );
    } catch (_) {
      // Fallback if completed_at column not yet migrated
      r = await q(
        `SELECT id, slot, time, icon, title, subtitle, xp, done FROM tasks WHERE user_id=$1 AND day_index=$2 ORDER BY time`,
        [uid(req), dayIndex]
      );
    }
    res.json({ day: dayIndex, tasks: r.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.post('/today/task/:id/complete', async (req, res) => {
  const taskId = parseInt(req.params.id, 10);
  if (!taskId) return res.status(400).json({ message: 'Invalid task id' });

  // Fetch the task to check its icon
  const taskRow = await q(
    `SELECT icon FROM tasks WHERE id=$1 AND user_id=$2`,
    [taskId, uid(req)]
  );
  if (!taskRow.rows[0]) return res.status(404).json({ message: 'Task not found' });

  const icon = taskRow.rows[0].icon;
  const today = new Date().toISOString().slice(0, 10);

  // Goal-based tasks: verify the goal is actually met before marking done
  if (icon === 'water_drop') {
    const r = await q(`SELECT water FROM daily_stats WHERE user_id=$1 AND date=$2`, [uid(req), today]);
    if ((r.rows[0]?.water ?? 0) < 8) return res.status(400).json({ message: 'Goal not met: need 8 glasses' });
  } else if (icon === 'directions_run' || icon === 'directions_walk') {
    const r = await q(`SELECT steps FROM daily_stats WHERE user_id=$1 AND date=$2`, [uid(req), today]);
    if ((r.rows[0]?.steps ?? 0) < 8000) return res.status(400).json({ message: 'Goal not met: need 8000 steps' });
  } else if (icon === 'scale') {
    const r = await q(
      `SELECT id FROM checkins WHERE user_id=$1 AND DATE(created_at)=$2 AND weight IS NOT NULL AND weight > 0`,
      [uid(req), today]
    );
    if (!r.rows[0]) return res.status(400).json({ message: 'Goal not met: log weight first' });
  } else if (icon === 'restaurant' || icon === 'lunch_dining') {
    const r = await q(
      `SELECT DISTINCT meal_type FROM meals WHERE user_id=$1 AND DATE(created_at)=$2`,
      [uid(req), today]
    );
    const types = r.rows.map(row => row.meal_type);
    if (!['Breakfast', 'Lunch', 'Dinner'].every(t => types.includes(t))) {
      return res.status(400).json({ message: 'Goal not met: log Breakfast, Lunch, and Dinner first' });
    }
  }

  await q(
    `UPDATE tasks SET done=TRUE, completed_at=NOW() WHERE id=$1 AND user_id=$2`,
    [taskId, uid(req)]
  );
  res.json({ done: true });
});

// ---- Movement (steps) ----
router.get('/movement', async (req, res) => {
  const today = new Date().toISOString().slice(0, 10);
  const r = await q(
    `SELECT steps FROM daily_stats WHERE user_id=$1 AND date=$2`,
    [uid(req), today]
  );
  res.json({ steps: r.rows[0]?.steps ?? 0 });
});

router.post('/movement/add', async (req, res) => {
  const today = new Date().toISOString().slice(0, 10);
  const add = Math.max(0, parseInt(req.body?.steps ?? 500, 10));
  const goal = 8000;
  const r = await q(
    `INSERT INTO daily_stats (user_id, date, steps) VALUES ($1, $2, $3)
     ON CONFLICT (user_id, date) DO UPDATE SET steps = LEAST(daily_stats.steps + $3, 99999)
     RETURNING steps`,
    [uid(req), today, add]
  );
  const steps = r.rows[0]?.steps ?? 0;
  if (steps >= goal) {
    markTasksDoneByIcon(uid(req), ['directions_run', 'directions_walk']).catch(() => {});
  }
  if (add > 0) await q(`UPDATE users SET xp = xp + 5 WHERE id=$1`, [uid(req)]);
  res.json({ steps, done: steps >= goal });
});

// ---- Hydration ----
router.get('/hydration', async (req, res) => {
  const today = new Date().toISOString().slice(0, 10);
  const r = await q(
    `SELECT water FROM daily_stats WHERE user_id=$1 AND date=$2`,
    [uid(req), today]
  );
  res.json({ glasses: r.rows[0]?.water ?? 0 });
});

router.post('/hydration/add', async (req, res) => {
  const today = new Date().toISOString().slice(0, 10);
  const r = await q(
    `INSERT INTO daily_stats (user_id, date, water) VALUES ($1, $2, 1)
     ON CONFLICT (user_id, date) DO UPDATE SET water = LEAST(daily_stats.water + 1, 8)
     RETURNING water`,
    [uid(req), today]
  );
  const glasses = r.rows[0]?.water ?? 0;
  if (glasses >= 8) {
    markTasksDoneByIcon(uid(req), ['water_drop']).catch(() => {});
  }
  await q(`UPDATE users SET xp = xp + 5 WHERE id=$1`, [uid(req)]);
  res.json({ glasses, done: glasses >= 8 });
});

// ---- Daily stats (steps / water / sleep) ----
router.get('/stats/today', async (req, res) => {
  const today = new Date().toISOString().slice(0, 10);
  const r = await q(
    `INSERT INTO daily_stats (user_id, date) VALUES ($1, $2)
     ON CONFLICT (user_id, date) DO UPDATE SET date = EXCLUDED.date
     RETURNING steps, water, sleep`,
    [uid(req), today]
  );
  res.json(r.rows[0]);
});

router.post('/stats/today', async (req, res) => {
  const today = new Date().toISOString().slice(0, 10);
  const { steps, water, sleep } = req.body || {};
  const sets = [];
  const vals = [uid(req), today];
  if (steps !== undefined) sets.push(`steps = $${vals.push(Number(steps))}`);
  if (water !== undefined) sets.push(`water = $${vals.push(Number(water))}`);
  if (sleep !== undefined) sets.push(`sleep = $${vals.push(Number(sleep))}`);
  if (sets.length === 0) return res.json({ updated: false });
  await q(
    `INSERT INTO daily_stats (user_id, date) VALUES ($1, $2)
     ON CONFLICT (user_id, date) DO UPDATE SET ${sets.join(', ')}`,
    vals
  );
  res.json({ updated: true });
});

// ---- Check-ins ----
router.post('/checkins', async (req, res, next) => {
  try {
  const { mood, weight, notes, tz_offset } = req.body || {};
  if (mood === undefined || mood === null || mood < 0 || mood > 4)
    return res.status(400).json({ message: 'mood must be 0–4' });
  await q(`INSERT INTO checkins (user_id, mood, weight, notes) VALUES ($1,$2,$3,$4)`,
    [uid(req), mood, weight, notes]);

  // Mark morning check-in task done only when BOTH mood AND weight are logged.
  const parsedWeight = weight !== undefined && weight !== null && !isNaN(Number(weight)) && Number(weight) > 0;
  if (parsedWeight) {
    markTasksDoneByIcon(uid(req), ['wb_sunny']).catch(() => {});
  }

  // Streak logic — timezone-aware using client-supplied tz_offset (minutes from UTC).
  // e.g. IST = +330. Falls back to UTC (0) if not provided.
  // We compute local-midnight boundaries as UTC timestamps so all DB comparisons
  // use raw TIMESTAMPTZ ranges — no ::date casts that would silently shift to UTC.
  const tzOffsetMin = Number(tz_offset ?? 0);
  const nowMs = Date.now();
  const localNow = new Date(nowMs + tzOffsetMin * 60000);
  const localMidnightUtc = new Date(
    Date.UTC(localNow.getUTCFullYear(), localNow.getUTCMonth(), localNow.getUTCDate())
    - tzOffsetMin * 60000
  );
  const localTodayEndUtc       = new Date(localMidnightUtc.getTime() + 86400000);
  const localYesterdayStartUtc = new Date(localMidnightUtc.getTime() - 86400000);

  // Has the user already checked in during local-today?
  // OFFSET 1 skips the row we just inserted so we detect a *prior* check-in today.
  const alreadyCheckedToday = (await q(
    `SELECT id FROM checkins
     WHERE user_id=$1 AND mood >= 0
       AND created_at >= $2 AND created_at < $3
     ORDER BY id DESC OFFSET 1 LIMIT 1`,
    [uid(req), localMidnightUtc, localTodayEndUtc]
  )).rows[0];

  const prevUser = (await q(`SELECT streak, total_xp FROM users WHERE id=$1`, [uid(req)])).rows[0] || {};
  const prevStreak = prevUser.streak || 0;

  let xpToAdd = 0;
  let streak = prevStreak;
  let multiplier = 1.0;

  if (!alreadyCheckedToday) {
    // Was the user's previous check-in within the local-yesterday window?
    const lastCheckin = (await q(
      `SELECT created_at FROM checkins
       WHERE user_id=$1 AND mood >= 0
       ORDER BY created_at DESC OFFSET 1 LIMIT 1`,
      [uid(req)]
    )).rows[0];
    const wasYesterday = !!lastCheckin &&
      new Date(lastCheckin.created_at) >= localYesterdayStartUtc &&
      new Date(lastCheckin.created_at) <  localMidnightUtc;

    // Increment if consecutive, reset to 1 otherwise (Snapchat-style).
    const newStreak = wasYesterday ? prevStreak + 1 : 1;
    if (newStreak >= 30) multiplier = 1.5;
    else if (newStreak >= 14) multiplier = 1.2;
    else if (newStreak >= 7) multiplier = 1.1;
    const baseXp = 10;
    xpToAdd = Math.round(baseXp * multiplier);

    const updated = await q(
      `UPDATE users SET xp=xp+$2, total_xp=total_xp+$2, streak=$3 WHERE id=$1 RETURNING streak, total_xp`,
      [uid(req), xpToAdd, newStreak]
    );
    streak = updated.rows[0]?.streak ?? newStreak;
    await q(`UPDATE group_members SET weekly_xp=weekly_xp+$2 WHERE user_id=$1`, [uid(req), xpToAdd]);
  }
  updateUserLevel(uid(req)).catch(() => {});

  // Streak badge milestones
  const streakBadgeMap = { 3:'streak_3', 7:'streak_7', 14:'streak_14', 30:'streak_30', 60:'streak_60' };
  let badgeEarned = false;
  let badge = null;
  const badgeCode = streakBadgeMap[streak];
  if (badgeCode) {
    const b = await q(`SELECT id, emoji, name, xp FROM badges WHERE code=$1`, [badgeCode]);
    if (b.rows[0]) {
      const inserted = await q(
        `INSERT INTO user_badges (user_id, badge_id) VALUES ($1,$2) ON CONFLICT DO NOTHING RETURNING badge_id`,
        [uid(req), b.rows[0].id]
      );
      if (inserted.rows.length > 0) {
        badgeEarned = true;
        badge = { emoji: b.rows[0].emoji, name: b.rows[0].name, xp: b.rows[0].xp, streak };
        await q(
          `INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'badge','${b.rows[0].emoji} Badge Unlocked!','You earned the ${b.rows[0].name} badge!')`,
          [uid(req)]
        );
      }
    }
  }

  // Award freeze every 7-day streak
  if (streak > 0 && streak % 7 === 0) {
    await q(`UPDATE users SET streak_freezes=streak_freezes+1 WHERE id=$1`, [uid(req)]);
  }

  // Milestone weight goal notifications
  const u2 = (await q(`SELECT start_weight, target_weight FROM users WHERE id=$1`, [uid(req)])).rows[0] || {};
  const lastWeight = (await q(`SELECT weight FROM checkins WHERE user_id=$1 AND weight IS NOT NULL ORDER BY created_at DESC LIMIT 1`, [uid(req)])).rows[0]?.weight;
  if (lastWeight && u2.start_weight && u2.target_weight) {
    const totalToLose = u2.start_weight - u2.target_weight;
    const lost = u2.start_weight - lastWeight;
    const pct = totalToLose > 0 ? (lost / totalToLose) * 100 : 0;
    const milestoneMap = { 25: 'Halfway milestone approaching!', 50: '🎯 50% of your goal achieved!', 75: '🏁 75% done — almost there!' };
    for (const [threshold, msg] of Object.entries(milestoneMap)) {
      if (pct >= Number(threshold)) {
        const existing = await q(
          `SELECT id FROM notifications WHERE user_id=$1 AND type='milestone_${threshold}'`, [uid(req)]
        );
        if (!existing.rows[0]) {
          await q(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,$2,'Weight Goal Milestone!',$3)`,
            [uid(req), `milestone_${threshold}`, msg]);
        }
      }
    }
  }

  res.json({ saved: true, xp_awarded: xpToAdd, streak, badge_earned: badgeEarned, badge, multiplier });
  } catch (err) { next(err); }
});

router.get('/checkins', async (req, res) => {
  // mood=-1 entries are evening weigh-ins (logged via /weighin) — exclude them here
  const r = await q(
    `SELECT mood, weight, notes, created_at FROM checkins WHERE user_id=$1 AND mood >= 0 ORDER BY created_at DESC LIMIT 30`,
    [uid(req)]
  );
  res.json({ checkins: r.rows });
});

// ---- Evening weigh-in ----
router.post('/weighin', async (req, res) => {
  const { weight, notes, evening_mood } = req.body || {};
  if (!weight) return res.status(400).json({ message: 'weight is required' });
  const mood = (evening_mood !== undefined && evening_mood !== null && evening_mood >= 0 && evening_mood <= 4)
    ? Number(evening_mood)
    : null;
  await q(
    `INSERT INTO checkins (user_id, mood, weight, notes, evening_mood) VALUES ($1, -1, $2, $3, $4)`,
    [uid(req), parseFloat(weight), notes || null, mood]
  );
  markTasksDoneByIcon(uid(req), ['scale']).catch(() => {});
  await q(`UPDATE users SET xp = xp + 5 WHERE id=$1`, [uid(req)]);
  res.json({ saved: true, xp_awarded: 5 });
});

router.get('/weighin', async (req, res) => {
  // Return only entries that were created via evening weigh-in (mood = -1)
  const r = await q(
    `SELECT weight, notes, evening_mood, created_at FROM checkins
     WHERE user_id=$1 AND mood=-1 AND weight IS NOT NULL
     ORDER BY created_at DESC LIMIT 30`,
    [uid(req)]
  );
  const u = (await q(`SELECT start_weight, target_weight FROM users WHERE id=$1`, [uid(req)])).rows[0] || {};
  res.json({ entries: r.rows, start_weight: u.start_weight, target_weight: u.target_weight });
});

// ---- Group / leaderboard ----
router.get('/group/leaderboard', async (req, res) => {
  const gid = await groupId(uid(req));
  const r = await q(
    `SELECT u.id, COALESCE(u.name, 'Member') AS name, gm.weekly_xp
     FROM group_members gm JOIN users u ON u.id=gm.user_id
     WHERE gm.group_id=$1 ORDER BY gm.weekly_xp DESC LIMIT 50`,
    [gid]
  );
  const leaderboard = r.rows.map((m, i) => ({ ...m, rank: i + 1, you: m.id === uid(req) }));
  res.json({ leaderboard, members: leaderboard }); // both keys for compatibility
});

// ---- Posts ----
router.get('/posts', async (req, res) => {
  try {
    const gid = await groupId(uid(req));
    const r = await q(
      `SELECT p.id, p.user_id, COALESCE(u.name,'Member') AS author, p.body, p.emoji,
              p.coach_pick, p.likes, p.fires, p.comments, p.created_at,
              (EXISTS (SELECT 1 FROM post_likes pl WHERE pl.post_id=p.id AND pl.user_id=$2)) AS user_liked
       FROM posts p JOIN users u ON u.id=p.user_id
       WHERE ($1::bigint IS NULL OR p.group_id = $1)
       ORDER BY p.created_at DESC LIMIT 50`,
      [gid, uid(req)]
    );
    res.json({ posts: r.rows, current_user_id: uid(req) });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.post('/posts', async (req, res) => {
  try {
    const { body, emoji, image_url, post_type } = req.body || {};
    if (!body?.trim()) return res.status(400).json({ message: 'post body is required' });
    const gid = await groupId(uid(req));
    const r = await q(
      `INSERT INTO posts (group_id, user_id, body, emoji, image_url, post_type) VALUES ($1,$2,$3,$4,$5,$6) RETURNING id`,
      [gid, uid(req), body, emoji, image_url || null, post_type || 'text']
    );
    // Award 10 XP for posting (max 3 posts/day checked by daily notifications)
    const today = new Date().toISOString().slice(0, 10);
    const postsToday = await q(
      `SELECT COUNT(*) FROM posts WHERE user_id=$1 AND DATE(created_at)=$2`,
      [uid(req), today]
    );
    if (Number(postsToday.rows[0].count) <= 3) {
      await q(`UPDATE users SET xp=xp+10, total_xp=total_xp+10 WHERE id=$1`, [uid(req)]);
      await q(`UPDATE group_members SET weekly_xp=weekly_xp+10 WHERE user_id=$1`, [uid(req)]);
    }
    // First post badge
    const totalPosts = await q(`SELECT COUNT(*) FROM posts WHERE user_id=$1`, [uid(req)]);
    if (Number(totalPosts.rows[0].count) === 1) {
      const b = await q(`SELECT id FROM badges WHERE code='first_post'`);
      if (b.rows[0]) await q(`INSERT INTO user_badges (user_id,badge_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`, [uid(req), b.rows[0].id]);
    }
    res.json({ id: r.rows[0].id, xp_awarded: 10 });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.put('/posts/:id', async (req, res) => {
  try {
    const { body } = req.body || {};
    if (!body?.trim()) return res.status(400).json({ message: 'body is required' });
    const r = await q(
      `UPDATE posts SET body=$1 WHERE id=$2 AND user_id=$3 RETURNING id`,
      [body, req.params.id, uid(req)]
    );
    if (r.rows.length === 0) return res.status(403).json({ message: 'Not allowed' });
    res.json({ updated: true });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.delete('/posts/:id', async (req, res) => {
  try {
    const r = await q(
      `DELETE FROM posts WHERE id=$1 AND user_id=$2 RETURNING id`,
      [req.params.id, uid(req)]
    );
    if (r.rows.length === 0) return res.status(403).json({ message: 'Not allowed' });
    res.json({ deleted: true });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.post('/posts/:id/like', async (req, res) => {
  try {
    const postId = req.params.id;
    const userId = uid(req);
    // Check if user already liked this post
    const existing = await q(`SELECT 1 FROM post_likes WHERE user_id=$1 AND post_id=$2`, [userId, postId]);
    if (existing.rows.length > 0) {
      // Already liked — remove like
      await q(`DELETE FROM post_likes WHERE user_id=$1 AND post_id=$2`, [userId, postId]);
      await q(`UPDATE posts SET likes = GREATEST(0, likes - 1) WHERE id=$1`, [postId]);
      res.json({ liked: false });
    } else {
      // Not yet liked — add like
      await q(`INSERT INTO post_likes (user_id, post_id) VALUES ($1,$2)`, [userId, postId]);
      await q(`UPDATE posts SET likes = likes + 1 WHERE id=$1`, [postId]);
      res.json({ liked: true });
    }
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.get('/posts/:id/comments', async (req, res) => {
  try {
    const r = await q(
      `SELECT c.id, c.body, COALESCE(u.name,'Member') AS author, c.user_id, c.created_at
       FROM post_comments c JOIN users u ON u.id=c.user_id
       WHERE c.post_id=$1 ORDER BY c.created_at ASC`,
      [req.params.id]
    );
    res.json({ comments: r.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.post('/posts/:id/comments', async (req, res) => {
  try {
    const { body } = req.body || {};
    if (!body?.trim()) return res.status(400).json({ message: 'body is required' });
    await q(
      `INSERT INTO post_comments (post_id, user_id, body) VALUES ($1,$2,$3)`,
      [req.params.id, uid(req), body]
    );
    await q(`UPDATE posts SET comments = comments + 1 WHERE id=$1`, [req.params.id]);
    res.json({ saved: true });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ---- Learning ----
router.get('/lessons', async (req, res) => {
  try {
    const r = await q(
      `SELECT id, week AS week_number, week_name, title, author, minutes,
              xp AS xp_reward, status, lesson_type, video_url,
              (status = 'completed') AS completed
       FROM lessons ORDER BY week, id`
    );
    res.json({ lessons: r.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.get('/lessons/:id', async (req, res) => {
  const r = await q(
    `SELECT id, week AS week_number, week_name, title, author, minutes,
            xp AS xp_reward, status, lesson_type, video_url, content, quiz_questions,
            (status = 'completed') AS completed
     FROM lessons WHERE id=$1`, [req.params.id]
  );
  if (!r.rows[0]) return res.status(404).json({ message: 'Not found' });
  const lesson = r.rows[0];
  if (typeof lesson.content === 'string') {
    try { lesson.content_slides = JSON.parse(lesson.content); } catch { lesson.content_slides = [lesson.content]; }
  }
  res.json({ lesson });
});

router.post('/lessons/:id/complete', async (req, res) => {
  const lesson = (await q(`SELECT id, xp FROM lessons WHERE id=$1`, [req.params.id])).rows[0];
  if (!lesson) return res.status(404).json({ message: 'Not found' });
  await q(`UPDATE lessons SET status='completed' WHERE id=$1`, [req.params.id]);
  const xpEarned = lesson.xp || 30;
  await q(`UPDATE users SET xp=xp+$2, total_xp=total_xp+$2 WHERE id=$1`, [uid(req), xpEarned]);
  await q(`UPDATE group_members SET weekly_xp=weekly_xp+$2 WHERE user_id=$1`, [uid(req), xpEarned]);
  res.json({ completed: true, xp_earned: xpEarned });
});

// ---- Health tip of the day ----
const HEALTH_TIPS = [
  { tip: 'Drink a glass of water before every meal. It reduces hunger and boosts metabolism.', category: 'Hydration' },
  { tip: 'Aim for 7-8 hours of sleep. Poor sleep increases hunger hormones by 24%.', category: 'Sleep' },
  { tip: 'Eat protein at breakfast. It keeps you full for 4+ hours and reduces afternoon cravings.', category: 'Nutrition' },
  { tip: 'Take a 10-minute walk after lunch. It lowers blood sugar spikes by up to 30%.', category: 'Movement' },
  { tip: 'Chew each bite 20 times. Slower eating reduces calorie intake by ~15%.', category: 'Mindful Eating' },
  { tip: 'Intermittent fasting for 14-16 hours triggers fat burning and cellular repair (autophagy).', category: 'Fasting' },
  { tip: 'Replace refined carbs with dal, sabzi, and vegetables for sustained energy.', category: 'Nutrition' },
  { tip: '8,000 steps/day reduces all-cause mortality risk by 51% vs. 4,000 steps.', category: 'Movement' },
  { tip: 'Stress raises cortisol which stores fat around the belly. 5 minutes of deep breathing helps.', category: 'Stress' },
  { tip: 'Green tea before exercise increases fat burning by 17% during the workout.', category: 'Nutrition' },
  { tip: 'Eating dinner before 7pm and breakfast at 8am creates a natural 13-hour fast.', category: 'Fasting' },
  { tip: 'Paneer, eggs, and legumes are the best protein sources for Indian vegetarians.', category: 'Nutrition' },
  { tip: 'Cold water increases calorie burn by ~50 calories as your body warms it.', category: 'Hydration' },
  { tip: 'Yoga 3x/week reduces cortisol by 20% and visceral fat by 15% in 12 weeks.', category: 'Movement' },
];
router.get('/health-tip', async (_req, res) => {
  const dayOfYear = Math.floor((Date.now() - new Date(new Date().getFullYear(), 0, 0)) / 86400000);
  res.json({ tip: HEALTH_TIPS[dayOfYear % HEALTH_TIPS.length] });
});

// ---- Weekly progress summary ----
router.get('/weekly-progress', async (req, res) => {
  try {
    // Use created_at (authoritative registration date) to derive the current program week.
    const user = (await q(`SELECT xp, streak, total_xp, level, created_at FROM users WHERE id=$1`, [uid(req)])).rows[0] || {};

    // Calculate current program day (same logic as dashboard).
    const createdAt = user.created_at ? new Date(user.created_at) : new Date();
    const todayMid = new Date(); todayMid.setHours(0, 0, 0, 0);
    const createdMid = new Date(createdAt); createdMid.setHours(0, 0, 0, 0);
    const diffDays = Math.floor((todayMid - createdMid) / 86400000);
    const dayIndex = Math.min(Math.max(diffDays + 1, 1), 84);

    // Program week (1–12). Week 1 = days 1-7, Week 2 = days 8-14, etc.
    const weekNum = Math.min(12, Math.max(1, Math.ceil(dayIndex / 7)));
    const weekDayStart = (weekNum - 1) * 7 + 1;   // first day_index of this week
    const weekDayEnd   = weekDayStart + 6;          // last day_index of this week

    // Calendar dates for the current program week (for meals / checkins).
    const weekStartDate = new Date(createdMid);
    weekStartDate.setDate(weekStartDate.getDate() + weekDayStart - 1);
    const weekEndDate = new Date(weekStartDate);
    weekEndDate.setDate(weekEndDate.getDate() + 7);
    const weekStartStr = weekStartDate.toISOString().slice(0, 10);
    const weekEndStr   = weekEndDate.toISOString().slice(0, 10);

    // XP from tasks this week (use day_index — reliable even when completed_at is NULL).
    const weekXp = (await q(
      `SELECT COALESCE(SUM(xp), 0) AS xp FROM tasks
       WHERE user_id=$1 AND done=TRUE AND day_index BETWEEN $2 AND $3`,
      [uid(req), weekDayStart, weekDayEnd]
    )).rows[0]?.xp ?? 0;

    // Tasks done / total this week.
    const tasksThisWeek = (await q(
      `SELECT COUNT(*) FILTER (WHERE done) AS done, COUNT(*) AS total
       FROM tasks WHERE user_id=$1 AND day_index BETWEEN $2 AND $3`,
      [uid(req), weekDayStart, weekDayEnd]
    )).rows[0] || { done: 0, total: 0 };

    // Meals logged this week (checkins table uses created_at, not logged_at).
    const mealsThisWeek = (await q(
      `SELECT COUNT(*) AS count FROM meals
       WHERE user_id=$1 AND created_at::date >= $2 AND created_at::date < $3`,
      [uid(req), weekStartStr, weekEndStr]
    )).rows[0]?.count ?? 0;

    // Average mood this week (checkins table uses created_at, not checked_at).
    const avgMood = (await q(
      `SELECT ROUND(AVG(mood), 1) AS avg FROM checkins
       WHERE user_id=$1 AND mood >= 0
         AND created_at::date >= $2 AND created_at::date < $3`,
      [uid(req), weekStartStr, weekEndStr]
    )).rows[0]?.avg ?? null;

    // Weight change: last reading minus first reading this week (actual direction).
    const weightRows = (await q(
      `SELECT weight FROM checkins WHERE user_id=$1 AND weight IS NOT NULL
       AND created_at::date >= $2 AND created_at::date < $3 ORDER BY created_at`,
      [uid(req), weekStartStr, weekEndStr]
    )).rows;
    const weightChange = weightRows.length >= 2
      ? Number(weightRows[weightRows.length - 1].weight) - Number(weightRows[0].weight)
      : null;

    const rank = (await q(
      `SELECT RANK() OVER (ORDER BY weekly_xp DESC) AS rank FROM group_members WHERE user_id=$1`,
      [uid(req)]
    )).rows[0]?.rank ?? null;

    // Day-by-day activity for each of the 7 days in the program week.
    const activeDatesSet = new Set(
      (await q(
        `SELECT DISTINCT created_at::date::text AS d FROM (
           SELECT created_at FROM checkins WHERE user_id=$1 AND created_at::date>=$2 AND created_at::date<$3
           UNION ALL
           SELECT created_at FROM meals   WHERE user_id=$1 AND created_at::date>=$2 AND created_at::date<$3
         ) combined`,
        [uid(req), weekStartStr, weekEndStr]
      )).rows.map(r => r.d)
    );
    const todayStr2 = new Date().toISOString().slice(0, 10);
    const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const dayActivity = Array.from({ length: 7 }, (_, i) => {
      const d = new Date(weekStartDate); d.setDate(d.getDate() + i);
      const ds = d.toISOString().slice(0, 10);
      return { label: DAY_NAMES[d.getDay()], date: ds, active: activeDatesSet.has(ds), isToday: ds === todayStr2, isFuture: ds > todayStr2 };
    });

    // Week score (0–100) weighted across 4 pillars.
    const tTotal = Number(tasksThisWeek.total);
    const taskPct  = tTotal > 0 ? (Number(tasksThisWeek.done) / tTotal) * 100 : 0;
    const dietPct  = Math.min((Number(mealsThisWeek) / 21) * 100, 100);
    const moodPct  = avgMood ? (Number(avgMood) / 5) * 100 : 50;
    const streakPct = Math.min(((user.streak ?? 0) / 7) * 100, 100);
    const weekScore = Math.round(taskPct * 0.4 + dietPct * 0.3 + moodPct * 0.2 + streakPct * 0.1);
    const stars = weekScore >= 75 ? 3 : weekScore >= 45 ? 2 : 1;

    const WEEK_CHALLENGES = [
      'Log all 3 meals every day this week',
      'Complete morning check-in 5 days in a row',
      'Hit 8,000 steps on at least 4 days',
      'Log your weight every evening this week',
      'Complete all daily tasks without missing a day',
      'Try a new healthy recipe from the library',
      'Maintain your fasting window for 5 days',
      'Drink 8 glasses of water daily for 5 days',
      'Write a reflection note every evening',
      'Earn a perfect 3-star week score',
      'Hit your calorie goal 5 days straight',
      'Complete all learning lessons this week',
    ];
    const nextWeekChallenge = WEEK_CHALLENGES[weekNum % WEEK_CHALLENGES.length];

    res.json({
      week_number: weekNum,
      week_xp: Number(weekXp),
      week_score: weekScore,
      stars,
      streak: user.streak ?? 0,
      level: user.level ?? 'bronze',
      tasks_done: Number(tasksThisWeek.done),
      tasks_total: tTotal,
      meals_logged: Number(mealsThisWeek),
      meals_target: 21,
      avg_mood: avgMood ? Number(avgMood) : null,
      weight_change: weightChange,
      rank: rank ? Number(rank) : null,
      day_activity: dayActivity,
      next_week_challenge: nextWeekChallenge,
    });
  } catch(e) { res.status(500).json({ message: e.message }); }
});

// ---- Badge gallery ----
router.get('/badges', async (req, res) => {
  const all = (await q(`SELECT id, code, emoji, name, xp FROM badges ORDER BY xp ASC`)).rows;
  const earned = (await q(
    `SELECT badge_id FROM user_badges WHERE user_id=$1`, [uid(req)]
  )).rows.map(r => r.badge_id);
  const earnedSet = new Set(earned);
  res.json({ badges: all.map(b => ({ ...b, earned: earnedSet.has(b.id) })) });
});

// ---- Chat ----
router.get('/chat', async (req, res) => {
  const r = await q(`SELECT from_coach, text, created_at FROM chat_messages WHERE user_id=$1 ORDER BY created_at ASC LIMIT 100`, [uid(req)]);
  res.json({ messages: r.rows });
});

router.post('/chat', async (req, res) => {
  const { text } = req.body || {};
  if (!text?.trim()) return res.status(400).json({ message: 'text is required' });
  await q(`INSERT INTO chat_messages (user_id, from_coach, text) VALUES ($1, FALSE, $2)`, [uid(req), text]);

  let reply = 'Great work staying consistent! Keep it up and hydrate well today 💪';

  const key = process.env.ANTHROPIC_API_KEY;
  if (key && text) {
    try {
      // Fetch last 10 messages for context.
      const history = (await q(
        `SELECT from_coach, text FROM chat_messages WHERE user_id=$1 ORDER BY created_at DESC LIMIT 10`,
        [uid(req)]
      )).rows.reverse();

      // Fetch user profile for personalisation.
      const u = (await q(`SELECT name, streak FROM users WHERE id=$1`, [uid(req)])).rows[0] || {};
      const p = (await q(`SELECT goal, food_pref FROM profiles WHERE user_id=$1`, [uid(req)])).rows[0] || {};

      const model = process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-6';
      const chatBody = {
        model,
        max_tokens: 200,
        system:
          `You are a warm, motivating fitness coach named Priya in a weight-loss app called FitQuest. ` +
          `The user's name is ${u.name || 'there'}, their goal is "${p.goal || 'lose weight'}", ` +
          `food preference is "${p.food_pref || 'vegetarian'}", and their current streak is ${u.streak || 0} days. ` +
          `Keep replies short (1-3 sentences), practical, and encouraging. No lists or markdown.`,
        messages: history.map((m) => ({
          role: m.from_coach ? 'assistant' : 'user',
          content: m.text,
        })),
      };
      // Try Bearer auth first (OAuth tokens), fall back to x-api-key (regular API keys).
      async function chatFetch(headers) {
        const r = await fetch('https://api.anthropic.com/v1/messages', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'anthropic-version': '2023-06-01', ...headers },
          body: JSON.stringify(chatBody),
        });
        const d = await r.json();
        if (!r.ok) throw Object.assign(new Error(d?.error?.message ?? r.statusText), { status: r.status });
        return d;
      }
      let chatData;
      try {
        chatData = await chatFetch({ 'Authorization': `Bearer ${key}` });
      } catch (authErr) {
        if (authErr.status === 401) {
          console.warn('[chat] Bearer auth failed, retrying with x-api-key');
          chatData = await chatFetch({ 'x-api-key': key });
        } else { throw authErr; }
      }
      reply = chatData.content?.[0]?.text?.trim() || reply;
    } catch (e) {
      console.warn('[chat] Claude failed, using fallback:', e.message);
    }
  }

  await q(`INSERT INTO chat_messages (user_id, from_coach, text) VALUES ($1, TRUE, $2)`, [uid(req), reply]);
  res.json({ reply });
});

// ---- Settings: language update ----
router.post('/settings/language', async (req, res) => {
  const { language } = req.body || {};
  if (!['en', 'ta'].includes(language)) return res.status(400).json({ message: 'en or ta only' });
  await q(`UPDATE users SET language=$2 WHERE id=$1`, [uid(req), language]);
  await q(`UPDATE profiles SET language=$2 WHERE user_id=$1`, [uid(req), language]);
  res.json({ updated: true });
});

// ---- DPDP Compliance: data export request ----
router.post('/compliance/data-export', async (req, res) => {
  await q(
    `INSERT INTO data_requests (user_id, type, status) VALUES ($1,'export','pending')`,
    [uid(req)]
  );
  // Return user's data summary
  const user = (await q(`SELECT id, name, phone, email, created_at FROM users WHERE id=$1`, [uid(req)])).rows[0];
  const profile = (await q(`SELECT * FROM profiles WHERE user_id=$1`, [uid(req)])).rows[0];
  const checkinsCount = (await q(`SELECT COUNT(*) FROM checkins WHERE user_id=$1`, [uid(req)])).rows[0];
  const mealsCount = (await q(`SELECT COUNT(*) FROM meals WHERE user_id=$1`, [uid(req)])).rows[0];
  res.json({
    request_submitted: true,
    data_summary: { user, profile, checkins_count: Number(checkinsCount.count), meals_count: Number(mealsCount.count) },
  });
});

// ---- DPDP Compliance: data deletion request ----
router.post('/compliance/data-delete', async (req, res) => {
  await q(
    `INSERT INTO data_requests (user_id, type, status) VALUES ($1,'delete','pending')`,
    [uid(req)]
  );
  res.json({ request_submitted: true, message: 'Your data deletion request has been received. Your account will be deleted within 30 days per DPDP Act requirements.' });
});

export default router;
