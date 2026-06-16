import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);

router.get('/', async (req, res) => {
  const { category, level } = req.query;
  let sql = `SELECT * FROM exercises WHERE TRUE`;
  const vals = [];
  if (category) { vals.push(category); sql += ` AND category=$${vals.length}`; }
  if (level)    { vals.push(level);    sql += ` AND level=$${vals.length}`; }
  sql += ` ORDER BY created_at ASC`;
  const rows = (await q(sql, vals)).rows;
  res.json({ exercises: rows });
});

router.get('/:id', async (req, res) => {
  const r = (await q(`SELECT * FROM exercises WHERE id=$1`, [req.params.id])).rows[0];
  if (!r) return res.status(404).json({ message: 'Not found' });
  res.json({ exercise: r });
});

export default router;
