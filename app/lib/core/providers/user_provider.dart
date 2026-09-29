import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../state/session.dart';

class UserProfile {
  const UserProfile({
    required this.name,
    required this.phone,
    required this.email,
    required this.xp,
    required this.totalXp,
    required this.streak,
    required this.badges,
    this.startWeight,
    this.targetWeight,
    this.height,
    this.profilePhotoUrl,
  });

  final String name;
  final String phone;
  final String email;
  /// Spendable XP (decremented on redeems). Use [totalXp] for display.
  final int xp;
  /// Cumulative lifetime XP — matches Royal leaderboard ranking.
  final int totalXp;
  final int streak;
  final List<Map<String, String>> badges; // [{emoji, name}]
  final double? startWeight;
  final double? targetWeight;
  final double? height;
  final String? profilePhotoUrl;

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

final userProvider = FutureProvider<UserProfile>((ref) async {
  ref.watch(currentUserKeyProvider);
  final api = ref.watch(apiClientProvider);
  final sessionName = ref.watch(sessionProvider).name ?? '';
  final data = await api.getJson('/profile');
  final user = (data['user'] as Map?) ?? {};
  final rawBadges = (data['badges'] as List?) ?? [];
  final dbName = (user['name'] as String?) ?? '';
  return UserProfile(
    name: dbName.isNotEmpty ? dbName
        : sessionName.isNotEmpty ? sessionName
        : 'User',
    phone: (user['phone'] as String?) ?? '',
    email: (user['email'] as String?) ?? '',
    xp: (user['xp'] as num?)?.toInt() ?? 0,
    totalXp: (user['total_xp'] as num?)?.toInt() ?? 0,
    streak: (user['streak'] as num?)?.toInt() ?? 0,
    startWeight: (user['start_weight'] as num?)?.toDouble(),
    targetWeight: (user['target_weight'] as num?)?.toDouble(),
    height: (user['height'] as num?)?.toDouble(),
    profilePhotoUrl: user['profile_photo_url'] as String?,
    badges: rawBadges
        .map((b) => {
              'emoji': (b['emoji'] as String?) ?? '🏅',
              'name': (b['name'] as String?) ?? 'Badge',
            })
        .toList(),
  );
});
