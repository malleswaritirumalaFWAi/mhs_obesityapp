import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_content_model.dart';
import '../../services/admin_service.dart';
import 'admin_users_panel.dart';
import 'admin_content_panel.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<AdminUser> _users = [];
  bool _loadingUsers = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    final real = await AdminService.fetchRealUsers();
    if (!mounted) return;
    setState(() {
      // Use real users if available; fall back to dummies so the panel is never empty
      _users = (real != null && real.isNotEmpty) ? real : kDummyUsers.toList();
      _loadingUsers = false;
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will be returned to the app home screen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log out',
                  style: TextStyle(color: AppColors.coral))),
        ],
      ),
    );
    if (confirm == true) {
      await AdminService.logout();
      if (mounted) context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(color: AppColors.shadowDark, blurRadius: 12, offset: Offset(4, 4)),
                BoxShadow(color: AppColors.shadowLight, blurRadius: 12, offset: Offset(-4, -4)),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 16, 20, 20),
            child: Row(
              children: [
                // Admin icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.coralSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Symbols.admin_panel_settings_rounded,
                      color: AppColors.coral, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Dashboard',
                        style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'FitQuest — Manage users & content',
                        style: TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Refresh users button
                GestureDetector(
                  onTap: _loadingUsers ? null : _loadUsers,
                  child: _loadingUsers
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral))
                      : const Icon(Symbols.refresh_rounded,
                          color: AppColors.inkMid, size: 22),
                ),
                const SizedBox(width: 12),
                // Logout button
                GestureDetector(
                  onTap: _logout,
                  child: const Icon(Symbols.logout_rounded,
                      color: AppColors.inkMid, size: 22),
                ),
              ],
            ),
          ),

          // ── Stats summary strip ────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryTile(
                  icon: Symbols.group_rounded,
                  label: 'Total Users',
                  value: '${_users.length}',
                  color: AppColors.teal,
                ),
                _Divider(),
                _SummaryTile(
                  icon: Symbols.emoji_events_rounded,
                  label: 'Challenges',
                  value: '${kChallengeWeeks.length}',
                  color: AppColors.orange,
                ),
                _Divider(),
                _SummaryTile(
                  icon: Symbols.menu_book_rounded,
                  label: 'Lessons',
                  value: '${kLessonModules.length}',
                  color: AppColors.berry,
                ),
              ],
            ),
          ),

          // ── Tab bar ────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                color: AppColors.coral,
                borderRadius: BorderRadius.circular(14),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.inkSoft,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Symbols.group_rounded, size: 18),
                  text: 'Users',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: Icon(Symbols.tune_rounded, size: 18),
                  text: 'Content',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
              ],
            ),
          ),

          // ── Tab views ──────────────────────────────────────────────────
          Expanded(
            child: _loadingUsers && _users.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tab,
                    children: [
                      AdminUsersPanel(users: _users),
                      AdminContentPanel(users: _users),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color)),
        Text(label,
            style: T.small(context).copyWith(fontSize: 10)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 36, color: AppColors.line);
  }
}
