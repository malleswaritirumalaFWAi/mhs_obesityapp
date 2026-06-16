import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../state/session.dart';

class DailyStats {
  const DailyStats({
    this.steps = 0,
    this.water = 0,
    this.sleep = 0.0,
    this.loading = false,
  });

  final int steps;
  final int water;    // glasses 0-8
  final double sleep; // hours
  final bool loading;

  DailyStats copyWith({int? steps, int? water, double? sleep, bool? loading}) =>
      DailyStats(
        steps: steps ?? this.steps,
        water: water ?? this.water,
        sleep: sleep ?? this.sleep,
        loading: loading ?? this.loading,
      );

  String get stepsLabel =>
      steps >= 1000 ? '${(steps / 1000).toStringAsFixed(1)}k' : '$steps';
  String get waterLabel => '$water/8';
  String get sleepLabel => sleep > 0 ? '${sleep.toStringAsFixed(1)}h' : '0h';

  String get stepsSub => steps >= 8000 ? '+${steps - 8000} ✓' : '${8000 - steps} to go';
  String get waterSub => water >= 8 ? 'target reached ✓' : '${8 - water} more';
  String get sleepSub => sleep >= 7 ? 'restful ✓' : 'aim for 7h+';
}

class DailyStatsNotifier extends StateNotifier<DailyStats> {
  DailyStatsNotifier(this._api) : super(const DailyStats(loading: true)) {
    _fetch();
  }

  final ApiClient _api;

  Future<void> _fetch() async {
    try {
      final res = await _api.getJson('/stats/today');
      state = DailyStats(
        steps: (res['steps'] as num?)?.toInt() ?? 0,
        water: (res['water'] as num?)?.toInt() ?? 0,
        sleep: double.tryParse(res['sleep']?.toString() ?? '0') ?? 0.0,
      );
    } catch (_) {
      state = const DailyStats(); // fallback to zeros
    }
  }

  Future<void> updateSteps(int steps) async {
    state = state.copyWith(steps: steps);
    try {
      await _api.postJson('/stats/today', {'steps': steps});
    } catch (_) {
      // Keep optimistic state — value already saved via /movement/add
    }
  }

  Future<void> updateWater(int glasses) async {
    state = state.copyWith(water: glasses.clamp(0, 8));
    try {
      await _api.postJson('/stats/today', {'water': glasses.clamp(0, 8)});
    } catch (_) {
      // Keep optimistic state — value already saved via /hydration/add
    }
  }

  Future<void> updateSleep(double hours) async {
    state = state.copyWith(sleep: hours.clamp(0, 24));
    try {
      await _api.postJson('/stats/today', {'sleep': hours.clamp(0, 24)});
    } catch (_) {
      // Keep optimistic state
    }
  }
}

final dailyStatsProvider =
    StateNotifierProvider<DailyStatsNotifier, DailyStats>((ref) {
  ref.watch(currentUserKeyProvider);
  return DailyStatsNotifier(ref.watch(apiClientProvider));
});
