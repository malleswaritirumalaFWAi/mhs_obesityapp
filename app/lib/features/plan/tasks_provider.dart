import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/state/session.dart';

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
  });

  final int id;
  final String slot;
  final String time;
  final String icon;
  final String title;
  final String subtitle;
  final int xp;
  final bool done;

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        slot: j['slot'] as String? ?? 'Morning',
        time: j['time'] as String? ?? '',
        icon: j['icon'] as String? ?? '',
        title: j['title'] as String? ?? '',
        subtitle: j['subtitle'] as String? ?? '',
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        done: j['done'] as bool? ?? false,
      );

  TaskItem copyWith({bool? done}) => TaskItem(
        id: id,
        slot: slot,
        time: time,
        icon: icon,
        title: title,
        subtitle: subtitle,
        xp: xp,
        done: done ?? this.done,
      );
}

List<TaskItem> _demoTasks() => const [
      TaskItem(id: 1, slot: 'Morning', time: '07:00', icon: 'wb_sunny', title: 'Morning check-in', subtitle: 'Log mood & weight', xp: 10, done: true),
      TaskItem(id: 2, slot: 'Morning', time: '08:00', icon: 'restaurant', title: 'Log breakfast', subtitle: 'Take a photo or search', xp: 10, done: false),
      TaskItem(id: 3, slot: 'Afternoon', time: '13:00', icon: 'lunch_dining', title: 'Log lunch', subtitle: 'Take a photo or search', xp: 10, done: false),
      TaskItem(id: 4, slot: 'Afternoon', time: '14:30', icon: 'directions_walk', title: '30-min walk', subtitle: 'Brisk walking outdoors', xp: 15, done: false),
      TaskItem(id: 5, slot: 'Evening', time: '19:00', icon: 'water_drop', title: 'Hydration check', subtitle: 'Drink 8 glasses today', xp: 5, done: false),
      TaskItem(id: 6, slot: 'Evening', time: '22:00', icon: 'bedtime', title: 'Sleep wind-down', subtitle: 'Lights out by 10 PM', xp: 10, done: false),
    ];

class TasksNotifier extends AsyncNotifier<List<TaskItem>> {
  @override
  Future<List<TaskItem>> build() {
    ref.watch(currentUserKeyProvider);
    return _fetch();
  }

  Future<List<TaskItem>> _fetch() async {
    try {
      final json = await ref.read(apiClientProvider).getJson('/today');
      final tasks = json['tasks'] as List? ?? [];
      return tasks.map((t) => TaskItem.fromJson(t as Map<String, dynamic>)).toList();
    } catch (_) {
      if (AppConfig.demoMode) return _demoTasks();
      rethrow;
    }
  }

  Future<void> completeTask(int taskId) async {
    await ref.read(apiClientProvider).postJson('/today/task/$taskId/complete', null);
    state = state.whenData(
      (tasks) => tasks.map((t) => t.id == taskId ? t.copyWith(done: true) : t).toList(),
    );
  }
}

final tasksProvider =
    AsyncNotifierProvider<TasksNotifier, List<TaskItem>>(TasksNotifier.new);
