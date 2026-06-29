import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';
import { markTasksDoneByIcon } from '../tasks.js';

/**
 * Call the Anthropic Messages API.
 * Tries Authorization: Bearer first (required for OAuth tokens sk-ant-oat*).
 * On 401, retries with x-api-key header (required for regular API keys sk-ant-api*).
 * This handles both key formats automatically without requiring env var changes.
 */
async function callClaude(key, body) {
  async function _fetch(headers) {
    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'anthropic-version': '2023-06-01', ...headers },
      body: JSON.stringify(body),
    });
    const data = await res.json();
    if (!res.ok) throw Object.assign(new Error(data?.error?.message ?? res.statusText), { status: res.status });
    return data;
  }

  try {
    return await _fetch({ 'Authorization': `Bearer ${key}` });
  } catch (e) {
    if (e.status === 401) {
      // Bearer auth rejected — try x-api-key format (regular API keys)
      console.warn('[callClaude] Bearer auth failed, retrying with x-api-key');
      return await _fetch({ 'x-api-key': key });
    }
    throw e;
  }
}

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

  // Log what we received so you can see it in the backend terminal.
  console.log('[meals/analyze] key set:', !!key, '| image_base64 length:', image_base64?.length ?? 0, '| mime:', mime);

  if (!key) {
    console.warn('[meals/analyze] No API key — returning mock');
    return res.json({ ...MOCK, _mock: true, _reason: 'no_api_key' });
  }
  if (!image_base64) {
    console.warn('[meals/analyze] No image data received — returning mock');
    return res.json({ ...MOCK, _mock: true, _reason: 'no_image' });
  }

  // Use Haiku for vision tasks: same food-ID quality, 10× higher rate limits,
  // 20× cheaper per token than Sonnet — avoids rate-limit errors in normal use.
  // Override with MEAL_ANALYSIS_MODEL env var if a different model is preferred.
  const model = process.env.MEAL_ANALYSIS_MODEL || 'claude-haiku-4-5-20251001';

  const requestBody = {
    model,
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
              'estimate totals. Respond with ONLY valid JSON, no prose, no markdown, shaped exactly as: ' +
              '{"items":["food name"],"calories":480,"confidence":92,' +
              '"carbs":55,"protein":25,"fat":20}. ' +
              'items is an array of strings. calories is a whole number. ' +
              'carbs+protein+fat must sum to 100.',
          },
        ],
      },
    ],
  };

  async function attemptAnalysis(attemptsLeft) {
    try {
      console.log(`[meals/analyze] Calling model: ${model} (attempts left: ${attemptsLeft})`);
      const msg = await callClaude(key, requestBody);

      const text = (msg.content || []).map((c) => c.text || '').join('').trim();
      console.log('[meals/analyze] Claude response:', text.slice(0, 300));

      const start = text.indexOf('{');
      const end   = text.lastIndexOf('}');
      if (start === -1 || end === -1) throw new Error('No JSON in Claude response: ' + text.slice(0, 100));
      return JSON.parse(text.slice(start, end + 1));
    } catch (e) {
      const isRateLimit = e.status === 429 || (e.message || '').toLowerCase().includes('rate limit');
      if (isRateLimit) {
        if (attemptsLeft > 1) {
          // Wait 8 seconds then retry — handles transient rate-limit spikes.
          console.warn(`[meals/analyze] Rate limited — retrying in 8s (${attemptsLeft - 1} left)`);
          await new Promise((r) => setTimeout(r, 8000));
          return attemptAnalysis(attemptsLeft - 1);
        }
        // All retries exhausted — return mock so the user can still log their meal.
        console.warn('[meals/analyze] Rate limit exhausted — returning mock estimate');
        return { ...MOCK, _mock: true, _reason: 'rate_limit' };
      }
      throw e;
    }
  }

  try {
    const json = await attemptAnalysis(3); // 1 attempt + 2 retries on rate limit
    res.json({ ...MOCK, ...json });
  } catch (e) {
    // Non-rate-limit failures: still fall back to mock so user isn't blocked.
    console.error('[meals/analyze] Claude FAILED —', e.message, '| status:', e.status ?? 'n/a');
    res.json({ ...MOCK, _mock: true, _reason: 'ai_error' });
  }
});

