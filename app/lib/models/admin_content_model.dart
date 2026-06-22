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
    title: 'Kickstart Week',
    scheduledUnlock: DateTime(2026, 6, 23, 9, 0),
    tasks: const [
      ChallengeTask(taskNum: 1, description: 'Walk 5,000 steps every day'),
      ChallengeTask(taskNum: 2, description: 'Drink 2L of water daily'),
      ChallengeTask(taskNum: 3, description: 'Log 3 meals per day in the app'),
      ChallengeTask(taskNum: 4, description: 'Complete morning stretching (10 min)'),
      ChallengeTask(taskNum: 5, description: 'Sleep 7+ hours each night'),
    ],
  ),
  ChallengeWeek(
    weekNum: 2,
    title: 'Burn Zone',
    scheduledUnlock: DateTime(2026, 6, 30, 9, 0),
    tasks: const [
      ChallengeTask(taskNum: 1, description: 'Complete 20-min cardio session daily'),
      ChallengeTask(taskNum: 2, description: 'Cut sugar intake by 50%'),
      ChallengeTask(taskNum: 3, description: 'Do 15 min HIIT, 3 times this week'),
      ChallengeTask(taskNum: 4, description: 'Eat a high-protein breakfast daily'),
      ChallengeTask(taskNum: 5, description: 'Walk or cycle instead of driving once'),
    ],
  ),
  ChallengeWeek(
    weekNum: 3,
    title: 'Strength Builder',
    scheduledUnlock: DateTime(2026, 7, 7, 9, 0),
    tasks: const [
      ChallengeTask(taskNum: 1, description: 'Complete bodyweight workout (3x10 reps)'),
      ChallengeTask(taskNum: 2, description: 'Increase daily protein to 100g'),
      ChallengeTask(taskNum: 3, description: 'Do 50 squats daily'),
      ChallengeTask(taskNum: 4, description: 'Learn 1 new resistance exercise'),
      ChallengeTask(taskNum: 5, description: 'Stretch 15 min after every workout'),
    ],
  ),
  ChallengeWeek(
    weekNum: 4,
    title: 'Endurance Push',
    scheduledUnlock: DateTime(2026, 7, 14, 9, 0),
    tasks: const [
      ChallengeTask(taskNum: 1, description: 'Complete a 5km walk or run'),
      ChallengeTask(taskNum: 2, description: 'Hold a 60-second plank daily'),
      ChallengeTask(taskNum: 3, description: 'Meditate for 10 minutes daily'),
      ChallengeTask(taskNum: 4, description: 'Meal prep for the entire week'),
      ChallengeTask(taskNum: 5, description: 'Maintain calorie deficit for 5 of 7 days'),
    ],
  ),
];

// ── Lesson modules ─────────────────────────────────────────────────────────

final kLessonModules = <LessonModule>[
  LessonModule(
    moduleNum: 1,
    title: 'Nutrition Basics',
    description: 'Understand macros, calorie deficit, and healthy eating habits.',
    videoUrl: 'https://www.youtube.com/embed/dQw4w9WgXcQ',
    scheduledUnlock: DateTime(2026, 6, 23, 9, 0),
  ),
  LessonModule(
    moduleNum: 2,
    title: 'Cardio Science',
    description: 'Learn heart rate zones, fat-burning cardio, and HIIT principles.',
    videoUrl: 'https://www.youtube.com/embed/dQw4w9WgXcQ',
    scheduledUnlock: DateTime(2026, 6, 25, 9, 0),
  ),
  LessonModule(
    moduleNum: 3,
    title: 'Strength Training 101',
    description: 'Master the basics of resistance training for fat loss.',
    videoUrl: 'https://www.youtube.com/embed/dQw4w9WgXcQ',
    scheduledUnlock: DateTime(2026, 6, 27, 9, 0),
  ),
  LessonModule(
    moduleNum: 4,
    title: 'Sleep & Recovery',
    description: 'Discover how sleep quality impacts weight loss and recovery.',
    videoUrl: 'https://www.youtube.com/embed/dQw4w9WgXcQ',
    scheduledUnlock: DateTime(2026, 6, 30, 9, 0),
  ),
  LessonModule(
    moduleNum: 5,
    title: 'Mindset for Fat Loss',
    description: 'Build the psychological foundation for lasting weight loss.',
    videoUrl: 'https://www.youtube.com/embed/dQw4w9WgXcQ',
    scheduledUnlock: DateTime(2026, 7, 2, 9, 0),
  ),
];
