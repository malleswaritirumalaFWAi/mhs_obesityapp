import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            NeuTopBar(title: 'Settings', onBack: () => context.pop()),
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
            _LinkRow(icon: Symbols.lock_rounded, label: 'Privacy & data'),
            _LinkRow(icon: Symbols.help_rounded, label: 'Help & support'),
            _LinkRow(icon: Symbols.description_rounded, label: 'Terms & conditions'),
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
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
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
