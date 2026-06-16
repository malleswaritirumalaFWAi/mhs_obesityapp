import { q } from './db.js';

export const TASK_TEMPLATES = [
  { slot: 'morning',   time: '07:00', icon: 'wb_sunny',       title: 'Morning check-in',  subtitle: 'Log mood & weight · +10 XP', xp: 10 },
  { slot: 'morning',   time: '08:30', icon: 'restaurant',     title: 'Log a meal',        subtitle: 'Breakfast · lunch · snack · dinner · +5 XP', xp: 5  },
  { slot: 'afternoon', time: '16:00', icon: 'water_drop',     title: 'Hydration check',   subtitle: '8 glasses daily target',     xp: 5  },
  { slot: 'evening',   time: '19:30', icon: 'directions_run', title: '8,000 step walk',   subtitle: 'Daily movement goal',        xp: 10 },
  { slot: 'evening',   time: '21:45', icon: 'scale',          title: 'Evening weigh-in',  subtitle: '5 min before bed',           xp: 5  },
];

/**
 * Seeds the standard 6 tasks for a user on a given day if they don't exist yet.
 * Safe to call multiple times — no-op if tasks already exist.
 */
export async function ensureTasksForDay(userId, dayIndex) {
  const existing = await q(
    `SELECT COUNT(*) AS n FROM tasks WHERE user_id=$1 AND day_index=$2`,
    [userId, dayIndex]
  );
  if (Number(existing.rows[0].n) === 0) {
    for (const t of TASK_TEMPLATES) {
      await q(
        `INSERT INTO tasks (user_id, day_index, slot, time, icon, title, subtitle, xp)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
         ON CONFLICT (user_id, day_index, icon) DO NOTHING`,
        [userId, dayIndex, t.slot, t.time, t.icon, t.title, t.subtitle, t.xp]
      );
    }
    console.log(`[tasks] seeded day ${dayIndex} for user ${userId}`);
  }
}

/**
 * Returns today's day index (1–84) for a user based on their batch start date.
 */
export async function getDayIndex(userId) {
  // Use users.created_at as the authoritative day-1 reference.
  // group_members.joined_at is unreliable — it may have been backfilled with
  // the migration timestamp (not the actual registration date) when the column
  // was first added, causing all pre-migration users to show Day 1 forever.
  const uRow = await q(`SELECT created_at FROM users WHERE id = $1`, [userId]);
  const createdAt = uRow.rows[0]?.created_at
    ? new Date(uRow.rows[0].created_at)
    : new Date();
  const today = new Date();
  const diffMs = today.setHours(0, 0, 0, 0) - new Date(createdAt).setHours(0, 0, 0, 0);
  return Math.min(Math.max(Math.floor(diffMs / 86400000) + 1, 1), 84);
}

/**
 * Seeds today's tasks for a user. Called from /profile on every login.
 */
export async function ensureTasksForToday(userId) {
  const dayIndex = await getDayIndex(userId);
  await ensureTasksForDay(userId, dayIndex);
}

/**
 * Marks tasks with the given icons as done for a user today.
 * Called automatically when user saves a check-in or logs a meal.
 */
export async function markTasksDoneByIcon(userId, icons) {
  const dayIndex = await getDayIndex(userId);
  await q(
    `UPDATE tasks SET done = TRUE, completed_at = NOW()
     WHERE user_id = $1 AND day_index = $2 AND icon = ANY($3) AND done = FALSE`,
    [userId, dayIndex, icons]
  );
}
