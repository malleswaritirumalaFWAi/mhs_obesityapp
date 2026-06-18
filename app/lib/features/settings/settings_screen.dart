import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/router.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _push = true;
  bool _coachDigest = true;
  bool _leaderboard = false;
  Future<void> _logout() async {
    await ref.read(sessionProvider.notifier).signOut();
    if (mounted) context.go(Routes.welcome);
  }

  Future<void> _requestDataExport() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export your data'),
        content: const Text(
          'We will prepare a copy of all your data and notify you when it\'s ready. '
          'This may take up to 24 hours.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Request')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(apiClientProvider).postJson('/compliance/data-export', {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data export requested. You\'ll be notified when ready.'),
          backgroundColor: AppColors.sage));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.coral));
    }
  }

  Future<void> _requestDataDeletion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your data'),
        content: const Text(
          'This will permanently delete all your data including progress, meals, and badges. '
          'This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.coral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete my data')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(apiClientProvider).postJson('/compliance/data-delete', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data deletion request submitted.'),
            backgroundColor: AppColors.sage));
        await ref.read(sessionProvider.notifier).signOut();
        if (mounted) context.go(Routes.welcome);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.coral));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.tealGrad,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Symbols.arrow_back_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text('Settings',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                ),
                const Icon(Symbols.tune_rounded, color: Colors.white, size: 22),
              ]),
            ),
            const SizedBox(height: 20),

            Text('NOTIFICATIONS', style: T.label(context)),
            const SizedBox(height: 12),
            NeuCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(children: [
                _Toggle(
                    icon: Symbols.notifications_rounded,
                    label: 'Push notifications',
                    value: _push,
                    onChanged: (v) => setState(() => _push = v)),
                _Toggle(
                    icon: Symbols.restaurant_rounded,
                    label: 'Daily coach digest',
                    value: _coachDigest,
                    onChanged: (v) => setState(() => _coachDigest = v)),
                _Toggle(
                    icon: Symbols.emoji_events_rounded,
                    label: 'Leaderboard updates',
                    value: _leaderboard,
                    onChanged: (v) => setState(() => _leaderboard = v),
                    last: true),
              ]),
            ),
            const SizedBox(height: 22),

            Text('ACCOUNT', style: T.label(context)),
            const SizedBox(height: 12),
            _LinkRow(icon: Symbols.favorite_rounded, label: 'Health goals'),
            _LinkRow(icon: Symbols.help_rounded, label: 'Help & support'),
            _LinkRow(icon: Symbols.description_rounded, label: 'Terms & conditions'),
            const SizedBox(height: 22),

            Text('PRIVACY & DATA (DPDP ACT 2023)', style: T.label(context)),
            const SizedBox(height: 12),
            NeuCard(
              onTap: _requestDataExport,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(children: [
                const Icon(Symbols.download_rounded, color: AppColors.inkMid),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Export my data', style: T.title(context).copyWith(fontSize: 15)),
                  Text('Get a copy of all your data', style: T.small(context)),
                ])),
                const Icon(Symbols.chevron_right_rounded, color: AppColors.inkSoft),
              ]),
            ),
            const SizedBox(height: 10),
            NeuCard(
              onTap: _requestDataDeletion,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(children: [
                const Icon(Symbols.delete_rounded, color: AppColors.coral),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Delete my data', style: T.title(context).copyWith(fontSize: 15, color: AppColors.coral)),
                  Text('Permanently remove all your data', style: T.small(context)),
                ])),
                const Icon(Symbols.chevron_right_rounded, color: AppColors.inkSoft),
              ]),
            ),
            const SizedBox(height: 22),

            NeuCard(
              onTap: _logout,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(children: [
                const Icon(Symbols.logout_rounded, color: AppColors.coral),
                const SizedBox(width: 14),
                Text('Log out',
                    style: T.title(context).copyWith(color: AppColors.coral, fontSize: 15)),
              ]),
            ),
            const SizedBox(height: 16),
            Center(child: Text('FitQuest v1.0.0', style: T.small(context))),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.last = false,
  });
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.inkMid, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: T.title(context).copyWith(fontSize: 15))),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.coral,
          inactiveTrackColor: AppColors.line,
        ),
      ]),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeuCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(children: [
          Icon(icon, color: AppColors.inkMid),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: T.title(context).copyWith(fontSize: 15))),
          const Icon(Symbols.chevron_right_rounded, color: AppColors.inkSoft),
        ]),
      ),
    );
  }
}
