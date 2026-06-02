import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);

const uid = (req) => req.user.uid;

// ---- Profile + quiz ----
router.get('/profile', async (req, res) => {
  const u = await q(`SELECT id, phone, name, onboarded, xp, streak, start_weight, target_weight FROM users WHERE id=$1`, [uid(req)]);
  const p = await q(`SELECT gender, activity, goal, food_pref, challenge FROM profiles WHERE user_id=$1`, [uid(req)]);
  const badges = await q(
    `SELECT b.emoji, b.name FROM user_badges ub JOIN badges b ON b.id=ub.badge_id WHERE ub.user_id=$1 ORDER BY ub.earned_at DESC`,
    [uid(req)]
  );
  res.json({ user: u.rows[0] || null, profile: p.rows[0] || null, badges: badges.rows });
});

router.post('/profile/quiz', async (req, res) => {
  const { gender, activity, goal, food_pref, challenge, name } = req.body || {};
  await q(
    `INSERT INTO profiles (user_id, gender, activity, goal, food_pref, challenge)
     VALUES ($1,$2,$3,$4,$5,$6)
     ON CONFLICT (user_id) DO UPDATE SET gender=$2, activity=$3, goal=$4, food_pref=$5, challenge=$6`,
    [uid(req), gender, activity, goal, food_pref, challenge]
  );
  if (name) await q(`UPDATE users SET name=$2 WHERE id=$1`, [uid(req), name]);
  res.json({ saved: true });
});

// ---- Coach / plan info ----
router.get('/coach', async (req, res) => {
  const r = await q(
    `SELECT c.name, c.title, c.rating, c.avatar, g.name AS batch, g.starts_on
     FROM groups g JOIN coaches c ON c.id=g.coach_id WHERE g.id=1`
  );
  res.json(r.rows[0] || {});
});

// ---- Dashboard summary ----
router.get('/dashboard', async (req, res) => {
  const u = (await q(`SELECT name, xp, streak FROM users WHERE id=$1`, [uid(req)])).rows[0] || {};
  const done = (await q(`SELECT COUNT(*) FILTER (WHERE done) AS d, COUNT(*) AS t FROM tasks WHERE user_id=$1 AND day_index=23`, [uid(req)])).rows[0];
  res.json({
    name: u.name || 'Aarav',
    day: 23,
    total_days: 84,
    done: Number(done?.d || 6),
    total: Number(done?.t || 8),
    steps: 8412,
    water: '6/8',
    sleep: '7.4h',
    rank: 12,
    xp: u.xp ?? 1840,
  });
});

// ---- Today's plan ----
router.get('/today', async (req, res) => {
  const r = await q(
    `SELECT slot, time, icon, title, subtitle, xp, done FROM tasks WHERE user_id=$1 AND day_index=$2 ORDER BY time`,
    [uid(req), Number(req.query.day) || 23]
  );
  res.json({ tasks: r.rows });
});

router.post('/today/task/:id/complete', async (req, res) => {
  await q(`UPDATE tasks SET done=TRUE WHERE id=$1 AND user_id=$2`, [req.params.id, uid(req)]);
  res.json({ done: true });
});

// ---- Check-ins ----
router.post('/checkins', async (req, res) => {
  const { mood, weight, notes } = req.body || {};
  await q(`INSERT INTO checkins (user_id, mood, weight, notes) VALUES ($1,$2,$3,$4)`,
    [uid(req), mood, weight, notes]);
  await q(`UPDATE users SET xp = xp + 10 WHERE id=$1`, [uid(req)]);
  res.json({ saved: true, xp_awarded: 10 });
});

router.get('/checkins', async (req, res) => {
  const r = await q(`SELECT mood, weight, notes, created_at FROM checkins WHERE user_id=$1 ORDER BY created_at DESC LIMIT 30`, [uid(req)]);
  res.json({ checkins: r.rows });
});

// ---- Group / leaderboard ----
router.get('/group/leaderboard', async (req, res) => {
  const r = await q(
    `SELECT u.id, COALESCE(u.name, 'Member') AS name, gm.weekly_xp AS xp
     FROM group_members gm JOIN users u ON u.id=gm.user_id
     WHERE gm.group_id=1 ORDER BY gm.weekly_xp DESC LIMIT 50`
  );
  res.json({ members: r.rows.map((m, i) => ({ ...m, rank: i + 1, you: m.id === uid(req) })) });
});

// ---- Posts ----
router.get('/posts', async (req, res) => {
  const r = await q(
    `SELECT p.id, COALESCE(u.name,'Member') AS author, p.body, p.emoji, p.coach_pick,
            p.likes, p.fires, p.comments, p.created_at
     FROM posts p JOIN users u ON u.id=p.user_id WHERE p.group_id=1 ORDER BY p.created_at DESC LIMIT 50`
  );
  res.json({ posts: r.rows });
});

router.post('/posts', async (req, res) => {
  const { body, emoji } = req.body || {};
  const r = await q(
    `INSERT INTO posts (group_id, user_id, body, emoji) VALUES (1,$1,$2,$3) RETURNING id`,
    [uid(req), body, emoji]
  );
  res.json({ id: r.rows[0].id });
});

router.post('/posts/:id/like', async (req, res) => {
  await q(`UPDATE posts SET likes = likes + 1 WHERE id=$1`, [req.params.id]);
  res.json({ liked: true });
});

// ---- Learning ----
router.get('/lessons', async (req, res) => {
  const r = await q(`SELECT week, title, author, minutes, xp, status FROM lessons ORDER BY week`);
  res.json({ lessons: r.rows });
});

// ---- Chat ----
router.get('/chat', async (req, res) => {
  const r = await q(`SELECT from_coach, text, created_at FROM chat_messages WHERE user_id=$1 ORDER BY created_at ASC LIMIT 100`, [uid(req)]);
  res.json({ messages: r.rows });
});

router.post('/chat', async (req, res) => {
  const { text } = req.body || {};
  await q(`INSERT INTO chat_messages (user_id, from_coach, text) VALUES ($1, FALSE, $2)`, [uid(req), text]);
  // A real build would generate a coach reply (Claude) here; demo echoes encouragement.
  const reply = 'Great work staying consistent! Keep it up and hydrate well today 💪';
  await q(`INSERT INTO chat_messages (user_id, from_coach, text) VALUES ($1, TRUE, $2)`, [uid(req), reply]);
  res.json({ reply });
});

export default router;
