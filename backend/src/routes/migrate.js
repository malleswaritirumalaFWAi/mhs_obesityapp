import { Router } from 'express';
import pg from 'pg';

const router = Router();

// ---- Embedded schema (mirrors src/schema.sql) ----------------------------
const SCHEMA_SQL = `
CREATE TABLE IF NOT EXISTS users (
  id            BIGSERIAL PRIMARY KEY,
  phone         TEXT UNIQUE NOT NULL,
  name          TEXT,
  email         TEXT UNIQUE,
  password_hash TEXT,
  onboarded     BOOLEAN NOT NULL DEFAULT FALSE,
  xp            INTEGER NOT NULL DEFAULT 0,
  streak        INTEGER NOT NULL DEFAULT 0,
  start_weight  NUMERIC(5,1),
  target_weight NUMERIC(5,1),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT UNIQUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT;

CREATE TABLE IF NOT EXISTS otps (
  phone      TEXT PRIMARY KEY,
  code       TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS profiles (
  user_id    BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  gender     TEXT,
  activity   TEXT,
  goal       TEXT,
  food_pref  TEXT,
  challenge  TEXT
);

CREATE TABLE IF NOT EXISTS coaches (
  id        BIGSERIAL PRIMARY KEY,
  name      TEXT NOT NULL,
  title     TEXT,
  rating    NUMERIC(2,1),
  avatar    TEXT
);

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
  id        BIGSERIAL PRIMARY KEY,
  user_id   BIGINT REFERENCES users(id) ON DELETE CASCADE,
  day_index INTEGER NOT NULL,
  slot      TEXT NOT NULL,
  time      TEXT,
  icon      TEXT,
  title     TEXT NOT NULL,
  subtitle  TEXT,
  xp           INTEGER NOT NULL DEFAULT 0,
  done         BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at TIMESTAMPTZ
);
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
CREATE UNIQUE INDEX IF NOT EXISTS tasks_user_day_icon_uidx ON tasks (user_id, day_index, icon);

CREATE TABLE IF NOT EXISTS checkins (
  id        BIGSERIAL PRIMARY KEY,
  user_id   BIGINT REFERENCES users(id) ON DELETE CASCADE,
  mood      INTEGER,
  weight    NUMERIC(5,1),
  notes     TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS meals (
  id        BIGSERIAL PRIMARY KEY,
  user_id   BIGINT REFERENCES users(id) ON DELETE CASCADE,
  meal_type TEXT,
  items     JSONB,
  calories  INTEGER,
  carbs     INTEGER,
  protein   INTEGER,
  fat       INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS posts (
  id         BIGSERIAL PRIMARY KEY,
  group_id   BIGINT REFERENCES groups(id) ON DELETE CASCADE,
  user_id    BIGINT REFERENCES users(id) ON DELETE CASCADE,
  body       TEXT,
  emoji      TEXT,
  coach_pick BOOLEAN NOT NULL DEFAULT FALSE,
  likes      INTEGER NOT NULL DEFAULT 0,
  fires      INTEGER NOT NULL DEFAULT 0,
  comments   INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

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
  id        BIGSERIAL PRIMARY KEY,
  week      INTEGER NOT NULL,
  title     TEXT NOT NULL,
  author    TEXT,
  minutes   INTEGER,
  xp        INTEGER NOT NULL DEFAULT 0,
  status    TEXT NOT NULL DEFAULT 'locked'
);

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
`;

// ---- Embedded seed (mirrors src/seed.sql) --------------------------------
const SEED_SQL = `
INSERT INTO coaches (id, name, title, rating, avatar)
VALUES (1, 'Priya Sharma', 'Certified Dietitian', 4.8, 'P')
ON CONFLICT (id) DO NOTHING;

INSERT INTO groups (id, name, coach_id, starts_on)
VALUES (1, 'Batch #47', 1, DATE '2026-03-03')
ON CONFLICT (id) DO NOTHING;

INSERT INTO badges (code, emoji, name, xp) VALUES
  ('streak_master', '🔥', 'Streak Master', 200),
  ('steps_100k',    '🏃', '100K Steps',    150),
  ('clean_week',    '🥗', 'Clean Week',    120)
ON CONFLICT (code) DO NOTHING;

INSERT INTO lessons (week, title, author, minutes, xp, status) VALUES
  (1, 'Foundation',        'Coach Priya', 6,  50,  'completed'),
  (2, 'Nutrition basics',  'Dr. Roy',     7,  50,  'completed'),
  (3, 'Power of walking',  'Coach Priya', 5,  50,  'active'),
  (4, 'Sleep & recovery',  'Dr. Roy',     6,  30,  'locked'),
  (5, 'Strength habits',   'Coach Priya', 8,  60,  'locked')
ON CONFLICT DO NOTHING;
`;

async function runMigration(useSsl) {
  const pool = new pg.Pool({
    connectionString: process.env.DATABASE_URL,
    options: '-c search_path=fitquest',
    ssl: useSsl ? { rejectUnauthorized: false } : false,
    connectionTimeoutMillis: 8000,
  });
  const client = await pool.connect();
  try {
    await client.query('CREATE SCHEMA IF NOT EXISTS fitquest');
    await client.query('SET search_path TO fitquest');
    await client.query(SCHEMA_SQL);
    await client.query(SEED_SQL);
  } finally {
    client.release();
    await pool.end();
  }
}

// GET /migrate?key=YOUR_MIGRATE_KEY  — run once, then remove this file.
router.get('/migrate', async (req, res) => {
  if (!process.env.MIGRATE_KEY || req.query.key !== process.env.MIGRATE_KEY) {
    return res.status(403).json({ ok: false, message: 'Forbidden — missing or wrong key.' });
  }
  if (!process.env.DATABASE_URL) {
    return res.status(500).json({ ok: false, message: 'DATABASE_URL is not set on this backend.' });
  }
  try {
    await runMigration(false);
    return res.json({ ok: true, ssl: false, message: 'Migration complete (no SSL). You can remove the migrate route now.' });
  } catch (eNoSsl) {
    try {
      await runMigration(true);
      return res.json({
        ok: true,
        ssl: true,
        message: 'Migration complete (SSL required). Add DB_SSL handling to db.js — tell Claude SSL was needed.',
        firstError: eNoSsl.message,
      });
    } catch (eSsl) {
      return res.status(500).json({
        ok: false,
        message: 'Migration failed on both no-SSL and SSL attempts.',
        error_without_ssl: eNoSsl.message,
        error_with_ssl: eSsl.message,
      });
    }
  }
});

export default router;
