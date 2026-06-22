import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);

async function requireAdmin(req, res) {
  const r = (await q(`SELECT role FROM users WHERE id=$1`, [req.user.uid])).rows[0];
  if (!r || r.role !== 'admin') { res.status(403).json({ message: 'Admin access required' }); return false; }
  return true;
}

// Weekly reset logic — also called by cron
export async function runWeeklyReset() {
  const today = new Date().toISOString().slice(0, 10);
  const existing = (await q(`SELECT id FROM weekly_reset_log WHERE reset_date=$1`, [today])).rows[0];
  if (existing) { console.log('[reset] already done for', today); return; }

  // Save top-3 per group
  const groups = (await q(`SELECT DISTINCT group_id FROM group_members`)).rows;
  for (const g of groups) {
    const topUsers = (await q(
      `SELECT user_id, weekly_xp FROM group_members WHERE group_id=$1 ORDER BY weekly_xp DESC LIMIT 3`,
      [g.group_id]
    )).rows;
    for (let i = 0; i < topUsers.length; i++) {
      const u = topUsers[i];
      await q(
        `INSERT INTO weekly_winners (group_id,week_start,user_id,rank,weekly_xp) VALUES ($1,$2,$3,$4,$5) ON CONFLICT DO NOTHING`,
        [g.group_id, today, u.user_id, i + 1, u.weekly_xp]
      ).catch(() => {});
      // Notify winner
      await q(
        `INSERT INTO notifications (user_id,type,title,body) VALUES ($1,'weekly_winner','You are a weekly winner!','Congratulations! You finished #${i + 1} this week!')`,
        [u.user_id]
      ).catch(() => {});
    }
  }

  // Award streak freeze every 7-day milestone
  const streakUsers = (await q(
    `SELECT id, streak FROM users WHERE streak > 0 AND streak % 7 = 0`
  )).rows;
  for (const u of streakUsers) {
    await q(`UPDATE users SET streak_freezes=streak_freezes+1 WHERE id=$1`, [u.id]);
    await q(
      `INSERT INTO notifications (user_id,type,title,body) VALUES ($1,'streak_freeze','Streak freeze earned!','Your ${u.streak}-day streak earned you a freeze!')`,
      [u.id]
    ).catch(() => {});
  }

  // Reset weekly XP
  await q(`UPDATE group_members SET weekly_xp=0`);
  await q(`INSERT INTO weekly_reset_log (reset_date) VALUES ($1)`, [today]);
  console.log('[reset] done for', today);
}

router.get('/stats', async (req, res) => {
  if (!await requireAdmin(req, res)) return;
  const users = (await q(`SELECT COUNT(*) AS total FROM users`)).rows[0];
  const activeToday = (await q(
    `SELECT COUNT(DISTINCT user_id) AS count FROM checkins WHERE checked_at::date=CURRENT_DATE`
  )).rows[0];
  const revenue = (await q(
    `SELECT COALESCE(SUM(amount),0) AS total FROM payments WHERE status='paid'`
  )).rows[0];
  res.json({ total_users: users.total, active_today: activeToday.count, total_revenue: revenue.total });
});

router.get('/cohorts', async (req, res) => {
  if (!await requireAdmin(req, res)) return;
  const rows = (await q(
    `SELECT g.*, c.name AS coach_name, COUNT(gm.user_id) AS member_count
     FROM groups g LEFT JOIN coaches c ON c.id=g.coach_id
     LEFT JOIN group_members gm ON gm.group_id=g.id
     GROUP BY g.id, c.name ORDER BY g.starts_on DESC`
  )).rows;
  res.json({ cohorts: rows });
});

router.post('/cohorts', async (req, res) => {
  if (!await requireAdmin(req, res)) return;
  const { name, coach_id, starts_on } = req.body || {};
  const r = await q(
    `INSERT INTO groups (name,coach_id,starts_on) VALUES ($1,$2,$3) RETURNING *`,
    [name, coach_id, starts_on]
  );
  res.json({ cohort: r.rows[0] });
});

router.get('/coaches', async (req, res) => {
  if (!await requireAdmin(req, res)) return;
  const rows = (await q(`SELECT c.*, u.phone, u.email FROM coaches c LEFT JOIN users u ON u.id=c.user_id`)).rows;
  res.json({ coaches: rows });
});

router.post('/coaches', async (req, res) => {
  if (!await requireAdmin(req, res)) return;
  const { name, title, specialization } = req.body || {};
  const r = await q(
    `INSERT INTO coaches (name,title,specialization) VALUES ($1,$2,$3) RETURNING *`,
    [name, title, specialization]
  );
  res.json({ coach: r.rows[0] });
});

router.get('/revenue', async (req, res) => {
  if (!await requireAdmin(req, res)) return;
  const monthly = (await q(
    `SELECT DATE_TRUNC('month', created_at) AS month, COALESCE(SUM(amount),0) AS revenue, COUNT(*) AS payments
     FROM payments WHERE status='paid'
     GROUP BY 1 ORDER BY 1 DESC LIMIT 12`
  )).rows;
  res.json({ monthly });
});

router.post('/content/lesson', async (req, res) => {
  if (!await requireAdmin(req, res)) return;
  const { title, content, week_number, lesson_type = 'article', video_url, quiz_questions } = req.body || {};
  const r = await q(
    `INSERT INTO lessons (title,content,week_number,lesson_type,video_url,quiz_questions)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
    [title, content, week_number, lesson_type, video_url || null, quiz_questions ? JSON.stringify(quiz_questions) : null]
  );
  res.json({ lesson: r.rows[0] });
});

router.post('/users/:id/role', async (req, res) => {
  if (!await requireAdmin(req, res)) return;
  const { role } = req.body || {};
  await q(`UPDATE users SET role=$1 WHERE id=$2`, [role, req.params.id]);
  res.json({ ok: true });
});

router.get('/users', async (req, res) => {
  if (!await requireAdmin(req, res)) return;
  const rows = (await q(
    `SELECT
       u.id, u.name, u.phone, u.email, u.role, u.xp, u.total_xp, u.streak, u.level, u.created_at,
       (SELECT COUNT(*)::int FROM challenge_entries WHERE user_id=u.id AND completed=TRUE) AS challenges_completed,
       (SELECT COUNT(*)::int FROM weekly_challenges) AS challenges_total,
       (SELECT COUNT(*)::int FROM lessons WHERE status='completed') AS lessons_completed,
       (SELECT COUNT(*)::int FROM lessons) AS lessons_total
     FROM users u
     WHERE u.role != 'admin'
     ORDER BY u.total_xp DESC NULLS LAST`
  )).rows;
  // Assign rank based on descending total_xp order
  const withRank = rows.map((r, i) => ({ ...r, rank: i + 1 }));
  res.json({ users: withRank });
});

router.post('/weekly-reset', async (req, res) => {
  if (!await requireAdmin(req, res)) return;
  await runWeeklyReset();
  res.json({ ok: true });
});

export default router;
