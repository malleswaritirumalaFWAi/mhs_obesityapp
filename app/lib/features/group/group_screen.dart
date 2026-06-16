import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

// Safe int parser — handles both num and String from PostgreSQL BIGINT fields
int _asInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

// ── Post model ────────────────────────────────────────────────────────────────

class _Post {
  _Post({
    required this.id,
    required this.userId,
    required this.author,
    required this.body,
    required this.likes,
    required this.comments,
    required this.fires,
    required this.createdAt,
    this.coachPick = false,
    this.emoji,
  });
  final int id;
  final int userId;
  final String author;
  String body;
  int likes;
  int comments;
  final int fires;
  final DateTime createdAt;
  final bool coachPick;
  final String? emoji;
  bool liked = false;

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    final now = DateTime.now();
    final isYesterday = DateTime(now.year, now.month, now.day)
            .difference(
                DateTime(createdAt.year, createdAt.month, createdAt.day))
            .inDays ==
        1;
    if (isYesterday) return 'Yesterday';
    return '${createdAt.day}/${createdAt.month}';
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({super.key});
  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  int _tab = 0; // 0 weekly, 1 royal, 2 posts, 3 coach
  List<Map<String, dynamic>> _leaderboard = [];
  List<Map<String, dynamic>> _royalLeaderboard = [];
  bool _loading = true;

