import { Router } from 'express';
import bcrypt from 'bcryptjs';
import rateLimit from 'express-rate-limit';
import { q } from '../db.js';
import { signToken } from '../auth.js';
import { ensureTasksForDay } from '../tasks.js';

const router = Router();

// 5 OTP requests per phone per 15 min
const otpRequestLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  keyGenerator: (req) => req.body?.phone || req.ip || 'unknown',
  message: { message: 'Too many OTP requests. Please wait 15 minutes and try again.' },
  standardHeaders: true,
  legacyHeaders: false,
});

// 10 verify attempts per phone per 15 min — locks out brute-force
const otpVerifyLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  keyGenerator: (req) => req.body?.phone || req.ip || 'unknown',
  message: { message: 'Too many verification attempts. Please wait 15 minutes and try again.' },
  standardHeaders: true,
  legacyHeaders: false,
});

function genCode() {
  // 6-digit numeric, no crypto needed for dev OTP
  return String(Math.floor(100000 + Math.random() * 900000));
}

async function sendSms(phone, code) {
  const key = process.env.MSG91_AUTH_KEY;
  if (!key) {
    console.log(`[OTP] (dev) ${phone} -> ${code}  (or use fixed ${process.env.DEV_FIXED_OTP || '123456'})`);
    return;
  }
  // MSG91 OTP send (India). Endpoint kept minimal; configure template in console.
  try {
    await fetch('https://control.msg91.com/api/v5/otp', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', authkey: key },
      body: JSON.stringify({
        mobile: phone.replace('+', ''),
        otp: code,
        sender: process.env.MSG91_SENDER_ID || 'FITQST',
      }),
    });
  } catch (e) {
    console.warn('[OTP] MSG91 send failed:', e.message);
  }
}

// POST /auth/otp/request { phone }
router.post('/otp/request', otpRequestLimiter, async (req, res) => {
  const { phone } = req.body || {};
  if (!phone) return res.status(400).json({ message: 'phone required' });
  const code = genCode();
  const expires = new Date(Date.now() + 5 * 60 * 1000);
  await q(
    `INSERT INTO otps (phone, code, expires_at) VALUES ($1,$2,$3)
     ON CONFLICT (phone) DO UPDATE SET code=$2, expires_at=$3`,
    [phone, code, expires]
  );
  await sendSms(phone, code);
  res.json({ sent: true });
});

// POST /auth/otp/verify { phone, code }
router.post('/otp/verify', otpVerifyLimiter, async (req, res) => {
  const { phone, code } = req.body || {};
  if (!phone || !code) return res.status(400).json({ message: 'phone and code required' });

  const r = await q(`SELECT code, expires_at FROM otps WHERE phone=$1`, [phone]);
  const row = r.rows[0];
  const ok = row && row.code === code && new Date(row.expires_at) > new Date();
  if (!ok) return res.status(401).json({ message: 'Invalid or expired code' });

  // upsert user + join default group
  const u = await q(
    `INSERT INTO users (phone) VALUES ($1)
     ON CONFLICT (phone) DO UPDATE SET phone=EXCLUDED.phone
     RETURNING id, phone, onboarded`,
    [phone]
  );
  const user = u.rows[0];
  await q(
    `INSERT INTO group_members (group_id, user_id, weekly_xp)
     VALUES (1, $1, 0) ON CONFLICT DO NOTHING`,
    [user.id]
  );
  await q(`DELETE FROM otps WHERE phone=$1`, [phone]);

  res.json({ token: signToken(user), onboarded: user.onboarded });
});

// POST /auth/signup { name, phone, email, password }
router.post('/signup', async (req, res) => {
  try {
    const { name, phone, email, password } = req.body || {};
    if (!name?.trim() || !phone?.trim() || !email?.trim() || !password)
      return res.status(400).json({ message: 'Name, phone, email and password are required' });
    if (password.length < 8)
      return res.status(400).json({ message: 'Password must be at least 8 characters' });

    const existing = await q(`SELECT id FROM users WHERE email=$1`, [email.toLowerCase().trim()]);
    if (existing.rows.length > 0)
      return res.status(409).json({ message: 'This email is already registered. Please sign in.' });

    const hash = await bcrypt.hash(password, 10);
    const u = await q(
      `INSERT INTO users (name, phone, email, password_hash)
       VALUES ($1, $2, $3, $4)
       RETURNING id, phone, onboarded`,
      [name.trim(), phone.trim(), email.toLowerCase().trim(), hash]
    );
    const user = u.rows[0];
    await q(
      `INSERT INTO group_members (group_id, user_id, weekly_xp)
       VALUES (1, $1, 0) ON CONFLICT DO NOTHING`,
      [user.id]
    );
    // Seed day 1 tasks immediately so every new user has tasks on first login.
    // Non-blocking: tasks are also re-seeded on first /profile load.
    ensureTasksForDay(user.id, 1).catch((e) => console.warn('[tasks] signup seed failed:', e.message));
    res.json({ token: signToken(user), onboarded: user.onboarded });
  } catch (e) {
    console.error('[signup]', e.message);
    res.status(500).json({ message: 'Sign up failed. Please try again.' });
  }
});

// POST /auth/admin-login { email, password }
// Validates hardcoded admin credentials, upserts admin user in DB, returns JWT.
// No authMiddleware on this route — it IS the auth step.
router.post('/admin-login', async (req, res) => {
  const { email, password } = req.body || {};
  if (
    email?.toLowerCase().trim() !== 'admin@gmail.com' ||
    password !== 'Admin@123'
  ) {
    return res.status(401).json({ message: 'Invalid admin credentials' });
  }
  try {
    // Find existing admin user by email
    let user = (await q(`SELECT id, phone FROM users WHERE email='admin@gmail.com'`)).rows[0];
    if (!user) {
      // Try by reserved phone
      user = (await q(`SELECT id, phone FROM users WHERE phone='+919999999999'`)).rows[0];
    }
    if (!user) {
      // Create admin user
      const hash = await bcrypt.hash('Admin@123', 10);
      const r = await q(
        `INSERT INTO users (phone, email, name, password_hash, onboarded, role)
         VALUES ('+919999999999', 'admin@gmail.com', 'Admin', $1, TRUE, 'admin')
         RETURNING id, phone`,
        [hash]
      );
      user = r.rows[0];
    } else {
      // Ensure role is admin
      await q(`UPDATE users SET role='admin' WHERE id=$1`, [user.id]);
    }
    res.json({ token: signToken(user) });
  } catch (e) {
    console.error('[admin-login]', e.message);
    res.status(500).json({ message: 'Admin login failed. Please try again.' });
  }
});

// POST /auth/signin { email, password }
router.post('/signin', async (req, res) => {
  try {
    const { email, password } = req.body || {};
    if (!email?.trim() || !password)
      return res.status(400).json({ message: 'Email and password are required' });

    const r = await q(
      `SELECT id, phone, name, password_hash, onboarded FROM users WHERE email=$1`,
      [email.toLowerCase().trim()]
    );
    const user = r.rows[0];
    if (!user || !user.password_hash)
      return res.status(401).json({ message: 'Invalid email or password' });

    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok)
      return res.status(401).json({ message: 'Invalid email or password' });

    // Ensure day-1 tasks exist (no-op if already seeded).
    ensureTasksForDay(user.id, 1).catch(() => {});

    res.json({ token: signToken(user), onboarded: user.onboarded, name: user.name || null });
  } catch (e) {
    console.error('[signin]', e.message);
    res.status(500).json({ message: 'Sign in failed. Please try again.' });
  }
});

export default router;
