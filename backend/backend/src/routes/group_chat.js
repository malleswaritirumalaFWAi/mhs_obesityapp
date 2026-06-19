import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

async function getGroupId(userId) {
  const r = await q(`SELECT group_id FROM group_members WHERE user_id=$1 LIMIT 1`, [userId]);
  return r.rows[0]?.group_id ?? 1;
}

// GET /group/chat?limit=50&before=id
router.get('/chat', async (req, res) => {
  const gid = await getGroupId(uid(req));
  const limit = Math.min(Number(req.query.limit ?? 50), 100);
  const before = req.query.before;
  const r = await q(
    `SELECT gcm.id, gcm.text, gcm.type, gcm.pinned, gcm.created_at,
            COALESCE(u.name,'Member') AS author_name, gcm.user_id,
            CASE WHEN gcm.user_id=$1 THEN TRUE ELSE FALSE END AS is_mine
     FROM group_chat_messages gcm JOIN users u ON u.id=gcm.user_id
     WHERE gcm.group_id=$2 ${before ? 'AND gcm.id < $4' : ''}
     ORDER BY gcm.created_at DESC LIMIT $3`,
    before ? [uid(req), gid, limit, before] : [uid(req), gid, limit]
  );
  res.json({ messages: r.rows.reverse() });
});

// POST /group/chat { text }
router.post('/chat', async (req, res) => {
  const { text } = req.body || {};
  if (!text?.trim()) return res.status(400).json({ message: 'text required' });
  const gid = await getGroupId(uid(req));
  const r = await q(
    `INSERT INTO group_chat_messages (group_id, user_id, text) VALUES ($1,$2,$3) RETURNING id, created_at`,
    [gid, uid(req), text]
  );
  // Award 5 XP for group engagement (max 3/day via task system — just award directly)
  await q(`UPDATE users SET xp=xp+5, total_xp=total_xp+5 WHERE id=$1`, [uid(req)]);
  await q(`UPDATE group_members SET weekly_xp=weekly_xp+5 WHERE user_id=$1`, [uid(req)]);

  // Team Player badge on first group message
  const count = await q(`SELECT COUNT(*) FROM group_chat_messages WHERE user_id=$1`, [uid(req)]);
  if (Number(count.rows[0].count) === 1) {
    const b = await q(`SELECT id FROM badges WHERE code='team_player'`);
    if (b.rows[0]) {
      await q(`INSERT INTO user_badges (user_id, badge_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
        [uid(req), b.rows[0].id]);
    }
  }

  res.json({ id: r.rows[0].id, created_at: r.rows[0].created_at });
});

// POST /group/chat/:id/pin — pin a message (coach/admin only in real app)
router.post('/chat/:id/pin', async (req, res) => {
  await q(`UPDATE group_chat_messages SET pinned=TRUE WHERE id=$1`, [req.params.id]);
  res.json({ pinned: true });
});

// GET /group/chat/pinned
router.get('/chat/pinned', async (req, res) => {
  const gid = await getGroupId(uid(req));
  const r = await q(
    `SELECT gcm.id, gcm.text, gcm.created_at, COALESCE(u.name,'Member') AS author_name
     FROM group_chat_messages gcm JOIN users u ON u.id=gcm.user_id
     WHERE gcm.group_id=$1 AND gcm.pinned=TRUE ORDER BY gcm.created_at DESC LIMIT 5`,
    [gid]
  );
  res.json({ pinned: r.rows });
});

export default router;
