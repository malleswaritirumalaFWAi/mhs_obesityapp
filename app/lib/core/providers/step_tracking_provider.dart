import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer_2/pedometer_2.dart';
import '../api/api_client.dart';
import '../state/session.dart';
import 'daily_stats_provider.dart';

class StepTrackingState {
  const StepTrackingState({
    this.isTracking = false,
    this.todaySteps = 0,
    this.permissionGranted = false,
    this.error,
  });
  final bool isTracking;
  final int todaySteps;
  final bool permissionGranted;
  final String? error;

  StepTrackingState copyWith({bool? isTracking, int? todaySteps, bool? permissionGranted, String? error}) =>
    StepTrackingState(
      isTracking: isTracking ?? this.isTracking,
      todaySteps: todaySteps ?? this.todaySteps,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      error: error,
    );
}

class StepTrackingNotifier extends StateNotifier<StepTrackingState> {
  StepTrackingNotifier(this._api, this._statsNotifier) : super(const StepTrackingState());
  final ApiClient _api;
  final DailyStatsNotifier _statsNotifier;
  StreamSubscription<int>? _subscription;
  int? _baselineSteps;

  Future<void> startTracking() async {
    try {
      _subscription?.cancel();
      final pedometer = Pedometer();
      final stream = pedometer.stepCountStream();
      _subscription = stream.listen(
        (steps) {
          _baselineSteps ??= steps;
          final todaySteps = steps - (_baselineSteps ?? 0);
          state = state.copyWith(
            isTracking: true,
            todaySteps: todaySteps,
            permissionGranted: true,
          );
          // Sync to backend periodically (every 500 steps)
          if (todaySteps > 0 && todaySteps % 500 == 0) {
            _syncToBackend(todaySteps);
          }
        },
        onError: (e) {
          state = state.copyWith(
            isTracking: false,
            error: 'Step sensor unavailable. Use manual entry.',
          );
        },
      );
      state = state.copyWith(isTracking: true, permissionGranted: true);
    } catch (e) {
      state = state.copyWith(
        isTracking: false,
        error: 'Could not access step sensor.',
      );
    }
  }

  Future<void> _syncToBackend(int steps) async {
    try {
      await _api.postJson('/stats/today', {'steps': steps});
      _statsNotifier.updateSteps(steps);
    } catch (_) {}
  }

  Future<void> syncNow() async {
    if (state.todaySteps > 0) {
      await _syncToBackend(state.todaySteps);
    }
  }

  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
    state = state.copyWith(isTracking: false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final stepTrackingProvider = StateNotifierProvider<StepTrackingNotifier, StepTrackingState>((ref) {
  ref.watch(currentUserKeyProvider);
  final api = ref.watch(apiClientProvider);
  final statsNotifier = ref.watch(dailyStatsProvider.notifier);
  return StepTrackingNotifier(api, statsNotifier);
});
