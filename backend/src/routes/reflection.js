import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

router.get('/', async (req, res) => {
  const { type = 'evening' } = req.query;
  const today = new Date().toISOString().slice(0, 10);
  const todayEntry = (await q(
    `SELECT * FROM reflections WHERE user_id=$1 AND type=$2 AND created_at::date=$3 LIMIT 1`,
    [uid(req), type, today]
  )).rows[0] || null;
  const history = (await q(
    `SELECT * FROM reflections WHERE user_id=$1 AND type=$2 ORDER BY created_at DESC LIMIT 30`,
    [uid(req), type]
  )).rows;
  res.json({ today: todayEntry, history });
});

router.post('/', async (req, res) => {
  const { type = 'evening', text, mood } = req.body || {};
  const r = await q(
    `INSERT INTO reflections (user_id,type,text,mood) VALUES ($1,$2,$3,$4) RETURNING *`,
    [uid(req), type, text || null, mood || null]
  );
  await q(`UPDATE users SET xp=xp+10, total_xp=total_xp+10 WHERE id=$1`, [uid(req)]);
  await q(`UPDATE group_members SET weekly_xp=weekly_xp+10 WHERE user_id=$1`, [uid(req)]);

  // Insert notification for reflection done
  await q(
    `INSERT INTO notifications (user_id,type,title,body) VALUES ($1,'reflection','Evening reflection done!','Great job journaling today. +10 XP')`,
    [uid(req)]
  ).catch(() => {});

  res.json({ reflection: r.rows[0], xp_earned: 10 });
});

export default router;
