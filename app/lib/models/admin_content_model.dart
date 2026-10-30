import 'package:flutter/material.dart';

// ── User model for admin panel ─────────────────────────────────────────────

/// Converts a DB level string (e.g. 'bronze') to a display integer.
int levelFromString(String? s) {
  const map = {
    'bronze': 1, 'silver': 2, 'gold': 3, 'platinum': 4,
    'diamond': 5, 'legend': 6, 'master': 7, 'royal': 8,
  };
  return map[s?.toLowerCase()] ?? 1;
}

/// Deterministic avatar color from any string seed (name or id).
Color avatarColorFor(String seed) {
  const palette = [
    Color(0xFF1B4F72), Color(0xFFFF6B35), Color(0xFF11998E),
    Color(0xFFB788D9), Color(0xFFE5B36A), Color(0xFF2E86AB),
    Color(0xFF6A11CB), Color(0xFF38A169),
  ];
  final idx = seed.codeUnits.fold(0, (a, b) => a + b) % palette.length;
  return palette[idx];
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.xp,
    required this.level,
    required this.streak,
    required this.rank,
    required this.challengeCompleted,
    required this.challengeTotal,
    required this.lessonCompleted,
    required this.lessonTotal,
    required this.avatarColor,
  });

  final String id;
  final String name;
  final int xp;
  final int level;
  final int streak;
  final int rank;
  final int challengeCompleted;
  final int challengeTotal;
  final int lessonCompleted;
  final int lessonTotal;
  final Color avatarColor;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Build from the enriched GET /admin/users response row.
  factory AdminUser.fromJson(Map<String, dynamic> j, int rank) {
    final name = (j['name'] as String?)?.trim();
    final displayName = (name != null && name.isNotEmpty) ? name : 'User #${j['id']}';
    return AdminUser(
      id: j['id'].toString(),
      name: displayName,
      xp: (j['total_xp'] as num?)?.toInt() ?? (j['xp'] as num?)?.toInt() ?? 0,
      level: levelFromString(j['level'] as String?),
      streak: (j['streak'] as num?)?.toInt() ?? 0,
      rank: rank,
      challengeCompleted: (j['challenges_completed'] as num?)?.toInt() ?? 0,
      challengeTotal: (j['challenges_total'] as num?)?.toInt() ?? 12,
      lessonCompleted: (j['lessons_completed'] as num?)?.toInt() ?? 0,
      lessonTotal: (j['lessons_total'] as num?)?.toInt() ?? 15,
      avatarColor: avatarColorFor(displayName),
    );
  }
}

// ── Challenge models ───────────────────────────────────────────────────────

class ChallengeTask {
  const ChallengeTask({required this.taskNum, required this.description});
  final int taskNum;
  final String description;
}

class ChallengeWeek {
  const ChallengeWeek({
    required this.weekNum,
    required this.title,
    required this.scheduledUnlock,
    required this.tasks,
  });
  final int weekNum;
  final String title;
  final DateTime scheduledUnlock;
  final List<ChallengeTask> tasks;

  String get unlockKey => 'unlock_challenge_week$weekNum';
}

// ── Lesson model ───────────────────────────────────────────────────────────

class LessonModule {
  const LessonModule({
    required this.moduleNum,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.scheduledUnlock,
  });
  final int moduleNum;
  final String title;
  final String description;
  final String videoUrl;
  final DateTime scheduledUnlock;

  String get unlockKey => 'unlock_lesson_module$moduleNum';
}

// ── Dummy users ────────────────────────────────────────────────────────────

