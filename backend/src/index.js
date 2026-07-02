import dotenv from 'dotenv';
import express from 'express';
import cors from 'cors';
import cron from 'node-cron';

import authRoutes         from './routes/auth.js';
import apiRoutes          from './routes/api.js';
import mealRoutes         from './routes/meals.js';
import paymentRoutes      from './routes/payments.js';
import fastingRoutes      from './routes/fasting.js';
import measurementRoutes  from './routes/measurements.js';
import reflectionRoutes   from './routes/reflection.js';
import gamificationRoutes from './routes/gamification.js';
import dietPlanRoutes     from './routes/diet_plan.js';
import progressRoutes     from './routes/progress.js';
import referralRoutes     from './routes/referral.js';
import notificationRoutes from './routes/notifications.js';
import challengeRoutes    from './routes/challenge.js';
import groupChatRoutes    from './routes/group_chat.js';
import recipesRoutes      from './routes/recipes.js';
import exercisesRoutes    from './routes/exercises.js';
import coachRoutes        from './routes/coach.js';
import adminRoutes, { runWeeklyReset } from './routes/admin.js';
import migrateRoutes      from './routes/migrate.js';
import { sendPush } from './push.js';

dotenv.config();

import { pool } from './db.js';

// Ensure the fitquest schema exists before any migration runs. Without this,
// every CREATE/ALTER below silently fails (search_path points at a missing schema).
async function ensureSchema() {
  const client = await pool.connect();
  try {
    await client.query('CREATE SCHEMA IF NOT EXISTS fitquest');
  } finally {
    client.release();
  }
}

