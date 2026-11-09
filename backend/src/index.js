import { fileURLToPath } from 'url';
import path from 'path';
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
      `CREATE UNIQUE INDEX IF NOT EXISTS weekly_challenges_week_uniq ON weekly_challenges (week_number)`,
      `CREATE UNIQUE INDEX IF NOT EXISTS challenge_entries_user_challenge_uniq ON challenge_entries (user_id, challenge_id)`,
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
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_photo_url TEXT`,
      `CREATE TABLE IF NOT EXISTS user_reminders (
        id BIGSERIAL PRIMARY KEY,
        user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        type TEXT NOT NULL,
        time TEXT NOT NULL DEFAULT '08:00',
        enabled BOOLEAN NOT NULL DEFAULT TRUE,
        UNIQUE (user_id, type)
      )`,
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

    // Upsert 12-week curriculum — idempotent via unique index on (week, title)
    await client.query(`
      INSERT INTO lessons (week, week_name, title, lesson_type, xp, status, author, minutes, content, quiz_questions) VALUES
        (1,'Getting Started','Why small habits beat willpower','article',30,'locked','Dr. Roy',5,
         'Willpower is a limited resource that runs out by evening. The FitQuest system works differently: we build tiny automatic behaviours that require zero willpower. A 2-minute morning weigh-in, logging one meal, a 10-minute walk — each one costs nothing but compounds into transformation.

Neuroscience shows habits take 66 days on average to become automatic. Our 84-day programme gives you 18 extra days of buffer. The key is starting so small that failure is impossible.

The Habit Stacking Method

Attach a new habit to an existing one: "After I brush my teeth, I will step on the scale." After I pour my morning chai, I will open FitQuest and check in. This piggybacks on neural pathways your brain already has.

Why This Programme Is Different

Most diets rely on motivation — which fades. FitQuest builds systems: daily check-ins, meal photos, step tracking. Each action takes under 2 minutes but sends a signal to your brain: I am someone who takes care of my health. That identity shift is what makes change permanent.',
         ''[{"question":"How long does research say it takes to form an automatic habit?","options":["21 days","45 days","66 days on average","Exactly 84 days"],"correct":2,"explanation":"University College London research found the average is 66 days, not the commonly cited 21 days."},{"question":"What is habit stacking?","options":["Doing all habits at once","Attaching a new habit to an existing routine","Stacking food on your plate","Doing habits only on weekends"],"correct":1,"explanation":"Habit stacking piggybacks new behaviours on existing neural pathways, making adoption much easier."}]''::jsonb),

        (2,'Nutrition','Reading your plate','article',30,'locked','Dr. Roy',5,
         'The simplest nutrition rule: fill half your plate with non-starchy vegetables, a quarter with lean protein, and a quarter with complex carbs. No calorie counting needed — just rearrange what is already on your plate.

The Indian Plate Method

For Indian meals this means: 2 cups sabzi (vegetables) + 1 cup dal or paneer + 1-2 rotis or a small serving of rice. This naturally gives you 400-500 kcal with fibre that keeps you full for 4+ hours.

Why Portion Arrangement Works

A 2019 study in the British Medical Journal found that people who used the plate method lost an average of 3.2 kg more than those counting calories over 12 weeks. The visual simplicity removes decision fatigue.

Common Mistakes to Avoid

1. Drowning vegetables in oil or ghee — this can triple the calories
2. Eating multiple rotis with small amounts of sabzi — flip the ratio
3. Skipping protein — you will be hungry again in 2 hours
4. Drinking calories — one glass of packaged juice has as many calories as a roti',
         ''[{"question":"What is the recommended plate ratio?","options":["All protein, no carbs","Half vegetables, quarter protein, quarter carbs","Equal thirds of everything","Mostly rice with some dal"],"correct":1,"explanation":"Half non-starchy vegetables, a quarter lean protein, and a quarter complex carbs gives optimal nutrition and satiety."},{"question":"Why does the plate method outperform calorie counting?","options":["It burns more calories","Visual simplicity removes decision fatigue","It allows unlimited eating","It only works for Indian food"],"correct":1,"explanation":"Research shows the visual plate method reduces decision fatigue and leads to more sustainable weight loss than calorie counting."}]''::jsonb),

        (3,'Movement','The science of 8,000 steps','article',30,'locked','Dr. Roy',5,
         'A landmark 2021 JAMA study of 2,110 adults found 8,000 steps/day cut all-cause mortality by 51% vs 4,000 steps. You do not need a gym — walking is the most powerful exercise for weight loss.

Why Walking Beats Running for Fat Loss

A 45-minute brisk walk burns 250-300 calories, improves insulin sensitivity for 24 hours, and releases BDNF — the brain''s growth hormone — which reduces food cravings. Unlike running, walking doesn''t spike hunger hormones afterward.

The NEAT Advantage

Non-Exercise Activity Thermogenesis (NEAT) accounts for 15-30% of your daily calorie burn. Walking, taking stairs, standing — these add up to more calories than a gym session. Increasing NEAT by 2,000 steps burns an extra 100 calories daily.

How to Hit 8,000 Steps Easily

Walk 10 minutes after each meal (3,000 steps). Take phone calls while walking (1,000 steps). Park farther from entrances. Take stairs. These tiny choices compound into 8,000+ steps without a dedicated workout.',
         ''[{"question":"By how much did 8,000 daily steps reduce mortality in the JAMA study?","options":["10%","25%","51%","75%"],"correct":2,"explanation":"The 2021 JAMA study found 8,000 steps/day cut all-cause mortality by 51% compared to 4,000 steps."},{"question":"What is NEAT?","options":["A type of exercise class","Non-Exercise Activity Thermogenesis — daily movement outside workouts","A nutritional supplement","A sleep technique"],"correct":1,"explanation":"NEAT accounts for 15-30% of daily calorie burn through walking, standing, fidgeting, and other non-exercise movement."}]''::jsonb),

        (4,'Sleep','Sleep & fat loss — the missing link','article',30,'locked','Dr. Roy',6,
         'Sleep deprivation of even one night raises ghrelin (hunger hormone) by 24% and cuts leptin (fullness hormone) by 18%. You wake up hungrier and need 300 extra calories to feel satisfied.

The Research Is Clear

A 2010 Annals of Internal Medicine study found that dieters sleeping 5.5 hours lost 55% less fat than those sleeping 8.5 hours — on the exact same diet. The difference was entirely due to sleep.

How Poor Sleep Sabotages Weight Loss

1. Increased cravings for sugary, high-fat foods (prefrontal cortex impaired)
2. Higher cortisol levels promoting belly fat storage
3. Reduced motivation to exercise
4. Impaired muscle recovery after workouts
5. Slower metabolism — your body conserves energy when tired

Your Sleep Action Plan

Set a consistent bedtime alarm. No screens 30 minutes before bed. Keep your room at 18-20°C. No caffeine after 2 PM. Use the FitQuest bedtime reminder to build this habit. Treat sleep as a non-negotiable part of your fitness programme.',
         ''[{"question":"How much less fat did sleep-deprived dieters lose in the study?","options":["10% less","25% less","55% less","No difference"],"correct":2,"explanation":"Dieters sleeping 5.5 hours lost 55% less fat than those sleeping 8.5 hours on the exact same diet."},{"question":"What happens to hunger hormones with poor sleep?","options":["Both increase","Both decrease","Ghrelin rises, leptin falls","Ghrelin falls, leptin rises"],"correct":2,"explanation":"Sleep deprivation raises ghrelin (hunger) by 24% and lowers leptin (fullness) by 18%, making you hungrier."}]''::jsonb),

        (5,'Strength','Why muscle burns fat while you sleep','article',30,'locked','Coach Priya',5,
         'One kilogram of muscle burns an extra 13 kcal per day at rest. Add 3 kg of muscle — common in 12 weeks of consistent training — and you burn 39 extra kcal/day effortlessly, even while sleeping.

Muscle as a Glucose Sink

Muscle tissue absorbs blood sugar rapidly, reducing insulin spikes after meals. More muscle means better blood sugar control, fewer cravings, and less fat storage. This is why strength training is essential for weight loss.

You Don''t Need a Gym

Three 20-minute bodyweight sessions per week are enough to build meaningful metabolic muscle. Start with these four exercises: squats (3×10), push-ups (3×8), lunges (2×8 per leg), and planks (3×20 seconds). Progress by adding 2 reps per week.

The Afterburn Effect

Strength training creates an "afterburn" — your metabolism stays elevated for 24-48 hours post-workout as your body repairs muscle fibres. A single bodyweight session can burn an extra 100 calories through this effect alone.',
         ''[{"question":"How many extra calories does 1 kg of muscle burn per day at rest?","options":["3 kcal","13 kcal","30 kcal","100 kcal"],"correct":1,"explanation":"Each kilogram of muscle burns approximately 13 extra kcal per day at rest, adding up significantly over time."},{"question":"What is the afterburn effect?","options":["Burning calories while sleeping","Elevated metabolism for 24-48 hours after strength training","A type of cardio exercise","Eating after a workout"],"correct":1,"explanation":"After strength training, your metabolism stays elevated for 24-48 hours as your body repairs muscle fibres."}]''::jsonb),

        (6,'Mindful Eating','Breaking emotional eating cycles','article',40,'locked','Dr. Roy',6,
         'Emotional eating is triggered by stress, boredom, or loneliness — not true hunger. Learning to tell the difference is one of the most powerful skills for lasting weight loss.

The H.A.L.T. Method

Before eating, ask: Am I Hungry, Angry, Lonely, or Tired? True hunger builds slowly and any food sounds good. Emotional hunger is sudden, craves specific comfort foods, and doesn''t go away after eating.

The 10-Minute Rule

When a craving hits, set a 10-minute timer and drink a glass of water. Research shows 70% of cravings pass in that window. For the other 30%, choose a small satisfying portion and eat it mindfully without screens.

Building Your Craving Toolkit

Replace emotional eating with alternative responses: stressed → 5-minute box breathing. Bored → take a short walk or call a friend. Lonely → post in your FitQuest group. Tired → take a 20-minute nap instead of reaching for sugar. The craving is real — but food isn''t always the answer.',
         ''[{"question":"What does H.A.L.T. stand for?","options":["Happy, Active, Lively, Thankful","Hungry, Angry, Lonely, Tired","Healthy, Aware, Light, Trim","None of the above"],"correct":1,"explanation":"H.A.L.T. helps you identify whether you are truly Hungry, or just Angry, Lonely, or Tired — emotional states that mimic hunger."},{"question":"What percentage of cravings pass within 10 minutes?","options":["30%","50%","70%","100%"],"correct":2,"explanation":"Research shows that 70% of food cravings pass within a 10-minute window if you delay and drink water."}]''::jsonb),

        (7,'Hydration','Water, metabolism & fat burning','article',30,'locked','Coach Priya',5,
         'Your liver converts stored fat into usable energy — but only when it is not busy doing the kidneys'' job. Dehydration forces the liver to step in, slowing fat metabolism by up to 30%.

The Metabolic Boost

Drinking 500 ml of cold water raises metabolic rate by 24-30% for 60 minutes (Journal of Clinical Endocrinology, 2003). Over a day, drinking 2 litres of extra water burns roughly 100 additional calories.

Your Personal Water Target

Target 35 ml per kg of body weight daily. For a 70 kg person: 2.45 litres — roughly 8-9 glasses. Spread intake throughout the day rather than chugging large amounts at once.

Practical Hydration Habits

Start each morning with 500 ml before tea or coffee. Drink a full glass before every meal — this also reduces calorie intake by 75 calories per meal. Keep a water bottle visible on your desk. Use the FitQuest hydration tracker to build the habit. If plain water bores you, add lemon, cucumber, or mint.',
         ''[{"question":"By how much does dehydration slow fat metabolism?","options":["5%","15%","30%","50%"],"correct":2,"explanation":"When dehydrated, the liver takes over kidney functions, slowing fat metabolism by up to 30%."},{"question":"How much does 500 ml of cold water boost metabolic rate?","options":["5-10%","12-15%","24-30%","50%"],"correct":2,"explanation":"Research published in the Journal of Clinical Endocrinology found 500 ml of cold water raises metabolic rate by 24-30% for 60 minutes."}]''::jsonb),

        (8,'Stress & Cortisol','Stress, cortisol & belly fat','article',40,'locked','Dr. Roy',7,
         'Cortisol — the stress hormone — directly signals fat cells in your abdomen to store more fat. Chronic stress keeps cortisol elevated all day, creating a vicious cycle of belly fat accumulation.

The Cortisol-Fat Connection

Under stress, your body enters survival mode. Cortisol tells your body to store energy (as fat) in the most accessible location — your abdomen. This is why stressed people often gain belly fat even without eating more.

Three Evidence-Based Cortisol Reducers

1. Box breathing (inhale 4s, hold 4s, exhale 4s, hold 4s) — drops cortisol by 23% within 30 minutes
2. A 20-minute walk in nature — reduces cortisol by 21% (Frontiers in Psychology, 2019)
3. Laughing for 10 minutes — lowers cortisol by 37-70% (Loma Linda University)

Stress Management IS Fat Loss Strategy

You can eat perfectly and exercise daily, but if cortisol stays elevated, your body will resist losing belly fat. Prioritise one stress-reduction technique daily. The FitQuest evening reflection is designed to help you decompress before sleep.',
         ''[{"question":"Where does cortisol primarily direct fat storage?","options":["Arms and legs","Abdomen","Face","Evenly throughout the body"],"correct":1,"explanation":"Cortisol specifically signals fat cells in the abdomen to store more fat, which is why chronic stress leads to belly fat."},{"question":"How much does box breathing reduce cortisol?","options":["5%","23%","50%","It has no effect"],"correct":1,"explanation":"Box breathing (inhale 4s, hold 4s, exhale 4s, hold 4s) drops cortisol levels by 23% within 30 minutes."}]''::jsonb),

        (9,'Progress Tracking','Tracking without obsessing','article',30,'locked','Coach Priya',5,
         'The scale is one data point, not the whole picture. Weight fluctuates 1-2 kg daily from water, food volume, and hormones. The true signal is the 4-week trend, not yesterday''s number.

The Three Numbers That Matter

1. Weekly average weight — weigh daily but only look at the weekly average
2. Waist circumference — measure monthly; this catches fat loss the scale misses
3. How your reference outfit fits — pick one outfit and try it on every 2 weeks

Why Photo Comparisons Work

Take a progress photo every 4 weeks in the same outfit, same lighting, same pose. Photos reveal fat loss and body composition changes that the scale completely misses — especially when you''re building muscle while losing fat.

Tracking Without Anxiety

Log your data in FitQuest and let the app show you trends. Don''t react to single-day spikes. A good week followed by a 1 kg "gain" is usually water retention and resolves within 48 hours. Trust the process and focus on consistency, not daily fluctuations.',
         ''[{"question":"What is the best timeframe for evaluating weight loss trends?","options":["Daily","Every other day","4-week trends","6 months"],"correct":2,"explanation":"Weight fluctuates 1-2 kg daily from water and food volume. The true signal emerges over 4-week trends, not daily readings."},{"question":"Why do progress photos work better than the scale alone?","options":["Photos are more accurate than scales","Photos reveal body composition changes the scale misses","Photos motivate you to eat less","Photos replace the need for weighing"],"correct":1,"explanation":"Progress photos catch fat loss and muscle gain that the scale misses, especially during body recomposition."}]''::jsonb),

        (10,'Plateaus','Breaking through weight plateaus','article',40,'locked','Dr. Roy',6,
         'A weight plateau after 4+ weeks signals metabolic adaptation — your body has recalculated maintenance calories at your new lower weight. Plateaus are biology, not failure.

Why Plateaus Happen

As you lose weight, your body needs fewer calories to maintain itself. A person who lost 5 kg now burns roughly 150-200 fewer calories per day. Your previous deficit has become your new maintenance.

Three Evidence-Based Plateau Breakers

1. Add 2,000 steps per day — this alone can create a 100-calorie deficit
2. Increase protein to 1.6g per kg body weight — reduces muscle loss and boosts metabolism
3. Take a 1-week diet break at maintenance calories — this resets leptin and hunger hormones, making the next deficit phase more effective

What NOT to Do

Don''t slash calories dramatically — this triggers further metabolic slowdown. Don''t exercise excessively — this increases cortisol and water retention. Don''t panic — plateaus typically break within 1-3 weeks if you stay consistent with your habits.',
         ''[{"question":"What causes a weight loss plateau?","options":["Not exercising enough","Your body recalculates maintenance calories at your new lower weight","Eating too much protein","Drinking too much water"],"correct":1,"explanation":"As you lose weight, your body needs fewer calories. Your previous deficit becomes your new maintenance, causing the plateau."},{"question":"What is a diet break and why does it help?","options":["Stopping the diet permanently","Eating at maintenance for 1 week to reset hunger hormones","Fasting for a week","Eating whatever you want"],"correct":1,"explanation":"A 1-week diet break at maintenance calories resets leptin and hunger hormones, making the next deficit phase more effective."}]''::jsonb),

        (11,'Sustainable Habits','Eating out & social eating','article',30,'locked','Coach Priya',5,
         'Social events are the biggest compliance killer. But you don''t need to avoid them — you need strategies that work in the real world.

The Pre-Event Strategy

Eat a protein-rich snack 30 minutes before the event. Arriving not starving gives you the clarity to make conscious choices instead of grabbing the nearest samosa.

Restaurant Rules That Work

1. Order protein + salad or vegetables first
2. Use the "one-plate rule" — choose your plate thoughtfully, eat it slowly, and stop
3. Decide whether dessert is truly worth it before it arrives — not after you see the menu
4. Ask for dressing and sauces on the side

The Alcohol Truth

Each drink adds 100-150 empty calories AND lowers your inhibitions around food. Two drinks can easily add 500+ calories to your evening (alcohol + the extra food you eat because of it). Club soda with lime tastes social and costs zero calories.

The 80/20 Rule

Eat well 80% of the time. The other 20% is for life — birthdays, festivals, dinners out. This ratio sustains results without making you miserable.',
         ''[{"question":"Why should you eat a protein snack before social events?","options":["Protein tastes better","Arriving not starving helps you make conscious food choices","It cancels out party food calories","Protein prevents alcohol absorption"],"correct":1,"explanation":"A protein-rich snack before the event gives you clarity to choose consciously instead of grabbing whatever is available."},{"question":"How many extra calories can 2 alcoholic drinks add to an evening?","options":["50 calories","200 calories","500+ calories including extra food","No calories"],"correct":2,"explanation":"Two drinks add 200-300 calories directly, plus alcohol lowers food inhibitions, easily totalling 500+ extra calories."}]''::jsonb),

        (12,'Maintenance','Life after the programme','article',50,'locked','Dr. Roy',8,
         'Maintaining weight loss requires slightly fewer calories than maintaining your original weight — about 150-200 kcal/day less. Your new maintenance is your goal, and the habits you''ve built are your tools.

The Four Behaviours of Successful Maintainers

Research from the National Weight Control Registry (tracking 10,000+ people who kept weight off for 5+ years) found four common behaviours:
1. They weigh themselves regularly
2. They exercise daily (mostly walking)
3. They eat breakfast
4. They limit screen time during meals

You have practised all four during this programme.

Your Maintenance Toolkit

The habits that got you here are permanent now — not temporary tools. Daily check-ins, meal awareness, movement, and sleep hygiene. If weight creeps up by 2 kg, don''t panic — return to tracking for one week and the trend will reverse.

The Identity Shift

The most powerful change is invisible: you are now someone who takes care of their health. Protect that identity. One small daily action at a time. Congratulations on completing the FitQuest programme.',
         ''[{"question":"How many fewer daily calories does maintenance require compared to your original weight?","options":["50 kcal","150-200 kcal","500 kcal","No difference"],"correct":1,"explanation":"Maintaining a lower weight requires about 150-200 fewer daily calories than maintaining your original weight."},{"question":"What do successful weight maintainers have in common?","options":["They never eat carbs","They exercise 3 hours daily","They weigh regularly, exercise daily, eat breakfast, and limit screen time during meals","They follow strict diets forever"],"correct":2,"explanation":"The National Weight Control Registry found these four behaviours are shared by 10,000+ people who kept weight off long-term."}]''::jsonb)
      ON CONFLICT (week, title) DO UPDATE
        SET content = EXCLUDED.content,
            xp      = EXCLUDED.xp,
            minutes = EXCLUDED.minutes,
            week_name = EXCLUDED.week_name,
            author  = EXCLUDED.author,
            quiz_questions = COALESCE(EXCLUDED.quiz_questions, lessons.quiz_questions)
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
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || 'https://mhs-backend.vercel.app,http://localhost:8080,http://localhost:4000').split(',');
app.use(cors({
  origin: (origin, cb) => {
    // Allow requests with no origin (mobile apps, curl), localhost on any port, and whitelisted origins
    if (!origin || ALLOWED_ORIGINS.includes(origin) || /^https?:\/\/localhost(:\d+)?$/.test(origin)) return cb(null, true);
    cb(new Error('Not allowed by CORS'));
  },
  methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.options('*', cors());
app.use(express.json({ limit: '12mb' }));

// Serve uploaded files (videos, images) as static assets
const __dirname = path.dirname(fileURLToPath(import.meta.url));
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

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
  const isDev = process.env.NODE_ENV !== 'production';
  res.status(500).json({ message: isDev ? err.message : 'Internal server error' });
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

// User-configured reminders — check every 15 minutes
cron.schedule('*/15 * * * *', async () => {
  try {
    const { pool } = await import('./db.js');
    const client = await pool.connect();
    const now = new Date();
    const hh = String(now.getHours()).padStart(2, '0');
    const mm = String(Math.floor(now.getMinutes() / 15) * 15).padStart(2, '0');
    const timeSlot = `${hh}:${mm}`;
    // Also check the previous slot in case cron was slightly delayed
    const prevMin = (Math.floor(now.getMinutes() / 15) * 15) - 15;
    const prevHH = prevMin < 0 ? String((now.getHours() - 1 + 24) % 24).padStart(2, '0') : hh;
    const prevMM = String((prevMin + 60) % 60).padStart(2, '0');
    const prevSlot = `${prevHH}:${prevMM}`;

    const reminders = (await client.query(
      `SELECT r.*, u.name FROM user_reminders r JOIN users u ON u.id=r.user_id
       WHERE r.enabled=TRUE AND (r.time=$1 OR r.time=$2)`,
      [timeSlot, prevSlot]
    )).rows;

    const messages = {
      water: { title: 'Hydration Reminder', body: 'Time to drink a glass of water! Stay hydrated.' },
      meal: { title: 'Meal Reminder', body: 'Don\'t forget to log your meal!' },
      weighin: { title: 'Weigh-in Reminder', body: 'Time for your daily weigh-in. Track your progress!' },
      fasting: { title: 'Fasting Reminder', body: 'Check your fasting window status!' },
      steps: { title: 'Movement Reminder', body: 'Time to get moving! Log your steps.' },
    };

    const today = new Date().toISOString().slice(0, 10);
    for (const r of reminders) {
      const msg = messages[r.type] || { title: 'FitQuest Reminder', body: 'Time for your health check!' };
      // Avoid duplicate notifications for same type today
      const existing = (await client.query(
        `SELECT id FROM notifications WHERE user_id=$1 AND type=$2 AND created_at::date=$3`,
        [r.user_id, `reminder_${r.type}`, today]
      )).rows[0];
      if (!existing) {
        await client.query(
          `INSERT INTO notifications (user_id,type,title,body) VALUES ($1,$2,$3,$4)`,
          [r.user_id, `reminder_${r.type}`, msg.title, msg.body]
        ).catch(() => {});
        sendPush(r.user_id, msg.title, msg.body).catch(() => {});
      }
    }
    client.release();
  } catch(e) { console.warn('[cron] Reminder error:', e.message); }
});

// Evening reminder: 6pm — nudge users who haven't completed all tasks today
cron.schedule('0 18 * * *', async () => {
  console.log('[cron] Evening reminder check...');
  try {
    const today = new Date().toISOString().slice(0, 10);
    const { pool } = await import('./db.js');
    const client = await pool.connect();
    const incomplete = (await client.query(
      `SELECT u.id, u.name,
              COUNT(t.id) FILTER (WHERE t.done = FALSE) AS remaining
       FROM users u
       JOIN tasks t ON t.user_id = u.id AND t.day::date = $1
       WHERE u.role='user'
       GROUP BY u.id, u.name
       HAVING COUNT(t.id) FILTER (WHERE t.done = FALSE) > 0`,
      [today]
    )).rows;
    for (const u of incomplete) {
      const existing = (await client.query(
        `SELECT id FROM notifications WHERE user_id=$1 AND type='evening_reminder' AND created_at::date=$2`,
        [u.id, today]
      )).rows[0];
      if (!existing) {
        const title = 'You still have tasks left today!';
        const body = 'Complete them before bed to keep your streak alive!';
        await client.query(
          `INSERT INTO notifications (user_id,type,title,body) VALUES ($1,'evening_reminder',$2,$3)`,
          [u.id, title, body]
        ).catch(() => {});
        sendPush(u.id, title, body).catch(() => {});
      }
    }
    client.release();
    console.log(`[cron] Evening reminders sent to ${incomplete.length} users`);
  } catch(e) { console.warn('[cron] Evening reminder error:', e.message); }
});

// Daily goals summary: 9pm — send progress summary to all active users
cron.schedule('0 21 * * *', async () => {
  console.log('[cron] Daily goals summary...');
  try {
    const today = new Date().toISOString().slice(0, 10);
    const { pool } = await import('./db.js');
    const client = await pool.connect();
    const summaries = (await client.query(
      `SELECT u.id, u.name,
              COUNT(t.id) AS total,
              COUNT(t.id) FILTER (WHERE t.done = TRUE) AS done
       FROM users u
       JOIN tasks t ON t.user_id = u.id AND t.day::date = $1
       WHERE u.role='user'
       GROUP BY u.id, u.name`,
      [today]
    )).rows;
    for (const u of summaries) {
      const existing = (await client.query(
        `SELECT id FROM notifications WHERE user_id=$1 AND type='daily_summary' AND created_at::date=$2`,
        [u.id, today]
      )).rows[0];
      if (!existing) {
        const allDone = Number(u.done) >= Number(u.total);
        const title = allDone
          ? 'Perfect day! All tasks completed!'
          : `You've completed ${u.done}/${u.total} tasks today`;
        const body = allDone
          ? 'Amazing work! Keep up the momentum tomorrow!'
          : 'Finish strong — there\'s still time!';
        await client.query(
          `INSERT INTO notifications (user_id,type,title,body) VALUES ($1,'daily_summary',$2,$3)`,
          [u.id, title, body]
        ).catch(() => {});
        sendPush(u.id, title, body).catch(() => {});
      }
    }
    client.release();
    console.log(`[cron] Daily summaries sent to ${summaries.length} users`);
  } catch(e) { console.warn('[cron] Daily summary error:', e.message); }
});

const port = process.env.PORT || 4000;
if (process.env.VERCEL !== '1') {
  app.listen(port, () => console.log(`🚀 FitQuest API on http://localhost:${port}`));
}

export default app;