const kDummyUsers = <AdminUser>[
  AdminUser(
    id: 'dummy_u1',
    name: 'Arjun Sharma',
    xp: 2450,
    level: 8,
    streak: 12,
    rank: 1,
    challengeCompleted: 4,
    challengeTotal: 5,
    lessonCompleted: 3,
    lessonTotal: 5,
    avatarColor: Color(0xFF1B4F72),
  ),
  AdminUser(
    id: 'dummy_u2',
    name: 'Priya Patel',
    xp: 1980,
    level: 7,
    streak: 7,
    rank: 2,
    challengeCompleted: 3,
    challengeTotal: 5,
    lessonCompleted: 2,
    lessonTotal: 5,
    avatarColor: Color(0xFFFF6B35),
  ),
  AdminUser(
    id: 'dummy_u3',
    name: 'Rohan Mehta',
    xp: 1650,
    level: 6,
    streak: 5,
    rank: 3,
    challengeCompleted: 3,
    challengeTotal: 5,
    lessonCompleted: 2,
    lessonTotal: 5,
    avatarColor: Color(0xFF11998E),
  ),
  AdminUser(
    id: 'dummy_u4',
    name: 'Sneha Kapoor',
    xp: 1200,
    level: 5,
    streak: 3,
    rank: 4,
    challengeCompleted: 2,
    challengeTotal: 5,
    lessonCompleted: 1,
    lessonTotal: 5,
    avatarColor: Color(0xFFB788D9),
  ),
  AdminUser(
    id: 'dummy_u5',
    name: 'Vikram Singh',
    xp: 750,
    level: 4,
    streak: 1,
    rank: 5,
    challengeCompleted: 1,
    challengeTotal: 5,
    lessonCompleted: 0,
    lessonTotal: 5,
    avatarColor: Color(0xFFE5B36A),
  ),
];

// ── Weekly challenges ──────────────────────────────────────────────────────

