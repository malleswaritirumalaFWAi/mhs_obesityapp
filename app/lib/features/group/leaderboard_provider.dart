import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/state/session.dart';

class LeaderboardMember {
  const LeaderboardMember({
    required this.id,
    required this.name,
    required this.xp,
    required this.rank,
    required this.you,
  });

  final int id;
  final String name;
  final int xp;
  final int rank;
  final bool you;

  factory LeaderboardMember.fromJson(Map<String, dynamic> j) => LeaderboardMember(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? 'Member',
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        you: j['you'] as bool? ?? false,
      );
}

List<LeaderboardMember> _demoMembers() => const [
      LeaderboardMember(id: 1, name: 'Priya S.', xp: 520, rank: 1, you: false),
      LeaderboardMember(id: 2, name: 'Alex', xp: 340, rank: 2, you: true),
      LeaderboardMember(id: 3, name: 'Rahul M.', xp: 290, rank: 3, you: false),
      LeaderboardMember(id: 4, name: 'Sunita K.', xp: 210, rank: 4, you: false),
      LeaderboardMember(id: 5, name: 'Amit R.', xp: 180, rank: 5, you: false),
      LeaderboardMember(id: 6, name: 'Kavya P.', xp: 150, rank: 6, you: false),
    ];

class LeaderboardNotifier extends AsyncNotifier<List<LeaderboardMember>> {
  @override
  Future<List<LeaderboardMember>> build() {
    ref.watch(currentUserKeyProvider);
    return _fetch();
  }

  Future<List<LeaderboardMember>> _fetch() async {
    try {
      final json = await ref.read(apiClientProvider).getJson('/group/leaderboard');
      final members = json['members'] as List? ?? [];
      return members
          .map((m) => LeaderboardMember.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      if (AppConfig.demoMode) return _demoMembers();
      rethrow;
    }
  }
}

final leaderboardProvider =
    AsyncNotifierProvider<LeaderboardNotifier, List<LeaderboardMember>>(
        LeaderboardNotifier.new);
