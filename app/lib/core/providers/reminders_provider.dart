import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../state/session.dart';

class Reminder {
  const Reminder({required this.type, required this.time, required this.enabled});
  final String type;
  final String time; // HH:mm
  final bool enabled;
}

class RemindersNotifier extends StateNotifier<List<Reminder>> {
  RemindersNotifier(this._api) : super([]) { load(); }
  final ApiClient _api;

  Future<void> load() async {
    try {
      final d = await _api.getJson('/reminders');
      final list = (d['reminders'] as List? ?? []).map((r) {
        final m = r as Map<String, dynamic>;
        return Reminder(
          type: m['type'] as String? ?? '',
          time: m['time'] as String? ?? '08:00',
          enabled: m['enabled'] as bool? ?? true,
        );
      }).toList();
      state = list;
    } catch (_) {}
  }

  Future<void> save(String type, String time, bool enabled) async {
    try {
      await _api.postJson('/reminders', {'type': type, 'time': time, 'enabled': enabled});
      await load();
    } catch (_) {}
  }
}

final remindersProvider = StateNotifierProvider<RemindersNotifier, List<Reminder>>(
  (ref) {
    ref.watch(currentUserKeyProvider);
    return RemindersNotifier(ref.watch(apiClientProvider));
  },
);