async function runMigrations() {
  await ensureSchema().catch(e => console.warn('  ensureSchema:', e.message));
  const client = await pool.connect();
  try {
    // Base tables (mirror schema.sql) — must exist before the ALTERs below.
    const baseTables = [
      `CREATE TABLE IF NOT EXISTS users (
        id BIGSERIAL PRIMARY KEY, phone TEXT UNIQUE NOT NULL, name TEXT,
        email TEXT UNIQUE, password_hash TEXT,
        onboarded BOOLEAN NOT NULL DEFAULT FALSE, xp INTEGER NOT NULL DEFAULT 0,
        streak INTEGER NOT NULL DEFAULT 0, start_weight NUMERIC(5,1),
        target_weight NUMERIC(5,1), created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS otps (
        phone TEXT PRIMARY KEY, code TEXT NOT NULL, expires_at TIMESTAMPTZ NOT NULL
      )`,
      `CREATE TABLE IF NOT EXISTS profiles (
        user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        gender TEXT, activity TEXT, goal TEXT, food_pref TEXT, challenge TEXT
      )`,
      `CREATE TABLE IF NOT EXISTS coaches (
        id BIGSERIAL PRIMARY KEY, name TEXT NOT NULL, title TEXT,
        rating NUMERIC(2,1), avatar TEXT
      )`,
      `CREATE TABLE IF NOT EXISTS groups (
        id BIGSERIAL PRIMARY KEY, name TEXT NOT NULL,
        coach_id BIGINT REFERENCES coaches(id), starts_on DATE
      )`,
      `CREATE TABLE IF NOT EXISTS group_members (
        group_id BIGINT REFERENCES groups(id) ON DELETE CASCADE,
        user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        weekly_xp INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (group_id, user_id)
      )`,
      `CREATE TABLE IF NOT EXISTS tasks (
        id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        day_index INTEGER NOT NULL, slot TEXT NOT NULL, time TEXT, icon TEXT,
        title TEXT NOT NULL, subtitle TEXT, xp INTEGER NOT NULL DEFAULT 0,
        done BOOLEAN NOT NULL DEFAULT FALSE, completed_at TIMESTAMPTZ
      )`,
      `CREATE TABLE IF NOT EXISTS checkins (
        id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        mood INTEGER, weight NUMERIC(5,1), notes TEXT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS meals (
        id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        meal_type TEXT, items JSONB, calories INTEGER, carbs INTEGER,
        protein INTEGER, fat INTEGER, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS posts (
        id BIGSERIAL PRIMARY KEY, group_id BIGINT REFERENCES groups(id) ON DELETE CASCADE,
        user_id BIGINT REFERENCES users(id) ON DELETE CASCADE, body TEXT, emoji TEXT,
        coach_pick BOOLEAN NOT NULL DEFAULT FALSE, likes INTEGER NOT NULL DEFAULT 0,
        fires INTEGER NOT NULL DEFAULT 0, comments INTEGER NOT NULL DEFAULT 0,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS badges (
        id BIGSERIAL PRIMARY KEY, code TEXT UNIQUE NOT NULL, emoji TEXT,
        name TEXT, xp INTEGER NOT NULL DEFAULT 0
      )`,
      `CREATE TABLE IF NOT EXISTS user_badges (
        user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        badge_id BIGINT REFERENCES badges(id) ON DELETE CASCADE,
        earned_at TIMESTAMPTZ NOT NULL DEFAULT now(), PRIMARY KEY (user_id, badge_id)
      )`,
      `CREATE TABLE IF NOT EXISTS lessons (
        id BIGSERIAL PRIMARY KEY, week INTEGER NOT NULL, title TEXT NOT NULL,
        author TEXT, minutes INTEGER, xp INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'locked'
      )`,
      `CREATE TABLE IF NOT EXISTS chat_messages (
        id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        from_coach BOOLEAN NOT NULL DEFAULT FALSE, text TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS daily_stats (
        user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        date DATE NOT NULL DEFAULT CURRENT_DATE, steps INTEGER NOT NULL DEFAULT 0,
        water INTEGER NOT NULL DEFAULT 0, sleep NUMERIC(3,1) NOT NULL DEFAULT 0,
        PRIMARY KEY (user_id, date)
      )`,
    ];
    for (const sql of baseTables) {
      await client.query(sql).catch(e => console.warn('  Base table skip:', e.message.slice(0, 100)));
    }

    const migrations = [
      `ALTER TABLE tasks ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ`,
      `CREATE TABLE IF NOT EXISTS post_comments (
        id BIGSERIAL PRIMARY KEY,
        post_id BIGINT REFERENCES posts(id) ON DELETE CASCADE,
        user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        body TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS height NUMERIC(5,1)`,
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS language TEXT NOT NULL DEFAULT 'en'`,
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS referral_code TEXT UNIQUE`,
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS level TEXT NOT NULL DEFAULT 'bronze'`,
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS streak_freezes INTEGER NOT NULL DEFAULT 0`,
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user'`,
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT`,
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS total_xp INTEGER NOT NULL DEFAULT 0`,
      `ALTER TABLE profiles ADD COLUMN IF NOT EXISTS medical_conditions TEXT`,
      `ALTER TABLE profiles ADD COLUMN IF NOT EXISTS medications TEXT`,
      `ALTER TABLE profiles ADD COLUMN IF NOT EXISTS dpdp_consent BOOLEAN NOT NULL DEFAULT FALSE`,
      `ALTER TABLE profiles ADD COLUMN IF NOT EXISTS medical_disclaimer_accepted BOOLEAN NOT NULL DEFAULT FALSE`,
      `ALTER TABLE profiles ADD COLUMN IF NOT EXISTS language TEXT NOT NULL DEFAULT 'en'`,
      `ALTER TABLE coaches ADD COLUMN IF NOT EXISTS user_id BIGINT`,
      `ALTER TABLE coaches ADD COLUMN IF NOT EXISTS phone TEXT`,
      `ALTER TABLE coaches ADD COLUMN IF NOT EXISTS specialization TEXT`,
      `ALTER TABLE meals ADD COLUMN IF NOT EXISTS photo_url TEXT`,
      `ALTER TABLE meals ADD COLUMN IF NOT EXISTS coach_feedback TEXT`,
      `ALTER TABLE meals ADD COLUMN IF NOT EXISTS coach_approved BOOLEAN`,
      `ALTER TABLE posts ADD COLUMN IF NOT EXISTS image_url TEXT`,
      `ALTER TABLE posts ADD COLUMN IF NOT EXISTS post_type TEXT NOT NULL DEFAULT 'text'`,
      `ALTER TABLE lessons ADD COLUMN IF NOT EXISTS video_url TEXT`,
      `ALTER TABLE lessons ADD COLUMN IF NOT EXISTS content TEXT`,
      `ALTER TABLE lessons ADD COLUMN IF NOT EXISTS quiz_questions JSONB`,
      `ALTER TABLE lessons ADD COLUMN IF NOT EXISTS lesson_type TEXT NOT NULL DEFAULT 'article'`,
      `ALTER TABLE lessons ADD COLUMN IF NOT EXISTS week_name TEXT NOT NULL DEFAULT ''`,
      `ALTER TABLE lessons ADD COLUMN IF NOT EXISTS author TEXT`,
      `ALTER TABLE lessons ADD COLUMN IF NOT EXISTS minutes INTEGER NOT NULL DEFAULT 5`,
      `ALTER TABLE group_members ADD COLUMN IF NOT EXISTS joined_at TIMESTAMPTZ NOT NULL DEFAULT now()`,
      `UPDATE group_members gm SET joined_at = u.created_at FROM users u WHERE u.id = gm.user_id AND gm.joined_at > u.created_at + INTERVAL '1 minute'`,
      `CREATE TABLE IF NOT EXISTS body_measurements (
        id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        waist NUMERIC(5,1), hips NUMERIC(5,1), chest NUMERIC(5,1), arms NUMERIC(5,1), weight NUMERIC(5,1),
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS fasting_sessions (
        id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        started_at TIMESTAMPTZ NOT NULL DEFAULT now(), ended_at TIMESTAMPTZ,
        target_hours INTEGER NOT NULL DEFAULT 16, completed BOOLEAN NOT NULL DEFAULT FALSE
      )`,
      `CREATE TABLE IF NOT EXISTS diet_plans (
        id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        coach_id BIGINT, week_number INTEGER NOT NULL DEFAULT 1, title TEXT,
        meals JSONB, grocery_list JSONB, notes TEXT,
        ai_generated BOOLEAN NOT NULL DEFAULT FALSE, status TEXT NOT NULL DEFAULT 'active',
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS reflections (
        id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        type TEXT NOT NULL DEFAULT 'evening', text TEXT, mood INTEGER,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS progress_photos (
        id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        photo_url TEXT NOT NULL, label TEXT, week INTEGER,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS referrals (
        id BIGSERIAL PRIMARY KEY, referrer_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        referred_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        status TEXT NOT NULL DEFAULT 'pending', reward_given BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS group_chat_messages (
        id BIGSERIAL PRIMARY KEY, group_id BIGINT REFERENCES groups(id) ON DELETE CASCADE,
        user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        text TEXT NOT NULL, type TEXT NOT NULL DEFAULT 'user',
        pinned BOOLEAN NOT NULL DEFAULT FALSE, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS notifications (
        id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        type TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL,
        read BOOLEAN NOT NULL DEFAULT FALSE, data JSONB,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS weekly_winners (
        id BIGSERIAL PRIMARY KEY, group_id BIGINT, week_start DATE NOT NULL,
        user_id BIGINT, rank INTEGER NOT NULL, weekly_xp INTEGER NOT NULL,
        prize_amount INTEGER, prize_status TEXT NOT NULL DEFAULT 'pending',
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS weekly_challenges (
        id BIGSERIAL PRIMARY KEY, week_number INTEGER NOT NULL,
        title TEXT NOT NULL, description TEXT, type TEXT NOT NULL DEFAULT 'steps',
        target INTEGER NOT NULL, xp_reward INTEGER NOT NULL DEFAULT 40,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS challenge_entries (
        id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        challenge_id BIGINT, progress INTEGER NOT NULL DEFAULT 0,
        completed BOOLEAN NOT NULL DEFAULT FALSE, completed_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS streak_freeze_log (
        id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        type TEXT NOT NULL DEFAULT 'earned', created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS habit_completions (
        user_id BIGINT, habit_type TEXT NOT NULL, date DATE NOT NULL DEFAULT CURRENT_DATE,
        completed BOOLEAN NOT NULL DEFAULT FALSE, PRIMARY KEY (user_id, habit_type, date)
      )`,
      `CREATE TABLE IF NOT EXISTS recipes (
        id BIGSERIAL PRIMARY KEY, title TEXT NOT NULL, cuisine TEXT, diet_type TEXT,
        calories INTEGER, prep_minutes INTEGER, ingredients JSONB, steps JSONB,
        image_url TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS exercises (
        id BIGSERIAL PRIMARY KEY, title TEXT NOT NULL, category TEXT,
        level TEXT NOT NULL DEFAULT 'beginner', duration_min INTEGER, calories_est INTEGER,
        instructions JSONB, video_url TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS data_requests (
        id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        type TEXT NOT NULL DEFAULT 'export', status TEXT NOT NULL DEFAULT 'pending',
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `CREATE TABLE IF NOT EXISTS weekly_reset_log (
        id BIGSERIAL PRIMARY KEY, reset_date DATE NOT NULL UNIQUE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
      `DELETE FROM tasks WHERE icon='lunch_dining'`,
      `CREATE UNIQUE INDEX IF NOT EXISTS tasks_user_day_icon_uidx ON tasks (user_id, day_index, icon)`,
      `CREATE TABLE IF NOT EXISTS post_likes (
        user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        post_id BIGINT REFERENCES posts(id) ON DELETE CASCADE,
        PRIMARY KEY (user_id, post_id)
      )`,
      `ALTER TABLE weekly_challenges ADD CONSTRAINT IF NOT EXISTS weekly_challenges_week_unique UNIQUE (week_number)`,
      `ALTER TABLE challenge_entries ADD CONSTRAINT IF NOT EXISTS challenge_entries_user_challenge_unique UNIQUE (user_id, challenge_id)`,
      `ALTER TABLE checkins ADD COLUMN IF NOT EXISTS evening_mood INTEGER`,
      `CREATE TABLE IF NOT EXISTS diet_completions (
        id BIGSERIAL PRIMARY KEY,
        user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        plan_id BIGINT,
        date DATE NOT NULL DEFAULT CURRENT_DATE,
        meal_type TEXT NOT NULL,
        xp_awarded INTEGER NOT NULL DEFAULT 0,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        UNIQUE (user_id, date, meal_type)
      )`,
      `ALTER TABLE weekly_challenges ADD COLUMN IF NOT EXISTS phase INTEGER NOT NULL DEFAULT 1`,
      `ALTER TABLE weekly_challenges ADD COLUMN IF NOT EXISTS min_value INTEGER NOT NULL DEFAULT 0`,
      `ALTER TABLE badges ADD COLUMN IF NOT EXISTS description TEXT NOT NULL DEFAULT ''`,
      // Per-user lesson completion tracking (replaces global lessons.status)
      `CREATE TABLE IF NOT EXISTS user_lesson_progress (
        user_id    BIGINT REFERENCES users(id) ON DELETE CASCADE,
        lesson_id  BIGINT REFERENCES lessons(id) ON DELETE CASCADE,
        completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        PRIMARY KEY (user_id, lesson_id)
      )`,
      // Remove duplicate lesson rows — keep only the lowest id per (week, title)
      `DELETE FROM lessons WHERE id NOT IN (
        SELECT MIN(id) FROM lessons GROUP BY week, title
      )`,
      // Unique constraint prevents future duplicate seeds
      `CREATE UNIQUE INDEX IF NOT EXISTS lessons_week_title_uidx ON lessons (week, title)`,
      // Reset global status column to 'locked' — status is now computed per-user at query time
      `UPDATE lessons SET status = 'locked'`,
      // Fasting: store XP awarded per session for accurate history display
      `ALTER TABLE fasting_sessions ADD COLUMN IF NOT EXISTS xp_awarded INTEGER NOT NULL DEFAULT 0`,
      // Backfill total_xp from xp for users where total_xp was added after they earned XP
      `UPDATE users SET total_xp = xp WHERE total_xp < xp`,
      // Deduplicate challenge_entries — CTE approach avoids NOT IN pitfalls
      `WITH ranked AS (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY user_id, challenge_id ORDER BY progress DESC, id DESC) AS rn
        FROM challenge_entries
      ) DELETE FROM challenge_entries WHERE id IN (SELECT id FROM ranked WHERE rn > 1)`,
      `ALTER TABLE challenge_entries ADD CONSTRAINT IF NOT EXISTS challenge_entries_user_challenge_unique UNIQUE (user_id, challenge_id)`,
    ];

    for (const sql of migrations) {
      await client.query(sql).catch(e => console.warn('  Migration skip:', e.message.slice(0, 100)));
    }

    // Seed reference data
    await client.query(`
      INSERT INTO badges (code, emoji, name, xp, description) VALUES
        ('first_step','👣','First Step',0,'Complete your very first morning check-in'),
        ('snapshot','📸','Snapshot',0,'Add your first progress photo'),
        ('baseline','⚖️','Baseline',0,'Log your weight for 7 consecutive days'),
        ('team_player','🤝','Team Player',0,'Post in the group feed for the first time'),
        ('streak_3','✨','Spark',50,'Build a 3-day activity streak'),
        ('streak_7','🔥','Flame',100,'Build a 7-day activity streak'),
        ('streak_14','🔥','Blaze',200,'Build a 14-day activity streak'),
        ('streak_30','🌋','Inferno',500,'Build a 30-day activity streak'),
        ('streak_60','💥','Unstoppable',1000,'Build a 60-day activity streak'),
        ('freeze_master','❄️','Freeze Master',100,'Use a streak freeze to protect your streak'),
        ('comeback_kid','💪','Comeback Kid',100,'Return after a missed day and restart your streak'),
        ('first_bite','🍽️','First Bite',0,'Log your first meal using Meal AI'),
        ('first_post','📝','First Post',0,'Share your first post in the group feed'),
        ('weekly_champ','🥇','Weekly Champ',500,'Finish #1 on the weekly XP leaderboard'),
        ('recruiter','🎁','Recruiter',300,'Refer a friend who joins FitQuest'),
        ('goal_crusher','🏆','Goal Crusher',1000,'Reach your target weight'),
        ('graduate','🎓','Graduate',1000,'Complete all 12 weeks of the programme'),
        ('streak_master','🔥','Streak Master',500,'Build a 30-day streak without a break'),
        ('fasting_pro','⏰','Fasting Pro',300,'Complete 5 intermittent fasting sessions'),
        ('royal_champion','👑','Royal Champion',2000,'Win the weekly leaderboard 3 weeks in a row')
      ON CONFLICT (code) DO UPDATE SET description=EXCLUDED.description
    `).catch(() => {});

    await client.query(`
      INSERT INTO weekly_challenges (week_number,phase,title,description,type,target,min_value,xp_reward) VALUES
        (1,1,'Know Your Baseline','Log weight + all meals every day for 7 days','weight_and_meals',7,0,50),
        (2,1,'Find Your Move','Hit 5,000+ steps on 4 days this week','steps_min_days',4,5000,50),
        (3,1,'Sleep Foundation','Log 7+ hours sleep on 5 days this week','sleep_days',5,0,50),
        (4,2,'Morning Anchor','Complete morning check-in every day for 7 days','morning_checkin',7,0,60),
        (5,2,'Move After Meals','Hit 5,000+ steps AND log all 3 meals on 5 days','steps_and_meals',5,5000,60),
        (6,2,'Halfway Audit','Log weight every day for 7 days (milestone week)','weight_daily',7,0,80),
        (7,3,'Step It Up','Hit 8,000+ steps on 5 days','steps_min_days',5,8000,70),
        (8,3,'Eat With Intent','Log all meals with no skips on 5 days','meal_all_days',5,0,70),
        (9,3,'Full System Week','Complete ALL 5 daily tasks on 4 days','all_tasks',4,0,80),
        (10,4,'10K Club','Hit 10,000+ steps on 5 days','steps_min_days',5,10000,90),
        (11,4,'Unbreakable Streak','Complete ALL 5 daily tasks every day for 7 days','all_tasks',7,0,100),
        (12,4,'Transformation Proof','Log weight + morning + evening check-in every day for 7 days','transformation_proof',7,0,150)
      ON CONFLICT (week_number) DO UPDATE
        SET title=EXCLUDED.title, description=EXCLUDED.description,
            type=EXCLUDED.type, target=EXCLUDED.target, min_value=EXCLUDED.min_value,
            xp_reward=EXCLUDED.xp_reward, phase=EXCLUDED.phase
    `).catch((e) => console.warn('[seed challenges]', e.message));

    // Upsert full 12-week curriculum — idempotent via unique index on (week, title)
    await client.query(`
      INSERT INTO lessons (week, week_name, title, lesson_type, xp, status, author, minutes, content) VALUES
        (1,'Getting Started','Why small habits beat willpower','article',30,'locked','Dr. Roy',5,
         'Willpower is a limited resource that runs out by evening. The FitQuest system works differently: we build tiny automatic behaviours that require zero willpower. A 2-minute morning weigh-in, logging one meal, a 10-minute walk — each one costs nothing but compounds into transformation. Neuroscience shows habits take 66 days on average to become automatic. Our 84-day programme gives you 18 extra days of buffer. Trust the process.'),
        (1,'Getting Started','Week 1 foundation quiz','quiz',50,'locked',NULL,3,NULL),
        (2,'Nutrition','Reading your plate','article',30,'locked','Dr. Roy',5,
         'The simplest nutrition rule: fill half your plate with non-starchy vegetables, a quarter with lean protein, and a quarter with complex carbs. For Indian meals this means: 2 cups sabzi + 1 cup dal + 1-2 rotis. This naturally gives you 400-500 kcal with fibre that keeps you full for 4+ hours. No calorie counting needed — just rearrange what is already on your thali.'),
        (2,'Nutrition','Nutrition quiz','quiz',50,'locked',NULL,3,NULL),
        (3,'Movement','The science of 8,000 steps','article',30,'locked','Dr. Roy',5,
         'A landmark 2021 JAMA study of 2,110 adults found 8,000 steps/day cut all-cause mortality by 51% vs 4,000 steps. You do not need a gym. A 45-minute brisk walk burns 250-300 calories, improves insulin sensitivity for 24 hours, and releases BDNF — the brain''s growth hormone — which reduces food cravings. Your best fat-burning tool costs nothing and requires no equipment.'),
        (3,'Movement','Movement quiz','quiz',50,'locked',NULL,3,NULL),
        (4,'Sleep','Sleep & fat loss — the missing link','article',30,'locked','Dr. Roy',6,
         'Sleep deprivation of even one night raises ghrelin (hunger hormone) by 24% and cuts leptin (fullness hormone) by 18%. You wake up hungrier and need 300 extra calories to feel satisfied. A 2010 Annals of Internal Medicine study found that dieters sleeping 5.5 hrs lost 55% less fat than those sleeping 8.5 hrs on the same diet. Optimising sleep is the highest-leverage action you can take for fat loss.'),
        (4,'Sleep','Sleep quiz','quiz',50,'locked',NULL,3,NULL),
        (5,'Strength','Why muscle burns fat while you sleep','article',30,'locked','Coach Priya',5,
         'One kilogram of muscle burns an extra 13 kcal per day at rest. Add 3 kg of muscle — common in 12 weeks of consistent training — and you burn 39 extra kcal/day effortlessly. Muscle also acts as a glucose sink: it absorbs blood sugar rapidly, reducing insulin spikes. You do not need a gym; three 20-minute bodyweight sessions per week (squats, push-ups, lunges) are enough to build meaningful metabolic muscle.'),
        (5,'Strength','Strength quiz','quiz',50,'locked',NULL,3,NULL),
        (6,'Mindful Eating','Breaking emotional eating cycles','article',40,'locked','Dr. Roy',6,
         'Emotional eating is triggered by stress, boredom, or loneliness — not true hunger. The H.A.L.T. method stops the cycle: before eating, ask Am I Hungry, Angry, Lonely, or Tired? True hunger builds slowly; emotional hunger is sudden and craves specific foods. Technique: when a craving hits, set a 10-minute timer and drink water. 70% of cravings pass in that window. For the other 30%, choose a small, satisfying portion and eat mindfully without screens.'),
        (6,'Mindful Eating','Mindful eating quiz','quiz',40,'locked',NULL,3,NULL),
        (7,'Hydration','Water, metabolism & fat burning','article',30,'locked','Coach Priya',5,
         'Your liver converts stored fat into usable energy — but only when it is not busy doing the kidneys'' job. Dehydration forces the liver to step in, slowing fat metabolism by up to 30%. Drinking 500 ml of cold water raises metabolic rate by 24-30% for 60 minutes (Journal of Clinical Endocrinology, 2003). Target: 35 ml per kg of body weight daily. For a 70 kg person: 2.45 litres. Spread across 8-9 glasses. Start each morning with 500 ml before tea or coffee.'),
        (7,'Hydration','Hydration quiz','quiz',30,'locked',NULL,3,NULL),
        (8,'Stress & Cortisol','Stress, cortisol & belly fat','article',40,'locked','Dr. Roy',7,
         'Cortisol — the stress hormone — directly signals fat cells in your abdomen to store more fat. Chronic stress keeps cortisol elevated all day. Three evidence-based cortisol reducers: (1) 5 minutes of box breathing (inhale 4s, hold 4s, exhale 4s, hold 4s) drops cortisol by 23% within 30 minutes. (2) A 20-minute walk in nature reduces cortisol by 21%. (3) Laughing for 10 minutes lowers cortisol by 37-70% (Loma Linda University). Stress management is fat loss strategy.'),
        (8,'Stress & Cortisol','Stress management quiz','quiz',50,'locked',NULL,3,NULL),
        (9,'Progress Tracking','Tracking without obsessing','article',30,'locked','Coach Priya',5,
         'Weekly weigh-ins outperform daily weigh-ins. Weight fluctuates 1-2 kg daily from water, food volume, and hormones — daily weighing creates anxiety without signal. The true signal is the 4-week trend. Photo comparisons every 4 weeks reveal fat loss that the scale misses (especially when building muscle). Track three numbers: weekly average weight, waist circumference (monthly), and how your reference outfit fits. These three give you the complete picture.'),
        (9,'Progress Tracking','Progress quiz','quiz',30,'locked',NULL,3,NULL),
        (10,'Plateaus','Breaking through weight plateaus','article',40,'locked','Dr. Roy',6,
         'A weight plateau after 4+ weeks signals metabolic adaptation — your body has recalculated maintenance calories at your new lower weight. Three plateau breakers: (1) Add 2,000 steps/day. (2) Increase protein to 1.6g per kg body weight (reduces muscle loss during deficit). (3) Take a 1-week diet break at maintenance calories — this resets leptin and hunger hormones, making the next deficit phase more effective. Plateaus are biology, not failure. They require strategy, not punishment.'),
        (10,'Plateaus','Plateau-breaking quiz','quiz',50,'locked',NULL,3,NULL),
        (11,'Sustainable Habits','Eating out & social eating','article',30,'locked','Coach Priya',5,
         'Social events are the biggest compliance killer. Strategies that work: (1) Eat a protein-rich snack before the event so you arrive not starving. (2) Use the "one-plate rule" — choose your plate thoughtfully, eat it slowly, and stop. (3) For restaurants: order protein + salad first; decide whether the dessert is truly worth it before it arrives. (4) Alcohol: each drink adds 100-150 empty calories and lowers inhibitions around food. Club soda with lime tastes social and costs zero calories.'),
        (11,'Sustainable Habits','Sustainable habits quiz','quiz',30,'locked',NULL,3,NULL),
        (12,'Maintenance','Life after the programme','article',50,'locked','Dr. Roy',8,
         'Maintaining weight loss requires slightly fewer calories than maintaining your original weight — about 150-200 kcal/day less. Your new maintenance is your goal. The habits that got you here (daily steps, protein at every meal, sleep hygiene, stress management) are permanent now — not temporary tools. Research shows that people who maintain weight loss long-term share four behaviours: they weigh themselves regularly, they exercise daily, they eat breakfast, and they limit screen time during meals. You have practised all four. Congratulations on completing the FitQuest programme.')
        ,
        (12,'Maintenance','Final graduation quiz','quiz',100,'locked',NULL,5,NULL),
        (13,'Beyond 12 Weeks','Making it permanent — the identity shift','article',40,'locked','Dr. Roy',6,
         'The most powerful thing that happened in the last 12 weeks is not the weight you lost — it is the identity you built. You are now someone who checks in daily, moves their body, eats mindfully, and manages stress. Research shows identity-based habits stick at 3× the rate of outcome-based habits. Instead of "I want to lose weight," your new story is "I am someone who takes care of their body." Protect that identity in year two the same way you built it in the first 84 days: one small daily action at a time.'),
        (13,'Beyond 12 Weeks','Long-term maintenance quiz','quiz',50,'locked',NULL,3,NULL),
        (14,'Advanced Nutrition','Personalising your macro targets','article',40,'locked','Coach Priya',7,
         'Now that your habits are solid, it is time to fine-tune your macros. Protein: 1.6-2.2 g per kg body weight preserves muscle during a cut and maximises muscle gain during a build phase. Carbohydrates: time your largest carb serving around your workout (within 1 hour before or after) for best energy and recovery. Fat: keep healthy fats (nuts, avocado, ghee in moderation) at 25-35% of total calories for hormone health. Track for 2 weeks, adjust based on energy and scale movement, then step back — you now have the data to self-coach.'),
        (14,'Advanced Nutrition','Advanced nutrition quiz','quiz',50,'locked',NULL,3,NULL)
      ON CONFLICT (week, title) DO UPDATE
        SET content = EXCLUDED.content,
            xp      = EXCLUDED.xp,
            minutes = EXCLUDED.minutes,
            week_name = EXCLUDED.week_name,
            author  = EXCLUDED.author
    `).catch(e => console.warn('Lessons upsert error:', e.message));

    await client.query(`
      INSERT INTO recipes (title,cuisine,diet_type,calories,prep_minutes,ingredients,steps) VALUES
        ('Masala Oats','north_indian','veg',280,10,'["oats","onion","tomato","cumin","salt"]','["Sauté onion","Add tomato","Add oats","Cook 5 min"]'),
        ('Dal Tadka','north_indian','veg',320,20,'["toor dal","tomatoes","garlic","cumin","ghee"]','["Pressure cook dal","Make tadka","Combine"]'),
        ('Idli Sambar','south_indian','veg',250,30,'["idli batter","toor dal","vegetables"]','["Steam idlis","Cook sambar","Serve"]'),
        ('Chicken Salad','continental','nonveg',350,15,'["grilled chicken","greens","tomatoes","olive oil"]','["Grill chicken","Toss salad","Drizzle dressing"]'),
        ('Paneer Bhurji','north_indian','veg',380,15,'["paneer","onion","tomatoes","spices"]','["Sauté onion","Add spices","Crumble paneer"]'),
        ('Sprout Salad','north_indian','veg',180,5,'["mixed sprouts","cucumber","tomato","lemon"]','["Mix all","Season with lemon & chaat masala"]')
      ON CONFLICT DO NOTHING
    `).catch(() => {});

    await client.query(`
      INSERT INTO exercises (title,category,level,duration_min,calories_est,instructions) VALUES
        ('Brisk Walk','cardio','beginner',30,150,'["Walk at 5-6 km/h","Keep back straight","Breathe steadily"]'),
        ('Bodyweight Squats','strength','beginner',15,80,'["Feet shoulder-width","Lower thighs parallel","Push through heels"]'),
        ('Push-ups','strength','beginner',10,60,'["High plank","Lower chest to ground","Push back up"]'),
        ('Sun Salutation','yoga','beginner',20,100,'["Mountain pose","Forward fold","Plank","Cobra","Downward dog"]'),
        ('Jumping Jacks','cardio','beginner',10,80,'["Feet together","Jump and raise arms","Return to start"]'),
        ('Plank Hold','strength','beginner',5,30,'["Forearm plank","Hips level","Hold 30-60s"]'),
        ('Lunges','strength','intermediate',15,90,'["Step forward","Lower back knee","Push back","Alternate"]'),
        ('Warrior Pose','yoga','beginner',15,50,'["Wide stance","Front knee 90°","Arms extended","Hold 30s"]'),
        ('Mountain Climbers','cardio','intermediate',10,100,'["High plank","Drive knee to chest","Alternate quickly"]'),
        ('Child Pose','yoga','beginner',5,20,'["Kneel on mat","Sit on heels","Extend arms","Breathe deeply"]')
      ON CONFLICT DO NOTHING
    `).catch(() => {});

    try {
      await client.query(`
        INSERT INTO coaches (name, title, specialization)
        SELECT 'Coach Priya', 'Certified Nutritionist', 'Weight loss & lifestyle'
        WHERE NOT EXISTS (SELECT 1 FROM coaches LIMIT 1)
      `);
      await client.query(`
        INSERT INTO groups (name, coach_id, starts_on)
        SELECT 'FitQuest Community', (SELECT id FROM coaches ORDER BY id LIMIT 1), CURRENT_DATE
        WHERE NOT EXISTS (SELECT 1 FROM groups LIMIT 1)
      `);
      await client.query(`
        INSERT INTO users (phone, name, email, onboarded, xp, streak)
        SELECT '+910000000001', 'Coach Priya', 'coach@fitquest.app', TRUE, 0, 0
        WHERE NOT EXISTS (SELECT 1 FROM users WHERE email='coach@fitquest.app')
      `);
      const postCount = (await client.query(`SELECT COUNT(*) AS n FROM posts`)).rows[0].n;
      if (Number(postCount) === 0) {
        const coachUser = (await client.query(
          `SELECT id FROM users WHERE email='coach@fitquest.app' LIMIT 1`
        )).rows[0];
        const defaultGroup = (await client.query(
          `SELECT id FROM groups ORDER BY id LIMIT 1`
        )).rows[0];
        if (coachUser && defaultGroup) {
          await client.query(`
            INSERT INTO posts (group_id, user_id, body, emoji, coach_pick, post_type) VALUES
              ($1, $2, 'Welcome to FitQuest! 🎉 Share your progress, wins, and motivate each other. Every step counts on this 12-week journey!', '🎉', TRUE, 'text'),
              ($1, $2, 'Tip of the week 💡 Drinking a glass of water before every meal can reduce calorie intake by up to 13%. Small habits, big results!', '💡', TRUE, 'text')
          `, [defaultGroup.id, coachUser.id]);
          console.log('[seed] 2 demo posts inserted');
        }
      }
    } catch (seedErr) {
      console.warn('[seed] warning:', seedErr.message);
    }

    console.log('✅ Migrations OK');
  } catch (e) {
    console.warn('⚠️  Migration warning:', e.message);
  } finally {
    client.release();
  }
}
runMigrations();

const app = express();
app.use(cors({
  origin: '*',
  methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.options('*', cors());
app.use(express.json({ limit: '12mb' }));

app.get('/health', (_req, res) => res.json({ ok: true, service: 'fitquest', ts: Date.now() }));
app.use('/',              migrateRoutes);     // one-time DB setup: GET /migrate?key=...

app.use('/auth',          authRoutes);
app.use('/meals',         mealRoutes);
app.use('/payments',      paymentRoutes);
app.use('/fasting',       fastingRoutes);
app.use('/measurements',  measurementRoutes);
app.use('/reflection',    reflectionRoutes);
app.use('/gamification',  gamificationRoutes);
app.use('/diet-plan',     dietPlanRoutes);
app.use('/progress',      progressRoutes);
app.use('/referral',      referralRoutes);
app.use('/notifications', notificationRoutes);
app.use('/challenge',     challengeRoutes);
app.use('/recipes',       recipesRoutes);
app.use('/exercises',     exercisesRoutes);
app.use('/coach',         coachRoutes);
app.use('/admin',         adminRoutes);
app.use('/',              groupChatRoutes);  // /group/chat routes
app.use('/',              apiRoutes);

// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ message: err.message || 'Server error' });
});

// Weekly XP reset + winners every Sunday at midnight
cron.schedule('0 0 * * 0', () => {
  console.log('[cron] Weekly reset...');
  runWeeklyReset();
});

// Daily morning nudge: 7am — notify users who haven't checked in today
cron.schedule('0 7 * * *', async () => {
  console.log('[cron] Morning nudge...');
  try {
    const today = new Date().toISOString().slice(0, 10);
    const messages = [
      'Good morning! Start your day with a check-in. Your streak is waiting!',
      'Rise and shine! Log your morning check-in and keep that streak alive.',
      'A new day, a new chance to crush your goals. Check in now!',
      'Your cohort is already logging in. Don\'t fall behind — check in now!',
      'Morning champion! Your FitQuest tasks for today are ready.',
    ];
    const { pool } = await import('./db.js');
    const client = await pool.connect();
    const users = (await client.query(
      `SELECT u.id, u.name FROM users u
       WHERE NOT EXISTS (
         SELECT 1 FROM checkins c WHERE c.user_id=u.id AND c.checked_at::date=$1 AND c.mood>=0
       ) AND u.role='user'`,
      [today]
    )).rows;
    const msg = messages[new Date().getDay() % messages.length];
    for (const u of users) {
      const firstName = u.name?.split(' ')[0] || 'there';
      const title = `Good morning, ${firstName}!`;
      await client.query(
        `INSERT INTO notifications (user_id,type,title,body) VALUES ($1,'morning_nudge',$2,$3)`,
        [u.id, title, msg]
      ).catch(() => {});
      sendPush(u.id, title, msg).catch(() => {});
    }
    client.release();
    console.log(`[cron] Morning nudge sent to ${users.length} users`);
  } catch(e) { console.warn('[cron] Morning nudge error:', e.message); }
});

// Nightly streak decrement: 00:05 — reduce streak by 1 for users who missed yesterday
cron.schedule('5 0 * * *', async () => {
  console.log('[cron] Nightly streak decrement...');
  try {
    const { pool } = await import('./db.js');
    const client = await pool.connect();
    // Decrement streak (min 0) for users with streak > 0 who have no check-in from yesterday (UTC date)
    const result = await client.query(
      `UPDATE users SET streak = GREATEST(streak - 1, 0)
       WHERE streak > 0 AND role = 'user'
         AND NOT EXISTS (
           SELECT 1 FROM checkins c
           WHERE c.user_id = users.id
             AND c.created_at::date = (CURRENT_DATE - INTERVAL '1 day')::date
         )
       RETURNING id, streak`
    );
    client.release();
    console.log(`[cron] Decremented streak for ${result.rowCount} users`);
  } catch(e) { console.warn('[cron] Streak decrement error:', e.message); }
});

// Streak at-risk alert: 8pm — warn users who haven't done any tasks today
cron.schedule('0 20 * * *', async () => {
  console.log('[cron] Streak at-risk check...');
  try {
    const today = new Date().toISOString().slice(0, 10);
    const { pool } = await import('./db.js');
    const client = await pool.connect();
    const atRisk = (await client.query(
      `SELECT u.id, u.name, u.streak FROM users u
       WHERE u.streak > 0 AND u.role='user'
         AND NOT EXISTS (
           SELECT 1 FROM tasks t WHERE t.user_id=u.id AND t.done=TRUE
             AND t.completed_at::date=$1
         )`,
      [today]
    )).rows;
    for (const u of atRisk) {
      const existing = (await client.query(
        `SELECT id FROM notifications WHERE user_id=$1 AND type='streak_risk' AND created_at::date=$2`,
        [u.id, today]
      )).rows[0];
      if (!existing) {
        const title = `Your ${u.streak}-day streak is at risk!`;
        const body = 'Complete at least one task before midnight to keep your streak alive!';
        await client.query(
          `INSERT INTO notifications (user_id,type,title,body) VALUES ($1,'streak_risk',$2,$3)`,
          [u.id, title, body]
        ).catch(() => {});
        sendPush(u.id, title, body).catch(() => {});
      }
    }
    client.release();
    console.log(`[cron] Streak alerts sent to ${atRisk.length} users`);
  } catch(e) { console.warn('[cron] Streak alert error:', e.message); }
});

const port = process.env.PORT || 4000;
if (process.env.VERCEL !== '1') {
  app.listen(port, () => console.log(`🚀 FitQuest API on http://localhost:${port}`));
}

export default app;