  // Posts state
  final List<_Post> _posts = [];
  bool _postsLoading = false;
  bool _postsLoaded = false;
  String? _postsError;
  bool _posting = false;
  int _currentUserId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Load leaderboard + posts together so posts are ready before user can
    // open the compose dialog. Structural rebuilds during dialog open cause
    // the _dependents.isEmpty assertion in InheritedElement.deactivate().
    try {
      final results = await Future.wait([
        ref.read(apiClientProvider).getJson('/group/leaderboard'),
        ref.read(apiClientProvider).getJson('/gamification/royal-leaderboard'),
        ref.read(apiClientProvider).getJson('/posts'),
      ]);
      if (mounted) {
        final raw = (results[2]['posts'] as List?) ?? [];
        final posts = raw.map((p) {
          final m = Map<String, dynamic>.from(p as Map);
          final post = _Post(
            id: _asInt(m['id']),
            userId: _asInt(m['user_id']),
            author: m['author'] as String? ?? 'Member',
            body: m['body'] as String? ?? '',
            likes: _asInt(m['likes']),
            comments: _asInt(m['comments']),
            fires: _asInt(m['fires']),
            createdAt: (DateTime.tryParse(m['created_at'] as String? ?? '') ??
                    DateTime.now())
                .toLocal(),
            coachPick: m['coach_pick'] == true,
            emoji: m['emoji'] as String?,
          );
          post.liked = m['user_liked'] == true;
          return post;
        }).toList();
        setState(() {
          _leaderboard = (results[0]['leaderboard'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          _royalLeaderboard = (results[1]['leaderboard'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          _loading = false;
          _currentUserId = _asInt(results[2]['current_user_id']);
          _posts..clear()..addAll(posts);
          _postsLoading = false;
          _postsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _postsLoading = false; });
    }
  }

  Future<void> _loadPosts() async {
    if (mounted) setState(() { _postsLoading = true; _postsError = null; });
    try {
      final res = await ref.read(apiClientProvider).getJson('/posts');
      _currentUserId = _asInt(res['current_user_id']);
      final raw = (res['posts'] as List?) ?? [];
      final posts = raw.map((p) {
        final m = Map<String, dynamic>.from(p as Map);
        final post = _Post(
          id: _asInt(m['id']),
          userId: _asInt(m['user_id']),
          author: m['author'] as String? ?? 'Member',
          body: m['body'] as String? ?? '',
          likes: _asInt(m['likes']),
          comments: _asInt(m['comments']),
          fires: _asInt(m['fires']),
          createdAt: (DateTime.tryParse(m['created_at'] as String? ?? '') ??
                  DateTime.now())
              .toLocal(),
          coachPick: m['coach_pick'] == true,
          emoji: m['emoji'] as String?,
        );
        post.liked = m['user_liked'] == true;
        return post;
      }).toList();
      if (mounted) {
        setState(() {
          _posts..clear()..addAll(posts);
          _postsLoading = false;
          _postsLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _postsLoading = false;
          _postsError = e.toString();
        });
      }
    }
  }

  Future<void> _likePost(int index) async {
    final post = _posts[index];
    // Optimistic toggle
    final wasLiked = post.liked;
    setState(() {
      post.liked = !wasLiked;
      post.likes = wasLiked ? (post.likes - 1).clamp(0, 99999) : post.likes + 1;
    });
    try {
      await ref.read(apiClientProvider).postJson('/posts/${post.id}/like', {});
    } catch (_) {
      // Revert on failure
      if (mounted) setState(() { post.liked = wasLiked; post.likes = wasLiked ? post.likes + 1 : (post.likes - 1).clamp(0, 99999); });
    }
  }

  Future<void> _showCompose() async {
    final bodyCtrl = TextEditingController();
    final emojiCtrl = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share with your group'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: bodyCtrl,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
                hintText: "What's on your mind?",
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: emojiCtrl,
            decoration: const InputDecoration(
                hintText: 'Emoji (optional, e.g. 🎉)',
                border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                final b = bodyCtrl.text.trim();
                if (b.isEmpty) return;
                Navigator.pop(
                    ctx, {'body': b, 'emoji': emojiCtrl.text.trim()});
              },
              child: const Text('Post')),
        ],
      ),
    );
    bodyCtrl.dispose();
    emojiCtrl.dispose();
    if (result == null || (result['body'] ?? '').isEmpty) return;
    if (!mounted) return;
    setState(() => _posting = true);
    try {
      await ref.read(apiClientProvider).postJson('/posts', {
        'body': result['body'],
        if ((result['emoji'] ?? '').isNotEmpty) 'emoji': result['emoji'],
      });
      await _loadPosts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to post: $e'),
            backgroundColor: AppColors.coral));
      }
    }
    if (mounted) setState(() => _posting = false);
  }

  Future<void> _deletePost(_Post post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.coral))),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    try {
      await ref.read(apiClientProvider).deleteJson('/posts/${post.id}');
      if (mounted) setState(() => _posts.remove(post));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: AppColors.coral));
      }
    }
  }

  void _openComments(_Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        post: post,
        api: ref.read(apiClientProvider),
        onCommentAdded: () {
          if (mounted) setState(() => post.comments += 1);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _tab == 2
          ? FloatingActionButton(
              backgroundColor: AppColors.coral,
              // Disable FAB while posts are loading to prevent structural
              // tree rebuilds during showDialog (causes _dependents assertion).
              onPressed: (_posting || _postsLoading) ? null : _showCompose,
              child: _posting
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Symbols.add_rounded, color: Colors.white),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Batch #47 · 50 members', style: T.small(context)),
                Text('My group', style: T.h2(context)),
              ]),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push(Routes.groupChat),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.coralSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Symbols.chat_rounded,
                        color: AppColors.coral, size: 18),
                    const SizedBox(width: 6),
                    Text('Group Chat',
                        style: T.small(context).copyWith(
                            color: AppColors.coral,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _Tabs(
              index: _tab,
              labels: const ['Weekly', 'Royal', 'Posts', 'Coach'],
              onChanged: (i) {
                setState(() => _tab = i);
                if (i == 2 && !_postsLoaded && !_postsLoading) {
                  _loadPosts();
                }
              },
            ),
            const SizedBox(height: 18),
            if (_loading && _tab != 2)
              const Center(child: CircularProgressIndicator())
            else if (_tab == 2)
              _postsTab(context)
            else if (_tab == 3)
              _coachUpdates(context)
            else if (_tab == 1)
              _royalBoard(context)
            else
              _weeklyBoard(context),
          ],
        ),
      ),
    );
  }

  Widget _postsTab(BuildContext context) {
    if (_postsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_postsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.wifi_off_rounded,
                size: 48, color: AppColors.inkSoft),
            const SizedBox(height: 12),
            Text('Could not load posts', style: T.title(context)),
            const SizedBox(height: 4),
            Text('Check your connection and retry',
                style: T.small(context)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loadPosts,
              child: const NeuPill(
                color: AppColors.coral,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text('Retry',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );
    }
    if (_posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.forum_rounded,
                size: 48, color: AppColors.inkSoft),
            const SizedBox(height: 12),
            Text('No posts yet', style: T.title(context)),
            const SizedBox(height: 4),
            Text('Tap + to share something with your group',
                style: T.small(context)),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < _posts.length; i++)
          _PostCard(
            post: _posts[i],
            isOwn: _posts[i].userId == _currentUserId,
            onLike: () => _likePost(i),
            onComment: () => _openComments(_posts[i]),
            onDelete: () => _deletePost(_posts[i]),
          ),
        const SizedBox(height: 72), // space for FAB
      ],
    );
  }

  Widget _weeklyBoard(BuildContext context) {
    final top3 = _leaderboard.take(3).toList();
    final rest = _leaderboard.skip(3).toList();
    final podiumOrder = top3.length >= 3
        ? [top3[1], top3[0], top3[2]]
        : top3;

    return Column(children: [
      Row(children: [
        const Text('🏆 ', style: TextStyle(fontSize: 18)),
        Text('Top 3 this week', style: T.title(context)),
        const Spacer(),
        const NeuPill(
          color: AppColors.goldSoft,
          child: Text('Win ₹500',
              style: TextStyle(
                  color: AppColors.goldDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ),
      ]),
      const SizedBox(height: 16),
      if (podiumOrder.length >= 3)
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
                child: _Podium(
                    name: podiumOrder[0]['name'] as String? ?? '?',
                    rank: _asInt(podiumOrder[0]['rank'], 2),
                    xp: _asInt(podiumOrder[0]['weekly_xp']),
                    height: 96)),
            Expanded(
                child: _Podium(
                    name: podiumOrder[1]['name'] as String? ?? '?',
                    rank: _asInt(podiumOrder[1]['rank'], 1),
                    xp: _asInt(podiumOrder[1]['weekly_xp']),
                    height: 124,
                    crown: true)),
            Expanded(
                child: _Podium(
                    name: podiumOrder[2]['name'] as String? ?? '?',
                    rank: _asInt(podiumOrder[2]['rank'], 3),
                    xp: _asInt(podiumOrder[2]['weekly_xp']),
                    height: 80)),
          ],
        ),
      const SizedBox(height: 24),
      Text('All members', style: T.title(context)),
      const SizedBox(height: 12),
      for (final m in rest)
        _MemberRow(
          rank: _asInt(m['rank']),
          name: m['name'] as String? ?? 'Member',
          xp: _asInt(m['weekly_xp']),
          isYou: m['you'] == true,
        ),
      if (rest.isEmpty && _leaderboard.isEmpty)
        const Center(child: Text('No leaderboard data yet')),
    ]);
  }

  Widget _royalBoard(BuildContext context) {
    return Column(children: [
      Row(children: [
        const Text('👑 ', style: TextStyle(fontSize: 18)),
        Text('Royal Challenge', style: T.title(context)),
        const Spacer(),
        NeuPill(
          color: AppColors.goldSoft,
          child: Text('All-time XP',
              style: T.small(context).copyWith(
                  color: AppColors.goldDark, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 8),
      Text('Compete with all FitQuest members for the top spot',
          style: T.small(context)),
      const SizedBox(height: 16),
      for (final m in _royalLeaderboard)
        _MemberRow(
          rank: _asInt(m['rank']),
          name: m['name'] as String? ?? 'Member',
          xp: _asInt(m['total_xp']),
          isYou: m['you'] == true,
          showLevel: m['level'] as String?,
        ),
      if (_royalLeaderboard.isEmpty)
        const Center(child: Text('No royal leaderboard data yet')),
    ]);
  }

  Widget _coachUpdates(BuildContext context) => Column(children: [
        NeuCard(
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: AppColors.berrySoft, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('P',
                  style: T.title(context).copyWith(color: AppColors.berry)),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Coach Priya · 1h ago', style: T.small(context)),
                  const SizedBox(height: 4),
                  Text(
                      'Reminder: weigh-in every morning before water. Consistency wins 💪',
                      style: T.body(context)),
                ])),
          ]),
        ),
      ]);
}

