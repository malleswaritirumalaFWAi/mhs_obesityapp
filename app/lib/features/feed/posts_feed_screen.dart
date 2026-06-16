import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
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

// ── Models ────────────────────────────────────────────────────────────────────

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
            .difference(DateTime(createdAt.year, createdAt.month, createdAt.day))
            .inDays ==
        1;
    if (isYesterday) return 'Yesterday';
    return '${createdAt.day}/${createdAt.month}';
  }
}

class _Comment {
  _Comment({
    required this.id,
    required this.userId,
    required this.author,
    required this.body,
    required this.createdAt,
  });
  final int id;
  final int userId;
  final String author;
  final String body;
  final DateTime createdAt;

  String get timeLabel {
    final h = createdAt.hour.toString().padLeft(2, '0');
    final m = createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PostsFeedScreen extends ConsumerStatefulWidget {
  const PostsFeedScreen({super.key});
  @override
  ConsumerState<PostsFeedScreen> createState() => _PostsFeedScreenState();
}

class _PostsFeedScreenState extends ConsumerState<PostsFeedScreen> {
  final _posts = <_Post>[];
  bool _loading = true;
  bool _posting = false;
  int _currentUserId = 0;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
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
              DateTime.now()).toLocal(),
          coachPick: m['coach_pick'] == true,
          emoji: m['emoji'] as String?,
        );
        post.liked = m['user_liked'] == true;
        return post;
      }).toList();
      if (mounted) {
        setState(() {
          _posts..clear()..addAll(posts);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _like(int index) async {
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
                hintText: 'Emoji (optional, e.g. \u{1F389})',
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
                Navigator.pop(ctx, {'body': b, 'emoji': emojiCtrl.text.trim()});
              },
              child: const Text('Post')),
        ],
      ),
    );
    bodyCtrl.dispose();
    emojiCtrl.dispose();
    if (result == null || (result['body'] ?? '').isEmpty) return;
    setState(() => _posting = true);
    try {
      await ref.read(apiClientProvider).postJson('/posts', {
        'body': result['body'],
        if ((result['emoji'] ?? '').isNotEmpty) 'emoji': result['emoji'],
      });
      await _loadPosts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e'), backgroundColor: AppColors.coral),
        );
      }
    }
    if (mounted) setState(() => _posting = false);
  }

  Future<void> _editPost(_Post post) async {
    final ctrl = TextEditingController(text: post.body);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit post'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                final t = ctrl.text.trim();
                if (t.isEmpty) return;
                Navigator.pop(ctx, t);
              },
              child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || result.isEmpty) return;
    try {
      await ref.read(apiClientProvider).putJson('/posts/${post.id}', {'body': result});
      setState(() => post.body = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Edit failed: $e'), backgroundColor: AppColors.coral),
        );
      }
    }
  }

  Future<void> _deletePost(_Post post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.coral))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(apiClientProvider).deleteJson('/posts/${post.id}');
      setState(() => _posts.remove(post));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppColors.coral),
        );
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
        onCommentAdded: () => setState(() => post.comments += 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.coral,
        onPressed: _posting ? null : _showCompose,
        child: _posting
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Symbols.add_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: NeuTopBar(title: 'Group feed', onBack: () => context.pop()),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _posts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Symbols.forum_rounded,
                                  size: 48, color: AppColors.inkSoft),
                              const SizedBox(height: 12),
                              Text('No posts yet', style: T.small(context)),
                              Text('Be the first to share!', style: T.small(context)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadPosts,
                          color: AppColors.coral,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                            itemCount: _posts.length,
                            itemBuilder: (_, i) => _PostCard(
                              post: _posts[i],
                              isOwn: _posts[i].userId == _currentUserId,
                              onLike: () => _like(i),
                              onComment: () => _openComments(_posts[i]),
                              onEdit: () => _editPost(_posts[i]),
                              onDelete: () => _deletePost(_posts[i]),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Post card ─────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.isOwn,
    required this.onLike,
    required this.onComment,
    required this.onEdit,
    required this.onDelete,
  });
  final _Post post;
  final bool isOwn;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: post.coachPick ? AppColors.goldSoft : AppColors.sageSoft,
                    shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(post.author[0],
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
                          ? '\u2B50 Coach pick \u00B7 ${post.timeAgo}'
                          : post.timeAgo,
                      style: T.small(context).copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              // 3-dot menu — edit/delete for own, nothing for others
              if (isOwn)
                PopupMenuButton<String>(
                  icon: const Icon(Symbols.more_vert_rounded,
                      color: AppColors.inkSoft),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(color: AppColors.coral))),
                  ],
                )
              else
                const Icon(Symbols.more_vert_rounded, color: AppColors.inkSoft),
            ]),
            const SizedBox(height: 12),
            Text(post.body,
                style: T.body(context).copyWith(color: AppColors.ink)),
            if (post.emoji != null) ...[
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
            // Reaction row
            Row(children: [
              _Reaction(
                icon: post.liked
                    ? Symbols.favorite_rounded
                    : Symbols.favorite_border_rounded,
                count: post.likes,
                color: post.liked ? AppColors.coral : AppColors.inkSoft,
                fill: post.liked,
                onTap: onLike,
              ),
              const SizedBox(width: 18),
              _Reaction(
                icon: Symbols.chat_bubble_outline_rounded,
                count: post.comments,
                color: AppColors.inkSoft,
                onTap: onComment,
              ),
              const SizedBox(width: 18),
              _Reaction(
                icon: Symbols.local_fire_department_rounded,
                count: post.fires,
                color: AppColors.gold,
              ),
              const Spacer(),
              const Icon(Symbols.share_rounded,
                  color: AppColors.inkSoft, size: 20),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Reaction widget ───────────────────────────────────────────────────────────

class _Reaction extends StatelessWidget {
  const _Reaction({
    required this.icon,
    required this.count,
    required this.color,
    this.fill = false,
    this.onTap,
  });
  final IconData icon;
  final int count;
  final Color color;
  final bool fill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, size: 20, color: color, fill: fill ? 1 : 0),
        const SizedBox(width: 6),
        Text('$count',
            style: T.small(context).copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Comments bottom sheet ─────────────────────────────────────────────────────

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
          userId: (m['user_id'] as num?)?.toInt() ?? 0,
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
          // Handle
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
          // Comments list (max 300 height)
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
          // Input row
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
            child: Text(c.author[0],
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
