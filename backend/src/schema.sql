-- FitQuest schema (PostgreSQL)

CREATE TABLE IF NOT EXISTS users (
  id            BIGSERIAL PRIMARY KEY,
  phone         TEXT UNIQUE NOT NULL,
  name          TEXT,
  onboarded     BOOLEAN NOT NULL DEFAULT FALSE,
  xp            INTEGER NOT NULL DEFAULT 0,
  streak        INTEGER NOT NULL DEFAULT 0,
  start_weight  NUMERIC(5,1),
  target_weight NUMERIC(5,1),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

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
  name       TEXT NOT NULL,        -- e.g. "Batch #47"
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
  amount      INTEGER NOT NULL,    -- paise
  order_id    TEXT,
  payment_id  TEXT,
  status      TEXT NOT NULL DEFAULT 'created',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tasks (
  id        BIGSERIAL PRIMARY KEY,
  user_id   BIGINT REFERENCES users(id) ON DELETE CASCADE,
  day_index INTEGER NOT NULL,
  slot      TEXT NOT NULL,         -- morning/afternoon/evening
  time      TEXT,
  icon      TEXT,
  title     TEXT NOT NULL,
  subtitle  TEXT,
  xp        INTEGER NOT NULL DEFAULT 0,
  done      BOOLEAN NOT NULL DEFAULT FALSE
);

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
  status    TEXT NOT NULL DEFAULT 'locked'   -- completed/active/locked
);

CREATE TABLE IF NOT EXISTS chat_messages (
  id         BIGSERIAL PRIMARY KEY,
  user_id    BIGINT REFERENCES users(id) ON DELETE CASCADE,
  from_coach BOOLEAN NOT NULL DEFAULT FALSE,
  text       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
