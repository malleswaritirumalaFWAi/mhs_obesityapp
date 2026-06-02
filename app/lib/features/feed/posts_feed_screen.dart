import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class _Post {
  _Post({
    required this.author,
    required this.meta,
    required this.body,
    required this.likes,
    required this.comments,
    required this.fires,
    this.coachPick = false,
    this.beforeAfter = false,
    this.emoji,
  });
  final String author;
  final String meta;
  final String body;
  int likes;
  final int comments;
  final int fires;
  final bool coachPick;
  final bool beforeAfter;
  final String? emoji;
  bool liked = false;
}

class PostsFeedScreen extends StatefulWidget {
  const PostsFeedScreen({super.key});
  @override
  State<PostsFeedScreen> createState() => _PostsFeedScreenState();
}

class _PostsFeedScreenState extends State<PostsFeedScreen> {
  final _posts = <_Post>[
    _Post(
      author: 'Rahul M.',
      meta: '⭐ Coach pick · 2h ago',
      body: 'Week 4 — 3 kg down! 🎉 Cut roti to 2/meal, hit 8K steps every day. Thank you Coach Priya!',
      likes: 42,
      comments: 12,
      fires: 8,
      coachPick: true,
      beforeAfter: true,
    ),
    _Post(
      author: 'Sneha K.',
      meta: '4h ago · +10 XP',
      body: 'Lunch today: added extra sprouts for protein. Feels light and healthy 🌱',
      likes: 18,
      comments: 3,
      fires: 2,
      emoji: '🥗',
    ),
    _Post(
      author: 'Imran A.',
      meta: '6h ago',
      body: 'Hit my 10,000 steps before lunch for the first time! Small wins 🏃',
      likes: 24,
      comments: 5,
      fires: 6,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.coral,
        onPressed: () => ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Compose post (demo)'))),
        child: const Icon(Symbols.add_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: NeuTopBar(title: 'Group feed', onBack: () => context.pop()),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: _posts.length,
                itemBuilder: (_, i) => _PostCard(
                  post: _posts[i],
                  onLike: () => setState(() {
                    final p = _posts[i];
                    p.liked = !p.liked;
                    p.likes += p.liked ? 1 : -1;
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onLike});
  final _Post post;
  final VoidCallback onLike;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: post.coachPick ? AppColors.goldSoft : AppColors.sageSoft,
                    shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(post.author[0], style: T.title(context).copyWith(fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.author, style: T.title(context).copyWith(fontSize: 15)),
                    Text(post.meta, style: T.small(context).copyWith(fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Symbols.more_vert_rounded, color: AppColors.inkSoft),
            ]),
            const SizedBox(height: 12),
            Text(post.body, style: T.body(context).copyWith(color: AppColors.ink)),
            if (post.beforeAfter) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _BeforeAfter(label: 'BEFORE')),
                const SizedBox(width: 10),
                Expanded(child: _BeforeAfter(label: 'AFTER')),
              ]),
            ],
            if (post.emoji != null) ...[
              const SizedBox(height: 12),
              Container(
                height: 90,
                decoration: BoxDecoration(
                    color: AppColors.bg, borderRadius: BorderRadius.circular(18)),
                alignment: Alignment.center,
                child: Text(post.emoji!, style: const TextStyle(fontSize: 40)),
              ),
            ],
            const SizedBox(height: 14),
            Row(children: [
              _Reaction(
                icon: post.liked ? Symbols.favorite_rounded : Symbols.favorite_border_rounded,
                count: post.likes,
                color: post.liked ? AppColors.coral : AppColors.inkSoft,
                fill: post.liked,
                onTap: onLike,
              ),
              const SizedBox(width: 18),
              _Reaction(
                  icon: Symbols.chat_bubble_outline_rounded,
                  count: post.comments,
                  color: AppColors.inkSoft),
              const SizedBox(width: 18),
              _Reaction(
                  icon: Symbols.local_fire_department_rounded,
                  count: post.fires,
                  color: AppColors.gold),
              const Spacer(),
              const Icon(Symbols.share_rounded, color: AppColors.inkSoft, size: 20),
            ]),
          ],
        ),
      ),
    );
  }
}

class _BeforeAfter extends StatelessWidget {
  const _BeforeAfter({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Symbols.person_rounded, size: 40, color: AppColors.inkSoft),
        const SizedBox(height: 6),
        Text(label, style: T.label(context).copyWith(fontSize: 11)),
      ]),
    );
  }
}

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
        Text('$count', style: T.small(context).copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
