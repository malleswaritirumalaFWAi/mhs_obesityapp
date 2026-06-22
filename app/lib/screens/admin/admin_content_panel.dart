import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_content_model.dart';
import '../../services/admin_service.dart';

class AdminContentPanel extends StatefulWidget {
  const AdminContentPanel({super.key, required this.users});

  final List<AdminUser> users;

  @override
  State<AdminContentPanel> createState() => _AdminContentPanelState();
}

class _AdminContentPanelState extends State<AdminContentPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // unlock state maps: contentKey → (userId/ALL_USERS → bool)
  final Map<String, Map<String, bool>> _unlockStates = {};
  bool _loadingStates = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadAllStates();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadAllStates() async {
    final userIds = widget.users.map((u) => u.id).toList();
    final allKeys = [
      ...kChallengeWeeks.map((w) => w.unlockKey),
      ...kLessonModules.map((m) => m.unlockKey),
    ];
    final Map<String, Map<String, bool>> result = {};
    for (final key in allKeys) {
      result[key] = await AdminService.loadStatesForContent(key, userIds);
    }
    if (mounted) {
      setState(() {
        _unlockStates.addAll(result);
        _loadingStates = false;
      });
    }
  }

  bool _isAllUnlocked(String contentKey) =>
      _unlockStates[contentKey]?['ALL_USERS'] ?? false;

  bool _isUserUnlocked(String contentKey, String userId) =>
      _unlockStates[contentKey]?[userId] ?? false;

  Future<void> _toggleAll(String contentKey, bool unlock) async {
    final userIds = widget.users.map((u) => u.id).toList();
    await AdminService.setUnlockForAll(contentKey, unlock, userIds);
    final updated =
        await AdminService.loadStatesForContent(contentKey, userIds);
    if (mounted) setState(() => _unlockStates[contentKey] = updated);
  }

  Future<void> _toggleUser(
      String contentKey, String userId, bool unlock) async {
    await AdminService.setUnlockForUser(contentKey, userId, unlock);
    final userIds = widget.users.map((u) => u.id).toList();
    final updated =
        await AdminService.loadStatesForContent(contentKey, userIds);
    if (mounted) setState(() => _unlockStates[contentKey] = updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingStates) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // ── Tab bar ────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.shadowDark,
                  blurRadius: 8,
                  offset: Offset(3, 3)),
              BoxShadow(
                  color: AppColors.shadowLight,
                  blurRadius: 8,
                  offset: Offset(-3, -3)),
            ],
          ),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              gradient: AppColors.tealGrad,
              borderRadius: BorderRadius.circular(14),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.inkSoft,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'Weekly Challenges'),
              Tab(text: 'Lesson Modules'),
            ],
          ),
        ),

        // ── Tab views ──────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _ChallengesTab(
                weeks: kChallengeWeeks,
                users: widget.users,
                isAllUnlocked: _isAllUnlocked,
                isUserUnlocked: _isUserUnlocked,
                toggleAll: _toggleAll,
                toggleUser: _toggleUser,
              ),
              _LessonsTab(
                modules: kLessonModules,
                users: widget.users,
                isAllUnlocked: _isAllUnlocked,
                isUserUnlocked: _isUserUnlocked,
                toggleAll: _toggleAll,
                toggleUser: _toggleUser,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Challenges tab ─────────────────────────────────────────────────────────

class _ChallengesTab extends StatelessWidget {
  const _ChallengesTab({
    required this.weeks,
    required this.users,
    required this.isAllUnlocked,
    required this.isUserUnlocked,
    required this.toggleAll,
    required this.toggleUser,
  });

  final List<ChallengeWeek> weeks;
  final List<AdminUser> users;
  final bool Function(String) isAllUnlocked;
  final bool Function(String, String) isUserUnlocked;
  final Future<void> Function(String, bool) toggleAll;
  final Future<void> Function(String, String, bool) toggleUser;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: weeks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _ContentCard(
        contentKey: weeks[i].unlockKey,
        badge: 'Week ${weeks[i].weekNum}',
        badgeColor: AppColors.orange,
        title: weeks[i].title,
        scheduledUnlock: weeks[i].scheduledUnlock,
        users: users,
        isAllUnlocked: isAllUnlocked,
        isUserUnlocked: isUserUnlocked,
        toggleAll: toggleAll,
        toggleUser: toggleUser,
        detailWidget: _TaskList(tasks: weeks[i].tasks),
      ),
    );
  }
}

// ── Lessons tab ─────────────────────────────────────────────────────────────

class _LessonsTab extends StatelessWidget {
  const _LessonsTab({
    required this.modules,
    required this.users,
    required this.isAllUnlocked,
    required this.isUserUnlocked,
    required this.toggleAll,
    required this.toggleUser,
  });

  final List<LessonModule> modules;
  final List<AdminUser> users;
  final bool Function(String) isAllUnlocked;
  final bool Function(String, String) isUserUnlocked;
  final Future<void> Function(String, bool) toggleAll;
  final Future<void> Function(String, String, bool) toggleUser;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: modules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _ContentCard(
        contentKey: modules[i].unlockKey,
        badge: 'Module ${modules[i].moduleNum}',
        badgeColor: AppColors.teal,
        title: modules[i].title,
        scheduledUnlock: modules[i].scheduledUnlock,
        users: users,
        isAllUnlocked: isAllUnlocked,
        isUserUnlocked: isUserUnlocked,
        toggleAll: toggleAll,
        toggleUser: toggleUser,
        detailWidget: _VideoPreview(
          description: modules[i].description,
          videoUrl: modules[i].videoUrl,
        ),
      ),
    );
  }
}

