import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/state/session.dart';

class DashboardData {
  const DashboardData({
    required this.name,
    required this.day,
    required this.totalDays,
    required this.done,
    required this.total,
    required this.steps,
    required this.water,
    required this.sleep,
    required this.rank,
    required this.xp,
  });

  final String name;
  final int day;
  final int totalDays;
  final int done;
  final int total;
  final int steps;
  final String water;
  final String sleep;
  final int rank;
  final int xp;

  static DashboardData demo() => const DashboardData(
        name: 'Alex',
        day: 14,
        totalDays: 84,
        done: 3,
        total: 6,
        steps: 5420,
        water: '4/8',
        sleep: '7h',
        rank: 2,
        xp: 340,
      );

  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
        name: j['name'] as String? ?? 'User',
        day: (j['day'] as num?)?.toInt() ?? 1,
        totalDays: (j['total_days'] as num?)?.toInt() ?? 84,
        done: (j['done'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 8,
        steps: (j['steps'] as num?)?.toInt() ?? 0,
        water: j['water'] as String? ?? '0/8',
        sleep: j['sleep'] as String? ?? '0h',
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        xp: (j['xp'] as num?)?.toInt() ?? 0,
      );
}

class DashboardNotifier extends AsyncNotifier<DashboardData> {
  @override
  Future<DashboardData> build() {
    ref.watch(currentUserKeyProvider);
    return _fetch();
  }

  Future<DashboardData> _fetch() async {
    try {
      final json = await ref.read(apiClientProvider).getJson('/dashboard');
      return DashboardData.fromJson(json);
    } catch (_) {
      if (AppConfig.demoMode) return DashboardData.demo();
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardData>(DashboardNotifier.new);
