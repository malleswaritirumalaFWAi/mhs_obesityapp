-- FitQuest schema (PostgreSQL) — v2 with all features

CREATE TABLE IF NOT EXISTS users (
  id            BIGSERIAL PRIMARY KEY,
  phone         TEXT UNIQUE NOT NULL,
  name          TEXT,
  email         TEXT UNIQUE,
  password_hash TEXT,
  onboarded     BOOLEAN NOT NULL DEFAULT FALSE,
  xp            INTEGER NOT NULL DEFAULT 0,
  total_xp      INTEGER NOT NULL DEFAULT 0,
  streak        INTEGER NOT NULL DEFAULT 0,
  start_weight  NUMERIC(5,1),
  target_weight NUMERIC(5,1),
  height        NUMERIC(5,1),
  language      TEXT NOT NULL DEFAULT 'en',
  referral_code TEXT UNIQUE,
  level         TEXT NOT NULL DEFAULT 'bronze',
  streak_freezes INTEGER NOT NULL DEFAULT 0,
  role          TEXT NOT NULL DEFAULT 'user',
  fcm_token     TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT UNIQUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS height NUMERIC(5,1);
ALTER TABLE users ADD COLUMN IF NOT EXISTS language TEXT NOT NULL DEFAULT 'en';
ALTER TABLE users ADD COLUMN IF NOT EXISTS referral_code TEXT UNIQUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS level TEXT NOT NULL DEFAULT 'bronze';
ALTER TABLE users ADD COLUMN IF NOT EXISTS streak_freezes INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user';
ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS total_xp INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS otps (
  phone      TEXT PRIMARY KEY,
  code       TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS profiles (
  user_id                     BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  gender                      TEXT,
  activity                    TEXT,
  goal                        TEXT,
  food_pref                   TEXT,
  challenge                   TEXT,
  medical_conditions          TEXT,
  medications                 TEXT,
  dpdp_consent                BOOLEAN NOT NULL DEFAULT FALSE,
  medical_disclaimer_accepted BOOLEAN NOT NULL DEFAULT FALSE,
  language                    TEXT NOT NULL DEFAULT 'en'
);

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS medical_conditions TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS medications TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS dpdp_consent BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS medical_disclaimer_accepted BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS language TEXT NOT NULL DEFAULT 'en';

CREATE TABLE IF NOT EXISTS coaches (
  id             BIGSERIAL PRIMARY KEY,
  name           TEXT NOT NULL,
  title          TEXT,
  rating         NUMERIC(2,1),
  avatar         TEXT,
  user_id        BIGINT REFERENCES users(id),
  phone          TEXT,
  specialization TEXT
);

ALTER TABLE coaches ADD COLUMN IF NOT EXISTS user_id BIGINT REFERENCES users(id);
ALTER TABLE coaches ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE coaches ADD COLUMN IF NOT EXISTS specialization TEXT;

CREATE TABLE IF NOT EXISTS groups (
  id         BIGSERIAL PRIMARY KEY,
  name       TEXT NOT NULL,
  coach_id   BIGINT REFERENCES coaches(id),
  starts_on  DATE
);

CREATE TABLE IF NOT EXISTS group_members (
  group_id  BIGINT REFERENCES groups(id) ON DELETE CASCADE,
  user_id   BIGINT REFERENCES users(id) ON DELETE CASCADE,
  weekly_xp INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (group_id, user_id)
);

CREATE TABLE IF NOT EXISTS payments (
  id          BIGSERIAL PRIMARY KEY,
  user_id     BIGINT REFERENCES users(id) ON DELETE CASCADE,
  plan        TEXT NOT NULL,
  amount      INTEGER NOT NULL,
  order_id    TEXT,
  payment_id  TEXT,
  status      TEXT NOT NULL DEFAULT 'created',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tasks (
  id           BIGSERIAL PRIMARY KEY,
  user_id      BIGINT REFERENCES users(id) ON DELETE CASCADE,
  day_index    INTEGER NOT NULL,
  slot         TEXT NOT NULL,
  time         TEXT,
  icon         TEXT,
  title        TEXT NOT NULL,
  subtitle     TEXT,
  xp           INTEGER NOT NULL DEFAULT 0,
  done         BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at TIMESTAMPTZ
);
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS checkins (
  id         BIGSERIAL PRIMARY KEY,
  user_id    BIGINT REFERENCES users(id) ON DELETE CASCADE,
  mood       INTEGER,
  weight     NUMERIC(5,1),
  notes      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS meals (
  id             BIGSERIAL PRIMARY KEY,
  user_id        BIGINT REFERENCES users(id) ON DELETE CASCADE,
  meal_type      TEXT,
  items          JSONB,
  calories       INTEGER,
  carbs          INTEGER,
  protein        INTEGER,
  fat            INTEGER,
  photo_url      TEXT,
  coach_feedback TEXT,
  coach_approved BOOLEAN,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE meals ADD COLUMN IF NOT EXISTS photo_url      TEXT;
ALTER TABLE meals ADD COLUMN IF NOT EXISTS coach_feedback TEXT;
ALTER TABLE meals ADD COLUMN IF NOT EXISTS coach_approved BOOLEAN;

CREATE TABLE IF NOT EXISTS posts (
  id         BIGSERIAL PRIMARY KEY,
  group_id   BIGINT REFERENCES groups(id) ON DELETE CASCADE,
  user_id    BIGINT REFERENCES users(id) ON DELETE CASCADE,
  body       TEXT,
  emoji      TEXT,
  image_url  TEXT,
  post_type  TEXT NOT NULL DEFAULT 'text',
  coach_pick BOOLEAN NOT NULL DEFAULT FALSE,
  likes      INTEGER NOT NULL DEFAULT 0,
  fires      INTEGER NOT NULL DEFAULT 0,
  comments   INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE posts ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS post_type TEXT NOT NULL DEFAULT 'text';

CREATE TABLE IF NOT EXISTS post_comments (
  id         BIGSERIAL PRIMARY KEY,
  post_id    BIGINT REFERENCES posts(id) ON DELETE CASCADE,
  user_id    BIGINT REFERENCES users(id) ON DELETE CASCADE,
  body       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS badges (
  id     BIGSERIAL PRIMARY KEY,
  code   TEXT UNIQUE NOT NULL,
  emoji  TEXT,
  name   TEXT,
  xp     INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS user_badges (
  user_id    BIGINT REFERENCES users(id) ON DELETE CASCADE,
  badge_id   BIGINT REFERENCES badges(id) ON DELETE CASCADE,
  earned_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, badge_id)
);

CREATE TABLE IF NOT EXISTS lessons (
  id             BIGSERIAL PRIMARY KEY,
  week           INTEGER NOT NULL,
  title          TEXT NOT NULL,
  author         TEXT,
  minutes        INTEGER,
  xp             INTEGER NOT NULL DEFAULT 0,
  status         TEXT NOT NULL DEFAULT 'locked',
  video_url      TEXT,
  content        TEXT,
  quiz_questions JSONB,
  lesson_type    TEXT NOT NULL DEFAULT 'article'
);

ALTER TABLE lessons ADD COLUMN IF NOT EXISTS video_url      TEXT;
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS content        TEXT;
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS quiz_questions JSONB;
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS lesson_type    TEXT NOT NULL DEFAULT 'article';

CREATE TABLE IF NOT EXISTS chat_messages (
  id         BIGSERIAL PRIMARY KEY,
  user_id    BIGINT REFERENCES users(id) ON DELETE CASCADE,
  from_coach BOOLEAN NOT NULL DEFAULT FALSE,
  text       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS daily_stats (
  user_id  BIGINT REFERENCES users(id) ON DELETE CASCADE,
  date     DATE NOT NULL DEFAULT CURRENT_DATE,
  steps    INTEGER NOT NULL DEFAULT 0,
  water    INTEGER NOT NULL DEFAULT 0,
  sleep    NUMERIC(3,1) NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, date)
);

ALTER TABLE daily_stats ADD COLUMN IF NOT EXISTS steps   INTEGER      NOT NULL DEFAULT 0;
ALTER TABLE daily_stats ADD COLUMN IF NOT EXISTS water   INTEGER      NOT NULL DEFAULT 0;
ALTER TABLE daily_stats ADD COLUMN IF NOT EXISTS sleep   NUMERIC(3,1) NOT NULL DEFAULT 0;

-- ── NEW TABLES ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS body_measurements (
  id         BIGSERIAL PRIMARY KEY,
  user_id    BIGINT REFERENCES users(id) ON DELETE CASCADE,
  waist      NUMERIC(5,1),
  hips       NUMERIC(5,1),
  chest      NUMERIC(5,1),
  arms       NUMERIC(5,1),
  weight     NUMERIC(5,1),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS fasting_sessions (
  id           BIGSERIAL PRIMARY KEY,
  user_id      BIGINT REFERENCES users(id) ON DELETE CASCADE,
  started_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at     TIMESTAMPTZ,
  target_hours INTEGER NOT NULL DEFAULT 16,
  completed    BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS diet_plans (
  id           BIGSERIAL PRIMARY KEY,
  user_id      BIGINT REFERENCES users(id) ON DELETE CASCADE,
  coach_id     BIGINT REFERENCES coaches(id),
  week_number  INTEGER NOT NULL DEFAULT 1,
  title        TEXT,
  meals        JSONB,
  grocery_list JSONB,
  notes        TEXT,
  ai_generated BOOLEAN NOT NULL DEFAULT FALSE,
  status       TEXT NOT NULL DEFAULT 'active',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS reflections (
  id         BIGSERIAL PRIMARY KEY,
  user_id    BIGINT REFERENCES users(id) ON DELETE CASCADE,
  type       TEXT NOT NULL DEFAULT 'evening',
  text       TEXT,
  mood       INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS progress_photos (
  id         BIGSERIAL PRIMARY KEY,
  user_id    BIGINT REFERENCES users(id) ON DELETE CASCADE,
  photo_url  TEXT NOT NULL,
  label      TEXT,
  week       INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS referrals (
  id           BIGSERIAL PRIMARY KEY,
  referrer_id  BIGINT REFERENCES users(id) ON DELETE CASCADE,
  referred_id  BIGINT REFERENCES users(id) ON DELETE CASCADE,
  status       TEXT NOT NULL DEFAULT 'pending',
  reward_given BOOLEAN NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(referrer_id, referred_id)
);

CREATE TABLE IF NOT EXISTS group_chat_messages (
  id         BIGSERIAL PRIMARY KEY,
  group_id   BIGINT REFERENCES groups(id) ON DELETE CASCADE,
  user_id    BIGINT REFERENCES users(id) ON DELETE CASCADE,
  text       TEXT NOT NULL,
  type       TEXT NOT NULL DEFAULT 'user',
  pinned     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notifications (
  id         BIGSERIAL PRIMARY KEY,
  user_id    BIGINT REFERENCES users(id) ON DELETE CASCADE,
  type       TEXT NOT NULL,
  title      TEXT NOT NULL,
  body       TEXT NOT NULL,
  read       BOOLEAN NOT NULL DEFAULT FALSE,
  data       JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS weekly_winners (
  id           BIGSERIAL PRIMARY KEY,
  group_id     BIGINT REFERENCES groups(id),
  week_start   DATE NOT NULL,
  user_id      BIGINT REFERENCES users(id),
  rank         INTEGER NOT NULL,
  weekly_xp    INTEGER NOT NULL,
  prize_amount INTEGER,
  prize_status TEXT NOT NULL DEFAULT 'pending',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(group_id, week_start, rank)
);

CREATE TABLE IF NOT EXISTS weekly_challenges (
  id          BIGSERIAL PRIMARY KEY,
  week_number INTEGER NOT NULL,
  title       TEXT NOT NULL,
  description TEXT,
  type        TEXT NOT NULL DEFAULT 'steps',
  target      INTEGER NOT NULL,
  xp_reward   INTEGER NOT NULL DEFAULT 40,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS challenge_entries (
  id           BIGSERIAL PRIMARY KEY,
  user_id      BIGINT REFERENCES users(id) ON DELETE CASCADE,
  challenge_id BIGINT REFERENCES weekly_challenges(id),
  progress     INTEGER NOT NULL DEFAULT 0,
  completed    BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, challenge_id)
);

CREATE TABLE IF NOT EXISTS streak_freeze_log (
  id         BIGSERIAL PRIMARY KEY,
  user_id    BIGINT REFERENCES users(id) ON DELETE CASCADE,
  type       TEXT NOT NULL DEFAULT 'earned',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS habit_completions (
  user_id    BIGINT REFERENCES users(id) ON DELETE CASCADE,
  habit_type TEXT NOT NULL,
  date       DATE NOT NULL DEFAULT CURRENT_DATE,
  completed  BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (user_id, habit_type, date)
);

CREATE TABLE IF NOT EXISTS recipes (
  id           BIGSERIAL PRIMARY KEY,
  title        TEXT NOT NULL,
  cuisine      TEXT,
  diet_type    TEXT,
  calories     INTEGER,
  prep_minutes INTEGER,
  ingredients  JSONB,
  steps        JSONB,
  image_url    TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS exercises (
  id           BIGSERIAL PRIMARY KEY,
  title        TEXT NOT NULL,
  category     TEXT,
  level        TEXT NOT NULL DEFAULT 'beginner',
  duration_min INTEGER,
  calories_est INTEGER,
  instructions JSONB,
  video_url    TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS data_requests (
  id         BIGSERIAL PRIMARY KEY,
  user_id    BIGINT REFERENCES users(id) ON DELETE CASCADE,
  type       TEXT NOT NULL DEFAULT 'export',
  status     TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS weekly_reset_log (
  id         BIGSERIAL PRIMARY KEY,
  reset_date DATE NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed default badges
INSERT INTO badges (code, emoji, name, xp) VALUES
  ('first_step',      '👣', 'First Step',        0),
  ('snapshot',        '📸', 'Snapshot',          0),
  ('baseline',        '⚖️',  'Baseline',          0),
  ('team_player',     '🤝', 'Team Player',       0),
  ('streak_3',        '✨', 'Spark',             50),
  ('streak_7',        '🔥', 'Flame',            100),
  ('streak_14',       '🔥', 'Blaze',            200),
  ('streak_30',       '🌋', 'Inferno',          500),
  ('streak_60',       '💥', 'Unstoppable',     1000),
  ('freeze_master',   '❄️',  'Freeze Master',   100),
  ('comeback_kid',    '💪', 'Comeback Kid',    100),
  ('first_bite',      '🍽️',  'First Bite',        0),
  ('shutterbug',      '📷', 'Shutterbug',       50),
  ('foodie_photo',    '📸', 'Foodie Photographer', 100),
  ('clean_eater',     '🥗', 'Clean Eater',     200),
  ('early_riser',     '🌅', 'Early Riser',     100),
  ('green_machine',   '🥦', 'Green Machine',    50),
  ('hydrated',        '💧', 'Hydrated',        100),
  ('first_steps',     '👟', 'First Steps',       0),
  ('walker_50k',      '🚶', 'Walker',          100),
  ('runner_200k',     '🏃', 'Runner',          500),
  ('yogi',            '🧘', 'Yogi',            200),
  ('gym_rat',         '🏋️',  'Gym Rat',         300),
  ('iron_will',       '🦾', 'Iron Will',       400),
  ('first_drop',      '⚖️',  'First Drop',        0),
  ('halfway_there',   '🎯', 'Halfway There',   300),
  ('almost_there',    '🏁', 'Almost There',    500),
  ('goal_crusher',    '🏆', 'Goal Crusher',   1000),
  ('consistent_loser','📉', 'Consistent Loser', 200),
  ('bmi_buster',      '💫', 'BMI Buster',      300),
  ('first_post',      '📝', 'First Post',        0),
  ('conversationalist','💬','Conversationalist', 50),
  ('beloved',         '❤️',  'Beloved',         100),
  ('influencer',      '⭐', 'Influencer',      200),
  ('supporter',       '🤗', 'Supporter',        50),
  ('cheerleader',     '📣', 'Cheerleader',     100),
  ('student',         '📚', 'Student',           0),
  ('scholar',         '🎓', 'Scholar',         200),
  ('binge_watcher',   '🎬', 'Binge Watcher',   300),
  ('quiz_master',     '🧠', 'Quiz Master',     200),
  ('nutrition_nerd',  '🔬', 'Nutrition Nerd',  300),
  ('weekly_champ',    '🥇', 'Weekly Champ',    500),
  ('silver_streak',   '🥈', 'Silver Streak',   300),
  ('consistent_contender','🎖️','Consistent Contender', 200),
  ('royal_champion',  '👑', 'Royal Champion', 2000),
  ('podium_finish',   '🏅', 'Podium Finish',  3000),
  ('night_owl_reform','🦉', 'Night Owl Reform', 200),
  ('fasting_pro',     '⏰', 'Fasting Pro',     300),
  ('mid_point_marvel','🌟', 'Mid-Point Marvel', 500),
  ('level_up',        '⬆️',  'Level Up',        200),
  ('recruiter',       '🎁', 'Recruiter',       300),
  ('tech_connected',  '📱', 'Tech Connected',  100),
  ('graduate',        '🎓', 'Graduate',       1000),
  ('diamond_member',  '💎', 'Diamond Member', 2000),
  ('streak_master',   '🔥', 'Streak Master',   500)
ON CONFLICT (code) DO NOTHING;

-- Seed weekly challenges (weeks 1-12)
INSERT INTO weekly_challenges (week_number, title, description, type, target, xp_reward) VALUES
  (1,  'Step Starter',     'Hit 8,000 steps/day for 3 days',   'steps',  3,  40),
  (2,  'Sleep Champion',   'Log 7+ hours of sleep 5 days',     'sleep',  5,  40),
  (3,  'Step Warrior',     'Hit 10,000 steps in a single day', 'steps',  10000, 60),
  (4,  'Meal Mastery',     'Log all 4 meals for 5 days',       'meals',  5,  40),
  (5,  'Workout Week',     'Complete daily exercise 5 days',   'tasks',  5,  50),
  (6,  'Fasting Focus',    'Complete 5 fasting windows',       'fasting',5,  50),
  (7,  'Yoga Challenge',   'Log 10+ min yoga 3 days',          'tasks',  3,  40),
  (8,  'Midpoint Madness', 'Perfect day 3 days in a row',      'tasks',  3,  80),
  (9,  'Hydration Hero',   'Hit 8 glasses every day for 5 days','water', 5,  40),
  (10, 'Step Master',      'Accumulate 60,000 steps this week','steps',  60000, 60),
  (11, 'Streak Keeper',    'Maintain streak all 7 days',       'streak', 7,  50),
  (12, 'Grand Finale',     'Complete all tasks for 5 days',    'tasks',  5,  100)
ON CONFLICT DO NOTHING;

-- Seed recipes
INSERT INTO recipes (title, cuisine, diet_type, calories, prep_minutes, ingredients, steps) VALUES
  ('Masala Oats', 'north_indian', 'veg', 280, 10,
   '["1 cup oats","1 onion","1 tomato","½ tsp cumin","salt","coriander"]',
   '["Sauté onion & spices","Add tomato","Add oats & water","Cook 5 min"]'),
  ('Dal Tadka', 'north_indian', 'veg', 320, 20,
   '["1 cup toor dal","2 tomatoes","garlic","cumin","turmeric","ghee"]',
   '["Pressure cook dal","Make tadka with garlic & cumin","Combine & serve"]'),
  ('Idli Sambar', 'south_indian', 'veg', 250, 30,
   '["2 cups idli batter","1 cup toor dal","vegetables","sambar powder"]',
   '["Steam idlis","Cook sambar with dal & vegetables","Serve hot"]'),
  ('Chicken Salad', 'continental', 'nonveg', 350, 15,
   '["200g grilled chicken","mixed greens","cherry tomatoes","olive oil","lemon"]',
   '["Grill chicken","Toss salad ingredients","Drizzle dressing"]'),
  ('Paneer Bhurji', 'north_indian', 'veg', 380, 15,
   '["200g paneer","1 onion","2 tomatoes","spices","coriander"]',
   '["Sauté onion","Add spices & tomato","Crumble paneer","Cook 5 min"]'),
  ('Ragi Porridge', 'south_indian', 'veg', 220, 10,
   '["3 tbsp ragi flour","1.5 cups milk","jaggery","cardamom"]',
   '["Mix ragi in cold milk","Heat stirring continuously","Add jaggery & cardamom"]'),
  ('Sprout Salad', 'north_indian', 'veg', 180, 5,
   '["1 cup mixed sprouts","cucumber","tomato","lemon","chaat masala"]',
   '["Mix all ingredients","Season with lemon & chaat masala"]'),
  ('Egg White Omelette', 'continental', 'nonveg', 150, 8,
   '["4 egg whites","spinach","mushrooms","salt","pepper"]',
   '["Whisk egg whites","Sauté vegetables","Cook omelette on low heat"]')
ON CONFLICT DO NOTHING;

-- Seed exercises
INSERT INTO exercises (title, category, level, duration_min, calories_est, instructions) VALUES
  ('Brisk Walk', 'cardio', 'beginner', 30, 150,
   '["Walk at 5-6 km/h pace","Keep back straight","Swing arms naturally","Breathe steadily"]'),
  ('Bodyweight Squats', 'strength', 'beginner', 15, 80,
   '["Stand feet shoulder-width","Lower until thighs parallel","Keep chest up","Push through heels"]'),
  ('Push-ups', 'strength', 'beginner', 10, 60,
   '["High plank position","Lower chest to ground","Push back up","Keep core tight"]'),
  ('Sun Salutation', 'yoga', 'beginner', 20, 100,
   '["Start in mountain pose","Forward fold","Plank","Cobra","Downward dog","Repeat 5x"]'),
  ('Jumping Jacks', 'cardio', 'beginner', 10, 80,
   '["Stand with feet together","Jump spreading feet and raise arms","Return to start","Repeat"]'),
  ('Plank Hold', 'strength', 'beginner', 5, 30,
   '["Forearm plank position","Keep hips level","Engage core","Hold 30-60 seconds"]'),
  ('Lunges', 'strength', 'intermediate', 15, 90,
   '["Step forward with right foot","Lower back knee toward ground","Push back to start","Alternate legs"]'),
  ('Warrior Pose', 'yoga', 'beginner', 15, 50,
   '["Wide stance","Front knee bent to 90°","Arms extended","Hold 30 seconds each side"]'),
  ('Mountain Climbers', 'cardio', 'intermediate', 10, 100,
   '["High plank position","Drive right knee to chest","Alternate legs quickly","Keep hips low"]'),
  ('Child Pose', 'yoga', 'beginner', 5, 20,
   '["Kneel on mat","Sit back on heels","Extend arms forward","Hold and breathe deeply"]')
ON CONFLICT DO NOTHING;
