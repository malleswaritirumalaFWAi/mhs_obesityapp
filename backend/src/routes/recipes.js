import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);

router.get('/', async (req, res) => {
  const { cuisine, diet_type, q: search } = req.query;
  let sql = `SELECT * FROM recipes WHERE TRUE`;
  const vals = [];
  if (cuisine) { vals.push(cuisine); sql += ` AND cuisine=$${vals.length}`; }
  if (diet_type) { vals.push(diet_type); sql += ` AND diet_type=$${vals.length}`; }
  if (search) { vals.push(`%${search}%`); sql += ` AND title ILIKE $${vals.length}`; }
  sql += ` ORDER BY created_at DESC`;
  const rows = (await q(sql, vals)).rows;
  res.json({ recipes: rows });
});

router.get('/:id', async (req, res) => {
  const r = (await q(`SELECT * FROM recipes WHERE id=$1`, [req.params.id])).rows[0];
  if (!r) return res.status(404).json({ message: 'Not found' });
  res.json({ recipe: r });
});

export default router;
