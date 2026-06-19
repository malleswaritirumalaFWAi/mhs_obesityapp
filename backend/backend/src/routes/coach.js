import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);

// Middleware: only coaches (role='coach' or 'admin')
router.use((req, res, next) => {
  if (req.user.role !== 'coach' && req.user.role !== 'admin') {
    return res.status(403).json({ message: 'Coach access required' });
  }
  next();
});

// Helper: get coach's group
async function coachGroupId(coachUserId) {
  const c = await q(`SELECT id FROM coaches WHERE user_id=$1 LIMIT 1`, [coachUserId]);
  if (!c.rows[0]) return 1; // fallback
  const g = await q(`SELECT id FROM groups WHERE coach_id=$1 LIMIT 1`, [c.rows[0].id]);
  return g.rows[0]?.id ?? 1;
}

// GET /coach/clients — all clients in coach's group with compliance summary
router.get('/clients', async (req, res) => {
  const gid = await coachGroupId(req.user.uid);
  const r = await q(
    `SELECT u.id, u.name, u.streak, u.xp, gm.weekly_xp,
            (SELECT COUNT(*) FILTER (WHERE done) FROM tasks t WHERE t.user_id=u.id AND t.day_index=
              GREATEST(1, FLOOR(EXTRACT(EPOCH FROM (NOW()-g.starts_on))/86400)+1)
            ) AS tasks_done_today,
            (SELECT COUNT(*) FROM tasks t WHERE t.user_id=u.id AND t.day_index=
              GREATEST(1, FLOOR(EXTRACT(EPOCH FROM (NOW()-g.starts_on))/86400)+1)
            ) AS tasks_total_today,
            (SELECT weight FROM checkins WHERE user_id=u.id ORDER BY created_at DESC LIMIT 1) AS last_weight,
            (SELECT created_at FROM checkins WHERE user_id=u.id ORDER BY created_at DESC LIMIT 1) AS last_checkin
     FROM group_members gm
     JOIN users u ON u.id=gm.user_id
     JOIN groups g ON g.id=gm.group_id
     WHERE gm.group_id=$1
     ORDER BY gm.weekly_xp DESC`,
    [gid]
  );
  res.json({ clients: r.rows });
});

// GET /coach/client/:id — detailed client profile
router.get('/client/:id', async (req, res) => {
  const clientId = req.params.id;
  const user = await q(`SELECT id, name, phone, email, xp, streak, start_weight, target_weight FROM users WHERE id=$1`, [clientId]);
  const profile = await q(`SELECT * FROM profiles WHERE user_id=$1`, [clientId]);
  const checkins = await q(
    `SELECT mood, weight, created_at FROM checkins WHERE user_id=$1 ORDER BY created_at DESC LIMIT 30`,
    [clientId]
  );
  const meals = await q(
    `SELECT meal_type, items, calories, coach_feedback, coach_approved, created_at
     FROM meals WHERE user_id=$1 ORDER BY created_at DESC LIMIT 20`,
    [clientId]
  );
  const measurements = await q(
    `SELECT * FROM body_measurements WHERE user_id=$1 ORDER BY created_at DESC LIMIT 5`,
    [clientId]
  );
  res.json({
    user: user.rows[0],
    profile: profile.rows[0],
    checkins: checkins.rows,
    meals: meals.rows,
    measurements: measurements.rows,
  });
});

// POST /coach/meal/:id/feedback { feedback, approved }
router.post('/meal/:id/feedback', async (req, res) => {
  const { feedback, approved } = req.body || {};
  await q(
    `UPDATE meals SET coach_feedback=$2, coach_approved=$3 WHERE id=$1`,
    [req.params.id, feedback || null, approved ?? null]
  );
  res.json({ updated: true });
});

// GET /coach/compliance — at-risk users (missed 2+ days or weight gain)
router.get('/compliance', async (req, res) => {
  const gid = await coachGroupId(req.user.uid);
  const r = await q(
    `SELECT u.id, u.name, u.streak,
            (SELECT COUNT(*) FROM checkins WHERE user_id=u.id AND created_at > NOW()-INTERVAL '48 hours') AS recent_checkins
     FROM group_members gm JOIN users u ON u.id=gm.user_id
     WHERE gm.group_id=$1
     HAVING (SELECT COUNT(*) FROM checkins WHERE user_id=u.id AND created_at > NOW()-INTERVAL '48 hours') = 0
     GROUP BY u.id, u.name, u.streak
     ORDER BY u.streak ASC LIMIT 20`,
    [gid]
  );
  res.json({ at_risk: r.rows });
});

// POST /coach/broadcast { text } — send group chat message as coach
router.post('/broadcast', async (req, res) => {
  const { text } = req.body || {};
  if (!text?.trim()) return res.status(400).json({ message: 'text required' });
  const gid = await coachGroupId(req.user.uid);
  await q(
    `INSERT INTO group_chat_messages (group_id, user_id, text, type) VALUES ($1,$2,$3,'coach')`,
    [gid, req.user.uid, text]
  );
  res.json({ sent: true });
});

// POST /coach/diet-plan { user_id, week_number, title, meals, notes }
router.post('/diet-plan', async (req, res) => {
  const { user_id, week_number, title, meals, grocery_list, notes } = req.body || {};
  if (!user_id) return res.status(400).json({ message: 'user_id required' });
  const c = await q(`SELECT id FROM coaches WHERE user_id=$1`, [req.user.uid]);
  const coachId = c.rows[0]?.id;

  await q(`UPDATE diet_plans SET status='archived' WHERE user_id=$1 AND status='active'`, [user_id]);
  const r = await q(
    `INSERT INTO diet_plans (user_id, coach_id, week_number, title, meals, grocery_list, notes)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
    [user_id, coachId, week_number || 1, title, JSON.stringify(meals || []),
     JSON.stringify(grocery_list || []), notes]
  );
  await q(
    `INSERT INTO notifications (user_id, type, title, body)
     VALUES ($1,'diet_plan','📋 New Diet Plan','Your coach has updated your meal plan!')`,
    [user_id]
  );
  res.json({ id: r.rows[0].id });
});

export default router;
