import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);

// GET /exercises?category=&level=
router.get('/', async (req, res) => {
  const { category, level } = req.query;
  let sql = `SELECT id, title, category, level, duration_min, calories_est FROM exercises WHERE TRUE`;
  const vals = [];
  if (category) { vals.push(category); sql += ` AND category=$${vals.length}`; }
  if (level) { vals.push(level); sql += ` AND level=$${vals.length}`; }
  sql += ` ORDER BY id`;
  const r = await q(sql, vals);
  res.json({ exercises: r.rows });
});

// GET /exercises/:id
router.get('/:id', async (req, res) => {
  const r = await q(`SELECT * FROM exercises WHERE id=$1`, [req.params.id]);
  if (!r.rows[0]) return res.status(404).json({ message: 'Not found' });
  res.json(r.rows[0]);
});

export default router;
