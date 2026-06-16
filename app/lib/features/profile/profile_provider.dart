import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/state/session.dart';

// PostgreSQL NUMERIC columns come back as strings — handle both.
double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

class BadgeItem {
  const BadgeItem({required this.emoji, required this.name});
  final String emoji;
  final String name;

  factory BadgeItem.fromJson(Map<String, dynamic> j) => BadgeItem(
        emoji: j['emoji'] as String? ?? '🏅',
        name: j['name'] as String? ?? '',
      );
}

class ProfileData {
  const ProfileData({
    required this.name,
    required this.phone,
    required this.xp,
    required this.streak,
    required this.startWeight,
    required this.currentWeight,
    required this.targetWeight,
    required this.badges,
    this.rank = 0,
  });

  final String name;
  final String phone;
  final int xp;
  final int streak;
  final double startWeight;
  final double currentWeight;
  final double targetWeight;
  final List<BadgeItem> badges;
  final int rank;

  factory ProfileData.fromJson(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>? ?? {};
    final badges = (j['badges'] as List? ?? [])
        .map((b) => BadgeItem.fromJson(b as Map<String, dynamic>))
        .toList();
    return ProfileData(
      name: user['name'] as String? ?? 'User',
      phone: user['phone'] as String? ?? '',
      xp: (user['xp'] as num?)?.toInt() ?? 0,
      streak: (user['streak'] as num?)?.toInt() ?? 0,
      startWeight: _toDouble(user['start_weight']),
      currentWeight: _toDouble(user['start_weight']),
      targetWeight: _toDouble(user['target_weight']),
      badges: badges,
    );
  }

  static ProfileData demo() => ProfileData(
        name: 'Alex',
        phone: '+91 98765 43210',
        xp: 340,
        streak: 14,
        startWeight: 92.0,
        currentWeight: 89.5,
        targetWeight: 78.0,
        badges: const [
          BadgeItem(emoji: '🔥', name: '7-Day Streak'),
          BadgeItem(emoji: '🥗', name: 'Clean Eater'),
        ],
        rank: 2,
      );
}

class ProfileNotifier extends AsyncNotifier<ProfileData> {
  @override
  Future<ProfileData> build() {
    ref.watch(currentUserKeyProvider);
    return _fetch();
  }

  Future<ProfileData> _fetch() async {
    try {
      final json = await ref.read(apiClientProvider).getJson('/profile');
      return ProfileData.fromJson(json);
    } catch (_) {
      if (AppConfig.demoMode) return ProfileData.demo();
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, ProfileData>(ProfileNotifier.new);

// ─── Weight History ───────────────────────────────────────────────────────────

class WeightHistoryData {
  const WeightHistoryData({
    required this.entries,
    required this.startWeight,
    required this.targetWeight,
  });
  final List<Map<String, dynamic>> entries;
  final double startWeight;
  final double targetWeight;

  double? get currentWeight {
    for (final e in entries) {
      final w = _toDouble(e['weight']);
      if (w > 0) return w;
    }
    return null;
  }

  double? get weightChange =>
      (currentWeight != null && startWeight > 0) ? currentWeight! - startWeight : null;
}

final weightHistoryProvider = FutureProvider<WeightHistoryData>((ref) async {
  ref.watch(currentUserKeyProvider);
  final api = ref.watch(apiClientProvider);
  final data = await api.getJson('/weighin');
  final entries = (data['entries'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
      [];
  return WeightHistoryData(
    entries: entries,
    startWeight: _toDouble(data['start_weight']),
    targetWeight: _toDouble(data['target_weight']),
  );
});
