import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../state/session.dart';

class FastingState {
  const FastingState({
    this.active = false,
    this.sessionId,
    this.startedAt,
    this.targetHours = 16,
    this.history = const [],
    this.loading = false,
  });
  final bool active, loading;
  final int? sessionId;
  final DateTime? startedAt;
  final int targetHours;
  final List<Map<String, dynamic>> history;

  Duration get elapsed => startedAt != null ? DateTime.now().difference(startedAt!) : Duration.zero;
  double get progress => targetHours > 0 ? (elapsed.inMinutes / (targetHours * 60)).clamp(0.0, 1.0) : 0;
  bool get completed => progress >= 1.0;

  FastingState copyWith({bool? active, int? sessionId, DateTime? startedAt,
    int? targetHours, List<Map<String,dynamic>>? history, bool? loading}) =>
    FastingState(
      active: active ?? this.active,
      sessionId: sessionId ?? this.sessionId,
      startedAt: startedAt ?? this.startedAt,
      targetHours: targetHours ?? this.targetHours,
      history: history ?? this.history,
      loading: loading ?? this.loading,
    );
}

class FastingNotifier extends StateNotifier<FastingState> {
  FastingNotifier(this._api) : super(const FastingState()) { load(); }
  final ApiClient _api;
  Timer? _ticker;

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
      if (a != null) {
        state = FastingState(
          active: true,
          sessionId: (a['id'] as num).toInt(),
          startedAt: DateTime.parse(a['started_at'] as String),
          targetHours: (a['target_hours'] as num?)?.toInt() ?? 16,
          history: history,
        );
        _startTicker();
      } else {
        state = FastingState(history: history);
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
      final d = await _api.postJson('/fasting/stop', {});
      _ticker?.cancel();
      state = FastingState(history: state.history);
      load();
      return d;
    } catch (_) { return {}; }
  }
}

final fastingProvider = StateNotifierProvider<FastingNotifier, FastingState>(
  (ref) {
    ref.watch(currentUserKeyProvider);
    return FastingNotifier(ref.watch(apiClientProvider));
  },
);
