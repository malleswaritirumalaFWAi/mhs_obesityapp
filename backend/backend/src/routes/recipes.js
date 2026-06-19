import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);

// GET /recipes?cuisine=&diet_type=&q=
router.get('/', async (req, res) => {
  const { cuisine, diet_type, q: search } = req.query;
  let sql = `SELECT id, title, cuisine, diet_type, calories, prep_minutes, image_url FROM recipes WHERE TRUE`;
  const vals = [];
  if (cuisine) { vals.push(cuisine); sql += ` AND cuisine=$${vals.length}`; }
  if (diet_type) { vals.push(diet_type); sql += ` AND diet_type=$${vals.length}`; }
  if (search) { vals.push(`%${search}%`); sql += ` AND title ILIKE $${vals.length}`; }
  sql += ` ORDER BY id LIMIT 50`;
  const r = await q(sql, vals);
  res.json({ recipes: r.rows });
});

// GET /recipes/:id — full recipe with ingredients and steps
router.get('/:id', async (req, res) => {
  const r = await q(`SELECT * FROM recipes WHERE id=$1`, [req.params.id]);
  if (!r.rows[0]) return res.status(404).json({ message: 'Not found' });
  res.json(r.rows[0]);
});

export default router;