// POST /meals  { meal_type, items, calories, carbs, protein, fat, photo_url }
router.post('/', async (req, res) => {
  const { meal_type, items, calories, carbs, protein, fat, photo_url } = req.body || {};

  // Check active perks before inserting
  const userRow = (await q(`SELECT double_xp_expires_at, cheat_meal_passes FROM users WHERE id=$1`, [req.user.uid])).rows[0] || {};
  const doubleXpActive = userRow.double_xp_expires_at && new Date(userRow.double_xp_expires_at) > new Date();
  const useCheatPass = (userRow.cheat_meal_passes ?? 0) > 0;

  const r = await q(
    `INSERT INTO meals (user_id, meal_type, items, calories, carbs, protein, fat, photo_url, cheat_meal)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`,
    [req.user.uid, meal_type, JSON.stringify(items || []), calories, carbs, protein, fat, photo_url || null, useCheatPass]
  );

  // Consume cheat meal pass if used
  if (useCheatPass) {
    await q(`UPDATE users SET cheat_meal_passes=cheat_meal_passes-1 WHERE id=$1`, [req.user.uid]);
  }

  const baseXp = doubleXpActive ? 30 : 15;
  await q(`UPDATE users SET xp=xp+$2, total_xp=total_xp+$2 WHERE id=$1`, [req.user.uid, baseXp]);
  await q(`UPDATE group_members SET weekly_xp=weekly_xp+$2 WHERE user_id=$1`, [req.user.uid, baseXp]);

  // First meal badge
  const mealCount = await q(`SELECT COUNT(*) FROM meals WHERE user_id=$1`, [req.user.uid]);
  if (Number(mealCount.rows[0].count) === 1) {
    const b = await q(`SELECT id FROM badges WHERE code='first_bite'`);
    if (b.rows[0]) await q(`INSERT INTO user_badges (user_id,badge_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`, [req.user.uid, b.rows[0].id]);
  }

  // Mark the "Log a meal" task done only when Breakfast + Lunch + Dinner are all logged today.
  const today = new Date().toISOString().slice(0, 10);
  const todayMeals = await q(
    `SELECT DISTINCT meal_type FROM meals WHERE user_id=$1 AND DATE(created_at)=$2`,
    [req.user.uid, today]
  );
  const types = todayMeals.rows.map(m => m.meal_type);
  if (['Breakfast', 'Lunch', 'Dinner'].every(t => types.includes(t))) {
    markTasksDoneByIcon(req.user.uid, ['restaurant']).catch(() => {});
  }

  // Combo bonus: all 4 meal types logged today
  let bonusXp = 0;
  if (['Breakfast','Lunch','Snack','Dinner'].every(t => types.includes(t))) {
    // Check if bonus already given today
    const alreadyGiven = await q(
      `SELECT id FROM notifications WHERE user_id=$1 AND type='combo_bonus' AND created_at::date=$2`,
      [req.user.uid, today]
    );
    if (!alreadyGiven.rows[0]) {
      bonusXp = doubleXpActive ? 40 : 20;
      await q(`UPDATE users SET xp=xp+$2, total_xp=total_xp+$2 WHERE id=$1`, [req.user.uid, bonusXp]);
      await q(`UPDATE group_members SET weekly_xp=weekly_xp+$2 WHERE user_id=$1`, [req.user.uid, bonusXp]);
      await q(`INSERT INTO notifications (user_id,type,title,body) VALUES ($1,'combo_bonus','🍽️ Combo Bonus!','All 4 meals logged today! +${bonusXp} bonus XP')`, [req.user.uid]);
    }
  }

  res.json({ id: r.rows[0].id, xp_awarded: baseXp + bonusXp, combo_bonus: bonusXp, double_xp_active: !!doubleXpActive, cheat_meal_used: useCheatPass });
});

// GET /meals  -> last 60 meals for the logged-in user, newest first
router.get('/', async (req, res) => {
  const r = await q(
    `SELECT id, meal_type, items, calories, carbs, protein, fat, created_at
     FROM meals WHERE user_id=$1
     ORDER BY created_at DESC LIMIT 60`,
    [req.user.uid]
  );
  res.json({ meals: r.rows });
});

export default router;
