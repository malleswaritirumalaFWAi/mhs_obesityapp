import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

router.get('/', async (req, res) => {
  const latest = (await q(
    `SELECT * FROM body_measurements WHERE user_id=$1 ORDER BY created_at DESC LIMIT 1`, [uid(req)]
  )).rows[0] || null;
  const history = (await q(
    `SELECT * FROM body_measurements WHERE user_id=$1 ORDER BY created_at DESC LIMIT 20`, [uid(req)]
  )).rows;
  res.json({ latest, history });
});

router.post('/', async (req, res) => {
  const { waist, hips, chest, arms, weight } = req.body || {};
  const r = await q(
    `INSERT INTO body_measurements (user_id,waist,hips,chest,arms,weight) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
    [uid(req), waist || null, hips || null, chest || null, arms || null, weight || null]
  );
  await q(`UPDATE users SET xp=xp+10, total_xp=total_xp+10 WHERE id=$1`, [uid(req)]);
  await q(`UPDATE group_members SET weekly_xp=weekly_xp+10 WHERE user_id=$1`, [uid(req)]);
  res.json({ measurement: r.rows[0], xp_earned: 10 });
});

export default router;
