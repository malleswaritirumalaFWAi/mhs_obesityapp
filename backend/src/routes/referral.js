import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';
import { updateUserLevel } from './gamification.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

function generateCode() {
  return 'FQ' + Math.random().toString(36).toUpperCase().slice(2, 9);
}

async function ensureCode(userId) {
  let r = (await q(`SELECT referral_code FROM users WHERE id=$1`, [userId])).rows[0];
  if (!r?.referral_code) {
    const code = generateCode();
    await q(`UPDATE users SET referral_code=$1 WHERE id=$2`, [code, userId]).catch(async () => {
      // conflict: generate new
      await q(`UPDATE users SET referral_code=$1 WHERE id=$2`, [generateCode(), userId]);
    });
    r = (await q(`SELECT referral_code FROM users WHERE id=$1`, [userId])).rows[0];
  }
  return r.referral_code;
}

router.get('/', async (req, res) => {
  const code = await ensureCode(uid(req));
  const stats = (await q(
    `SELECT COUNT(*) AS joined,
            SUM(CASE WHEN reward_given THEN 1 ELSE 0 END) AS rewarded
     FROM referrals WHERE referrer_id=$1`,
    [uid(req)]
  )).rows[0] || {};
  const leaderboard = (await q(
    `SELECT u.name, COUNT(r.id) AS referrals,
            RANK() OVER (ORDER BY COUNT(r.id) DESC) AS rank,
            u.id
     FROM referrals r JOIN users u ON u.id=r.referrer_id
     GROUP BY u.id, u.name ORDER BY referrals DESC LIMIT 10`
  )).rows.map(row => ({ ...row, you: row.id === uid(req) }));
  res.json({ referral_code: code, stats, leaderboard });
});

router.post('/apply', async (req, res) => {
  const { code } = req.body || {};
  if (!code) return res.status(400).json({ message: 'code required' });
  const referrer = (await q(`SELECT id FROM users WHERE referral_code=$1`, [code.toUpperCase()])).rows[0];
  if (!referrer) return res.status(404).json({ message: 'Invalid referral code' });
  if (referrer.id === uid(req)) return res.status(400).json({ message: 'Cannot apply your own code' });
  const existing = (await q(
    `SELECT id FROM referrals WHERE referred_id=$1`, [uid(req)]
  )).rows[0];
  if (existing) return res.status(400).json({ message: 'You have already used a referral code' });

  await q(
    `INSERT INTO referrals (referrer_id,referred_id,status,reward_given) VALUES ($1,$2,'completed',TRUE)`,
    [referrer.id, uid(req)]
  );
  // Award +500 XP to both
  for (const userId of [referrer.id, uid(req)]) {
    await q(`UPDATE users SET xp=xp+500, total_xp=total_xp+500 WHERE id=$1`, [userId]);
    await q(`UPDATE group_members SET weekly_xp=weekly_xp+500 WHERE user_id=$1`, [userId]);
    await updateUserLevel(userId);
  }
  // Award recruiter badge after 3 referrals
  const refCount = (await q(
    `SELECT COUNT(*) AS c FROM referrals WHERE referrer_id=$1`, [referrer.id]
  )).rows[0]?.c ?? 0;
  if (Number(refCount) >= 3) {
    const badge = (await q(`SELECT id FROM badges WHERE code='recruiter'`)).rows[0];
    if (badge) {
      await q(
        `INSERT INTO user_badges (user_id,badge_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
        [referrer.id, badge.id]
      );
    }
  }
  await q(
    `INSERT INTO notifications (user_id,type,title,body) VALUES ($1,'referral','Referral bonus!','+500 XP credited for referring a friend!')`,
    [referrer.id]
  ).catch(() => {});
  res.json({ ok: true, xp_earned: 500 });
});

export default router;
