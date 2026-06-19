import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);

router.use((req, res, next) => {
  if (req.user.role !== 'admin') return res.status(403).json({ message: 'Admin access required' });
  next();
});

// GET /admin/stats — platform overview
router.get('/stats', async (req, res) => {
  const [users, cohorts, revenue, weeklyActive] = await Promise.all([
    q(`SELECT COUNT(*) AS total, COUNT(*) FILTER (WHERE onboarded) AS onboarded FROM users`),
    q(`SELECT COUNT(*) AS active FROM groups WHERE starts_on <= NOW() AND starts_on > NOW()-INTERVAL '84 days'`),
    q(`SELECT COALESCE(SUM(amount),0) AS total FROM payments WHERE status='paid'`),
    q(`SELECT COUNT(DISTINCT user_id) AS count FROM checkins WHERE created_at > NOW()-INTERVAL '7 days'`),
  ]);
  res.json({
    total_users: Number(users.rows[0].total),
    onboarded_users: Number(users.rows[0].onboarded),
    active_cohorts: Number(cohorts.rows[0].active),
    total_revenue_paise: Number(revenue.rows[0].total),
    weekly_active_users: Number(weeklyActive.rows[0].count),
  });
});

// GET /admin/cohorts — all cohorts with stats
router.get('/cohorts', async (req, res) => {
  const r = await q(
    `SELECT g.id, g.name, g.starts_on, c.name AS coach_name,
            COUNT(gm.user_id) AS member_count,
            ROUND(AVG(gm.weekly_xp)) AS avg_weekly_xp
     FROM groups g
     LEFT JOIN coaches c ON c.id=g.coach_id
     LEFT JOIN group_members gm ON gm.group_id=g.id
     GROUP BY g.id, g.name, g.starts_on, c.name
     ORDER BY g.starts_on DESC`
  );
  res.json({ cohorts: r.rows });
});

// POST /admin/cohorts — create cohort
router.post('/cohorts', async (req, res) => {
  const { name, coach_id, starts_on } = req.body || {};
  if (!name || !starts_on) return res.status(400).json({ message: 'name and starts_on required' });
  const r = await q(
    `INSERT INTO groups (name, coach_id, starts_on) VALUES ($1,$2,$3) RETURNING id`,
    [name, coach_id || null, starts_on]
  );
  res.json({ id: r.rows[0].id });
});

// GET /admin/coaches — all coaches with performance
router.get('/coaches', async (req, res) => {
  const r = await q(
    `SELECT c.id, c.name, c.title, c.rating, c.specialization,
            g.name AS cohort_name,
            COUNT(gm.user_id) AS client_count,
            ROUND(AVG(gm.weekly_xp)) AS avg_client_xp
     FROM coaches c
     LEFT JOIN groups g ON g.coach_id=c.id
     LEFT JOIN group_members gm ON gm.group_id=g.id
     GROUP BY c.id, c.name, c.title, c.rating, c.specialization, g.name
     ORDER BY avg_client_xp DESC NULLS LAST`
  );
  res.json({ coaches: r.rows });
});

// POST /admin/coaches — create coach
router.post('/coaches', async (req, res) => {
  const { name, title, specialization, phone } = req.body || {};
  if (!name) return res.status(400).json({ message: 'name required' });
  const r = await q(
    `INSERT INTO coaches (name, title, specialization, phone) VALUES ($1,$2,$3,$4) RETURNING id`,
    [name, title || 'Dietitian', specialization || null, phone || null]
  );
  res.json({ id: r.rows[0].id });
});

// GET /admin/revenue — financial dashboard
router.get('/revenue', async (req, res) => {
  const monthly = await q(
    `SELECT DATE_TRUNC('month', created_at) AS month,
            COUNT(*) AS payments, SUM(amount) AS revenue
     FROM payments WHERE status='paid'
     GROUP BY DATE_TRUNC('month', created_at)
     ORDER BY month DESC LIMIT 12`
  );
  const prizes = await q(
    `SELECT SUM(prize_amount) AS total_prizes, COUNT(*) AS total_winners FROM weekly_winners`
  );
  res.json({ monthly_revenue: monthly.rows, prizes: prizes.rows[0] });
});

