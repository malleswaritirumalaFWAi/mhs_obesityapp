import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

// GET /diet-plan — user's active diet plan + daily nutrition summary
router.get('/', async (req, res) => {
  const plan = await q(
    `SELECT dp.*, c.name AS coach_name
     FROM diet_plans dp LEFT JOIN coaches c ON c.id=dp.coach_id
     WHERE dp.user_id=$1 AND dp.status='active'
     ORDER BY dp.created_at DESC LIMIT 1`,
    [uid(req)]
  );

  // Today's calorie summary
  const today = new Date().toISOString().slice(0, 10);
  const nutrition = await q(
    `SELECT COALESCE(SUM(calories),0) AS calories,
            COALESCE(SUM(carbs),0) AS carbs,
            COALESCE(SUM(protein),0) AS protein,
            COALESCE(SUM(fat),0) AS fat
     FROM meals WHERE user_id=$1 AND DATE(created_at)=$2`,
    [uid(req), today]
  );

  // Recent meals
  const recent = await q(
    `SELECT meal_type, items, calories, carbs, protein, fat, coach_feedback, coach_approved, created_at
     FROM meals WHERE user_id=$1 ORDER BY created_at DESC LIMIT 10`,
    [uid(req)]
  );

  res.json({
    plan: plan.rows[0] || null,
    today_nutrition: nutrition.rows[0],
    recent_meals: recent.rows,
  });
});

// POST /diet-plan — coach/admin creates a plan for user
router.post('/', async (req, res) => {
  const { user_id, week_number, title, meals, grocery_list, notes, ai_generated } = req.body || {};
  const targetUser = user_id || uid(req);
  const r = await q(
    `INSERT INTO diet_plans (user_id, week_number, title, meals, grocery_list, notes, ai_generated)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
    [targetUser, week_number || 1, title, JSON.stringify(meals || []),
     JSON.stringify(grocery_list || []), notes, ai_generated || false]
  );
  // Archive old plans
  await q(
    `UPDATE diet_plans SET status='archived' WHERE user_id=$1 AND id != $2`,
    [targetUser, r.rows[0].id]
  );
  res.json({ id: r.rows[0].id });
});

// POST /diet-plan/generate — AI generates a plan based on user profile
router.post('/generate', async (req, res) => {
  const profile = await q(
    `SELECT u.name, u.start_weight, u.target_weight, u.height,
            p.gender, p.activity, p.goal, p.food_pref, p.medical_conditions
     FROM users u LEFT JOIN profiles p ON p.user_id=u.id WHERE u.id=$1`,
    [uid(req)]
  );
  const user = profile.rows[0] || {};
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) {
    return res.json({ plan: _mockPlan(user), _mock: true });
  }

  try {
    const model = process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-6';
    const chatRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'anthropic-version': '2023-06-01', 'Authorization': `Bearer ${key}` },
      body: JSON.stringify({
        model, max_tokens: 1000,
        messages: [{
          role: 'user',
          content: `Create a 7-day Indian meal plan for: ${JSON.stringify(user)}.
Return ONLY valid JSON array of 7 objects: [{day:1, breakfast:{items:[],cal:0}, lunch:{items:[],cal:0}, dinner:{items:[],cal:0}, snack:{items:[],cal:0}}].
Keep it practical, Indian food only, within 1400-1600 cal/day.`
        }]
      })
    });
    const data = await chatRes.json();
    const text = data.content?.[0]?.text || '';
    const start = text.indexOf('[');
    const end = text.lastIndexOf(']');
    const meals = JSON.parse(text.slice(start, end + 1));
    res.json({ plan: meals });
  } catch (e) {
    res.json({ plan: _mockPlan(user), _mock: true, error: e.message });
  }
});

function _mockPlan(user) {
  const isVeg = user.food_pref === 'Vegetarian';
  return Array.from({ length: 7 }, (_, i) => ({
    day: i + 1,
    breakfast: { items: ['Oats', 'Banana', 'Green tea'], cal: 280 },
    lunch: { items: [isVeg ? 'Dal + Roti (2)' : 'Chicken curry + Rice', 'Salad'], cal: 420 },
    snack: { items: ['Sprouts', 'Buttermilk'], cal: 120 },
    dinner: { items: [isVeg ? 'Paneer Bhurji + Roti' : 'Grilled fish + Dal', 'Vegetables'], cal: 380 },
  }));
}

export default router;
