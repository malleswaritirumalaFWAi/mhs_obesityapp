-- Seed reference data so screens look populated immediately.

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
