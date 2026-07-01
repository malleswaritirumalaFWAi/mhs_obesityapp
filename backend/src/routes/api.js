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
  const u = await q(`SELECT id, phone, email, name, onboarded, xp, total_xp, streak, start_weight, target_weight FROM users WHERE id=$1`, [uid(req)]);
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
    await markTasksDoneByIcon(uid(req), ['directions_run', 'directions_walk']);
  }
  if (add > 0) {
    const ux = (await q(`SELECT double_xp_expires_at FROM users WHERE id=$1`, [uid(req)])).rows[0];
    const dxp = ux?.double_xp_expires_at && new Date(ux.double_xp_expires_at) > new Date() ? 10 : 5;
    await q(`UPDATE users SET xp=xp+$2, total_xp=total_xp+$2 WHERE id=$1`, [uid(req), dxp]);
    await q(`UPDATE group_members SET weekly_xp=weekly_xp+$2 WHERE user_id=$1`, [uid(req), dxp]);
    await updateUserLevel(uid(req));
  }
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
    await markTasksDoneByIcon(uid(req), ['water_drop']);
  }
  const uxh = (await q(`SELECT double_xp_expires_at FROM users WHERE id=$1`, [uid(req)])).rows[0];
  const dxph = uxh?.double_xp_expires_at && new Date(uxh.double_xp_expires_at) > new Date() ? 10 : 5;
  await q(`UPDATE users SET xp=xp+$2, total_xp=total_xp+$2 WHERE id=$1`, [uid(req), dxph]);
  await q(`UPDATE group_members SET weekly_xp=weekly_xp+$2 WHERE user_id=$1`, [uid(req), dxph]);
  await updateUserLevel(uid(req));
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
  // Mark hydration task done if water reached 8 via home screen card
  if (water !== undefined && Number(water) >= 8) {
    await markTasksDoneByIcon(uid(req), ['water_drop']);
  }
  res.json({ updated: true });
});

