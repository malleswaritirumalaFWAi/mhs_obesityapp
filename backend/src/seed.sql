-- Seed reference data so screens look populated immediately.

INSERT INTO coaches (id, name, title, rating, avatar)
VALUES (1, 'Priya Sharma', 'Certified Dietitian', 4.8, 'P')
ON CONFLICT (id) DO NOTHING;

INSERT INTO groups (id, name, coach_id, starts_on)
VALUES (1, 'Batch #47', 1, DATE '2026-03-03')
ON CONFLICT (id) DO NOTHING;

INSERT INTO badges (code, emoji, name, xp, description) VALUES
  ('streak_master', '🔥', 'Streak Master', 200, 'Build a 30-day streak without a break'),
  ('steps_100k',    '🏃', '100K Steps',    150, 'Accumulate 100,000 total steps across all sessions'),
  ('clean_week',    '🥗', 'Clean Week',    120, 'Log all meals for 7 consecutive days without skipping')
ON CONFLICT (code) DO UPDATE SET description=EXCLUDED.description;

INSERT INTO lessons (week, title, author, minutes, xp, status) VALUES
  (1, 'Foundation',        'Coach Priya', 6,  50,  'completed'),
  (2, 'Nutrition basics',  'Dr. Roy',     7,  50,  'completed'),
  (3, 'Power of walking',  'Coach Priya', 5,  50,  'active'),
  (4, 'Sleep & recovery',  'Dr. Roy',     6,  30,  'locked'),
  (5, 'Strength habits',   'Coach Priya', 8,  60,  'locked')
ON CONFLICT DO NOTHING;
