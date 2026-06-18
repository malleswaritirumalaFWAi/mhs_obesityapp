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
    ];

    for (const sql of migrations) {
      await client.query(sql).catch(e => console.warn('  Migration skip:', e.message.slice(0, 100)));
    }

    // Seed reference data
    await client.query(`
      INSERT INTO badges (code, emoji, name, xp) VALUES
        ('first_step','👣','First Step',0),('snapshot','📸','Snapshot',0),
        ('baseline','⚖️','Baseline',0),('team_player','🤝','Team Player',0),
        ('streak_3','✨','Spark',50),('streak_7','🔥','Flame',100),
        ('streak_14','🔥','Blaze',200),('streak_30','🌋','Inferno',500),
        ('streak_60','💥','Unstoppable',1000),('freeze_master','❄️','Freeze Master',100),
        ('comeback_kid','💪','Comeback Kid',100),('first_bite','🍽️','First Bite',0),
        ('first_post','📝','First Post',0),('weekly_champ','🥇','Weekly Champ',500),
        ('recruiter','🎁','Recruiter',300),('goal_crusher','🏆','Goal Crusher',1000),
        ('graduate','🎓','Graduate',1000),('streak_master','🔥','Streak Master',500),
        ('fasting_pro','⏰','Fasting Pro',300),('royal_champion','👑','Royal Champion',2000)
      ON CONFLICT (code) DO NOTHING
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

    const lessonCount = (await client.query('SELECT COUNT(*) FROM lessons')).rows[0].count;
    if (Number(lessonCount) === 0) {
      await client.query(`
        INSERT INTO lessons (week, week_name, title, lesson_type, xp, status, author, minutes, content) VALUES
          (1,'Foundation','Why small habits beat willpower','article',30,'completed','Dr. Roy',5,'Willpower is finite but tiny habits compound. The FitQuest system replaces effort with routine.'),
          (1,'Foundation','The FitQuest method','video',30,'completed','Dr. Roy',7,'A 3-pillar approach: move daily, eat intentionally, sleep deeply. Small wins create momentum.'),
          (1,'Foundation','Foundation quiz','quiz',50,'completed',NULL,3,NULL),
          (2,'Nutrition basics','Reading your plate','article',30,'completed','Dr. Roy',5,'Half plate vegetables, quarter protein, quarter complex carbs. This ratio fits any Indian meal.'),
          (2,'Nutrition basics','Indian foods for weight loss','video',30,'completed','Dr. Roy',8,'Dal, sabzi, curd, roti — the Indian diet is naturally weight-loss friendly when portioned right.'),
          (2,'Nutrition basics','Nutrition quiz','quiz',50,'completed',NULL,3,NULL),
          (3,'Power of walking','Science of 10,000 steps','article',30,'completed','Dr. Roy',5,'Daily walking improves insulin sensitivity and burns 300-400 extra calories without the gym.'),
          (3,'Power of walking','Why 8K steps changes everything','article',50,'active','Dr. Roy',5,'Research: 8,000 steps/day cuts all-cause mortality by 51%. The gym is optional. Walking is not.'),
          (3,'Power of walking','Why sleep matters','video',30,'locked','Dr. Roy',5,'Sleep deprivation raises ghrelin (hunger hormone) 24% and cuts fat loss by 55%. Sleep is training.'),
          (4,'Sleep & recovery','Quick quiz','quiz',100,'locked',NULL,3,NULL),
          (4,'Sleep & recovery','Sleep cycles explained','article',30,'locked','Dr. Roy',5,NULL),
          (4,'Sleep & recovery','Recovery for fat loss','video',30,'locked','Dr. Roy',6,NULL),
          (5,'Strength habits','Why muscle burns fat','article',30,'locked','Dr. Roy',5,NULL),
          (5,'Strength habits','Bodyweight basics','video',30,'locked','Dr. Roy',8,NULL),
          (5,'Strength habits','Strength quiz','quiz',50,'locked',NULL,3,NULL)
      `).catch(e => console.warn('Lessons seed error:', e.message));
    }

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
      await client.query(
        `INSERT INTO notifications (user_id,type,title,body) VALUES ($1,'morning_nudge','Good morning, ${u.name?.split(' ')[0] || 'there'}!','${msg}')`,
        [u.id]
      ).catch(() => {});
    }
    client.release();
    console.log(`[cron] Morning nudge sent to ${users.length} users`);
  } catch(e) { console.warn('[cron] Morning nudge error:', e.message); }
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
        await client.query(
          `INSERT INTO notifications (user_id,type,title,body) VALUES ($1,'streak_risk','Your ${u.streak}-day streak is at risk!','Complete at least one task before midnight to keep your streak alive!')`,
          [u.id]
        ).catch(() => {});
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
