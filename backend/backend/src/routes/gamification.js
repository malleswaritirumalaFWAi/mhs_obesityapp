import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

// Level thresholds (total_xp)
const LEVELS = [
  { name: 'bronze',   min: 0,     label: 'Bronze',   emoji: '🥉' },
  { name: 'silver',   min: 1000,  label: 'Silver',   emoji: '🥈' },
  { name: 'gold',     min: 3000,  label: 'Gold',     emoji: '🥇' },
  { name: 'platinum', min: 6000,  label: 'Platinum', emoji: '💎' },
  { name: 'diamond',  min: 10000, label: 'Diamond',  emoji: '👑' },
];

export function computeLevel(totalXp) {
  let level = LEVELS[0];
  for (const l of LEVELS) {
    if (totalXp >= l.min) level = l;
  }
  const idx = LEVELS.indexOf(level);
  const next = LEVELS[idx + 1] || null;
  return { ...level, next_level: next, progress_to_next: next ? totalXp - level.min : null, next_threshold: next?.min };
}

// GET /gamification/status — full gamification status
router.get('/status', async (req, res) => {
  const u = (await q(
    `SELECT xp, total_xp, streak, streak_freezes, level FROM users WHERE id=$1`,
    [uid(req)]
  )).rows[0] || {};

  const levelInfo = computeLevel(u.total_xp || 0);

  // Royal Challenge rank (cumulative)
  const gid = (await q(`SELECT group_id FROM group_members WHERE user_id=$1 LIMIT 1`, [uid(req)])).rows[0]?.group_id;
  let royalRank = null;
  if (gid) {
    const rr = await q(
      `SELECT rank FROM (
         SELECT user_id, RANK() OVER (ORDER BY weekly_xp DESC) AS rank
         FROM group_members WHERE group_id=$1
       ) r WHERE user_id=$2`,
      [gid, uid(req)]
    );
    royalRank = rr.rows[0]?.rank ?? null;
  }

  res.json({
    xp: u.xp || 0,
    total_xp: u.total_xp || 0,
    streak: u.streak || 0,
    streak_freezes: u.streak_freezes || 0,
    level: levelInfo,
    royal_rank: royalRank,
    levels: LEVELS,
  });
});

// GET /gamification/royal-leaderboard
router.get('/royal-leaderboard', async (req, res) => {
  const gid = (await q(`SELECT group_id FROM group_members WHERE user_id=$1 LIMIT 1`, [uid(req)])).rows[0]?.group_id ?? 1;
  // Use total XP stored in users for royal challenge (cumulative across all weeks)
  const r = await q(
    `SELECT u.id, COALESCE(u.name,'Member') AS name, u.total_xp AS xp, u.level
     FROM group_members gm JOIN users u ON u.id=gm.user_id
     WHERE gm.group_id=$1 ORDER BY u.total_xp DESC LIMIT 50`,
    [gid]
  );
  const rows = r.rows.map((m, i) => ({ ...m, rank: i + 1, you: m.id === uid(req) }));
  res.json({ members: rows });
});

// GET /gamification/weekly-winners
router.get('/weekly-winners', async (req, res) => {
  const gid = (await q(`SELECT group_id FROM group_members WHERE user_id=$1 LIMIT 1`, [uid(req)])).rows[0]?.group_id ?? 1;
  const r = await q(
    `SELECT ww.week_start, ww.rank, ww.weekly_xp, ww.prize_amount, u.name
     FROM weekly_winners ww JOIN users u ON u.id=ww.user_id
     WHERE ww.group_id=$1 ORDER BY ww.week_start DESC, ww.rank ASC LIMIT 15`,
    [gid]
  );
  res.json({ winners: r.rows });
});

// POST /gamification/freeze/use — use a streak freeze
router.post('/freeze/use', async (req, res) => {
  const u = (await q(`SELECT streak_freezes, streak FROM users WHERE id=$1`, [uid(req)])).rows[0];
  if (!u || u.streak_freezes < 1) {
    return res.status(400).json({ message: 'No streak freezes available' });
  }
  await q(`UPDATE users SET streak_freezes=streak_freezes-1 WHERE id=$1`, [uid(req)]);
  await q(`INSERT INTO streak_freeze_log (user_id, type) VALUES ($1,'used')`, [uid(req)]);
  res.json({ remaining_freezes: u.streak_freezes - 1, streak: u.streak });
});

// POST /gamification/freeze/buy — spend 500 XP for a freeze
router.post('/freeze/buy', async (req, res) => {
  const u = (await q(`SELECT xp, streak_freezes FROM users WHERE id=$1`, [uid(req)])).rows[0];
  if (!u || u.xp < 500) return res.status(400).json({ message: 'Need 500 XP to buy a freeze' });
  await q(`UPDATE users SET xp=xp-500, streak_freezes=streak_freezes+1 WHERE id=$1`, [uid(req)]);
  await q(`INSERT INTO streak_freeze_log (user_id, type) VALUES ($1,'purchased')`, [uid(req)]);
  res.json({ xp_remaining: u.xp - 500, streak_freezes: u.streak_freezes + 1 });
});

// GET /gamification/points-store — items available for purchase
router.get('/points-store', async (req, res) => {
  const u = (await q(`SELECT xp FROM users WHERE id=$1`, [uid(req)])).rows[0] || {};
  const items = [
    { id: 'freeze', name: 'Streak Freeze', emoji: '❄️', cost: 500, description: 'Protect your streak for 1 day' },
    { id: 'double_xp_day', name: 'Double XP Day', emoji: '⚡', cost: 1000, description: 'Earn 2× XP for 24 hours' },
    { id: 'cheat_meal', name: 'Cheat Meal Pass', emoji: '🍕', cost: 800, description: 'One guilt-free meal pass' },
  ];
  res.json({ items, xp: u.xp || 0 });
});

// POST /gamification/points-store/redeem { item_id }
router.post('/points-store/redeem', async (req, res) => {
  const { item_id } = req.body || {};
  const costs = { freeze: 500, double_xp_day: 1000, cheat_meal: 800 };
  const cost = costs[item_id];
  if (!cost) return res.status(400).json({ message: 'Invalid item' });

  const u = (await q(`SELECT xp, streak_freezes FROM users WHERE id=$1`, [uid(req)])).rows[0];
  if (!u || u.xp < cost) return res.status(400).json({ message: `Need ${cost} XP` });

  await q(`UPDATE users SET xp=xp-$2 WHERE id=$1`, [uid(req), cost]);
  if (item_id === 'freeze') {
    await q(`UPDATE users SET streak_freezes=streak_freezes+1 WHERE id=$1`, [uid(req)]);
    await q(`INSERT INTO streak_freeze_log (user_id, type) VALUES ($1,'purchased')`, [uid(req)]);
  }
  res.json({ success: true, xp_remaining: u.xp - cost });
});

// POST /gamification/update-level — recalculate user level (call after XP award)
export async function updateUserLevel(userId) {
  try {
    const u = (await q(`SELECT total_xp FROM users WHERE id=$1`, [userId])).rows[0];
    if (!u) return;
    const level = computeLevel(u.total_xp || 0);
    await q(`UPDATE users SET level=$2 WHERE id=$1`, [userId, level.name]);
  } catch (e) {
    console.warn('[gamification] updateUserLevel failed:', e.message);
  }
}

export default router;
