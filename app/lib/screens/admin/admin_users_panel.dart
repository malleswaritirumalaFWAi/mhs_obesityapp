import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_content_model.dart';

class AdminUsersPanel extends StatelessWidget {
  const AdminUsersPanel({super.key, required this.users});

  final List<AdminUser> users;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.group_rounded, size: 64, color: AppColors.inkSoft),
            const SizedBox(height: 12),
            Text('No users yet', style: T.body(context)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _UserCard(user: users[i]),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowDark, blurRadius: 12, offset: Offset(4, 4)),
          BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 12,
              offset: Offset(-4, -4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: avatar + name + rank ─────────────────────────────
          Row(
            children: [
              // Avatar circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: user.avatarColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: T.title(context)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _StatPill(
                          icon: Symbols.military_tech_rounded,
                          label: 'Rank #${user.rank}',
                          color: AppColors.goldSoft,
                          textColor: AppColors.goldDark,
                        ),
                        const SizedBox(width: 8),
                        _StatPill(
                          icon: Symbols.local_fire_department_rounded,
                          label: '${user.streak}d streak',
                          color: AppColors.orangeSoft,
                          textColor: AppColors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Level badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.sageSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text('LVL',
                        style: TextStyle(
                            color: AppColors.sageDark,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                    Text('${user.level}',
                        style: const TextStyle(
                            color: AppColors.sageDark,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(color: AppColors.line, height: 1),
          const SizedBox(height: 14),

          // ── XP bar ────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Symbols.bolt_rounded,
                  size: 16, color: AppColors.amber),
              const SizedBox(width: 4),
              Text('${user.xp} XP',
                  style: T.small(context).copyWith(
                      color: AppColors.ink, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),

          // ── Progress rows ──────────────────────────────────────────────
          _ProgressRow(
            icon: Symbols.emoji_events_rounded,
            label: 'Weekly Challenge',
            completed: user.challengeCompleted,
            total: user.challengeTotal,
            color: AppColors.orange,
          ),
          const SizedBox(height: 8),
          _ProgressRow(
            icon: Symbols.menu_book_rounded,
            label: 'Lessons',
            completed: user.lessonCompleted,
            total: user.lessonTotal,
            color: AppColors.teal,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.icon,
    required this.label,
    required this.completed,
    required this.total,
    required this.color,
  });
  final IconData icon;
  final String label;
  final int completed;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: T.small(context)
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text('$completed / $total',
                      style: T.small(context).copyWith(
                          color: color, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.line,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