// ── Reusable content card ──────────────────────────────────────────────────

class _ContentCard extends StatefulWidget {
  const _ContentCard({
    required this.contentKey,
    required this.badge,
    required this.badgeColor,
    required this.title,
    required this.scheduledUnlock,
    required this.users,
    required this.isAllUnlocked,
    required this.isUserUnlocked,
    required this.toggleAll,
    required this.toggleUser,
    required this.detailWidget,
  });

  final String contentKey;
  final String badge;
  final Color badgeColor;
  final String title;
  final DateTime scheduledUnlock;
  final List<AdminUser> users;
  final bool Function(String) isAllUnlocked;
  final bool Function(String, String) isUserUnlocked;
  final Future<void> Function(String, bool) toggleAll;
  final Future<void> Function(String, String, bool) toggleUser;
  final Widget detailWidget;

  @override
  State<_ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<_ContentCard> {
  bool _expanded = false;
  bool _busy = false;

  Future<void> _handleToggleAll(bool value) async {
    setState(() => _busy = true);
    await widget.toggleAll(widget.contentKey, value);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _handleToggleUser(String userId, bool value) async {
    await widget.toggleUser(widget.contentKey, userId, value);
  }

  @override
  Widget build(BuildContext context) {
    final allUnlocked = widget.isAllUnlocked(widget.contentKey);
    final fmt = DateFormat('MMM d, y — h:mm a');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowDark,
              blurRadius: 12,
              offset: Offset(4, 4)),
          BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 12,
              offset: Offset(-4, -4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: widget.badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.badge,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: widget.badgeColor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: T.title(context)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Symbols.schedule_rounded,
                              size: 13, color: AppColors.inkSoft),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Scheduled: ${fmt.format(widget.scheduledUnlock)}',
                              style: T.small(context)
                                  .copyWith(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Unlock-all toggle ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: allUnlocked
                        ? AppColors.sageSoft
                        : AppColors.coralSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      allUnlocked
                          ? Symbols.lock_open_rounded
                          : Symbols.lock_rounded,
                      size: 13,
                      color: allUnlocked
                          ? AppColors.sageDark
                          : AppColors.coral,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      allUnlocked ? 'Unlocked for All' : 'Locked',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: allUnlocked
                              ? AppColors.sageDark
                              : AppColors.coral),
                    ),
                  ]),
                ),
                const Spacer(),
                // Unlock-all button
                _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : GestureDetector(
                        onTap: () => _handleToggleAll(!allUnlocked),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: allUnlocked
                                ? null
                                : AppColors.tealGrad,
                            color: allUnlocked
                                ? AppColors.coralSoft
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: allUnlocked
                                ? null
                                : [
                                    BoxShadow(
                                        color:
                                            AppColors.teal.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3)),
                                  ],
                          ),
                          child: Text(
                            allUnlocked ? 'Lock All' : 'Unlock All',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: allUnlocked
                                    ? AppColors.coral
                                    : Colors.white),
                          ),
                        ),
                      ),
              ],
            ),
          ),

          // ── Expand toggle ────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Text(
                    _expanded ? 'Hide details' : 'Show details & per-user unlock',
                    style: T.small(context).copyWith(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Symbols.keyboard_arrow_up_rounded
                        : Symbols.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.teal,
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable section ───────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.all(16),
              child: widget.detailWidget,
            ),
            const Divider(height: 1, color: AppColors.line),
            // Per-user toggles
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Per-User Unlock', style: T.label(context)),
                  const SizedBox(height: 10),
                  ...widget.users.map((u) {
                    final unlocked =
                        widget.isUserUnlocked(widget.contentKey, u.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: u.avatarColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                u.initials,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(u.name,
                                  style: T.small(context).copyWith(
                                      fontWeight: FontWeight.w600))),
                          Switch.adaptive(
                            value: unlocked,
                            onChanged: (v) =>
                                _handleToggleUser(u.id, v),
                            activeTrackColor: AppColors.teal,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Task list widget (challenge detail) ───────────────────────────────────

class _TaskList extends StatelessWidget {
  const _TaskList({required this.tasks});

  final List<ChallengeTask> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tasks', style: T.label(context)),
        const SizedBox(height: 8),
        ...tasks.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.orangeSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${t.taskNum}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.orange),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(t.description, style: T.small(context)),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ── Video preview widget (lesson detail) ──────────────────────────────────

class _VideoPreview extends StatelessWidget {
  const _VideoPreview(
      {required this.description, required this.videoUrl});

  final String description;
  final String videoUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(description, style: T.small(context)),
        const SizedBox(height: 12),
        // Placeholder video card
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Text(
                  videoUrl,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Symbols.play_arrow_rounded,
                    color: Colors.white, size: 32),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Video URL: $videoUrl',
            style: T.small(context).copyWith(fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
