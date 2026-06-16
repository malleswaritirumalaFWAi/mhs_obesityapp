import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';
import Anthropic from '@anthropic-ai/sdk';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

const MEAL_XP = 15; // XP awarded per completed meal

// Quantity lookup for common Indian foods (enriches old string-format plans)
const ITEM_QTY_LOOKUP = {
  'oats with milk': '1 cup oats (80g) + 200ml milk',
  'oats': '1 cup (80g) with 200ml milk',
  'banana': '1 medium (100g)',
  'dal rice': '1 cup dal + 1 cup rice (~300g)',
  'dal': '1/2 cup cooked (100g)',
  'rice': '1 cup cooked (150g)',
  'salad': '1 medium bowl (100g)',
  'curd': '1/2 cup (100g)',
  'fruits': '1 cup mixed (150g)',
  'mixed fruits': '1 cup (150g)',
  'nuts': '1 small handful (30g)',
  'mixed nuts': '1 small handful (30g)',
  'roti': '2 rotis (30g each)',
  'sabzi': '1 cup cooked (150g)',
  'chapati': '2 chapatis (30g each)',
  'idli': '3 pieces (~50g each)',
  'sambar': '1/2 cup (100ml)',
  'poha': '1 cup cooked (150g)',
  'upma': '1 cup cooked (150g)',
  'paneer': '100g (~4-5 cubes)',
  'egg': '2 whole eggs',
  'milk': '1 glass (200ml)',
  'sprouts': '1/2 cup (80g)',
  'green tea': '1 cup (200ml)',
  'buttermilk': '1 glass (200ml)',
};

function enrichItems(items) {
  if (!Array.isArray(items)) return [];
  return items.map(item => {
    if (item && typeof item === 'object' && item.name) return item;
    const name = String(item || '');
    const qty = ITEM_QTY_LOOKUP[name.toLowerCase()] || '';
    return { name, qty };
  });
}

router.get('/', async (req, res) => {
  try {
    const plan = (await q(
      `SELECT dp.*, c.name AS coach_name FROM diet_plans dp
       LEFT JOIN coaches c ON c.id=dp.coach_id
       WHERE dp.user_id=$1 AND dp.status='active' ORDER BY dp.created_at DESC LIMIT 1`,
      [uid(req)]
    )).rows[0] || null;

    const today = new Date().toISOString().slice(0, 10);
    const todayNutrition = (await q(
      `SELECT COALESCE(SUM(calories),0) AS calories, COALESCE(SUM(protein),0) AS protein,
              COALESCE(SUM(carbs),0) AS carbs, COALESCE(SUM(fat),0) AS fat
       FROM meals WHERE user_id=$1 AND created_at::date=$2`,
      [uid(req), today]
    )).rows[0] || null;

    // Determine program day from users.created_at — same formula used by /dashboard and /today
    // so the day counter is consistent across all screens.
    const uRow = (await q(`SELECT created_at FROM users WHERE id=$1`, [uid(req)])).rows[0];
    const userCreatedAt = uRow?.created_at ? new Date(uRow.created_at) : new Date();
    const now = new Date();
    const diffMs = now.setHours(0,0,0,0) - new Date(userCreatedAt).setHours(0,0,0,0);
    const programDay = Math.min(Math.max(Math.floor(diffMs / 86400000) + 1, 1), 84);

    let todayDay = programDay;
    let todayWeek = Math.ceil(programDay / 7);       // week 1-12
    let dayInWeek = ((programDay - 1) % 7) + 1;      // day 1-7 within the week
    let todayMeals = null;

    if (plan) {
      const meals = Array.isArray(plan.meals) ? plan.meals : [];
      // Pick the day entry from the 7-day plan that matches today's day-in-week
      const dayPlan = meals.find(m => m.day === dayInWeek) || meals[dayInWeek - 1];
      if (dayPlan) {
        const enrich = meal => meal ? { ...meal, items: enrichItems(meal.items) } : null;
        todayMeals = {
          breakfast: enrich(dayPlan.breakfast),
          lunch: enrich(dayPlan.lunch),
          snack: enrich(dayPlan.snack),
          dinner: enrich(dayPlan.dinner),
        };
      }
    }

    // Fetch today's meal completions
    const completionRows = (await q(
      `SELECT meal_type, xp_awarded FROM diet_completions WHERE user_id=$1 AND date=$2`,
      [uid(req), today]
    )).rows;
    const completions = {};
    let totalXpEarned = 0;
    for (const row of completionRows) {
      completions[row.meal_type] = true;
      totalXpEarned += Number(row.xp_awarded);
    }

    res.json({ plan, today_nutrition: todayNutrition, today_day: todayDay, today_week: todayWeek, day_in_week: dayInWeek, today_meals: todayMeals, completions, total_xp_earned: totalXpEarned });
  } catch (e) {
    console.error('[diet_plan GET /]', e.message);
    res.status(500).json({ message: e.message });
  }
});

