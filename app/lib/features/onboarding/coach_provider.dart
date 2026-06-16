import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/state/session.dart';

class CoachData {
  const CoachData({
    required this.name,
    required this.title,
    required this.rating,
    required this.avatar,
    required this.batch,
  });

  final String name;
  final String title;
  final double rating;
  final String avatar;
  final String batch;

  /// First letter of name, used as avatar fallback.
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : 'C';

  factory CoachData.fromJson(Map<String, dynamic> j) => CoachData(
        name: j['name'] as String? ?? 'Your Coach',
        title: j['title'] as String? ?? 'Certified Dietitian',
        rating: (j['rating'] as num?)?.toDouble() ?? 0.0,
        avatar: j['avatar'] as String? ?? '',
        batch: j['batch'] as String? ?? '',
      );
}

class CoachNotifier extends AsyncNotifier<CoachData> {
  @override
  Future<CoachData> build() async {
    ref.watch(currentUserKeyProvider);
    try {
      final json = await ref.read(apiClientProvider).getJson('/coach');
      return CoachData.fromJson(json);
    } catch (_) {
      if (AppConfig.demoMode) {
        return const CoachData(
          name: 'Priya Sharma',
          title: 'Certified Dietitian & Fitness Coach',
          rating: 4.9,
          avatar: '',
          batch: 'Batch #47',
        );
      }
      rethrow;
    }
  }
}

final coachProvider =
    AsyncNotifierProvider<CoachNotifier, CoachData>(CoachNotifier.new);
