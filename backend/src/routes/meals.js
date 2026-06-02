import { Router } from 'express';
import Anthropic from '@anthropic-ai/sdk';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);

const MOCK = {
  items: ['Roti (2)', 'Dal', 'Sabzi', 'Salad'],
  calories: 480,
  confidence: 92,
  carbs: 55,
  protein: 25,
  fat: 20,
};

// POST /meals/analyze { image_base64, mime }  -> Claude vision food + macros
router.post('/analyze', async (req, res) => {
  const { image_base64, mime } = req.body || {};
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key || !image_base64) return res.json(MOCK); // demo fallback

  try {
    const client = new Anthropic({ apiKey: key });
    const msg = await client.messages.create({
      model: process.env.ANTHROPIC_MODEL || 'claude-opus-4-8',
      max_tokens: 400,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'image',
              source: { type: 'base64', media_type: mime || 'image/jpeg', data: image_base64 },
            },
            {
              type: 'text',
              text:
                'You are a nutrition assistant. Identify the foods in this meal photo and ' +
                'estimate totals. Respond with ONLY compact JSON, no prose, shaped exactly as: ' +
                '{"items":["..."],"calories":int,"confidence":int(0-100),' +
                '"carbs":int_pct,"protein":int_pct,"fat":int_pct}. Macro percents sum to 100.',
            },
          ],
        },
      ],
    });
    const text = (msg.content || []).map((c) => c.text || '').join('');
    const json = JSON.parse(text.slice(text.indexOf('{'), text.lastIndexOf('}') + 1));
    res.json({ ...MOCK, ...json });
  } catch (e) {
    console.warn('[meals/analyze] Claude failed, returning mock:', e.message);
    res.json(MOCK);
  }
});

// POST /meals  { meal_type, items, calories, carbs, protein, fat }
router.post('/', async (req, res) => {
  const { meal_type, items, calories, carbs, protein, fat } = req.body || {};
  const r = await q(
    `INSERT INTO meals (user_id, meal_type, items, calories, carbs, protein, fat)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
    [req.user.uid, meal_type, JSON.stringify(items || []), calories, carbs, protein, fat]
  );
  await q(`UPDATE users SET xp = xp + 15 WHERE id=$1`, [req.user.uid]);
  res.json({ id: r.rows[0].id, xp_awarded: 15 });
});

export default router;
