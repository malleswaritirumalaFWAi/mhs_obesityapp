import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../state/session.dart';

class FastingStats {
  const FastingStats({
    this.totalCompleted = 0,
    this.totalHours = 0.0,
    this.thisWeek = 0,
  });
  final int totalCompleted;
  final double totalHours;
  final int thisWeek;
}

class FastingState {
  const FastingState({
    this.active = false,
    this.sessionId,
    this.startedAt,
    this.targetHours = 16,
    this.history = const [],
    this.loading = false,
    this.stats = const FastingStats(),
  });
  final bool active, loading;
  final int? sessionId;
  final DateTime? startedAt;
  final int targetHours;
  final List<Map<String, dynamic>> history;
  final FastingStats stats;

  Duration get elapsed => startedAt != null ? DateTime.now().difference(startedAt!) : Duration.zero;
  Duration get remaining {
    if (!active) return Duration.zero;
    final target = Duration(hours: targetHours);
    final diff = target - elapsed;
    return diff.isNegative ? Duration.zero : diff;
  }
  DateTime? get breakFastAt => (active && startedAt != null)
      ? startedAt!.add(Duration(hours: targetHours))
      : null;
  double get progress => targetHours > 0 ? (elapsed.inMinutes / (targetHours * 60)).clamp(0.0, 1.0) : 0;
  bool get completed => progress >= 1.0;

  /// Current metabolic phase index (0–5) based on elapsed hours.
  int get phaseIndex {
    final h = elapsed.inMinutes / 60.0;
    if (h >= 18) return 5;
    if (h >= 16) return 4;
    if (h >= 12) return 3;
    if (h >= 8)  return 2;
    if (h >= 4)  return 1;
    return 0;
  }

  FastingState copyWith({bool? active, int? sessionId, DateTime? startedAt,
    int? targetHours, List<Map<String,dynamic>>? history, bool? loading,
    FastingStats? stats}) =>
    FastingState(
      active: active ?? this.active,
      sessionId: sessionId ?? this.sessionId,
      startedAt: startedAt ?? this.startedAt,
      targetHours: targetHours ?? this.targetHours,
      history: history ?? this.history,
      loading: loading ?? this.loading,
      stats: stats ?? this.stats,
    );
}

class FastingNotifier extends StateNotifier<FastingState> {
  FastingNotifier(this._api) : super(const FastingState()) { load(); }
  final ApiClient _api;
  Timer? _ticker;

  /// Timestamp when the last fast was stopped — used to gate the undo window.
  DateTime? _stoppedAt;
  int _lastTargetHours = 16;

  bool get canUndo =>
      _stoppedAt != null &&
      DateTime.now().difference(_stoppedAt!).inSeconds < 300; // 5 min window

  @override
  void dispose() { _ticker?.cancel(); super.dispose(); }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && state.active) state = state.copyWith();
    });
  }

  Future<void> load() async {
    state = state.copyWith(loading: true);
    try {
      final d = await _api.getJson('/fasting');
      final a = d['active'] as Map<String, dynamic>?;
      final history = (d['history'] as List? ?? []).cast<Map<String, dynamic>>();
      final s = d['stats'] as Map<String, dynamic>? ?? {};
      final stats = FastingStats(
        totalCompleted: (s['total_completed'] as num?)?.toInt() ?? 0,
        totalHours: (s['total_hours'] as num?)?.toDouble() ?? 0.0,
        thisWeek: (s['this_week'] as num?)?.toInt() ?? 0,
      );
      if (a != null) {
        state = FastingState(
          active: true,
          sessionId: (a['id'] as num).toInt(),
          startedAt: DateTime.parse(a['started_at'] as String),
          targetHours: (a['target_hours'] as num?)?.toInt() ?? 16,
          history: history,
          stats: stats,
        );
        _startTicker();
      } else {
        state = FastingState(history: history, stats: stats);
      }
    } catch (_) { state = const FastingState(); }
  }

  Future<void> start(int targetHours) async {
    try {
      final d = await _api.postJson('/fasting/start', {'target_hours': targetHours});
      final s = d['session'] as Map<String, dynamic>?;
      state = FastingState(
        active: true,
        sessionId: (s?['id'] as num?)?.toInt(),
        startedAt: DateTime.now(),
        targetHours: targetHours,
        history: state.history,
      );
      _startTicker();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> stop() async {
    try {
      _lastTargetHours = state.targetHours;
      final d = await _api.postJson('/fasting/stop', {});
      _ticker?.cancel();
      _stoppedAt = DateTime.now();
      state = FastingState(history: state.history);
      load();
      return d;
    } catch (_) { return {}; }
  }

  /// Undo the last stop if called within 5 minutes.
  Future<bool> resume() async {
    try {
      final d = await _api.postJson('/fasting/resume', {});
      final s = d['session'] as Map<String, dynamic>?;
      if (s == null) return false;
      _stoppedAt = null;
      state = FastingState(
        active: true,
        sessionId: (s['id'] as num?)?.toInt(),
        startedAt: DateTime.parse(s['started_at'] as String),
        targetHours: (s['target_hours'] as num?)?.toInt() ?? _lastTargetHours,
        history: state.history,
      );
      _startTicker();
      return true;
    } catch (_) { return false; }
  }
}

final fastingProvider = StateNotifierProvider<FastingNotifier, FastingState>(
  (ref) {
    ref.watch(currentUserKeyProvider);
    return FastingNotifier(ref.watch(apiClientProvider));
  },
);
