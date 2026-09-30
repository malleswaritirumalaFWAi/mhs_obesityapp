import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';
import { updateUserLevel } from './gamification.js';
import { markTasksDoneByIcon } from '../tasks.js';

const NUTRITION_PROMPT =
  'You are a nutrition assistant. Identify the foods in this meal photo and ' +
  'estimate totals. Respond with ONLY valid JSON, no prose, no markdown, shaped exactly as: ' +
  '{"items":["food name"],"calories":480,"confidence":92,' +
  '"carbs":55,"protein":25,"fat":20}. ' +
  'items is an array of strings. calories is a whole number. ' +
  'carbs+protein+fat must sum to 100.';

/** Parse the JSON nutrition object from any LLM text response. */
function parseNutritionJson(text) {
  const start = text.indexOf('{');
  const end   = text.lastIndexOf('}');
  if (start === -1 || end === -1) throw new Error('No JSON in response: ' + text.slice(0, 100));
  return JSON.parse(text.slice(start, end + 1));
}

/**
 * Call Anthropic Claude vision API.
 * Supports both OAuth tokens (Bearer) and regular API keys (x-api-key).
 * Includes anthropic-workspace-id header if ANTHROPIC_WORKSPACE_ID is set.
 */
async function callClaude(key, image_base64, mime) {
  const workspaceId = process.env.ANTHROPIC_WORKSPACE_ID;
  const extraHeaders = workspaceId ? { 'anthropic-workspace-id': workspaceId } : {};
  const model = process.env.MEAL_ANALYSIS_MODEL || 'claude-haiku-4-5-20251001';

  const body = {
    model,
    max_tokens: 400,
    messages: [{
      role: 'user',
      content: [
        { type: 'image', source: { type: 'base64', media_type: mime || 'image/jpeg', data: image_base64 } },
        { type: 'text', text: NUTRITION_PROMPT },
      ],
    }],
  };

  async function _fetch(authHeaders) {
    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'anthropic-version': '2023-06-01', ...extraHeaders, ...authHeaders },
      body: JSON.stringify(body),
    });
    const data = await res.json();
    if (!res.ok) throw Object.assign(new Error(data?.error?.message ?? res.statusText), { status: res.status });
    const text = (data.content || []).map((c) => c.text || '').join('').trim();
    console.log('[callClaude] response:', text.slice(0, 200));
    return parseNutritionJson(text);
  }

  try {
    return await _fetch({ 'Authorization': `Bearer ${key}` });
  } catch (e) {
    if (e.status === 401) {
      console.warn('[callClaude] Bearer failed, retrying with x-api-key');
      return await _fetch({ 'x-api-key': key });
    }
    throw e;
  }
}

/**
 * Call Google Gemini vision API (free tier: 1500 req/day).
 * Get a free API key at https://aistudio.google.com/app/apikey
 */
async function callGemini(key, image_base64, mime) {
  const model = process.env.GEMINI_MODEL || 'gemini-flash-latest';
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`;
  const body = {
    contents: [{
      parts: [
        { inline_data: { mime_type: mime || 'image/jpeg', data: image_base64 } },
        { text: NUTRITION_PROMPT },
      ],
    }],
    generationConfig: { maxOutputTokens: 400, temperature: 0.1 },
  };

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) throw Object.assign(new Error(data?.error?.message ?? res.statusText), { status: res.status });
  const text = (data.candidates?.[0]?.content?.parts?.[0]?.text || '').trim();
  console.log('[callGemini] response:', text.slice(0, 200));
  return parseNutritionJson(text);
}

/**
 * Call DeepSeek-V4.1-Flash vision API.
 * Model: deepseek-flash — supports image input, uses reasoning.
 * Uses effort=low to skip deep reasoning for simple food ID tasks.
 */
async function callDeepSeek(key, image_base64, mime) {
  const body = {
    model: 'deepseek-flash',
    max_tokens: 8000, // reasoning model needs room to think + respond
    messages: [{
      role: 'user',
      content: [
        { type: 'image_url', image_url: { url: `data:${mime || 'image/jpeg'};base64,${image_base64}` } },
        { type: 'text', text: NUTRITION_PROMPT },
      ],
    }],
  };

  const res = await fetch('https://api.deepseek.com/chat/completions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${key}` },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) throw Object.assign(new Error(data?.error?.message ?? res.statusText), { status: res.status });
  // deepseek-flash is a reasoning model: final answer in content, thinking in reasoning_content
  const text = (data.choices?.[0]?.message?.content || data.choices?.[0]?.message?.reasoning_content || '').trim();
  console.log('[callDeepSeek] response:', text.slice(0, 200));
  return parseNutritionJson(text);
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

