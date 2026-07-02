import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

async function groupId(userId) {
  const r = await q(`SELECT group_id FROM group_members WHERE user_id=$1 LIMIT 1`, [userId]);
  return r.rows[0]?.group_id ?? 1;
}

router.get('/group/chat', async (req, res) => {
  const { limit = 50, before } = req.query;
  const gid = await groupId(uid(req));
  const rows = (await q(
    `SELECT m.id, m.text, m.type, m.pinned, m.created_at,
            u.name AS author_name, u.id AS author_id,
            COALESCE(u.role,'user') AS author_role
     FROM group_chat_messages m JOIN users u ON u.id=m.user_id
     WHERE m.group_id=$1 ${before ? 'AND m.id < $3' : ''}
     ORDER BY m.created_at DESC LIMIT $2`,
    before ? [gid, Number(limit), before] : [gid, Number(limit)]
  )).rows.reverse();
  res.json({ messages: rows });
});

router.post('/group/chat', async (req, res) => {
  const { text } = req.body || {};
  if (!text?.trim()) return res.status(400).json({ message: 'text required' });
  const gid = await groupId(uid(req));
  const userRow = (await q(`SELECT role FROM users WHERE id=$1`, [uid(req)])).rows[0];
  const type = ['coach', 'admin'].includes(userRow?.role) ? 'coach' : 'user';

  // Check before insert: first message today? (for XP cap)
  const todayMsgs = (await q(
    `SELECT COUNT(*) AS c FROM group_chat_messages WHERE user_id=$1 AND created_at::date = CURRENT_DATE`,
    [uid(req)]
  )).rows[0]?.c ?? 0;
  const firstToday = Number(todayMsgs) === 0;
  const r = await q(
    `INSERT INTO group_chat_messages (group_id,user_id,text,type) VALUES ($1,$2,$3,$4) RETURNING *`,
    [gid, uid(req), text.trim(), type]
  );
  // Award 5 XP only on the first message of the day
  if (firstToday) {
    await q(`UPDATE users SET xp=xp+5, total_xp=total_xp+5 WHERE id=$1`, [uid(req)]);
    await q(`UPDATE group_members SET weekly_xp=weekly_xp+5 WHERE user_id=$1`, [uid(req)]);
  }
  const msgCount = (await q(
    `SELECT COUNT(*) AS c FROM group_chat_messages WHERE user_id=$1`, [uid(req)]
  )).rows[0]?.c ?? 0;
  if (Number(msgCount) === 1) {
    const badge = (await q(`SELECT id FROM badges WHERE code='team_player'`)).rows[0];
    if (badge) await q(
      `INSERT INTO user_badges (user_id,badge_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
      [uid(req), badge.id]
    );
  }
  res.json({ message: r.rows[0] });
});

router.post('/group/chat/:id/pin', async (req, res) => {
  const userRow = (await q(`SELECT role FROM users WHERE id=$1`, [uid(req)])).rows[0];
  if (!['coach', 'admin'].includes(userRow?.role)) {
    return res.status(403).json({ message: 'Coach access required' });
  }
  await q(`UPDATE group_chat_messages SET pinned=TRUE WHERE id=$1`, [req.params.id]);
  res.json({ ok: true });
});

router.get('/group/chat/pinned', async (req, res) => {
  const gid = await groupId(uid(req));
  const rows = (await q(
    `SELECT m.*, u.name AS author_name FROM group_chat_messages m JOIN users u ON u.id=m.user_id
     WHERE m.group_id=$1 AND m.pinned=TRUE ORDER BY m.created_at DESC LIMIT 10`,
    [gid]
  )).rows;
  res.json({ pinned: rows });
});

export default router;
