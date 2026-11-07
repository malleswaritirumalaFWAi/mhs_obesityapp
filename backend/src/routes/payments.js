import { Router } from 'express';
import crypto from 'node:crypto';
import Razorpay from 'razorpay';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);

const PLANS = { premium: { amount: 499900, label: 'FitQuest Premium' } };

// POST /payments/order { plan }
router.post('/order', async (req, res) => {
  const plan = PLANS[(req.body?.plan) || 'premium'] || PLANS.premium;
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;

  if (!keyId || !keySecret) {
    return res.status(503).json({ message: 'Payments not configured (demo mode)' });
  }

  const rzp = new Razorpay({ key_id: keyId, key_secret: keySecret });
  const order = await rzp.orders.create({
    amount: plan.amount,
    currency: 'INR',
    receipt: `fq_${req.user.uid}_${Date.now()}`,
  });
  await q(
    `INSERT INTO payments (user_id, plan, amount, order_id, status)
     VALUES ($1,$2,$3,$4,'created')`,
    [req.user.uid, 'premium', plan.amount, order.id]
  );
  res.json({ order_id: order.id, amount: plan.amount, currency: 'INR' });
});

// POST /payments/verify { order_id, payment_id, signature }
router.post('/verify', async (req, res) => {
  const { order_id, payment_id, signature } = req.body || {};
  if (!order_id || !payment_id || !signature) {
    return res.status(400).json({ message: 'order_id, payment_id, and signature are required' });
  }

  const secret = process.env.RAZORPAY_KEY_SECRET;
  if (!secret) return res.status(503).json({ message: 'Payments not configured' });

  // Verify the order belongs to this user
  const orderRow = await q(
    `SELECT user_id FROM payments WHERE order_id=$1`, [order_id]
  );
  if (!orderRow.rows[0] || orderRow.rows[0].user_id !== req.user.uid) {
    return res.status(403).json({ message: 'Order not found' });
  }

  const expected = crypto
    .createHmac('sha256', secret)
    .update(`${order_id}|${payment_id}`)
    .digest('hex');

  // Use timing-safe comparison to prevent timing attacks
  if (expected.length !== signature.length ||
      !crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature))) {
    await q(`UPDATE payments SET status='failed' WHERE order_id=$1`, [order_id]);
    return res.status(400).json({ message: 'Signature verification failed' });
  }

  await q(
    `UPDATE payments SET status='paid', payment_id=$2 WHERE order_id=$1`,
    [order_id, payment_id]
  );
  await q(`UPDATE users SET onboarded=TRUE WHERE id=$1`, [req.user.uid]);
  res.json({ verified: true });
});

export default router;