// POST /admin/content/lesson — publish a lesson
router.post('/content/lesson', async (req, res) => {
  const { week, title, author, minutes, xp, content, lesson_type, video_url, quiz_questions } = req.body || {};
  if (!week || !title) return res.status(400).json({ message: 'week and title required' });
  const r = await q(
    `INSERT INTO lessons (week, title, author, minutes, xp, content, lesson_type, video_url, quiz_questions, status)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'active') RETURNING id`,
    [week, title, author, minutes || 5, xp || 25, content, lesson_type || 'article', video_url,
     quiz_questions ? JSON.stringify(quiz_questions) : null]
  );
  res.json({ id: r.rows[0].id });
});

// POST /admin/users/:id/role — set user role
router.post('/users/:id/role', async (req, res) => {
  const { role } = req.body || {};
  if (!['user', 'coach', 'admin'].includes(role)) return res.status(400).json({ message: 'invalid role' });
  await q(`UPDATE users SET role=$2 WHERE id=$1`, [req.params.id, role]);
  res.json({ updated: true });
});

// GET /admin/users — user list
router.get('/users', async (req, res) => {
  const r = await q(
    `SELECT id, name, phone, email, onboarded, xp, streak, level, role, created_at
     FROM users ORDER BY created_at DESC LIMIT 200`
  );
  res.json({ users: r.rows });
});

// POST /admin/weekly-reset — manually trigger weekly XP reset + record winners
router.post('/weekly-reset', async (req, res) => {
  await runWeeklyReset();
  res.json({ done: true });
});

export async function runWeeklyReset() {
  try {
    const today = new Date().toISOString().slice(0, 10);
    // Check if already reset today
    const already = await q(`SELECT id FROM weekly_reset_log WHERE reset_date=$1`, [today]);
    if (already.rows[0]) return;

    const groups = await q(`SELECT id FROM groups`);
    for (const group of groups.rows) {
      // Save top 3 as weekly winners
      const top3 = await q(
        `SELECT user_id, weekly_xp FROM group_members WHERE group_id=$1
         ORDER BY weekly_xp DESC LIMIT 3`,
        [group.id]
      );
      for (let i = 0; i < top3.rows.length; i++) {
        const w = top3.rows[i];
        if (w.weekly_xp === 0) continue;
        await q(
          `INSERT INTO weekly_winners (group_id, week_start, user_id, rank, weekly_xp, prize_amount)
           VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT DO NOTHING`,
          [group.id, today, w.user_id, i + 1, w.weekly_xp, i === 0 ? 500 : i === 1 ? 500 : 500]
        );
        // Notify winner
        await q(
          `INSERT INTO notifications (user_id, type, title, body)
           VALUES ($1,'weekly_winner','🏆 Weekly Winner!','You finished rank #${i+1} this week! 🎉 ₹500 voucher incoming!')`,
          [w.user_id]
        );
        // Award weekly_champ badge to rank 1
        if (i === 0) {
          const b = await q(`SELECT id FROM badges WHERE code='weekly_champ'`);
          if (b.rows[0]) {
            await q(`INSERT INTO user_badges (user_id, badge_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
              [w.user_id, b.rows[0].id]);
          }
        }
      }

      // Reset weekly XP
      await q(`UPDATE group_members SET weekly_xp=0 WHERE group_id=$1`, [group.id]);
    }

    // Also award 7-day streak freeze to users with active streak
    await q(`UPDATE users SET streak_freezes=streak_freezes+1 WHERE streak>0 AND streak%7=0`);

    await q(`INSERT INTO weekly_reset_log (reset_date) VALUES ($1)`, [today]);
    console.log('[cron] Weekly reset done:', today);
  } catch (e) {
    console.error('[cron] Weekly reset failed:', e.message);
  }
}

export default router;