// ── Post card ─────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.isOwn,
    required this.onLike,
    required this.onComment,
    required this.onDelete,
  });
  final _Post post;
  final bool isOwn;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: post.coachPick
                        ? AppColors.goldSoft
                        : AppColors.sageSoft,
                    shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(post.author.isNotEmpty ? post.author[0] : '?',
                    style: T.title(context).copyWith(fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.author,
                        style: T.title(context).copyWith(fontSize: 15)),
                    Text(
                      post.coachPick
                          ? '⭐ Coach pick · ${post.timeAgo}'
                          : post.timeAgo,
                      style: T.small(context).copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isOwn)
                PopupMenuButton<String>(
                  icon: const Icon(Symbols.more_vert_rounded,
                      color: AppColors.inkSoft),
                  onSelected: (v) {
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(color: AppColors.coral))),
                  ],
                )
              else
                const Icon(Symbols.more_vert_rounded,
                    color: AppColors.inkSoft),
            ]),
            const SizedBox(height: 12),
            Text(post.body,
                style: T.body(context).copyWith(color: AppColors.ink)),
            if (post.emoji != null && post.emoji!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                height: 90,
                decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(18)),
                alignment: Alignment.center,
                child: Text(post.emoji!,
                    style: const TextStyle(fontSize: 40)),
              ),
            ],
            const SizedBox(height: 14),
            // Reactions
            Row(children: [
              GestureDetector(
                onTap: onLike,
                child: Row(children: [
                  Icon(
                    post.liked
                        ? Symbols.favorite_rounded
                        : Symbols.favorite_border_rounded,
                    size: 20,
                    color: post.liked ? AppColors.coral : AppColors.inkSoft,
                    fill: post.liked ? 1 : 0,
                  ),
                  const SizedBox(width: 6),
                  Text('${post.likes}',
                      style: T.small(context)
                          .copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(width: 18),
              GestureDetector(
                onTap: onComment,
                child: Row(children: [
                  const Icon(Symbols.chat_bubble_outline_rounded,
                      size: 20, color: AppColors.inkSoft),
                  const SizedBox(width: 6),
                  Text('${post.comments}',
                      style: T.small(context)
                          .copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(width: 18),
              Row(children: [
                const Icon(Symbols.local_fire_department_rounded,
                    size: 20, color: AppColors.gold),
                const SizedBox(width: 6),
                Text('${post.fires}',
                    style: T.small(context)
                        .copyWith(fontWeight: FontWeight.w700)),
              ]),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Comments bottom sheet ─────────────────────────────────────────────────────

class _Comment {
  _Comment({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
  });
  final int id;
  final String author;
  final String body;
  final DateTime createdAt;

  String get timeLabel {
    final h = createdAt.hour.toString().padLeft(2, '0');
    final m = createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({
    required this.post,
    required this.api,
    required this.onCommentAdded,
  });
  final _Post post;
  final ApiClient api;
  final VoidCallback onCommentAdded;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();
  final _comments = <_Comment>[];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res =
          await widget.api.getJson('/posts/${widget.post.id}/comments');
      final raw = (res['comments'] as List?) ?? [];
      final list = raw.map((c) {
        final m = Map<String, dynamic>.from(c as Map);
        return _Comment(
          id: (m['id'] as num?)?.toInt() ?? 0,
          author: m['author'] as String? ?? 'Member',
          body: m['body'] as String? ?? '',
          createdAt: (DateTime.tryParse(m['created_at'] as String? ?? '') ??
              DateTime.now()).toLocal(),
        );
      }).toList();
      if (mounted) setState(() { _comments..clear()..addAll(list); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.api
          .postJson('/posts/${widget.post.id}/comments', {'body': text});
      _ctrl.clear();
      widget.onCommentAdded();
      await _load();
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          Text('Comments', style: T.title(context)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                            child: Text('No comments yet. Be the first!',
                                style: T.small(context))),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _comments.length,
                        itemBuilder: (_, i) => _CommentTile(c: _comments[i]),
                      ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: NeuTextField(
                controller: _ctrl,
                hint: 'Add a comment…',
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _sending ? AppColors.inkSoft : AppColors.coral,
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Symbols.send_rounded,
                        color: Colors.white, fill: 1),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.c});
  final _Comment c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
                color: AppColors.sageSoft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(c.author.isNotEmpty ? c.author[0] : '?',
                style: T.small(context).copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(c.author,
                      style: T.small(context)
                          .copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 8),
                  Text(c.timeLabel,
                      style: T.small(context)
                          .copyWith(fontSize: 11, color: AppColors.inkSoft)),
                ]),
                const SizedBox(height: 2),
                Text(c.body, style: T.body(context).copyWith(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tabs ──────────────────────────────────────────────────────────────────────

class _Tabs extends StatelessWidget {
  const _Tabs(
      {required this.index,
      required this.labels,
      required this.onChanged});
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: index == i ? AppColors.coral : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(labels[i],
                    style: TextStyle(
                        color:
                            index == i ? Colors.white : AppColors.inkSoft,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Podium ────────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  const _Podium(
      {required this.name,
      required this.rank,
      required this.xp,
      required this.height,
      this.crown = false});
  final String name;
  final int rank, xp;
  final double height;
  final bool crown;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (crown) const Text('👑', style: TextStyle(fontSize: 22)),
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: crown ? AppColors.coral : AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadowDark,
                offset: Offset(3, 3),
                blurRadius: 8)
          ],
        ),
        alignment: Alignment.center,
        child: Text(name.isNotEmpty ? name[0] : '?',
            style: TextStyle(
                color: crown ? Colors.white : AppColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
      ),
      const SizedBox(height: 6),
      Text(name,
          style:
              T.small(context).copyWith(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      Text('$xp XP', style: T.small(context).copyWith(fontSize: 11)),
      const SizedBox(height: 6),
      Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: crown ? AppColors.coralSoft : AppColors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(14)),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadowDark,
                offset: Offset(4, 4),
                blurRadius: 10),
            BoxShadow(
                color: AppColors.shadowLight,
                offset: Offset(-4, -4),
                blurRadius: 10),
          ],
        ),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 8),
        child: Text('#$rank',
            style: T.title(context).copyWith(
                color: crown ? AppColors.coral : AppColors.inkMid)),
      ),
    ]);
  }
}

// ── Member row ────────────────────────────────────────────────────────────────

class _MemberRow extends StatelessWidget {
  const _MemberRow(
      {required this.rank,
      required this.name,
      required this.xp,
      this.isYou = false,
      this.showLevel});
  final int rank, xp;
  final String name;
  final bool isYou;
  final String? showLevel;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeuCard(
        color: isYou ? AppColors.coralSoft : null,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          SizedBox(
            width: 28,
            child: Text('$rank',
                style: T.title(context).copyWith(
                    fontSize: 15,
                    color: isYou ? AppColors.coral : AppColors.inkSoft)),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: AppColors.bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(name.isNotEmpty ? name[0] : '?',
                style: T.title(context).copyWith(fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(isYou ? 'You' : name,
                    style: T.title(context).copyWith(fontSize: 14)),
                if (showLevel != null)
                  Text(showLevel!,
                      style: T.small(context).copyWith(
                          fontSize: 11, color: AppColors.gold))
                else
                  Text(isYou ? 'Keep going! 🔥' : 'Member',
                      style: T.small(context).copyWith(fontSize: 12)),
              ])),
          Text('$xp XP',
              style: T.title(context).copyWith(
                  fontSize: 15,
                  color: isYou ? AppColors.coral : AppColors.ink)),
        ]),
      ),
    );
  }
}
