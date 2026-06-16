import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../config.dart';
import '../state/session.dart';

class TaskItem {
  const TaskItem({
    required this.id,
    required this.slot,
    required this.time,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.xp,
    required this.done,
    this.completedAt,
  });

  final int id;
  final String slot;
  final String time;       // template/scheduled time e.g. "07:00"
  final String icon;
  final String title;
  final String subtitle;
  final int xp;
  final bool done;
  final DateTime? completedAt; // actual completion timestamp

  /// Returns the time to display: actual completion time if done, else scheduled.
  String get displayTime {
    if (done && completedAt != null) {
      final h = completedAt!.hour.toString().padLeft(2, '0');
      final m = completedAt!.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return time;
  }

  TaskItem copyWith({bool? done, DateTime? completedAt}) => TaskItem(
        id: id,
        slot: slot,
        time: time,
        icon: icon,
        title: title,
        subtitle: subtitle,
        xp: xp,
        done: done ?? this.done,
        completedAt: completedAt ?? this.completedAt,
      );

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: (j['id'] as num).toInt(),
        slot: (j['slot'] as String?) ?? '',
        time: (j['time'] as String?) ?? '',
        icon: (j['icon'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        subtitle: (j['subtitle'] as String?) ?? '',
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        done: j['done'] == true,
        completedAt: j['completed_at'] != null
            ? DateTime.tryParse(j['completed_at'] as String)?.toLocal()
            : null,
      );
}

class TasksState {
  const TasksState({
    this.tasks = const [],
    this.day = 1,
    this.loading = false,
    this.error,
  });

  final List<TaskItem> tasks;
  final int day;
  final bool loading;
  final String? error;

  int get done => tasks.where((t) => t.done).length;
  int get total => tasks.length;

  TasksState copyWith({
    List<TaskItem>? tasks,
    int? day,
    bool? loading,
    String? error,
  }) =>
      TasksState(
        tasks: tasks ?? this.tasks,
        day: day ?? this.day,
        loading: loading ?? this.loading,
        error: error,
      );
}

// Shown when backend is unreachable (demo / offline mode).
// Negative IDs mark them as local-only (no API call on complete).
const _demoTasks = [
  TaskItem(id: -1, slot: 'morning',   time: '07:00', icon: 'wb_sunny',       title: 'Morning check-in',  subtitle: 'Log mood & weight · +10 XP', xp: 10, done: false),
  TaskItem(id: -2, slot: 'morning',   time: '08:30', icon: 'restaurant',     title: 'Log a meal',        subtitle: 'Breakfast · lunch · snack · dinner',  xp: 5,  done: false),
  TaskItem(id: -4, slot: 'afternoon', time: '16:00', icon: 'water_drop',     title: 'Hydration check',   subtitle: '8 glasses daily target',     xp: 5,  done: false),
  TaskItem(id: -5, slot: 'evening',   time: '19:30', icon: 'directions_run', title: '8,000 step walk',   subtitle: 'Daily movement goal',        xp: 10, done: false),
  TaskItem(id: -6, slot: 'evening',   time: '21:45', icon: 'scale',          title: 'Evening weigh-in',  subtitle: '5 min before bed',           xp: 5,  done: false),
];

class TasksNotifier extends StateNotifier<TasksState> {
  TasksNotifier(this._api) : super(const TasksState(loading: true)) {
    fetch();
    _scheduleMidnightRefresh();
  }

  final ApiClient _api;
  String? _lastFetchDate;
  Timer? _midnightTimer;

  /// True when the calendar date has changed since tasks were last fetched.
  bool get isDateChanged {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _lastFetchDate != null && _lastFetchDate != today;
  }

  /// Schedule a one-shot timer that fires at the next midnight.
  /// On trigger, re-fetch so the day counter advances and tasks reset.
  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now);
    _midnightTimer = Timer(delay, () {
      if (mounted) {
        fetch();
        _scheduleMidnightRefresh(); // arm next midnight
      }
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  Future<void> fetch() async {
    _lastFetchDate = DateTime.now().toIso8601String().substring(0, 10);
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.getJson('/today');
      final rawTasks = (res['tasks'] as List?) ?? [];
      final tasks = rawTasks
          .map((t) => TaskItem.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList();
      state = TasksState(
        // In demo mode, fall back to demo tasks when API returns empty.
        tasks: tasks.isNotEmpty ? tasks : (AppConfig.demoMode ? _demoTasks : []),
        day: (res['day'] as num?)?.toInt() ?? 1,
        loading: false,
      );
    } catch (_) {
      if (AppConfig.demoMode) {
        // Demo mode: show placeholder tasks so the screen is never blank.
        state = TasksState(
          tasks: _demoTasks,
          day: state.day > 1 ? state.day : 1,
          loading: false,
        );
      } else {
        // Production: show an error rather than fake data.
        state = state.copyWith(
          loading: false,
          error: 'Could not load tasks. Check your connection.',
        );
      }
    }
  }

  Future<void> complete(int taskId) async {
    // Optimistic update immediately with actual timestamp.
    final now = DateTime.now();
    state = state.copyWith(
      tasks: state.tasks
          .map((t) => t.id == taskId
              ? t.copyWith(done: true, completedAt: now)
              : t)
          .toList(),
    );
    // Demo tasks (negative IDs) are local-only — skip API call.
    if (taskId < 0) return;
    try {
      await _api.postJson('/today/task/$taskId/complete', null);
    } catch (_) {
      // Revert on failure.
      state = state.copyWith(
        tasks: state.tasks
            .map((t) => t.id == taskId ? t.copyWith(done: false) : t)
            .toList(),
      );
    }
  }
}

final tasksProvider =
    StateNotifierProvider<TasksNotifier, TasksState>((ref) {
  ref.watch(currentUserKeyProvider);
  return TasksNotifier(ref.watch(apiClientProvider));
});
