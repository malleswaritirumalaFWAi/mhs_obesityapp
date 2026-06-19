import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../state/session.dart';

/// Tracks which meals the user has logged today and exposes progress
/// towards the "Log a meal" task (all 3 main meals: Breakfast + Lunch + Dinner).
class MealStats {
  const MealStats({this.logged = const {}, this.loading = false});
  final Set<String> logged;
  final bool loading;

  static const _mainTypes = {'Breakfast', 'Lunch', 'Dinner'};

  Set<String> get mainLogged => logged.intersection(_mainTypes);
  int get mainCount => mainLogged.length;
  bool get isComplete => mainCount >= 3;
  String get progressLabel => '$mainCount/3 meals';
  bool has(String type) => logged.contains(type);
}

class MealStatsNotifier extends StateNotifier<MealStats> {
  MealStatsNotifier(this._api) : super(const MealStats(loading: true)) {
    _fetch();
  }

  final ApiClient _api;

  static String _prefsKey() {
    final d = DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return 'meal_types_${d.year}_${m}_$day';
  }

  Future<void> _fetch() async {
    final now = DateTime.now();
    try {
      final res = await _api.getJson('/meals');
      final raw = (res['meals'] as List?) ?? [];
      final logged = <String>{};
      for (final m in raw) {
        final map = Map<String, dynamic>.from(m as Map);
        final ca = (DateTime.tryParse(map['created_at'] as String? ?? '') ??
                DateTime(0))
            .toLocal();
        final isToday = ca.year == now.year &&
            ca.month == now.month &&
            ca.day == now.day;
        if (isToday) {
          final mt = (map['meal_type'] as String?) ?? '';
          if (mt.isNotEmpty) logged.add(mt);
        }
      }
      await _saveToPrefs(logged);
      if (mounted) state = MealStats(logged: logged);
    } catch (_) {
      // Fallback to local cache for the current day.
      final cached = await _loadFromPrefs();
      if (mounted) state = MealStats(logged: cached ?? {});
    }
  }

  Future<void> refresh() => _fetch();

  /// Optimistically records a new meal type immediately after saving,
  /// so the progress indicator updates without waiting for a re-fetch.
  void addMealType(String mealType) {
    if (!mounted) return;
    final updated = {...state.logged, mealType};
    state = MealStats(logged: updated);
    _saveToPrefs(updated);
  }

  Future<void> _saveToPrefs(Set<String> logged) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey(), jsonEncode(logged.toList()));
    } catch (_) {}
  }

  Future<Set<String>?> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefsKey());
      if (cached == null) return null;
      final list = (jsonDecode(cached) as List).cast<String>();
      return Set.from(list);
    } catch (_) {
      return null;
    }
  }
}

final mealStatsProvider =
    StateNotifierProvider<MealStatsNotifier, MealStats>((ref) {
  ref.watch(currentUserKeyProvider);
  return MealStatsNotifier(ref.watch(apiClientProvider));
});