// Mark a meal as completed for today and award XP
router.post('/complete', async (req, res) => {
  const { meal_type } = req.body || {};
  if (!['breakfast', 'lunch', 'snack', 'dinner'].includes(meal_type)) {
    return res.status(400).json({ message: 'Invalid meal_type' });
  }
  const today = new Date().toISOString().slice(0, 10);
  try {
    const existing = (await q(
      `SELECT id FROM diet_completions WHERE user_id=$1 AND date=$2 AND meal_type=$3`,
      [uid(req), today, meal_type]
    )).rows[0];
    if (existing) return res.json({ already_completed: true, xp: 0 });

    const plan = (await q(
      `SELECT id FROM diet_plans WHERE user_id=$1 AND status='active' ORDER BY created_at DESC LIMIT 1`,
      [uid(req)]
    )).rows[0];

    await q(
      `INSERT INTO diet_completions (user_id, plan_id, date, meal_type, xp_awarded) VALUES ($1,$2,$3,$4,$5)`,
      [uid(req), plan?.id || null, today, meal_type, MEAL_XP]
    );
    await q(`UPDATE users SET xp=xp+$1, total_xp=total_xp+$1 WHERE id=$2`, [MEAL_XP, uid(req)]);
    await q(`UPDATE group_members SET weekly_xp=weekly_xp+$1 WHERE user_id=$2`, [MEAL_XP, uid(req)]).catch(() => {});

    res.json({ completed: true, xp: MEAL_XP });
  } catch (e) {
    console.error('[diet_plan POST /complete]', e.message);
    res.status(500).json({ message: e.message });
  }
});

router.post('/', authMiddleware, async (req, res) => {
  // Coach creates a diet plan
  const { user_id, week_number = 1, title, meals, notes } = req.body || {};
  const coachUser = (await q(`SELECT role FROM users WHERE id=$1`, [uid(req)])).rows[0];
  if (!coachUser || !['coach', 'admin'].includes(coachUser.role)) {
    return res.status(403).json({ message: 'Coach access required' });
  }
  await q(`UPDATE diet_plans SET status='archived' WHERE user_id=$1`, [user_id]);
  const r = await q(
    `INSERT INTO diet_plans (user_id,week_number,title,meals,notes,status)
     VALUES ($1,$2,$3,$4,$5,'active') RETURNING *`,
    [user_id, week_number, title, JSON.stringify(meals), notes]
  );
  await q(
    `INSERT INTO notifications (user_id,type,title,body) VALUES ($1,'diet_plan','New Diet Plan!','Your coach has created a personalized diet plan for you.')`,
    [user_id]
  ).catch(() => {});
  res.json({ plan: r.rows[0] });
});

router.post('/generate', async (req, res) => {
  const profile = (await q(
    `SELECT p.food_pref, p.goal, u.start_weight, u.target_weight, u.height, p.medical_conditions
     FROM profiles p JOIN users u ON u.id=p.user_id WHERE p.user_id=$1`,
    [uid(req)]
  )).rows[0] || {};

  const mockPlan = {
    title: 'AI-Generated 7-Day Indian Meal Plan',
    meals: Array.from({ length: 7 }, (_, i) => ({
      day: i + 1,
      breakfast: { items: [{ name: 'Oats with milk', qty: '1 cup oats (80g) + 200ml milk' }, { name: 'Banana', qty: '1 medium (100g)' }], cal: 320 },
      lunch:     { items: [{ name: 'Dal rice', qty: '1 cup dal + 1 cup rice (200g)' }, { name: 'Salad', qty: '1 bowl (100g)' }, { name: 'Curd', qty: '1/2 cup (100g)' }], cal: 480 },
      snack:     { items: [{ name: 'Mixed fruits', qty: '1 cup (150g)' }, { name: 'Nuts', qty: '1 handful (30g)' }], cal: 150 },
      dinner:    { items: [{ name: 'Roti', qty: '2 pieces (60g each)' }, { name: 'Sabzi', qty: '1 cup (150g)' }, { name: 'Dal', qty: '1/2 cup (100g)' }], cal: 420 },
    })),
  };

  try {
    if (process.env.ANTHROPIC_API_KEY) {
      const client = new Anthropic();
      const prompt = `Create a 7-day Indian meal plan for:
Food preference: ${profile.food_pref || 'vegetarian'}
Goal: ${profile.goal || 'lose weight'}
Medical conditions: ${profile.medical_conditions || 'none'}
Current weight: ${profile.start_weight || '?'} kg, Target: ${profile.target_weight || '?'} kg

Return JSON: { "title": "...", "meals": [ { "day": 1, "breakfast": {"items":[{"name":"...","qty":"..."}],"cal":300}, "lunch": {...}, "snack": {...}, "dinner": {...} } ... ] }
Each item must include "name" and "qty" (exact quantity e.g. "1 cup (80g)", "2 pieces (60g each)").
Focus on Indian foods: dal, sabzi, roti, rice, idli, poha, upma, paneer etc.`;

      const msg = await client.messages.create({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 2048,
        messages: [{ role: 'user', content: prompt }],
      });
      const text = msg.content[0]?.text || '';
      const json = JSON.parse(text.match(/\{[\s\S]+\}/)?.[0] || '{}');
      if (json.meals) {
        await q(`UPDATE diet_plans SET status='archived' WHERE user_id=$1`, [uid(req)]);
        await q(
          `INSERT INTO diet_plans (user_id,title,meals,ai_generated,status)
           VALUES ($1,$2,$3,TRUE,'active')`,
          [uid(req), json.title || mockPlan.title, JSON.stringify(json.meals)]
        );
        return res.json({ generated: true, plan: json });
      }
    }
  } catch (e) { console.warn('[diet-plan AI]', e.message); }

  // Fallback
  await q(`UPDATE diet_plans SET status='archived' WHERE user_id=$1`, [uid(req)]);
  await q(
    `INSERT INTO diet_plans (user_id,title,meals,ai_generated,status)
     VALUES ($1,$2,$3,TRUE,'active')`,
    [uid(req), mockPlan.title, JSON.stringify(mockPlan.meals)]
  );
  res.json({ generated: true, plan: mockPlan });
});

export default router;