final kChallengeWeeks = <ChallengeWeek>[
  ChallengeWeek(
    weekNum: 1,
    title: 'Know Your Baseline',
    scheduledUnlock: DateTime(2026, 6, 23, 9, 0),
    tasks: const [
      ChallengeTask(taskNum: 1, description: 'Log your weight every morning'),
      ChallengeTask(taskNum: 2, description: 'Log all 3 meals daily'),
      ChallengeTask(taskNum: 3, description: 'Complete morning mood check-in'),
      ChallengeTask(taskNum: 4, description: 'Drink 8 glasses of water'),
      ChallengeTask(taskNum: 5, description: 'Do this for 7 consecutive days'),
    ],
  ),
  ChallengeWeek(
    weekNum: 2,
    title: 'Find Your Move',
    scheduledUnlock: DateTime(2026, 6, 30, 9, 0),
    tasks: const [
      ChallengeTask(taskNum: 1, description: 'Walk 5,000+ steps on 4 days'),
      ChallengeTask(taskNum: 2, description: 'Take a 10-min walk after lunch'),
      ChallengeTask(taskNum: 3, description: 'Use stairs instead of elevator'),
      ChallengeTask(taskNum: 4, description: 'Log all meals with photos'),
      ChallengeTask(taskNum: 5, description: 'Track steps in the app daily'),
    ],
  ),
  ChallengeWeek(
    weekNum: 3,
    title: 'Sleep Foundation',
    scheduledUnlock: DateTime(2026, 7, 7, 9, 0),
    tasks: const [
      ChallengeTask(taskNum: 1, description: 'Sleep 7+ hours on 5 days'),
      ChallengeTask(taskNum: 2, description: 'Set a consistent bedtime'),
      ChallengeTask(taskNum: 3, description: 'No screens 30 min before bed'),
      ChallengeTask(taskNum: 4, description: 'No caffeine after 2 PM'),
      ChallengeTask(taskNum: 5, description: 'Log sleep in evening reflection'),
    ],
  ),
  ChallengeWeek(
    weekNum: 4,
    title: 'Morning Anchor',
    scheduledUnlock: DateTime(2026, 7, 14, 9, 0),
    tasks: const [
      ChallengeTask(taskNum: 1, description: 'Complete morning check-in 7 days'),
      ChallengeTask(taskNum: 2, description: 'Log weight every morning'),
      ChallengeTask(taskNum: 3, description: 'Eat breakfast within 1 hour of waking'),
      ChallengeTask(taskNum: 4, description: 'Drink a glass of water on waking'),
      ChallengeTask(taskNum: 5, description: 'Review today\'s plan each morning'),
    ],
  ),
  ChallengeWeek(
    weekNum: 5,
    title: 'Move After Meals',
    scheduledUnlock: DateTime(2026, 7, 21, 9, 0),
    tasks: const [
      ChallengeTask(taskNum: 1, description: 'Walk 5K+ steps and log 3 meals on 5 days'),
      ChallengeTask(taskNum: 2, description: 'Take a 10-min post-meal walk'),
      ChallengeTask(taskNum: 3, description: 'Hit protein target at every meal'),
      ChallengeTask(taskNum: 4, description: 'Log all snacks in the app'),
      ChallengeTask(taskNum: 5, description: 'Complete evening reflection daily'),
    ],
  ),
  ChallengeWeek(
    weekNum: 6,
    title: 'Halfway Audit',
    scheduledUnlock: DateTime(2026, 7, 28, 9, 0),
    tasks: const [
      ChallengeTask(taskNum: 1, description: 'Log weight every day for 7 days'),
      ChallengeTask(taskNum: 2, description: 'Review your weight chart trend'),
      ChallengeTask(taskNum: 3, description: 'Increase daily steps by 1,000'),
      ChallengeTask(taskNum: 4, description: 'Try one new healthy recipe'),
      ChallengeTask(taskNum: 5, description: 'Celebrate your non-scale victories'),
    ],
  ),
  ChallengeWeek(
    weekNum: 7,
    title: 'Step It Up',
    scheduledUnlock: DateTime(2026, 8, 4, 9, 0),
    tasks: const [
      ChallengeTask(taskNum: 1, description: 'Hit 8,000+ steps on 5 days'),
      ChallengeTask(taskNum: 2, description: 'Try interval walking (2 min fast, 1 min normal)'),
      ChallengeTask(taskNum: 3, description: 'Add incline walking or stairs'),
      ChallengeTask(taskNum: 4, description: 'Do bodyweight exercises on 2 days'),
      ChallengeTask(taskNum: 5, description: 'Log all movement in the app'),
    ],
  ),
  ChallengeWeek(
    weekNum: 8,
    title: 'Eat With Intent',
    scheduledUnlock: DateTime(2026, 8, 11, 9, 0),
    tasks: const [
      ChallengeTask(taskNum: 1, description: 'Log all 3 meal types on 5 days'),
      ChallengeTask(taskNum: 2, description: 'Eat without screens at every meal'),
      ChallengeTask(taskNum: 3, description: 'Chew each bite 15-20 times'),
      ChallengeTask(taskNum: 4, description: 'Stop eating at 80% full'),
      ChallengeTask(taskNum: 5, description: 'Rate hunger before and after meals'),
    ],
  ),
  ChallengeWeek(
    weekNum: 9,
    title: 'Full System Week',
    scheduledUnlock: DateTime(2026, 8, 18, 9, 0),
    tasks: const [
      ChallengeTask(taskNum: 1, description: 'Complete 5+ daily tasks on 4 days'),
      ChallengeTask(taskNum: 2, description: 'Morning check-in + weight log'),
      ChallengeTask(taskNum: 3, description: 'All meals logged with photos'),
      ChallengeTask(taskNum: 4, description: '8K+ steps daily'),
      ChallengeTask(taskNum: 5, description: 'Evening reflection before bed'),
    ],
  ),
  ChallengeWeek(
    weekNum: 10,
    title: '10K Club',
    scheduledUnlock: DateTime(2026, 8, 25, 9, 0),
    tasks: const [
      ChallengeTask(taskNum: 1, description: 'Hit 10,000+ steps on 5 days'),
      ChallengeTask(taskNum: 2, description: 'Morning walk: 3,000 steps'),
      ChallengeTask(taskNum: 3, description: 'Post-lunch walk: 2,000 steps'),
      ChallengeTask(taskNum: 4, description: 'Evening walk: 3,000 steps'),
      ChallengeTask(taskNum: 5, description: 'Share your step count with the group'),
    ],
  ),
  ChallengeWeek(
    weekNum: 11,
    title: 'Unbreakable Streak',
    scheduledUnlock: DateTime(2026, 9, 1, 9, 0),
    tasks: const [
      ChallengeTask(taskNum: 1, description: 'Complete ALL daily tasks for 7 days'),
      ChallengeTask(taskNum: 2, description: 'Morning weight + mood check-in'),
      ChallengeTask(taskNum: 3, description: 'All 3 meals logged'),
      ChallengeTask(taskNum: 4, description: '10K+ steps and 7+ hours sleep'),
      ChallengeTask(taskNum: 5, description: 'Evening reflection every night'),
    ],
  ),
  ChallengeWeek(
    weekNum: 12,
    title: 'Transformation Proof',
    scheduledUnlock: DateTime(2026, 9, 8, 9, 0),
    tasks: const [
      ChallengeTask(taskNum: 1, description: 'Log weight + morning mood + evening mood for 7 days'),
      ChallengeTask(taskNum: 2, description: 'Take a progress photo'),
      ChallengeTask(taskNum: 3, description: 'Review your 12-week weight chart'),
      ChallengeTask(taskNum: 4, description: 'Share your transformation with the group'),
      ChallengeTask(taskNum: 5, description: 'Celebrate — you did it!'),
    ],
  ),
];

