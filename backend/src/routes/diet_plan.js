import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';
import Anthropic from '@anthropic-ai/sdk';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

const MEAL_XP = 15; // XP awarded per completed meal

/**
 * Build a personalised 7-day plan based on the user's profile.
 * Varies by food_pref (vegetarian / non-vegetarian / vegan / eggetarian)
 * and adjusts calorie targets for goal (lose / maintain / gain).
 */
function buildDefaultPlan(profile = {}) {
  const pref  = (profile.food_pref || 'vegetarian').toLowerCase();
  const goal  = (profile.goal      || 'lose weight').toLowerCase();

  const isVegan    = pref.includes('vegan');
  const isNonVeg   = pref.includes('non') || pref.includes('chicken') || pref.includes('meat') || pref.includes('fish');
  const isEgg      = pref.includes('egg') || isNonVeg;

  // Calorie multiplier: lose → base, maintain → +300, gain → +600
  const calBoost   = goal.includes('maintain') ? 300 : goal.includes('gain') ? 600 : 0;
  const bump       = (cal) => cal + Math.round(calBoost / 4); // spread across 4 meals

  // ── Breakfast pool ──
  const bfVeg = [
    { items: [{ name: 'Oats with milk',   qty: '1 cup (80g) + 200ml milk' },     { name: 'Banana',         qty: '1 medium (100g)' }],                    cal: bump(320) },
    { items: [{ name: 'Idli',             qty: '3 pieces (150g)' },               { name: 'Sambar',         qty: '1/2 cup (100ml)' },  { name: 'Coconut chutney', qty: '2 tbsp (30g)' }], cal: bump(280) },
    { items: [{ name: 'Poha',             qty: '1 cup cooked (150g)' },           { name: 'Green tea',      qty: '1 cup (200ml)' }],                       cal: bump(260) },
    { items: [{ name: 'Upma',             qty: '1 cup cooked (150g)' },           { name: 'Buttermilk',     qty: '1 glass (200ml)' }],                     cal: bump(270) },
    { items: [{ name: 'Whole wheat roti', qty: '2 rotis (30g each)' },            { name: 'Paneer bhurji',  qty: '1/2 cup (80g)' }],                       cal: bump(340) },
    { items: [{ name: 'Sprouts salad',    qty: '1 cup (150g)' },                  { name: 'Milk',           qty: '1 glass (200ml)' }],                     cal: bump(250) },
    { items: [{ name: 'Dalia porridge',   qty: '1 cup cooked (150g)' },           { name: 'Mixed fruits',   qty: '1/2 cup (80g)' }],                       cal: bump(300) },
  ];
  const bfEgg = [
    { items: [{ name: 'Boiled eggs',      qty: '2 whole eggs' },                  { name: 'Whole wheat toast', qty: '2 slices (60g)' }, { name: 'Green tea', qty: '1 cup' }], cal: bump(310) },
    { items: [{ name: 'Egg omelette',     qty: '2 eggs + 1 tsp oil' },            { name: 'Oats',           qty: '1/2 cup (40g) cooked' }],               cal: bump(320) },
    { items: [{ name: 'Scrambled eggs',   qty: '2 eggs' },                        { name: 'Multigrain bread', qty: '2 slices (60g)' }],                    cal: bump(300) },
  ];
  const bfVegan = [
    { items: [{ name: 'Oats with soy milk', qty: '1 cup (80g) + 200ml soy milk' }, { name: 'Banana',       qty: '1 medium (100g)' }],                    cal: bump(310) },
    { items: [{ name: 'Idli',             qty: '3 pieces (150g)' },               { name: 'Sambar',         qty: '1/2 cup (100ml)' }],                    cal: bump(260) },
    { items: [{ name: 'Poha',             qty: '1 cup cooked (150g)' },           { name: 'Green tea',      qty: '1 cup (200ml)' }],                       cal: bump(240) },
    { items: [{ name: 'Sprouts bowl',     qty: '1 cup (150g)' },                  { name: 'Coconut water',  qty: '1 glass (200ml)' }],                     cal: bump(230) },
    { items: [{ name: 'Upma',             qty: '1 cup (150g)' },                  { name: 'Lemon water',    qty: '1 glass' }],                             cal: bump(250) },
    { items: [{ name: 'Dalia porridge with soy milk', qty: '1 cup cooked' },      { name: 'Apple',          qty: '1 medium (150g)' }],                     cal: bump(290) },
    { items: [{ name: 'Peanut butter toast', qty: '2 slices whole wheat + 1 tbsp' }, { name: 'Banana',      qty: '1 medium (100g)' }],                    cal: bump(330) },
  ];

  // ── Lunch pool ──
  const lunchVeg = [
    { items: [{ name: 'Dal rice',         qty: '1 cup dal + 1 cup rice (200g)' }, { name: 'Salad',          qty: '1 bowl (100g)' },    { name: 'Curd',    qty: '1/2 cup' }], cal: bump(480) },
    { items: [{ name: 'Rajma rice',       qty: '1 cup rajma + 1 cup rice' },      { name: 'Salad',          qty: '1 bowl (100g)' }],                       cal: bump(460) },
    { items: [{ name: 'Chole roti',       qty: '1/2 cup chole + 2 rotis' },       { name: 'Onion salad',    qty: '1/2 cup' }],                             cal: bump(440) },
    { items: [{ name: 'Paneer sabzi',     qty: '80g paneer + 1 cup sabzi' },      { name: 'Roti',           qty: '2 rotis (60g)' },    { name: 'Dal',     qty: '1/2 cup' }], cal: bump(490) },
    { items: [{ name: 'Mixed veg khichdi', qty: '1.5 cups cooked (250g)' },       { name: 'Curd',           qty: '1/2 cup' }],                             cal: bump(420) },
    { items: [{ name: 'Palak dal',        qty: '1 cup' },                          { name: 'Brown rice',     qty: '1 cup cooked' },     { name: 'Salad',   qty: '1 bowl' }], cal: bump(450) },
    { items: [{ name: 'Vegetable pulao',  qty: '1.5 cups cooked' },               { name: 'Raita',          qty: '1/2 cup' },          { name: 'Papad',   qty: '1 piece' }], cal: bump(470) },
  ];
  const lunchNonVeg = [
    { items: [{ name: 'Chicken curry',    qty: '100g chicken + 1/2 cup gravy' },  { name: 'Rice',           qty: '1 cup cooked (150g)' }, { name: 'Salad', qty: '1 bowl' }], cal: bump(500) },
    { items: [{ name: 'Grilled chicken',  qty: '120g' },                           { name: 'Roti',           qty: '2 rotis (60g)' },    { name: 'Dal',     qty: '1/2 cup' }], cal: bump(480) },
    { items: [{ name: 'Fish curry',       qty: '100g fish + 1/2 cup gravy' },     { name: 'Brown rice',     qty: '1 cup cooked' },     { name: 'Salad',   qty: '1 bowl' }], cal: bump(460) },
    { items: [{ name: 'Egg curry',        qty: '2 eggs + 1/2 cup gravy' },        { name: 'Roti',           qty: '2 rotis' },          { name: 'Sabzi',   qty: '1/2 cup' }], cal: bump(450) },
    { items: [{ name: 'Dal rice',         qty: '1 cup dal + 1 cup rice' },        { name: 'Boiled egg',     qty: '1 egg' },            { name: 'Salad',   qty: '1 bowl' }], cal: bump(480) },
    { items: [{ name: 'Chicken rice bowl', qty: '100g chicken + 1 cup rice' },    { name: 'Raita',          qty: '1/2 cup' }],                             cal: bump(490) },
    { items: [{ name: 'Mutton roti',      qty: '80g mutton + 2 rotis' },          { name: 'Dal',            qty: '1/2 cup' },          { name: 'Salad',   qty: '1 bowl' }], cal: bump(520) },
  ];
  const lunchVegan = [
    { items: [{ name: 'Dal rice',         qty: '1 cup dal + 1 cup rice' },        { name: 'Salad',          qty: '1 bowl' }],                              cal: bump(440) },
    { items: [{ name: 'Rajma rice',       qty: '1 cup rajma + 1 cup rice' },      { name: 'Salad',          qty: '1 bowl' }],                              cal: bump(430) },
    { items: [{ name: 'Tofu sabzi',       qty: '100g tofu + 1 cup sabzi' },       { name: 'Roti',           qty: '2 rotis' }],                             cal: bump(410) },
    { items: [{ name: 'Chole roti',       qty: '1/2 cup chole + 2 rotis' },       { name: 'Onion salad',    qty: '1/2 cup' }],                             cal: bump(430) },
    { items: [{ name: 'Mixed veg khichdi', qty: '1.5 cups cooked' },              { name: 'Coconut water',  qty: '1 glass' }],                             cal: bump(390) },
    { items: [{ name: 'Palak dal',        qty: '1 cup' },                          { name: 'Brown rice',     qty: '1 cup cooked' }],                       cal: bump(400) },
    { items: [{ name: 'Vegetable pulao',  qty: '1.5 cups cooked' },               { name: 'Cucumber raita (soy curd)', qty: '1/2 cup' }],                 cal: bump(420) },
  ];

  // ── Snack pool ──
  const snackVeg = [
    { items: [{ name: 'Mixed fruits',     qty: '1 cup (150g)' },                  { name: 'Nuts',           qty: '1 handful (30g)' }],                     cal: bump(150) },
    { items: [{ name: 'Roasted chana',    qty: '30g' },                            { name: 'Green tea',      qty: '1 cup' }],                               cal: bump(130) },
    { items: [{ name: 'Buttermilk',       qty: '1 glass (200ml)' },               { name: 'Apple',          qty: '1 medium (150g)' }],                     cal: bump(140) },
    { items: [{ name: 'Curd with fruits', qty: '1/2 cup curd + 1/2 cup fruits' }],                                                                          cal: bump(160) },
    { items: [{ name: 'Makhana',          qty: '1 cup roasted (30g)' },           { name: 'Green tea',      qty: '1 cup' }],                               cal: bump(120) },
    { items: [{ name: 'Banana',           qty: '1 medium (100g)' },               { name: 'Peanut butter',  qty: '1 tbsp (15g)' }],                        cal: bump(180) },
    { items: [{ name: 'Sprouts chaat',    qty: '1 cup (100g)' },                  { name: 'Lemon water',    qty: '1 glass' }],                             cal: bump(130) },
  ];
  const snackNonVeg = [
    { items: [{ name: 'Boiled egg',       qty: '1 egg' },                          { name: 'Apple',          qty: '1 medium (150g)' }],                     cal: bump(160) },
    { items: [{ name: 'Mixed fruits',     qty: '1 cup (150g)' },                  { name: 'Nuts',           qty: '1 handful (30g)' }],                     cal: bump(150) },
    { items: [{ name: 'Roasted chana',    qty: '30g' },                            { name: 'Green tea',      qty: '1 cup' }],                               cal: bump(130) },
    { items: [{ name: 'Buttermilk',       qty: '1 glass' },                       { name: 'Banana',         qty: '1 medium (100g)' }],                     cal: bump(150) },
    { items: [{ name: 'Chicken tikka',    qty: '60g (2 pieces)' },                { name: 'Green tea',      qty: '1 cup' }],                               cal: bump(170) },
    { items: [{ name: 'Makhana',          qty: '1 cup (30g)' },                   { name: 'Green tea',      qty: '1 cup' }],                               cal: bump(120) },
    { items: [{ name: 'Banana',           qty: '1 medium (100g)' },               { name: 'Peanut butter',  qty: '1 tbsp' }],                              cal: bump(180) },
  ];

  // ── Dinner pool ──
  const dinnerVeg = [
    { items: [{ name: 'Roti',             qty: '2 pieces (60g)' },                { name: 'Sabzi',          qty: '1 cup (150g)' },     { name: 'Dal',     qty: '1/2 cup' }], cal: bump(420) },
    { items: [{ name: 'Moong dal khichdi', qty: '1.5 cups cooked' },              { name: 'Curd',           qty: '1/2 cup' }],                             cal: bump(380) },
    { items: [{ name: 'Paneer roti',      qty: '80g paneer + 2 rotis' },          { name: 'Dal',            qty: '1/2 cup' },          { name: 'Salad',   qty: '1 bowl' }], cal: bump(440) },
    { items: [{ name: 'Vegetable soup',   qty: '1 bowl (200ml)' },                { name: 'Roti',           qty: '2 pieces (60g)' },   { name: 'Sabzi',   qty: '1/2 cup' }], cal: bump(360) },
    { items: [{ name: 'Brown rice',       qty: '1 cup cooked (150g)' },           { name: 'Rajma',          qty: '1/2 cup' },          { name: 'Salad',   qty: '1 bowl' }], cal: bump(430) },
    { items: [{ name: 'Chapati',          qty: '3 pieces (30g each)' },           { name: 'Mixed veg sabzi', qty: '1 cup' },           { name: 'Dal',     qty: '1/2 cup' }], cal: bump(410) },
    { items: [{ name: 'Oats soup',        qty: '1 bowl' },                         { name: 'Roti',           qty: '1 piece (30g)' },    { name: 'Curd',    qty: '1/2 cup' }], cal: bump(340) },
  ];
  const dinnerNonVeg = [
    { items: [{ name: 'Grilled chicken',  qty: '100g' },                           { name: 'Roti',           qty: '2 pieces (60g)' },   { name: 'Salad',   qty: '1 bowl' }], cal: bump(430) },
    { items: [{ name: 'Fish curry',       qty: '100g fish + 1/2 cup gravy' },     { name: 'Roti',           qty: '2 pieces' },         { name: 'Dal',     qty: '1/2 cup' }], cal: bump(440) },
    { items: [{ name: 'Egg bhurji',       qty: '2 eggs + 1/2 cup veg' },          { name: 'Roti',           qty: '2 pieces (60g)' },   { name: 'Salad',   qty: '1 bowl' }], cal: bump(400) },
    { items: [{ name: 'Chicken soup',     qty: '1 bowl (200ml)' },                { name: 'Roti',           qty: '2 pieces (60g)' },   { name: 'Sabzi',   qty: '1/2 cup' }], cal: bump(380) },
    { items: [{ name: 'Dal roti',         qty: '1/2 cup dal + 2 rotis' },         { name: 'Boiled egg',     qty: '1 egg' },            { name: 'Salad',   qty: '1 bowl' }], cal: bump(420) },
    { items: [{ name: 'Chicken tikka',    qty: '100g' },                           { name: 'Roti',           qty: '2 pieces (60g)' },   { name: 'Dal',     qty: '1/2 cup' }], cal: bump(450) },
    { items: [{ name: 'Mutton soup',      qty: '1 bowl (150ml)' },                { name: 'Brown rice',     qty: '1/2 cup cooked' },   { name: 'Sabzi',   qty: '1/2 cup' }], cal: bump(410) },
  ];
  const dinnerVegan = [
    { items: [{ name: 'Roti',             qty: '2 pieces (60g)' },                { name: 'Sabzi',          qty: '1 cup (150g)' },     { name: 'Dal',     qty: '1/2 cup' }], cal: bump(400) },
    { items: [{ name: 'Moong dal khichdi', qty: '1.5 cups cooked' },              { name: 'Coconut water',  qty: '1 glass' }],                             cal: bump(360) },
    { items: [{ name: 'Tofu stir-fry',    qty: '100g tofu + 1 cup veg' },         { name: 'Brown rice',     qty: '1/2 cup cooked' }],                     cal: bump(380) },
    { items: [{ name: 'Vegetable soup',   qty: '1 bowl (200ml)' },                { name: 'Roti',           qty: '2 pieces (60g)' }],                      cal: bump(330) },
    { items: [{ name: 'Rajma roti',       qty: '1/2 cup rajma + 2 rotis' },       { name: 'Salad',          qty: '1 bowl' }],                              cal: bump(400) },
    { items: [{ name: 'Lentil soup',      qty: '1 bowl (200ml)' },                { name: 'Chapati',        qty: '2 pieces (60g)' }],                      cal: bump(360) },
    { items: [{ name: 'Vegetable biryani (no ghee)', qty: '1.5 cups' },           { name: 'Cucumber salad', qty: '1 bowl' }],                              cal: bump(390) },
  ];

  const bf     = isVegan ? bfVegan    : bfVeg;
  const lunch  = isVegan ? lunchVegan : isNonVeg ? lunchNonVeg  : lunchVeg;
  const snack  = isNonVeg ? snackNonVeg : snackVeg;
  const dinner = isVegan ? dinnerVegan : isNonVeg ? dinnerNonVeg : dinnerVeg;

  const label = isVegan ? 'Vegan' : isNonVeg ? 'Non-Vegetarian' : 'Vegetarian';
  const goalLabel = goal.includes('maintain') ? 'Maintenance' : goal.includes('gain') ? 'Muscle Gain' : 'Weight Loss';

  return {
    title: `FitQuest 7-Day ${label} ${goalLabel} Plan`,
    meals: Array.from({ length: 7 }, (_, i) => ({
      day:       i + 1,
      breakfast: bf[i],
      lunch:     lunch[i],
      snack:     snack[i],
      dinner:    dinner[i],
    })),
  };
}

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
    let plan = (await q(
      `SELECT dp.*, c.name AS coach_name FROM diet_plans dp
       LEFT JOIN coaches c ON c.id=dp.coach_id
       WHERE dp.user_id=$1 AND dp.status='active' ORDER BY dp.created_at DESC LIMIT 1`,
      [uid(req)]
    )).rows[0] || null;

    // Auto-seed a profile-aware plan for new users who have never had one.
    if (!plan) {
      const profileRow = (await q(
        `SELECT p.food_pref, p.goal FROM profiles p WHERE p.user_id=$1`,
        [uid(req)]
      )).rows[0] || {};
      const defaultPlan = buildDefaultPlan(profileRow);
      const inserted = await q(
        `INSERT INTO diet_plans (user_id, title, meals, ai_generated, status)
         VALUES ($1, $2, $3, FALSE, 'active') RETURNING *`,
        [uid(req), defaultPlan.title, JSON.stringify(defaultPlan.meals)]
      );
      plan = inserted.rows[0];
    }

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

  const mockPlan = buildDefaultPlan(profile);

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
