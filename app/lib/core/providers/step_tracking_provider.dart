import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
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
const _kUseHealthConnect = 'step_use_health_connect';

/// Step source — Health Connect (preferred) or device pedometer (fallback).
enum StepSource { healthConnect, pedometer, none }

class StepTrackingState {
  const StepTrackingState({
    this.isTracking = false,
    this.todaySteps = 0,
    this.permissionGranted = false,
    this.source = StepSource.none,
    this.error,
  });
  final bool isTracking;
  final int todaySteps;
  final bool permissionGranted;
  final StepSource source;
  final String? error;

  StepTrackingState copyWith({
    bool? isTracking,
    int? todaySteps,
    bool? permissionGranted,
    StepSource? source,
    String? error,
  }) =>
      StepTrackingState(
        isTracking: isTracking ?? this.isTracking,
        todaySteps: todaySteps ?? this.todaySteps,
        permissionGranted: permissionGranted ?? this.permissionGranted,
        source: source ?? this.source,
        error: error,
      );
}

class StepTrackingNotifier extends StateNotifier<StepTrackingState> {
  StepTrackingNotifier(this._api, this._statsNotifier)
      : super(const StepTrackingState()) {
    _restoreState();
  }

  final ApiClient _api;
  final DailyStatsNotifier _statsNotifier;
  StreamSubscription<int>? _pedometerSub;
  Timer? _healthPollTimer;
  int? _baselineSteps;
  int _lastSyncedSteps = 0;

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── Restore on launch ────────────────────────────────────────────────────

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

  // ── Public API ───────────────────────────────────────────────────────────

  Future<void> startTracking() async {
    // Try Health Connect first, fall back to pedometer.
    final hcStarted = await _tryHealthConnect();
    if (hcStarted) return;
    await _startPedometer();
  }

  Future<void> syncNow() async {
    // Re-read from Health Connect if active.
    if (state.source == StepSource.healthConnect) {
      await _readHealthConnectSteps();
    }
    if (state.todaySteps > 0) {
      await _syncToBackend(state.todaySteps);
      _lastSyncedSteps = state.todaySteps;
      await _persistLastSynced(state.todaySteps);
    }
  }

  Future<void> stopTracking() async {
    _pedometerSub?.cancel();
    _pedometerSub = null;
    _healthPollTimer?.cancel();
    _healthPollTimer = null;
    state = state.copyWith(isTracking: false, source: StepSource.none);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kTrackingEnabled, false);
    } catch (_) {}
  }

  // ── Health Connect ───────────────────────────────────────────────────────

  Future<bool> _tryHealthConnect() async {
    try {
      final health = Health();

      // Check if Health Connect is available on this device.
      final installed = await health.isHealthConnectAvailable();
      if (!installed) {
        debugPrint('StepTracking: Health Connect not available');
        return false;
      }

      // Request permissions.
      final types = [HealthDataType.STEPS];
      final permissions = [HealthDataAccess.READ];
      final granted = await health.requestAuthorization(types, permissions: permissions);
      if (!granted) {
        debugPrint('StepTracking: Health Connect permission denied');
        return false;
      }

      // Read steps immediately.
      await _readHealthConnectSteps();

      // Save state.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kTrackingEnabled, true);
      await prefs.setBool(_kUseHealthConnect, true);

      // Poll Health Connect every 30 seconds for updated counts.
      _healthPollTimer?.cancel();
      _healthPollTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _readHealthConnectSteps(),
      );

      state = state.copyWith(
        isTracking: true,
        permissionGranted: true,
        source: StepSource.healthConnect,
      );

      debugPrint('StepTracking: using Health Connect');
      return true;
    } catch (e) {
      debugPrint('StepTracking: Health Connect failed: $e');
      return false;
    }
  }

  Future<void> _readHealthConnectSteps() async {
    try {
      final health = Health();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      final steps = await health.getTotalStepsInInterval(midnight, now);
      final todaySteps = steps ?? 0;

      state = state.copyWith(
        todaySteps: todaySteps,
        isTracking: true,
        permissionGranted: true,
        source: StepSource.healthConnect,
      );

      // Auto-sync to backend every 100 steps.
      if (todaySteps > 0 && todaySteps - _lastSyncedSteps >= 100) {
        _lastSyncedSteps = todaySteps;
        _syncToBackend(todaySteps);
        _persistLastSynced(todaySteps);
      }
    } catch (e) {
      debugPrint('StepTracking: HC read failed: $e');
    }
  }

  // ── Pedometer fallback ───────────────────────────────────────────────────

  Future<void> _startPedometer() async {
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
      await prefs.setBool(_kUseHealthConnect, false);
      await _loadBaseline(prefs);

      _pedometerSub?.cancel();
      final pedometer = Pedometer();
      final stream = pedometer.stepCountStream();
      _pedometerSub = stream.listen(
        (totalSteps) {
          // First reading of the day — set baseline.
          if (_baselineSteps == null) {
            _baselineSteps = totalSteps;
            _saveBaseline(totalSteps);
          }

          // Sensor restarted (reboot) — reset baseline.
          if (totalSteps < _baselineSteps!) {
            _baselineSteps = totalSteps;
            _saveBaseline(totalSteps);
          }

          final todaySteps = totalSteps - _baselineSteps!;
          state = state.copyWith(
            isTracking: true,
            todaySteps: todaySteps,
            permissionGranted: true,
            source: StepSource.pedometer,
          );

          // Sync to backend every 100 steps.
          if (todaySteps > 0 && todaySteps - _lastSyncedSteps >= 100) {
            _lastSyncedSteps = todaySteps;
            _syncToBackend(todaySteps);
            _persistLastSynced(todaySteps);
          }
        },
        onError: (e) {
          debugPrint('StepTracking: pedometer error: $e');
          state = state.copyWith(
            isTracking: false,
            error: 'Step sensor unavailable. Use manual entry.',
          );
        },
      );

      state = state.copyWith(
        isTracking: true,
        permissionGranted: true,
        source: StepSource.pedometer,
      );
      debugPrint('StepTracking: using pedometer fallback');
    } catch (e) {
      debugPrint('StepTracking: pedometer failed: $e');
      state = state.copyWith(
        isTracking: false,
        error: 'Could not access step sensor.',
      );
    }
  }

  // ── Baseline persistence (pedometer only) ────────────────────────────────

  Future<void> _loadBaseline(SharedPreferences prefs) async {
    final savedDate = prefs.getString(_kBaselineDate) ?? '';
    if (savedDate == _todayDate) {
      _baselineSteps = prefs.getInt(_kBaselineSteps);
      _lastSyncedSteps = prefs.getInt(_kLastSyncedSteps) ?? 0;
    } else {
      _baselineSteps = null;
      _lastSyncedSteps = 0;
    }
  }

  Future<void> _saveBaseline(int baseline) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBaselineSteps, baseline);
    await prefs.setString(_kBaselineDate, _todayDate);
  }

  // ── Backend sync ─────────────────────────────────────────────────────────

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

  @override
  void dispose() {
    _pedometerSub?.cancel();
    _healthPollTimer?.cancel();
    super.dispose();
  }
}

final stepTrackingProvider =
    StateNotifierProvider<StepTrackingNotifier, StepTrackingState>((ref) {
  ref.watch(currentUserKeyProvider);
  final api = ref.watch(apiClientProvider);
  final statsNotifier = ref.watch(dailyStatsProvider.notifier);
  return StepTrackingNotifier(api, statsNotifier);
});
