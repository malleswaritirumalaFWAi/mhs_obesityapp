import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../state/session.dart';

class LessonItem {
  const LessonItem({
    required this.id,
    required this.title,
    required this.weekNumber,
    required this.weekName,
    required this.lessonType,
    required this.xpReward,
    required this.status,
    this.content = '',
    this.videoUrl,
    this.quizQuestions,
    this.completed = false,
    this.author = '',
    this.minutes = 5,
  });
  final int id;
  final String title;
  final int weekNumber;
  final String weekName;
  final String lessonType; // article, video, quiz
  final int xpReward;
  final String status; // completed, active, locked
  final String content;
  final String? videoUrl;
  final List<dynamic>? quizQuestions;
  final bool completed;
  final String author;
  final int minutes;

  bool get isActive => status == 'active';
  bool get isLocked => status == 'locked';

  String get upNextSubtitle => lessonType == 'quiz'
      ? 'Test week $weekNumber · earn big +$xpReward XP'
      : '${author.isNotEmpty ? author : 'Dr. Roy'} · $minutes min · +$xpReward XP';

  factory LessonItem.fromJson(Map<String, dynamic> j) => LessonItem(
        id: (j['id'] as num).toInt(),
        title: (j['title'] as String?) ?? '',
        weekNumber: (j['week_number'] as num?)?.toInt() ?? 1,
        weekName: (j['week_name'] as String?) ?? '',
        lessonType: (j['lesson_type'] as String?) ?? 'article',
        xpReward: (j['xp_reward'] as num?)?.toInt() ?? 30,
        status: (j['status'] as String?) ?? 'locked',
        content: (j['content'] as String?) ?? '',
        videoUrl: j['video_url'] as String?,
        quizQuestions: j['quiz_questions'] as List<dynamic>?,
        completed: j['completed'] == true,
        author: (j['author'] as String?) ?? '',
        minutes: (j['minutes'] as num?)?.toInt() ?? 5,
      );
}

// A grouped week module for "Your journey" section
class WeekModule {
  const WeekModule({required this.weekNumber, required this.weekName, required this.lessons});
  final int weekNumber;
  final String weekName;
  final List<LessonItem> lessons;

  bool get isCompleted => lessons.isNotEmpty && lessons.every((l) => l.completed);
  bool get isLocked => lessons.every((l) => l.isLocked && !l.completed);
  bool get isActive => !isCompleted && !isLocked;
}

class LessonsState {
  const LessonsState({this.lessons = const [], this.loading = false});
  final List<LessonItem> lessons;
  final bool loading;

  // First lesson with status 'active'
  LessonItem? get activeLesson =>
      lessons.cast<LessonItem?>().firstWhere((l) => l!.isActive, orElse: () => null);

  // All lessons in the same week as the active lesson
  List<LessonItem> get activeWeekLessons {
    final active = activeLesson;
    if (active == null) return [];
    return lessons.where((l) => l.weekNumber == active.weekNumber).toList();
  }

  // Up to 2 lessons after the active one (the "Up next" list)
  List<LessonItem> get upNext {
    final active = activeLesson;
    if (active == null) return [];
    final idx = lessons.indexOf(active);
    if (idx < 0) return [];
    return lessons.skip(idx + 1).take(2).toList();
  }

  // Grouped weeks for "Your journey" section
  List<WeekModule> get weekModules {
    final map = <int, List<LessonItem>>{};
    for (final l in lessons) {
      map.putIfAbsent(l.weekNumber, () => []).add(l);
    }
    final weeks = map.keys.toList()..sort();
    return weeks.map((w) {
      final ls = map[w]!;
      final name = ls.first.weekName;
      return WeekModule(weekNumber: w, weekName: name, lessons: ls);
    }).toList();
  }
}

class LessonsNotifier extends StateNotifier<LessonsState> {
  LessonsNotifier(this._api) : super(const LessonsState(loading: true)) {
    fetch();
  }
  final ApiClient _api;

  Future<void> fetch() async {
    try {
      final d = await _api.getJson('/lessons');
      final raw = (d['lessons'] as List?) ?? [];
      final lessons = raw
          .map((e) => LessonItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      state = LessonsState(lessons: lessons, loading: false);
    } catch (_) {
      state = const LessonsState(loading: false);
    }
  }

  Future<void> complete(int id) async {
    try {
      await _api.postJson('/lessons/$id/complete', null);
      state = LessonsState(
        loading: false,
        lessons: state.lessons.map((l) => l.id == id
            ? LessonItem(
                id: l.id, title: l.title, weekNumber: l.weekNumber,
                weekName: l.weekName, lessonType: l.lessonType,
                xpReward: l.xpReward, status: 'completed',
                content: l.content, videoUrl: l.videoUrl,
                quizQuestions: l.quizQuestions, completed: true,
                author: l.author, minutes: l.minutes)
            : l).toList(),
      );
    } catch (_) {}
  }
}

final lessonsProvider =
    StateNotifierProvider<LessonsNotifier, LessonsState>((ref) {
  ref.watch(currentUserKeyProvider);
  return LessonsNotifier(ref.watch(apiClientProvider));
});

// Daily health tip
final healthTipProvider = FutureProvider<Map<String, String>>((ref) async {
  ref.watch(currentUserKeyProvider);
  try {
    final api = ref.watch(apiClientProvider);
    final d = await api.getJson('/health-tip');
    return {
      'tip': (d['tip']?['tip'] as String?) ?? '',
      'category': (d['tip']?['category'] as String?) ?? 'Wellness',
    };
  } catch (_) {
    return {
      'tip': 'Drink a glass of water before every meal to reduce hunger and stay hydrated.',
      'category': 'Hydration',
    };
  }
});

// Weekly progress
final weeklyProgressProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(currentUserKeyProvider);
  final api = ref.watch(apiClientProvider);
  return await api.getJson('/weekly-progress');
});
