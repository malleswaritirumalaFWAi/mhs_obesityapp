import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/state/session.dart';

class Post {
  const Post({
    required this.id,
    required this.author,
    required this.body,
    required this.emoji,
    required this.coachPick,
    required this.likes,
    required this.fires,
    required this.comments,
  });

  final int id;
  final String author;
  final String body;
  final String emoji;
  final bool coachPick;
  final int likes;
  final int fires;
  final int comments;

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: (j['id'] as num?)?.toInt() ?? 0,
        author: j['author'] as String? ?? 'Member',
        body: j['body'] as String? ?? '',
        emoji: j['emoji'] as String? ?? '',
        coachPick: j['coach_pick'] as bool? ?? false,
        likes: (j['likes'] as num?)?.toInt() ?? 0,
        fires: (j['fires'] as num?)?.toInt() ?? 0,
        comments: (j['comments'] as num?)?.toInt() ?? 0,
      );

  Post copyWith({int? likes}) => Post(
        id: id,
        author: author,
        body: body,
        emoji: emoji,
        coachPick: coachPick,
        likes: likes ?? this.likes,
        fires: fires,
        comments: comments,
      );
}

List<Post> _demoPosts() => const [
      Post(id: 1, author: 'Priya S.', body: 'Just hit my 7-day streak! Feeling amazing 💪', emoji: '🔥', coachPick: true, likes: 12, fires: 8, comments: 3),
      Post(id: 2, author: 'Rahul M.', body: 'Logged my first clean meal today. Grilled chicken & salad!', emoji: '🥗', coachPick: false, likes: 7, fires: 4, comments: 1),
      Post(id: 3, author: 'Sunita K.', body: 'Morning walk done ✅ 8,000 steps before 8am!', emoji: '🚶', coachPick: false, likes: 5, fires: 6, comments: 2),
    ];

class PostsNotifier extends AsyncNotifier<List<Post>> {
  @override
  Future<List<Post>> build() {
    ref.watch(currentUserKeyProvider);
    return _fetch();
  }

  Future<List<Post>> _fetch() async {
    try {
      final json = await ref.read(apiClientProvider).getJson('/posts');
      final posts = json['posts'] as List? ?? [];
      return posts.map((p) => Post.fromJson(p as Map<String, dynamic>)).toList();
    } catch (_) {
      if (AppConfig.demoMode) return _demoPosts();
      rethrow;
    }
  }

  Future<void> likePost(int postId) async {
    await ref.read(apiClientProvider).postJson('/posts/$postId/like', null);
    state = state.whenData(
      (posts) => posts
          .map((p) => p.id == postId ? p.copyWith(likes: p.likes + 1) : p)
          .toList(),
    );
  }

  Future<void> addPost(String body, String emoji) async {
    await ref.read(apiClientProvider).postJson('/posts', {'body': body, 'emoji': emoji});
    state = await AsyncValue.guard(_fetch);
  }
}

final postsProvider =
    AsyncNotifierProvider<PostsNotifier, List<Post>>(PostsNotifier.new);
