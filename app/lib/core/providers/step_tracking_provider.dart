import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer_2/pedometer_2.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../state/session.dart';
import 'daily_stats_provider.dart';

// SharedPreferences keys
const _kTrackingEnabled = 'step_tracking_enabled';
const _kBaselineSteps = 'step_baseline';
const _kBaselineDate = 'step_baseline_date';
const _kLastSyncedSteps = 'step_last_synced';

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
  StepTrackingNotifier(this._api, this._statsNotifier) : super(const StepTrackingState()) {
    _restoreState();
  }
  final ApiClient _api;
  final DailyStatsNotifier _statsNotifier;
  StreamSubscription<int>? _subscription;
  int? _baselineSteps;
  int _lastSyncedSteps = 0;

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Restore previous tracking state on app launch.
  Future<void> _restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasEnabled = prefs.getBool(_kTrackingEnabled) ?? false;
      if (wasEnabled) {
        await startTracking();
      }
    } catch (e) {
      debugPrint('StepTracking: restore failed: $e');
    }
  }

  /// Load persisted baseline for today (or reset if it's a new day).
  Future<void> _loadBaseline(SharedPreferences prefs) async {
    final savedDate = prefs.getString(_kBaselineDate) ?? '';
    if (savedDate == _todayDate) {
      _baselineSteps = prefs.getInt(_kBaselineSteps);
      _lastSyncedSteps = prefs.getInt(_kLastSyncedSteps) ?? 0;
    } else {
      // New day — baseline will be set from the first sensor reading.
      _baselineSteps = null;
      _lastSyncedSteps = 0;
    }
  }

  /// Persist baseline so it survives app restarts.
  Future<void> _saveBaseline(int baseline) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBaselineSteps, baseline);
    await prefs.setString(_kBaselineDate, _todayDate);
  }

  Future<void> startTracking() async {
    try {
      // Request runtime permission (required on Android 10+).
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        state = state.copyWith(
          isTracking: false,
          permissionGranted: false,
          error: 'Activity permission denied. Enable it in Settings.',
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kTrackingEnabled, true);
      await _loadBaseline(prefs);

      _subscription?.cancel();
      final pedometer = Pedometer();
      final stream = pedometer.stepCountStream();
      _subscription = stream.listen(
        (totalSteps) {
          // First reading of the day — set baseline.
          if (_baselineSteps == null) {
            _baselineSteps = totalSteps;
            _saveBaseline(totalSteps);
          }

          // If sensor restarted (reboot) and total < baseline, reset.
          if (totalSteps < _baselineSteps!) {
            _baselineSteps = totalSteps;
            _saveBaseline(totalSteps);
          }

          final todaySteps = totalSteps - _baselineSteps!;
          state = state.copyWith(
            isTracking: true,
            todaySteps: todaySteps,
            permissionGranted: true,
          );

          // Sync to backend every 100 steps (only the delta).
          if (todaySteps > 0 && todaySteps - _lastSyncedSteps >= 100) {
            _lastSyncedSteps = todaySteps;
            _syncToBackend(todaySteps);
            _persistLastSynced(todaySteps);
          }
        },
        onError: (e) {
          debugPrint('StepTracking: sensor error: $e');
          state = state.copyWith(
            isTracking: false,
            error: 'Step sensor unavailable. Use manual entry.',
          );
        },
      );
      state = state.copyWith(isTracking: true, permissionGranted: true);
    } catch (e) {
      debugPrint('StepTracking: startTracking failed: $e');
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
    } catch (e) {
      debugPrint('StepTracking: sync failed: $e');
    }
  }

  Future<void> _persistLastSynced(int steps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastSyncedSteps, steps);
    } catch (_) {}
  }

  Future<void> syncNow() async {
    if (state.todaySteps > 0) {
      await _syncToBackend(state.todaySteps);
      _lastSyncedSteps = state.todaySteps;
      await _persistLastSynced(state.todaySteps);
    }
  }

  Future<void> stopTracking() async {
    _subscription?.cancel();
    _subscription = null;
    state = state.copyWith(isTracking: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kTrackingEnabled, false);
    } catch (_) {}
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
