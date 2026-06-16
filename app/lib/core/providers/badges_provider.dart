import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../state/session.dart';

class BadgeItem {
  const BadgeItem({
    required this.id,
    required this.slug,
    required this.emoji,
    required this.name,
    required this.description,
    required this.xpReward,
    required this.earned,
    this.earnedAt,
  });
  final int id;
  final String slug;
  final String emoji;
  final String name;
  final String description;
  final int xpReward;
  final bool earned;
  final DateTime? earnedAt;

  factory BadgeItem.fromJson(Map<String, dynamic> j) => BadgeItem(
        id: (j['id'] as num).toInt(),
        slug: (j['slug'] as String?) ?? '',
        emoji: (j['emoji'] as String?) ?? '🏅',
        name: (j['name'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        xpReward: (j['xp_reward'] as num?)?.toInt() ?? 0,
        earned: j['earned'] == true,
        earnedAt: j['earned_at'] != null
            ? DateTime.tryParse(j['earned_at'] as String)?.toLocal()
            : null,
      );
}

class BadgesNotifier extends StateNotifier<AsyncValue<List<BadgeItem>>> {
  BadgesNotifier(this._api) : super(const AsyncLoading()) {
    fetch();
  }
  final ApiClient _api;

  Future<void> fetch() async {
    try {
      final d = await _api.getJson('/badges');
      final raw = (d['badges'] as List?) ?? [];
      final badges = raw
          .map((e) => BadgeItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      state = AsyncData(badges);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final badgesProvider =
    StateNotifierProvider<BadgesNotifier, AsyncValue<List<BadgeItem>>>((ref) {
  ref.watch(currentUserKeyProvider);
  return BadgesNotifier(ref.watch(apiClientProvider));
});
