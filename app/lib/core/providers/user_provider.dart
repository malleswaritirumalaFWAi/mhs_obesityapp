import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../state/session.dart';

class UserProfile {
  const UserProfile({
    required this.name,
    required this.phone,
    required this.email,
    required this.xp,
    required this.streak,
    required this.badges,
  });

  final String name;
  final String phone;
  final String email;
  final int xp;
  final int streak;
  final List<Map<String, String>> badges; // [{emoji, name}]

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

final userProvider = FutureProvider<UserProfile>((ref) async {
  ref.watch(currentUserKeyProvider);
  final api = ref.watch(apiClientProvider);
  final data = await api.getJson('/profile');
  final user = (data['user'] as Map?) ?? {};
  final rawBadges = (data['badges'] as List?) ?? [];
  return UserProfile(
    name: (user['name'] as String?) ?? 'User',
    phone: (user['phone'] as String?) ?? '',
    email: (user['email'] as String?) ?? '',
    xp: (user['xp'] as num?)?.toInt() ?? 0,
    streak: (user['streak'] as num?)?.toInt() ?? 0,
    badges: rawBadges
        .map((b) => {
              'emoji': (b['emoji'] as String?) ?? '🏅',
              'name': (b['name'] as String?) ?? 'Badge',
            })
        .toList(),
  );
});
