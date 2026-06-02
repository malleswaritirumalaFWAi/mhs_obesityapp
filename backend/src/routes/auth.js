import { Router } from 'express';
import { q } from '../db.js';
import { signToken } from '../auth.js';

const router = Router();

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
router.post('/otp/request', async (req, res) => {
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
router.post('/otp/verify', async (req, res) => {
  const { phone, code } = req.body || {};
  if (!phone || !code) return res.status(400).json({ message: 'phone and code required' });

  const fixed = process.env.DEV_FIXED_OTP || '123456';
  let ok = code === fixed; // dev bypass
  if (!ok) {
    const r = await q(`SELECT code, expires_at FROM otps WHERE phone=$1`, [phone]);
    const row = r.rows[0];
    ok = row && row.code === code && new Date(row.expires_at) > new Date();
  }
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

export default router;