// POST /meals/analyze { image_base64, mime }  -> AI vision food + macros
router.post('/analyze', async (req, res) => {
  const { image_base64, mime } = req.body || {};
  const deepseekKey  = process.env.DEEPSEEK_API_KEY;
  const geminiKey    = process.env.GEMINI_API_KEY;
  const anthropicKey = process.env.ANTHROPIC_API_KEY;
  // Priority: DeepSeek → Gemini (free) → Anthropic (paid)
  const provider  = deepseekKey ? 'deepseek' : geminiKey ? 'gemini' : anthropicKey ? 'anthropic' : 'none';

  console.log('[meals/analyze] provider:', provider, '| image length:', image_base64?.length ?? 0);

  if (provider === 'none') {
    console.warn('[meals/analyze] No API key — returning mock');
    return res.json({ ...MOCK, _mock: true, _reason: 'no_api_key' });
  }
  if (!image_base64) {
    console.warn('[meals/analyze] No image — returning mock');
    return res.json({ ...MOCK, _mock: true, _reason: 'no_image' });
  }

  async function attemptAnalysis(attemptsLeft) {
    try {
      const json = deepseekKey
        ? await callDeepSeek(deepseekKey, image_base64, mime)
        : geminiKey
          ? await callGemini(geminiKey, image_base64, mime)
          : await callClaude(anthropicKey, image_base64, mime);
      return json;
    } catch (e) {
      const isRateLimit = e.status === 429 || (e.message || '').toLowerCase().includes('rate limit');
      if (isRateLimit && attemptsLeft > 1) {
        console.warn(`[meals/analyze] Rate limited — retrying in 8s (${attemptsLeft - 1} left)`);
        await new Promise((r) => setTimeout(r, 8000));
        return attemptAnalysis(attemptsLeft - 1);
      }
      if (isRateLimit) {
        console.warn('[meals/analyze] Rate limit exhausted — returning mock');
        return { ...MOCK, _mock: true, _reason: 'rate_limit' };
      }
      throw e;
    }
  }

  try {
    const json = await attemptAnalysis(3);
    res.json({ ...MOCK, ...json });
  } catch (e) {
    console.error('[meals/analyze] AI FAILED —', e.message, '| status:', e.status ?? 'n/a');
    const reason = (e.status === 401 || e.status === 403) ? 'auth_error' : 'ai_error';
    res.json({ ...MOCK, _mock: true, _reason: reason });
  }
});

// POST /meals  { meal_type, items, calories, carbs, protein, fat, photo_url }
router.post('/', async (req, res) => {
  const { meal_type, items, calories, carbs, protein, fat, photo_url } = req.body || {};

  // Idempotency guard: block duplicate submissions of the same meal_type
  // within a 30-second window (catches double-tap / slow-network re-submits).
  const recent = (await q(
    `SELECT id FROM meals WHERE user_id=$1 AND meal_type=$2
       AND created_at > NOW() - INTERVAL '30 seconds' LIMIT 1`,
    [req.user.uid, meal_type]
  )).rows[0];
  if (recent) return res.json({ id: recent.id, xp_awarded: 0, combo_bonus: 0, duplicate: true });

  // Duplicate guard for main meals (Breakfast / Lunch / Dinner) — only one per day allowed.
  // Snacks can be logged multiple times.
  const isSnack = (meal_type || '').toLowerCase() === 'snacks';
  if (!isSnack) {
    const today = new Date().toISOString().slice(0, 10);
    const existing = (await q(
      `SELECT id FROM meals WHERE user_id=$1 AND meal_type=$2 AND DATE(created_at)=$3 LIMIT 1`,
      [req.user.uid, meal_type, today]
    )).rows[0];
    if (existing) {
      return res.status(409).json({ error: 'duplicate_meal', existing_id: existing.id,
        message: `You already logged ${meal_type} today. Use PUT /meals/${existing.id} to update it.` });
    }
  }

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
  await updateUserLevel(req.user.uid);

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
    await markTasksDoneByIcon(req.user.uid, ['restaurant']);
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
      await updateUserLevel(req.user.uid);
      await q(`INSERT INTO notifications (user_id,type,title,body) VALUES ($1,'combo_bonus','🍽️ Combo Bonus!','All 4 meals logged today! +${bonusXp} bonus XP')`, [req.user.uid]);
    }
  }

  res.json({ id: r.rows[0].id, xp_awarded: baseXp + bonusXp, combo_bonus: bonusXp, double_xp_active: !!doubleXpActive, cheat_meal_used: useCheatPass });
});

// PUT /meals/:id  -> append new items/macros to an existing meal entry (update flow)
router.put('/:id', async (req, res) => {
  const { items, calories, carbs, protein, fat } = req.body || {};
  const mealId = parseInt(req.params.id, 10);
  if (!mealId) return res.status(400).json({ message: 'Invalid meal id' });

  const existing = (await q(
    `SELECT id, items, calories, carbs, protein, fat FROM meals WHERE id=$1 AND user_id=$2`,
    [mealId, req.user.uid]
  )).rows[0];
  if (!existing) return res.status(404).json({ message: 'Meal not found' });

  let existingItems = [];
  try { existingItems = JSON.parse(existing.items || '[]'); } catch (_) {}
  const newItems = Array.isArray(items) ? items : [];
  const mergedItems = [...existingItems, ...newItems];

  await q(
    `UPDATE meals SET items=$1, calories=$2, carbs=$3, protein=$4, fat=$5, created_at=NOW() WHERE id=$6`,
    [
      JSON.stringify(mergedItems),
      (Number(existing.calories) || 0) + (Number(calories) || 0),
      (Number(existing.carbs)   || 0) + (Number(carbs)    || 0),
      (Number(existing.protein) || 0) + (Number(protein)  || 0),
      (Number(existing.fat)     || 0) + (Number(fat)      || 0),
      mealId,
    ]
  );

  res.json({ updated: true });
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