// ---- Check-ins ----
router.post('/checkins', async (req, res, next) => {
  try {
  const { mood, weight, notes, tz_offset } = req.body || {};
  if (mood === undefined || mood === null || mood < 0 || mood > 4)
    return res.status(400).json({ message: 'mood must be 0–4' });

  // Timezone-aware today boundaries (IST = +330, falls back to UTC).
  const tzOffsetMin = Number(tz_offset ?? 0);
  const nowMs = Date.now();
  const localNow = new Date(nowMs + tzOffsetMin * 60000);
  const localMidnightUtc = new Date(
    Date.UTC(localNow.getUTCFullYear(), localNow.getUTCMonth(), localNow.getUTCDate())
    - tzOffsetMin * 60000
  );
  const localTodayEndUtc       = new Date(localMidnightUtc.getTime() + 86400000);
  const localYesterdayStartUtc = new Date(localMidnightUtc.getTime() - 86400000);

  // One entry per day: update today's record if it exists, otherwise insert.
  const existingToday = (await q(
    `SELECT id FROM checkins WHERE user_id=$1 AND mood >= 0
       AND created_at >= $2 AND created_at < $3 ORDER BY id DESC LIMIT 1`,
    [uid(req), localMidnightUtc, localTodayEndUtc]
  )).rows[0];

  const isUpdate = !!existingToday;
  if (isUpdate) {
    await q(`UPDATE checkins SET mood=$1, weight=$2, notes=$3, created_at=NOW() WHERE id=$4`,
      [mood, weight, notes, existingToday.id]);
  } else {
    await q(`INSERT INTO checkins (user_id, mood, weight, notes) VALUES ($1,$2,$3,$4)`,
      [uid(req), mood, weight, notes]);
  }

  // Mark morning check-in task done only when BOTH mood AND weight are logged.
  const parsedWeight = weight !== undefined && weight !== null && !isNaN(Number(weight)) && Number(weight) > 0;
  if (parsedWeight) {
    await markTasksDoneByIcon(uid(req), ['wb_sunny']);
  }

  const prevUser = (await q(`SELECT streak, total_xp FROM users WHERE id=$1`, [uid(req)])).rows[0] || {};
  const prevStreak = prevUser.streak || 0;

  let xpToAdd = 0;
  let streak = prevStreak;
  let multiplier = 1.0;

  // Only award XP and update streak on the FIRST checkin of the day.
  if (!isUpdate) {
    // Was the user's previous check-in within the local-yesterday window?
    // OFFSET 1 skips the row we just inserted to get the prior check-in.
    const lastCheckin = (await q(
      `SELECT created_at FROM checkins
       WHERE user_id=$1 AND mood >= 0
       ORDER BY created_at DESC OFFSET 1 LIMIT 1`,
      [uid(req)]
    )).rows[0];
    const wasYesterday = !!lastCheckin &&
      new Date(lastCheckin.created_at) >= localYesterdayStartUtc &&
      new Date(lastCheckin.created_at) <  localMidnightUtc;

    // Increment if consecutive, decrement by 1 if a day was missed (min 1).
    const newStreak = wasYesterday ? prevStreak + 1 : Math.max(prevStreak - 1, 1);
    if (newStreak >= 30) multiplier = 1.5;
    else if (newStreak >= 14) multiplier = 1.2;
    else if (newStreak >= 7) multiplier = 1.1;
    const dxpRow = (await q(`SELECT double_xp_expires_at FROM users WHERE id=$1`, [uid(req)])).rows[0];
    const doubleXp = dxpRow?.double_xp_expires_at && new Date(dxpRow.double_xp_expires_at) > new Date();
    const baseXp = doubleXp ? 20 : 10;
    xpToAdd = Math.round(baseXp * multiplier);

    const updated = await q(
      `UPDATE users SET xp=xp+$2, total_xp=total_xp+$2, streak=$3 WHERE id=$1 RETURNING streak, total_xp`,
      [uid(req), xpToAdd, newStreak]
    );
    streak = updated.rows[0]?.streak ?? newStreak;
    await q(`UPDATE group_members SET weekly_xp=weekly_xp+$2 WHERE user_id=$1`, [uid(req), xpToAdd]);
  }
  await updateUserLevel(uid(req));

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
  const { weight, notes, evening_mood, tz_offset } = req.body || {};
  if (!weight) return res.status(400).json({ message: 'weight is required' });
  const mood = (evening_mood !== undefined && evening_mood !== null && evening_mood >= 0 && evening_mood <= 4)
    ? Number(evening_mood)
    : null;

  // Timezone-aware today boundaries — same approach as /checkins.
  const tzOffsetMin = Number(tz_offset ?? 0);
  const localNow = new Date(Date.now() + tzOffsetMin * 60000);
  const localMidnightUtc = new Date(
    Date.UTC(localNow.getUTCFullYear(), localNow.getUTCMonth(), localNow.getUTCDate())
    - tzOffsetMin * 60000
  );
  const localTodayEndUtc = new Date(localMidnightUtc.getTime() + 86400000);

  // One entry per day: update today's record if it exists, otherwise insert.
  const existingToday = (await q(
    `SELECT id FROM checkins WHERE user_id=$1 AND mood=-1
       AND created_at >= $2 AND created_at < $3 ORDER BY id DESC LIMIT 1`,
    [uid(req), localMidnightUtc, localTodayEndUtc]
  )).rows[0];

  if (existingToday) {
    await q(`UPDATE checkins SET weight=$1, notes=$2, evening_mood=$3, created_at=NOW() WHERE id=$4`,
      [parseFloat(weight), notes || null, mood, existingToday.id]);
    res.json({ saved: true, xp_awarded: 0 });
  } else {
    await q(
      `INSERT INTO checkins (user_id, mood, weight, notes, evening_mood) VALUES ($1, -1, $2, $3, $4)`,
      [uid(req), parseFloat(weight), notes || null, mood]
    );
    await markTasksDoneByIcon(uid(req), ['scale']);
    await q(`UPDATE users SET xp = xp + 5 WHERE id=$1`, [uid(req)]);
    res.json({ saved: true, xp_awarded: 5 });
  }
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
// Helper: compute current program week for a user (week 1 from day 0, week 2 from day 7, etc.)
function userCurrentWeek(createdAt) {
  const days = Math.max(Math.floor((Date.now() - new Date(createdAt).getTime()) / 86400000), 0);
  return Math.min(Math.floor(days / 7) + 1, 12);
}

router.get('/lessons', async (req, res) => {
  try {
    const user = (await q(`SELECT created_at FROM users WHERE id=$1`, [uid(req)])).rows[0];
    const currentWeek = userCurrentWeek(user?.created_at ?? new Date());

    const r = await q(
      `SELECT l.id,
              l.week       AS week_number,
              l.week_name,
              l.title,
              l.author,
              l.minutes,
              l.xp         AS xp_reward,
              l.lesson_type,
              l.video_url,
              l.content,
              l.quiz_questions,
              CASE
                WHEN ulp.lesson_id IS NOT NULL THEN 'completed'
                WHEN l.week <= $2              THEN 'active'
                ELSE                               'locked'
              END AS status,
              (ulp.lesson_id IS NOT NULL) AS completed
       FROM lessons l
       LEFT JOIN user_lesson_progress ulp
              ON ulp.lesson_id = l.id AND ulp.user_id = $1
       ORDER BY l.week, l.id`,
      [uid(req), currentWeek]
    );
    res.json({ lessons: r.rows, current_week: currentWeek });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.get('/lessons/:id', async (req, res) => {
  try {
    const user = (await q(`SELECT created_at FROM users WHERE id=$1`, [uid(req)])).rows[0];
    const currentWeek = userCurrentWeek(user?.created_at ?? new Date());

    const r = await q(
      `SELECT l.id,
              l.week       AS week_number,
              l.week_name,
              l.title,
              l.author,
              l.minutes,
              l.xp         AS xp_reward,
              l.lesson_type,
              l.video_url,
              l.content,
              l.quiz_questions,
              CASE
                WHEN ulp.lesson_id IS NOT NULL THEN 'completed'
                WHEN l.week <= $3              THEN 'active'
                ELSE                               'locked'
              END AS status,
              (ulp.lesson_id IS NOT NULL) AS completed
       FROM lessons l
       LEFT JOIN user_lesson_progress ulp
              ON ulp.lesson_id = l.id AND ulp.user_id = $2
       WHERE l.id = $1`,
      [req.params.id, uid(req), currentWeek]
    );
    if (!r.rows[0]) return res.status(404).json({ message: 'Not found' });
    const lesson = r.rows[0];
    if (typeof lesson.content === 'string') {
      try { lesson.content_slides = JSON.parse(lesson.content); } catch { lesson.content_slides = [lesson.content]; }
    }
    res.json({ lesson });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.post('/lessons/:id/complete', async (req, res, next) => {
  try {
    const lesson = (await q(`SELECT id, xp FROM lessons WHERE id=$1`, [req.params.id])).rows[0];
    if (!lesson) return res.status(404).json({ message: 'Not found' });

    // Idempotent — only award XP on first completion
    const inserted = await q(
      `INSERT INTO user_lesson_progress (user_id, lesson_id)
       VALUES ($1, $2) ON CONFLICT DO NOTHING RETURNING lesson_id`,
      [uid(req), lesson.id]
    );

    let xpEarned = 0;
    if (inserted.rows.length > 0) {
      xpEarned = lesson.xp || 30;
      await q(`UPDATE users SET xp=xp+$2, total_xp=total_xp+$2 WHERE id=$1`, [uid(req), xpEarned]);
      await q(`UPDATE group_members SET weekly_xp=weekly_xp+$2 WHERE user_id=$1`, [uid(req), xpEarned]);
      await updateUserLevel(uid(req));
    }
    res.json({ completed: true, xp_earned: xpEarned });
  } catch (err) { next(err); }
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

    // Use UTC midnight consistently — avoids getDay()/toISOString() mismatch
    // when the server runs in a non-UTC timezone (e.g. IST).
    const createdAt = user.created_at ? new Date(user.created_at) : new Date();
    const todayUTC      = new Date().toISOString().slice(0, 10);          // "YYYY-MM-DD"
    const createdUTC    = createdAt.toISOString().slice(0, 10);
    const todayMidUTC   = new Date(todayUTC   + 'T00:00:00Z');
    const createdMidUTC = new Date(createdUTC + 'T00:00:00Z');

    const diffDays = Math.floor((todayMidUTC - createdMidUTC) / 86400000);
    const dayIndex = Math.min(Math.max(diffDays + 1, 1), 84);

    // Program week (1–12). Week 1 = days 1-7, Week 2 = days 8-14, etc.
    const weekNum = Math.min(12, Math.max(1, Math.ceil(dayIndex / 7)));
    const weekDayStart = (weekNum - 1) * 7 + 1;   // first day_index of this week
    const weekDayEnd   = weekDayStart + 6;          // last day_index of this week

    // Calendar dates for the current program week — all UTC.
    const weekStartDate = new Date(createdMidUTC);
    weekStartDate.setUTCDate(weekStartDate.getUTCDate() + weekDayStart - 1);
    const weekEndDate = new Date(weekStartDate);
    weekEndDate.setUTCDate(weekEndDate.getUTCDate() + 7);
    const weekStartStr = weekStartDate.toISOString().slice(0, 10);
    const weekEndStr   = weekEndDate.toISOString().slice(0, 10);

    // XP from ALL sources this week: tasks + checkins + fasting + lessons.
    const weekXpRow = (await q(
      `SELECT COALESCE(SUM(xp_amount), 0) AS total FROM (
         SELECT xp AS xp_amount FROM tasks
           WHERE user_id=$1 AND done=TRUE AND day_index BETWEEN $2 AND $3
         UNION ALL
         SELECT 10 AS xp_amount FROM checkins
           WHERE user_id=$1 AND created_at::date >= $4 AND created_at::date < $5
         UNION ALL
         SELECT l.xp AS xp_amount FROM user_lesson_progress ulp
           JOIN lessons l ON l.id = ulp.lesson_id
           WHERE ulp.user_id=$1 AND ulp.completed_at::date >= $4 AND ulp.completed_at::date < $5
         UNION ALL
         SELECT xp_awarded AS xp_amount FROM fasting_sessions
           WHERE user_id=$1 AND completed=TRUE
             AND ended_at::date >= $4 AND ended_at::date < $5
       ) combined`,
      [uid(req), weekDayStart, weekDayEnd, weekStartStr, weekEndStr]
    )).rows[0];
    const weekXp = Number(weekXpRow?.total ?? 0);

    // Tasks done / total this week.
    const tasksThisWeek = (await q(
      `SELECT COUNT(*) FILTER (WHERE done) AS done, COUNT(*) AS total
       FROM tasks WHERE user_id=$1 AND day_index BETWEEN $2 AND $3`,
      [uid(req), weekDayStart, weekDayEnd]
    )).rows[0] || { done: 0, total: 0 };

    // Meals logged this week.
    const mealsThisWeek = (await q(
      `SELECT COUNT(*) AS count FROM meals
       WHERE user_id=$1 AND created_at::date >= $2 AND created_at::date < $3`,
      [uid(req), weekStartStr, weekEndStr]
    )).rows[0]?.count ?? 0;

    // Average mood this week.
    const avgMood = (await q(
      `SELECT ROUND(AVG(mood), 1) AS avg FROM checkins
       WHERE user_id=$1 AND mood >= 0
         AND created_at::date >= $2 AND created_at::date < $3`,
      [uid(req), weekStartStr, weekEndStr]
    )).rows[0]?.avg ?? null;

    // Weight change: last reading minus first reading this week.
    const weightRows = (await q(
      `SELECT weight FROM checkins WHERE user_id=$1 AND weight IS NOT NULL
       AND created_at::date >= $2 AND created_at::date < $3 ORDER BY created_at`,
      [uid(req), weekStartStr, weekEndStr]
    )).rows;
    const weightChange = weightRows.length >= 2
      ? Number(weightRows[weightRows.length - 1].weight) - Number(weightRows[0].weight)
      : null;

    // Fasting sessions completed this week.
    const fastingCount = Number((await q(
      `SELECT COUNT(*) AS count FROM fasting_sessions
       WHERE user_id=$1 AND completed=TRUE
         AND ended_at::date >= $2 AND ended_at::date < $3`,
      [uid(req), weekStartStr, weekEndStr]
    )).rows[0]?.count ?? 0);

    // Lessons completed this week.
    const lessonsCompleted = Number((await q(
      `SELECT COUNT(*) AS count FROM user_lesson_progress
       WHERE user_id=$1 AND completed_at::date >= $2 AND completed_at::date < $3`,
      [uid(req), weekStartStr, weekEndStr]
    )).rows[0]?.count ?? 0);

    // Checkins this week (for activity tracking).
    const checkinsCount = Number((await q(
      `SELECT COUNT(*) AS count FROM checkins
       WHERE user_id=$1 AND created_at::date >= $2 AND created_at::date < $3`,
      [uid(req), weekStartStr, weekEndStr]
    )).rows[0]?.count ?? 0);

    // Rank within the user's group (fixed: window fn runs over all members first).
    const rankRow = (await q(
      `SELECT rank FROM (
         SELECT user_id, RANK() OVER (ORDER BY weekly_xp DESC) AS rank
         FROM group_members
         WHERE group_id IN (SELECT group_id FROM group_members WHERE user_id=$1 LIMIT 1)
       ) sub WHERE user_id=$1`,
      [uid(req)]
    )).rows[0];
    const rank = rankRow?.rank ? Number(rankRow.rank) : null;

    // Day-by-day activity — active if any checkin, meal, fast, or lesson that day.
    const activeDatesSet = new Set(
      (await q(
        `SELECT DISTINCT d FROM (
           SELECT created_at::date::text AS d FROM checkins
             WHERE user_id=$1 AND created_at::date>=$2 AND created_at::date<$3
           UNION ALL
           SELECT created_at::date::text AS d FROM meals
             WHERE user_id=$1 AND created_at::date>=$2 AND created_at::date<$3
           UNION ALL
           SELECT ended_at::date::text AS d FROM fasting_sessions
             WHERE user_id=$1 AND completed=TRUE AND ended_at::date>=$2 AND ended_at::date<$3
           UNION ALL
           SELECT completed_at::date::text AS d FROM user_lesson_progress
             WHERE user_id=$1 AND completed_at::date>=$2 AND completed_at::date<$3
         ) combined`,
        [uid(req), weekStartStr, weekEndStr]
      )).rows.map(r => r.d)
    );
    const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const dayActivity = Array.from({ length: 7 }, (_, i) => {
      const d = new Date(weekStartDate);
      d.setUTCDate(d.getUTCDate() + i);          // advance by i days in UTC
      const ds = d.toISOString().slice(0, 10);   // UTC date string
      return {
        label: DAY_NAMES[d.getUTCDay()],          // UTC weekday — matches ds
        date: ds,
        active: activeDatesSet.has(ds),
        isToday: ds === todayUTC,                 // both UTC → correct highlight
        isFuture: ds > todayUTC,
      };
    });

    // Week score (0–100) — 5 pillars, gracefully handles missing data.
    const tTotal = Number(tasksThisWeek.total);
    // If no tasks seeded yet, fall back to checkin consistency as activity proxy.
    const taskPct    = tTotal > 0 ? (Number(tasksThisWeek.done) / tTotal) * 100
                                   : Math.min((checkinsCount / 7) * 100, 100);
    const dietPct    = Math.min((Number(mealsThisWeek) / 21) * 100, 100);
    const moodPct    = avgMood != null ? (Number(avgMood) / 5) * 100 : 50;
    const streakPct  = Math.min(((user.streak ?? 0) / 7) * 100, 100);
    const fastingPct = Math.min((fastingCount / 3) * 100, 100); // 3 fasts/week = 100%
    const weekScore  = Math.round(
      taskPct * 0.30 + dietPct * 0.25 + moodPct * 0.20 + streakPct * 0.15 + fastingPct * 0.10
    );
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
      week_xp: weekXp,
      week_score: weekScore,
      stars,
      streak: user.streak ?? 0,
      level: user.level ?? 'bronze',
      tasks_done: Number(tasksThisWeek.done),
      tasks_total: tTotal,
      meals_logged: Number(mealsThisWeek),
      meals_target: 21,
      avg_mood: avgMood != null ? Number(avgMood) : null,
      weight_change: weightChange,
      fasting_count: fastingCount,
      lessons_completed: lessonsCompleted,
      checkins_count: checkinsCount,
      rank,
      day_activity: dayActivity,
      next_week_challenge: nextWeekChallenge,
    });
  } catch(e) { res.status(500).json({ message: e.message }); }
});

// ---- Badge gallery ----
router.get('/badges', async (req, res) => {
  const all = (await q(`SELECT id, code, emoji, name, xp, description FROM badges ORDER BY xp ASC`)).rows;
  const earnedRows = (await q(
    `SELECT badge_id, earned_at FROM user_badges WHERE user_id=$1`, [uid(req)]
  )).rows;
  const earnedMap = new Map(earnedRows.map(r => [r.badge_id, r.earned_at]));
  res.json({
    badges: all.map(b => ({
      id: b.id,
      slug: b.code,
      emoji: b.emoji,
      name: b.name,
      description: b.description,
      xp_reward: b.xp,
      earned: earnedMap.has(b.id),
      earned_at: earnedMap.get(b.id) ?? null,
    })),
  });
});

// ---- Chat ----
router.get('/chat', async (req, res) => {
  const r = await q(`SELECT from_coach, text, created_at FROM chat_messages WHERE user_id=$1 ORDER BY created_at ASC LIMIT 100`, [uid(req)]);
  res.json({ messages: r.rows });
});

/**
 * Detects health inputs that require a safety-first response rather than
 * generic encouragement. Returns a safe reply string, or null if input is normal.
 */
function safetyCheck(text) {
  const t = text.toLowerCase();

  // Extreme or impossible weight changes
  const extremeWt = /lost\s+(\d+(?:\.\d+)?)\s*(kg|kilo|pound|lb)/i.exec(text);
  if (extremeWt) {
    const amt = parseFloat(extremeWt[1]);
    const unit = extremeWt[2].toLowerCase();
    const kg = unit.startsWith('kg') || unit.startsWith('kilo') ? amt : amt * 0.453592;
    // More than 1 kg in a single day is physiologically extreme
    if (kg > 1 && /\b(hour|hr|minute|min|day|24h)\b/i.test(text)) {
      return 'That rate of weight loss sounds very unusual and could be a sign of dehydration or a medical issue — not healthy fat loss. Please stop exercising, drink water, and consult a doctor or emergency services if you feel unwell.';
    }
  }

  // Medical emergency signals
  if (/chest\s*pain|can'?t\s*breathe|difficulty\s*breath|passed\s*out|faint(ed)?|vomit(ing)?\s*blood|heart\s*(attack|racing)|stroke/i.test(t)) {
    return 'This sounds like it could be a medical emergency. Please stop what you are doing and contact emergency services or see a doctor immediately. Your health and safety come first.';
  }

  // Self-harm or eating disorder signals
  if (/not\s*eating|starv(ing|ation)|haven'?t\s*eaten\s*(in\s*)?\d+\s*(day|hour|hr)|purge?|laxative|cut(ting)?\s*myself/i.test(t)) {
    return 'I\'m concerned about what you\'ve shared. Restricting food or harming yourself is dangerous and not part of the FitQuest programme. Please speak to a healthcare professional or a trusted person about how you are feeling.';
  }

  return null; // input is safe — proceed normally
}

router.post('/chat', async (req, res) => {
  const { text } = req.body || {};
  if (!text?.trim()) return res.status(400).json({ message: 'text is required' });
  await q(`INSERT INTO chat_messages (user_id, from_coach, text) VALUES ($1, FALSE, $2)`, [uid(req), text]);

  // Safety gate — respond before calling Claude for dangerous inputs
  const safeReply = safetyCheck(text);
  if (safeReply) {
    await q(`INSERT INTO chat_messages (user_id, from_coach, text) VALUES ($1, TRUE, $2)`, [uid(req), safeReply]);
    return res.json({ reply: safeReply });
  }

  // Context-aware fallback used only when Claude is unavailable
  let reply = 'I\'m having a moment of connectivity trouble — try again in a bit! In the meantime, keep up your daily tasks and stay hydrated.';

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
          `Keep replies short (1-3 sentences), practical, and encouraging. No lists or markdown. ` +
          `SAFETY RULE: If the user describes any medical emergency, extreme symptoms, ` +
          `dangerous weight loss rates, self-harm, or eating disorders, ALWAYS advise them ` +
          `to seek immediate medical attention — never give generic praise for these inputs.`,
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
