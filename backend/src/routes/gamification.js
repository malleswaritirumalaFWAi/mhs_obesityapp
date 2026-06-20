import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

const LEVELS = [
  { name: 'bronze',   label: 'Bronze',   emoji: '🥉', min: 0,     max: 999   },
  { name: 'silver',   label: 'Silver',   emoji: '🥈', min: 1000,  max: 2999  },
  { name: 'gold',     label: 'Gold',     emoji: '🥇', min: 3000,  max: 5999  },
  { name: 'platinum', label: 'Platinum', emoji: '💎', min: 6000,  max: 9999  },
  { name: 'diamond',  label: 'Diamond',  emoji: '👑', min: 10000, max: Infinity },
];

export async function updateUserLevel(userId) {
  try {
    const r = await q(`SELECT total_xp FROM users WHERE id=$1`, [userId]);
    const totalXp = r.rows[0]?.total_xp ?? 0;
    const level = LEVELS.find(l => totalXp >= l.min && totalXp <= l.max) ?? LEVELS[0];
    await q(`UPDATE users SET level=$1 WHERE id=$2`, [level.name, userId]);
    return level;
  } catch { return null; }
}

router.get('/status', async (req, res) => {
  const u = (await q(`SELECT xp, total_xp, streak, streak_freezes, level FROM users WHERE id=$1`, [uid(req)])).rows[0] || {};
  const totalXp = u.total_xp ?? 0;
  const level = LEVELS.find(l => totalXp >= l.min && totalXp <= l.max) ?? LEVELS[0];
  const nextLevel = LEVELS[LEVELS.indexOf(level) + 1];
  const rank = (await q(
    `SELECT COUNT(*)+1 AS rank FROM users WHERE total_xp > $1`, [totalXp]
  )).rows[0]?.rank ?? null;
  res.json({
    xp: u.xp ?? 0,
    total_xp: totalXp,
    streak: u.streak ?? 0,
    streak_freezes: u.streak_freezes ?? 0,
    royal_rank: Number(rank),
    level: {
      name: level.name, label: level.label, emoji: level.emoji,
      next_threshold: nextLevel?.min ?? null,
      progress_to_next: nextLevel ? totalXp - level.min : null,
    },
  });
});

router.get('/royal-leaderboard', async (req, res) => {
  const rows = (await q(
    `SELECT u.id, u.name, u.total_xp, u.level,
       RANK() OVER (ORDER BY u.total_xp DESC) AS rank
     FROM users u ORDER BY u.total_xp DESC LIMIT 50`
  )).rows;
  const userId = uid(req);
  res.json({ leaderboard: rows.map(r => ({ ...r, you: r.id === userId })) });
});

router.get('/weekly-winners', async (req, res) => {
  const rows = (await q(
    `SELECT ww.*, u.name FROM weekly_winners ww JOIN users u ON u.id=ww.user_id
     ORDER BY ww.week_start DESC, ww.rank ASC LIMIT 15`
  )).rows;
  res.json({ winners: rows });
});

router.post('/freeze/use', async (req, res) => {
  const r = (await q(`SELECT streak_freezes FROM users WHERE id=$1`, [uid(req)])).rows[0];
  if (!r || r.streak_freezes < 1) return res.status(400).json({ message: 'No freezes available' });
  await q(`UPDATE users SET streak_freezes=streak_freezes-1 WHERE id=$1`, [uid(req)]);
  await q(`INSERT INTO streak_freeze_log (user_id, type) VALUES ($1,'used')`, [uid(req)]);
  res.json({ ok: true });
});

router.post('/freeze/buy', async (req, res) => {
  const r = (await q(`SELECT xp, streak_freezes FROM users WHERE id=$1`, [uid(req)])).rows[0];
  if (!r || r.xp < 500) return res.status(400).json({ message: 'Insufficient XP (need 500)' });
  await q(`UPDATE users SET xp=xp-500, streak_freezes=streak_freezes+1 WHERE id=$1`, [uid(req)]);
  res.json({ ok: true });
});

router.get('/points-store', async (_req, res) => {
  res.json({ items: [
    { id: 'freeze',        name: 'Streak Freeze',    emoji: '❄️',  cost: 500,  description: 'Protect your streak for 1 day' },
    { id: 'double_xp_day', name: 'Double XP Day',    emoji: '⚡',  cost: 1000, description: 'Earn 2x XP for 24 hours' },
    { id: 'cheat_meal',    name: 'Cheat Meal Pass',  emoji: '🍕',  cost: 800,  description: 'One guilt-free meal pass' },
  ]});
});

router.post('/points-store/redeem', async (req, res) => {
  const { item_id } = req.body || {};
  const costs = { freeze: 500, double_xp_day: 1000, cheat_meal: 800 };
  const cost = costs[item_id];
  if (!cost) return res.status(400).json({ message: 'Invalid item' });
  const r = (await q(`SELECT xp, streak_freezes FROM users WHERE id=$1`, [uid(req)])).rows[0];
  if (!r || r.xp < cost) return res.status(400).json({ message: `Need ${cost} XP` });
  await q(`UPDATE users SET xp=xp-$2 WHERE id=$1`, [uid(req), cost]);
  if (item_id === 'freeze') {
    await q(`UPDATE users SET streak_freezes=streak_freezes+1 WHERE id=$1`, [uid(req)]);
  }
  res.json({ ok: true, message: `${item_id} redeemed!` });
});

export default router;
