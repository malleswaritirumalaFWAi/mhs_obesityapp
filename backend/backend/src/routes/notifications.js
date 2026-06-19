import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

// GET /notifications — last 50 notifications
router.get('/', async (req, res) => {
  const r = await q(
    `SELECT id, type, title, body, read, data, created_at
     FROM notifications WHERE user_id=$1 ORDER BY created_at DESC LIMIT 50`,
    [uid(req)]
  );
  const unread = await q(
    `SELECT COUNT(*) FROM notifications WHERE user_id=$1 AND read=FALSE`,
    [uid(req)]
  );
  res.json({ notifications: r.rows, unread_count: Number(unread.rows[0].count) });
});

// POST /notifications/read-all
router.post('/read-all', async (req, res) => {
  await q(`UPDATE notifications SET read=TRUE WHERE user_id=$1`, [uid(req)]);
  res.json({ updated: true });
});

// POST /notifications/:id/read
router.post('/:id/read', async (req, res) => {
  await q(`UPDATE notifications SET read=TRUE WHERE id=$1 AND user_id=$2`, [req.params.id, uid(req)]);
  res.json({ updated: true });
});

// POST /notifications/fcm-token { token } — register FCM token
router.post('/fcm-token', async (req, res) => {
  const { token } = req.body || {};
  if (!token) return res.status(400).json({ message: 'token required' });
  await q(`UPDATE users SET fcm_token=$2 WHERE id=$1`, [uid(req), token]);
  res.json({ saved: true });
});

export default router;