// ── Lesson modules ─────────────────────────────────────────────────────────

final kLessonModules = <LessonModule>[
  LessonModule(
    moduleNum: 1,
    title: 'Awareness',
    description: 'Your body, your baseline — understanding calories and tracking.',
    videoUrl: '',
    scheduledUnlock: DateTime(2026, 6, 23, 9, 0),
  ),
  LessonModule(
    moduleNum: 2,
    title: 'Movement',
    description: 'The power of walking, NEAT, and building a step habit.',
    videoUrl: '',
    scheduledUnlock: DateTime(2026, 6, 30, 9, 0),
  ),
  LessonModule(
    moduleNum: 3,
    title: 'Recovery',
    description: 'How sleep affects weight loss, cortisol, and hunger hormones.',
    videoUrl: '',
    scheduledUnlock: DateTime(2026, 7, 7, 9, 0),
  ),
  LessonModule(
    moduleNum: 4,
    title: 'Habit Building',
    description: 'Morning routines, the habit loop, and the 2-minute rule.',
    videoUrl: '',
    scheduledUnlock: DateTime(2026, 7, 14, 9, 0),
  ),
  LessonModule(
    moduleNum: 5,
    title: 'Nutrition',
    description: 'Protein science, thermic effect, and practical meal planning.',
    videoUrl: '',
    scheduledUnlock: DateTime(2026, 7, 21, 9, 0),
  ),
  LessonModule(
    moduleNum: 6,
    title: 'Midpoint Review',
    description: 'Halfway checkpoint — plateaus, non-scale victories, adjustments.',
    videoUrl: '',
    scheduledUnlock: DateTime(2026, 7, 28, 9, 0),
  ),
  LessonModule(
    moduleNum: 7,
    title: 'Pushing Limits',
    description: 'Progressive overload, 8K steps, fat-burning zones.',
    videoUrl: '',
    scheduledUnlock: DateTime(2026, 8, 4, 9, 0),
  ),
  LessonModule(
    moduleNum: 8,
    title: 'Nutrition Mastery',
    description: 'Mindful eating, hunger scale, and meal timing.',
    videoUrl: '',
    scheduledUnlock: DateTime(2026, 8, 11, 9, 0),
  ),
  LessonModule(
    moduleNum: 9,
    title: 'Integration',
    description: 'Full daily system — morning to evening, all habits combined.',
    videoUrl: '',
    scheduledUnlock: DateTime(2026, 8, 18, 9, 0),
  ),
  LessonModule(
    moduleNum: 10,
    title: 'Peak Performance',
    description: '10K step club, structured exercise, and social accountability.',
    videoUrl: '',
    scheduledUnlock: DateTime(2026, 8, 25, 9, 0),
  ),
  LessonModule(
    moduleNum: 11,
    title: 'Identity Shift',
    description: 'The unbreakable streak — consistency, compound effect, never miss twice.',
    videoUrl: '',
    scheduledUnlock: DateTime(2026, 9, 1, 9, 0),
  ),
  LessonModule(
    moduleNum: 12,
    title: 'Transformation',
    description: 'Your transformation story — review, maintenance, and next chapter.',
    videoUrl: '',
    scheduledUnlock: DateTime(2026, 9, 8, 9, 0),
  ),
];
