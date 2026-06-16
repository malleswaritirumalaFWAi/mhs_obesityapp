import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

router.get('/', async (req, res) => {
  const rows = (await q(
    `SELECT * FROM notifications WHERE user_id=$1 ORDER BY created_at DESC LIMIT 50`,
    [uid(req)]
  )).rows;
  const unread = rows.filter(n => !n.read).length;
  res.json({ notifications: rows, unread_count: unread });
});

router.post('/read-all', async (req, res) => {
  await q(`UPDATE notifications SET read=TRUE WHERE user_id=$1`, [uid(req)]);
  res.json({ ok: true });
});

router.post('/:id/read', async (req, res) => {
  await q(`UPDATE notifications SET read=TRUE WHERE id=$1 AND user_id=$2`, [req.params.id, uid(req)]);
  res.json({ ok: true });
});

router.post('/fcm-token', async (req, res) => {
  const { token } = req.body || {};
  if (!token) return res.status(400).json({ message: 'token required' });
  await q(`UPDATE users SET fcm_token=$1 WHERE id=$2`, [token, uid(req)]);
  res.json({ ok: true });
});

export default router;
