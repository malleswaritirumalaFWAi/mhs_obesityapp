import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);

async function requireCoach(req, res) {
  const r = (await q(`SELECT role FROM users WHERE id=$1`, [req.user.uid])).rows[0];
  if (!r || !['coach', 'admin'].includes(r.role)) {
    res.status(403).json({ message: 'Coach access required' });
    return false;
  }
  return true;
}

// GET /coach/clients — all users in coach's groups
router.get('/clients', async (req, res) => {
  if (!await requireCoach(req, res)) return;
  const today = new Date().toISOString().slice(0, 10);
  const rows = (await q(
    `SELECT u.id, u.name, u.phone, u.xp, u.streak, u.level,
            gm.weekly_xp, gm.group_id,
            (SELECT COUNT(*) FROM tasks t WHERE t.user_id=u.id AND t.done=TRUE AND t.completed_at::date=$1) AS done_today,
            (SELECT COUNT(*) FROM tasks t WHERE t.user_id=u.id) AS total_tasks
     FROM users u JOIN group_members gm ON gm.user_id=u.id
     ORDER BY gm.weekly_xp DESC`,
    [today]
  )).rows;
  res.json({ clients: rows });
});

// GET /coach/client/:id — detailed client profile
router.get('/client/:id', async (req, res) => {
  if (!await requireCoach(req, res)) return;
  const clientId = req.params.id;
  const user = (await q(`SELECT * FROM users WHERE id=$1`, [clientId])).rows[0];
  const profile = (await q(`SELECT * FROM profiles WHERE user_id=$1`, [clientId])).rows[0];
  const measurements = (await q(
    `SELECT * FROM body_measurements WHERE user_id=$1 ORDER BY created_at DESC LIMIT 10`, [clientId]
  )).rows;
  const meals = (await q(
    `SELECT * FROM meals WHERE user_id=$1 ORDER BY logged_at DESC LIMIT 20`, [clientId]
  )).rows;
  const checkins = (await q(
    `SELECT * FROM checkins WHERE user_id=$1 ORDER BY checked_at DESC LIMIT 30`, [clientId]
  )).rows;
  res.json({ user, profile, measurements, meals, checkins });
});

// POST /coach/meal/:id/feedback
router.post('/meal/:id/feedback', async (req, res) => {
  if (!await requireCoach(req, res)) return;
  const { feedback, approved } = req.body || {};
  await q(
    `UPDATE meals SET coach_feedback=$1, coach_approved=$2 WHERE id=$3`,
    [feedback || null, approved ?? null, req.params.id]
  );
  const meal = (await q(`SELECT user_id FROM meals WHERE id=$1`, [req.params.id])).rows[0];
  if (meal) {
    await q(
      `INSERT INTO notifications (user_id,type,title,body) VALUES ($1,'meal_feedback','Coach reviewed your meal','${approved ? 'Great choice!' : 'Your coach left feedback on your meal.'}')`,
      [meal.user_id]
    ).catch(() => {});
  }
  res.json({ ok: true });
});

// GET /coach/compliance — at-risk users (no checkin in 48h)
router.get('/compliance', async (req, res) => {
  if (!await requireCoach(req, res)) return;
  const rows = (await q(
    `SELECT u.id, u.name, u.streak, u.xp,
            MAX(c.checked_at) AS last_checkin,
            EXTRACT(EPOCH FROM (now() - MAX(c.checked_at)))/3600 AS hours_since
     FROM users u
     LEFT JOIN checkins c ON c.user_id=u.id
     GROUP BY u.id, u.name, u.streak, u.xp
     HAVING EXTRACT(EPOCH FROM (now() - MAX(c.checked_at)))/3600 > 48
        OR MAX(c.checked_at) IS NULL
     ORDER BY hours_since DESC NULLS FIRST
     LIMIT 20`
  )).rows;
  res.json({ at_risk: rows });
});

// POST /coach/broadcast
router.post('/broadcast', async (req, res) => {
  if (!await requireCoach(req, res)) return;
  const { text } = req.body || {};
  if (!text?.trim()) return res.status(400).json({ message: 'text required' });
  const coachUser = (await q(`SELECT id FROM users WHERE id=$1`, [req.user.uid])).rows[0];
  const members = (await q(`SELECT user_id FROM group_members`)).rows;
  // Insert group chat as coach
  const groups = (await q(`SELECT DISTINCT group_id FROM group_members`)).rows;
  for (const g of groups) {
    await q(
      `INSERT INTO group_chat_messages (group_id,user_id,text,type) VALUES ($1,$2,$3,'coach')`,
      [g.group_id, coachUser.id, text.trim()]
    );
  }
  // Notify all users
  for (const m of members) {
    await q(
      `INSERT INTO notifications (user_id,type,title,body) VALUES ($1,'coach_message','Message from Coach','${text.trim().slice(0, 100)}')`,
      [m.user_id]
    ).catch(() => {});
  }
  res.json({ ok: true, sent_to: members.length });
});

// POST /coach/diet-plan
router.post('/diet-plan', async (req, res) => {
  if (!await requireCoach(req, res)) return;
  const { user_id, week_number = 1, title, meals, notes } = req.body || {};
  if (!user_id) return res.status(400).json({ message: 'user_id required' });
  await q(`UPDATE diet_plans SET status='archived' WHERE user_id=$1`, [user_id]);
  const r = await q(
    `INSERT INTO diet_plans (user_id,coach_id,week_number,title,meals,notes,status)
     VALUES ($1,$2,$3,$4,$5,$6,'active') RETURNING *`,
    [user_id, req.user.uid, week_number, title, JSON.stringify(meals), notes]
  );
  await q(
    `INSERT INTO notifications (user_id,type,title,body) VALUES ($1,'diet_plan','New Diet Plan!','Your coach has created a personalized diet plan.')`,
    [user_id]
  ).catch(() => {});
  res.json({ plan: r.rows[0] });
});

export default router;
