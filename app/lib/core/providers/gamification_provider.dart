import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../state/session.dart';

// ── Tier utility ─────────────────────────────────────────────────────────────
// Mirrors the LEVELS array in backend/src/routes/gamification.js.

class XpTier {
  const XpTier({required this.name, required this.label, required this.emoji,
    required this.min, this.nextMin});
  final String name, label, emoji;
  final int min;
  final int? nextMin;
}

const List<XpTier> xpTiers = [
  XpTier(name: 'bronze',   label: 'Bronze',   emoji: '🥉', min: 0,     nextMin: 1000),
  XpTier(name: 'silver',   label: 'Silver',   emoji: '🥈', min: 1000,  nextMin: 3000),
  XpTier(name: 'gold',     label: 'Gold',     emoji: '🥇', min: 3000,  nextMin: 6000),
  XpTier(name: 'platinum', label: 'Platinum', emoji: '💎', min: 6000,  nextMin: 10000),
  XpTier(name: 'diamond',  label: 'Diamond',  emoji: '👑', min: 10000, nextMin: null),
];

/// Returns the tier for [totalXp]. Matches backend gamification.js LEVELS array.
XpTier getTierFromXP(int totalXp) {
  for (var i = xpTiers.length - 1; i >= 0; i--) {
    if (totalXp >= xpTiers[i].min) return xpTiers[i];
  }
  return xpTiers.first;
}

class LevelInfo {
  const LevelInfo({required this.name, required this.label, required this.emoji,
    required this.totalXp, this.nextThreshold, this.progressToNext});
  final String name, label, emoji;
  final int totalXp;
  final int? nextThreshold, progressToNext;
}

class GamificationState {
  const GamificationState({
    this.xp = 0, this.totalXp = 0, this.streak = 0,
    this.streakFreezes = 0, this.royalRank,
    this.level = const LevelInfo(name:'bronze',label:'Bronze',emoji:'🥉',totalXp:0),
    this.loading = false,
    this.doubleXpActive = false,
    this.doubleXpExpiresAt,
    this.cheatMealPasses = 0,
  });
  final int xp, totalXp, streak, streakFreezes;
  final int? royalRank;
  final LevelInfo level;
  final bool loading;
  final bool doubleXpActive;
  final DateTime? doubleXpExpiresAt;
  final int cheatMealPasses;

  GamificationState copyWith({int? xp, int? totalXp, int? streak,
    int? streakFreezes, int? royalRank, LevelInfo? level, bool? loading,
    bool? doubleXpActive, DateTime? doubleXpExpiresAt, int? cheatMealPasses}) =>
    GamificationState(
      xp: xp ?? this.xp, totalXp: totalXp ?? this.totalXp,
      streak: streak ?? this.streak, streakFreezes: streakFreezes ?? this.streakFreezes,
      royalRank: royalRank ?? this.royalRank,
      level: level ?? this.level, loading: loading ?? this.loading,
      doubleXpActive: doubleXpActive ?? this.doubleXpActive,
      doubleXpExpiresAt: doubleXpExpiresAt ?? this.doubleXpExpiresAt,
      cheatMealPasses: cheatMealPasses ?? this.cheatMealPasses,
    );
}

class GamificationNotifier extends StateNotifier<GamificationState> {
  GamificationNotifier(this._api) : super(const GamificationState()) { load(); }
  final ApiClient _api;

  Future<void> load() async {
    state = state.copyWith(loading: true);
    try {
      final d = await _api.getJson('/gamification/status');
      final l = d['level'] as Map<String, dynamic>? ?? {};
      final expiresStr = d['double_xp_expires_at'] as String?;
      final expiresAt = expiresStr != null ? DateTime.tryParse(expiresStr) : null;
      state = GamificationState(
        xp: (d['xp'] as num?)?.toInt() ?? 0,
        totalXp: (d['total_xp'] as num?)?.toInt() ?? 0,
        streak: (d['streak'] as num?)?.toInt() ?? 0,
        streakFreezes: (d['streak_freezes'] as num?)?.toInt() ?? 0,
        royalRank: (d['royal_rank'] as num?)?.toInt(),
        level: LevelInfo(
          name: l['name'] as String? ?? 'bronze',
          label: l['label'] as String? ?? 'Bronze',
          emoji: l['emoji'] as String? ?? '🥉',
          totalXp: (d['total_xp'] as num?)?.toInt() ?? 0,
          nextThreshold: (l['next_threshold'] as num?)?.toInt(),
          progressToNext: (l['progress_to_next'] as num?)?.toInt(),
        ),
        doubleXpActive: d['double_xp_active'] as bool? ?? false,
        doubleXpExpiresAt: expiresAt,
        cheatMealPasses: (d['cheat_meal_passes'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {}
  }

  Future<bool> useFreeze() async {
    try {
      await _api.postJson('/gamification/freeze/use', {});
      state = state.copyWith(streakFreezes: (state.streakFreezes - 1).clamp(0, 99));
      return true;
    } catch (_) { return false; }
  }

  Future<bool> buyFreeze() async {
    try {
      await _api.postJson('/gamification/freeze/buy', {});
      state = state.copyWith(
        xp: (state.xp - 500).clamp(0, 999999),
        totalXp: (state.totalXp - 500).clamp(0, 999999),
        streakFreezes: state.streakFreezes + 1,
      );
      return true;
    } catch (_) { return false; }
  }
}

final gamificationProvider = StateNotifierProvider<GamificationNotifier, GamificationState>(
  (ref) {
    ref.watch(currentUserKeyProvider);
    return GamificationNotifier(ref.watch(apiClientProvider));
  },
);
