import { Router } from 'express';
import { q } from '../db.js';
import { authMiddleware } from '../auth.js';

const router = Router();
router.use(authMiddleware);
const uid = (req) => req.user.uid;

function genCode(userId) {
  return `FQ${userId}${Math.random().toString(36).slice(2,6).toUpperCase()}`;
}

// GET /referral — my referral code + stats
router.get('/', async (req, res) => {
  let user = (await q(`SELECT referral_code, xp FROM users WHERE id=$1`, [uid(req)])).rows[0];
  if (!user) return res.status(404).json({ message: 'User not found' });

  // Generate code if not exists
  if (!user.referral_code) {
    const code = genCode(uid(req));
    await q(`UPDATE users SET referral_code=$2 WHERE id=$1`, [uid(req), code]);
    user = { ...user, referral_code: code };
  }

  const stats = await q(
    `SELECT COUNT(*) FILTER (WHERE status='joined') AS joined,
            COUNT(*) FILTER (WHERE reward_given) AS rewarded
     FROM referrals WHERE referrer_id=$1`,
    [uid(req)]
  );
  const leaderboard = await q(
    `SELECT u.id, COALESCE(u.name,'Member') AS name, COUNT(r.id) AS referrals
     FROM referrals r JOIN users u ON u.id=r.referrer_id
     WHERE r.status='joined' GROUP BY u.id, u.name
     ORDER BY COUNT(r.id) DESC LIMIT 10`
  );
  res.json({
    referral_code: user.referral_code,
    stats: stats.rows[0],
    leaderboard: leaderboard.rows.map((m, i) => ({ ...m, rank: i + 1, you: m.id === uid(req) }))
  });
});

// POST /referral/apply { code } — apply a referral code
router.post('/apply', async (req, res) => {
  const { code } = req.body || {};
  if (!code) return res.status(400).json({ message: 'code required' });

  const referrer = await q(`SELECT id FROM users WHERE referral_code=$1`, [code]);
  if (!referrer.rows[0]) return res.status(404).json({ message: 'Invalid referral code' });
  if (referrer.rows[0].id === uid(req)) return res.status(400).json({ message: 'Cannot use own code' });

  const existing = await q(
    `SELECT id FROM referrals WHERE referrer_id=$1 AND referred_id=$2`,
    [referrer.rows[0].id, uid(req)]
  );
  if (existing.rows[0]) return res.status(400).json({ message: 'Referral already applied' });

  await q(
    `INSERT INTO referrals (referrer_id, referred_id, status) VALUES ($1,$2,'joined')`,
    [referrer.rows[0].id, uid(req)]
  );

  // Award ₹1000 discount (represented as 1000 bonus XP for now)
  await q(`UPDATE users SET xp=xp+500, total_xp=total_xp+500 WHERE id=$1`, [uid(req)]);
  await q(`UPDATE users SET xp=xp+500, total_xp=total_xp+500 WHERE id=$1`, [referrer.rows[0].id]);
  await q(`UPDATE referrals SET reward_given=TRUE WHERE referrer_id=$1 AND referred_id=$2`,
    [referrer.rows[0].id, uid(req)]);

  // Recruiter badge after 3 referrals
  const count = await q(
    `SELECT COUNT(*) FROM referrals WHERE referrer_id=$1 AND status='joined'`,
    [referrer.rows[0].id]
  );
  if (Number(count.rows[0].count) >= 3) {
    const b = await q(`SELECT id FROM badges WHERE code='recruiter'`);
    if (b.rows[0]) {
      await q(`INSERT INTO user_badges (user_id, badge_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
        [referrer.rows[0].id, b.rows[0].id]);
    }
  }

  res.json({ applied: true, xp_bonus: 500 });
});

export default router;
