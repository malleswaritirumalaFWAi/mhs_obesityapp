import 'dart:convert';
import 'dart:math' show min, max;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/providers/gamification_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../features/group/leaderboard_provider.dart';
import 'profile_provider.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [_profileHeader(context, ref, null)],
          ),
          data: (user) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [_profileHeader(context, ref, user)],
          ),
        ),
      ),
    );
  }

  Widget _profileHeader(BuildContext context, WidgetRef ref, dynamic user) {
    final name = (user?.name as String?) ?? 'User';
    final email = (user?.email as String?) ?? '';
    final phone = (user?.phone as String?) ?? '';
    final xp = (user?.totalXp as int?) ?? 0;
    final streak = (user?.streak as int?) ?? 0;
    final badges = (user?.badges as List?) ?? [];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final profilePhotoUrl = (user?.profilePhotoUrl as String?);
    final gamState = ref.watch(gamificationProvider);
    final levelLabel = gamState.level.label;
    final leaderboardData = ref.watch(leaderboardProvider);
    final royalRank = leaderboardData.whenOrNull(
      data: (members) {
        final me = members.where((m) => m.you).firstOrNull;
        return me?.rank;
      },
    );
    final weightAsync = ref.watch(weightHistoryProvider);

    // Level progress calculation
    final tier = getTierFromXP(gamState.totalXp);
    final nextTier = tier.nextMin;
    final levelProgress = nextTier != null
        ? ((gamState.totalXp - tier.min) / (nextTier - tier.min)).clamp(0.0, 1.0)
        : 1.0;
    final xpInLevel = gamState.totalXp - tier.min;
    final xpNeeded = nextTier != null ? nextTier - tier.min : 0;
    // Find next tier label
    final tierIndex = xpTiers.indexOf(tier);
    final nextTierLabel = tierIndex < xpTiers.length - 1
        ? xpTiers[tierIndex + 1].label
        : 'Max';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Profile hero card ──
        NeuCard(
          depth: 0.5,
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              _buildProfileAvatar(initial, profilePhotoUrl, 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: T.title(context).copyWith(fontSize: 18)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.coralSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Symbols.local_fire_department_rounded,
                                size: 13, color: AppColors.coral),
                            const SizedBox(width: 3),
                            Text('$streak day streak',
                                style: const TextStyle(
                                    color: AppColors.coral,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.coralSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(levelLabel,
                            style: const TextStyle(
                                color: AppColors.coral,
                                fontWeight: FontWeight.w700,
                                fontSize: 11)),
                      ),
                    ]),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push(Routes.editProfile),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Symbols.edit_rounded,
                      color: AppColors.inkMid, size: 20),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => context.push(Routes.settings),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Symbols.settings_rounded,
                      color: AppColors.inkMid, size: 20),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Stats row ──
        Text('STATS', style: T.section(context)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _StatCard(
              icon: Symbols.bolt_rounded,
              iconBg: AppColors.coral,
              value: '$xp',
              label: 'Total XP',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Symbols.local_fire_department_rounded,
              iconBg: AppColors.coral,
              value: '$streak',
              label: 'Day Streak',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Symbols.leaderboard_rounded,
              iconBg: AppColors.coral,
              value: royalRank != null ? '#$royalRank' : '#--',
              label: 'Rank',
            ),
          ),
        ]),
        const SizedBox(height: 24),

        // ── Level progress ──
        Text('LEVEL PROGRESS', style: T.section(context)),
        const SizedBox(height: 12),
        NeuCard(
          depth: 0.5,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Symbols.workspace_premium_rounded,
                      size: 18, color: AppColors.coral),
                ),
                const SizedBox(width: 10),
                Text('$levelLabel  \u2192  $nextTierLabel',
                    style: T.title(context).copyWith(fontSize: 14)),
                const Spacer(),
                Text(
                  nextTier != null ? '$xpInLevel / $xpNeeded XP' : 'MAX',
                  style: T.small(context).copyWith(
                      fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: levelProgress,
                  minHeight: 6,
                  backgroundColor: AppColors.line,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.coral),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Weight progress ──
        Text('WEIGHT PROGRESS', style: T.section(context)),
        const SizedBox(height: 12),
        weightAsync.when(
          loading: () => NeuCard(
            depth: 0.5,
            child: SizedBox(
              height: 100,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (w) {
            final curW = w.currentWeight ?? (w.startWeight > 0 ? w.startWeight : null);
            final change = w.weightChange;

            // Build ascending list of up to last 4 weigh-in entries.
            final ascending = w.entries.reversed.toList();
            final last4 = ascending.length > 4
                ? ascending.sublist(ascending.length - 4)
                : ascending;
            final spots = <FlSpot>[];
            for (int i = 0; i < last4.length; i++) {
              final raw = last4[i]['weight'];
              final wt = raw is num
                  ? raw.toDouble()
                  : double.tryParse(raw?.toString() ?? '');
              if (wt != null && wt > 0) spots.add(FlSpot(i.toDouble(), wt));
            }

            // Date labels for each entry, last one = 'Now'.
            const months = ['Jan','Feb','Mar','Apr','May','Jun',
                            'Jul','Aug','Sep','Oct','Nov','Dec'];
            final labels = last4.map((e) {
              final dt = DateTime.tryParse(e['created_at'] as String? ?? '');
              if (dt == null) return '';
              return '${months[dt.month - 1]} ${dt.day}';
            }).toList();
            if (labels.isNotEmpty) labels[labels.length - 1] = 'Now';

            double minY = 60, maxY = 100;
            if (spots.isNotEmpty) {
              final ys = spots.map((s) => s.y).toList();
              minY = (ys.reduce(min) - 3).floorToDouble();
              maxY = (ys.reduce(max) + 3).ceilToDouble();
            }
            if (w.targetWeight > 0) minY = min(minY, w.targetWeight - 2);
            if (w.startWeight > 0) maxY = max(maxY, w.startWeight + 2);

            return NeuCard(
              depth: 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.coral.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Symbols.monitor_weight_rounded,
                          size: 18, color: AppColors.coral),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        curW != null ? '${curW.toStringAsFixed(1)} kg' : '-- kg',
                        style: T.h2(context),
                      ),
                    ),
                    if (change != null)
                      NeuPill(
                        color: change <= 0 ? AppColors.coralSoft : AppColors.coralSoft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              change <= 0
                                  ? Symbols.trending_down_rounded
                                  : Symbols.trending_up_rounded,
                              size: 14,
                              color: change <= 0 ? AppColors.coral : AppColors.coral,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${change.abs().toStringAsFixed(1)} kg',
                              style: TextStyle(
                                color: change <= 0 ? AppColors.coral : AppColors.coral,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 42),
                    child: Text(
                      [
                        if (w.startWeight > 0) 'from ${w.startWeight.toStringAsFixed(1)}',
                        if (w.targetWeight > 0) 'target ${w.targetWeight.toStringAsFixed(0)}',
                      ].join(' \u00B7 '),
                      style: T.small(context),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (spots.length >= 2) ...[
                    SizedBox(
                      height: 140,
                      child: _WeightChart(spots: spots, minY: minY, maxY: maxY),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: labels
                          .map((l) => Text(l,
                              style: T.small(context).copyWith(fontSize: 11)))
                          .toList(),
                    ),
                  ] else
                    const SizedBox(
                      height: 60,
                      child: Center(
                        child: Text(
                          'Log your weight to see progress here',
                          style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // ── Account details ──
        Text('ACCOUNT', style: T.section(context)),
        const SizedBox(height: 12),
        NeuCard(
          depth: 0.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(icon: Symbols.person_rounded, iconBg: AppColors.coral, label: 'Name', value: name),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 14),
                _InfoRow(icon: Symbols.mail_rounded, iconBg: AppColors.coral, label: 'Email', value: email),
              ],
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 14),
                _InfoRow(icon: Symbols.phone_rounded, iconBg: AppColors.coral, label: 'Phone', value: phone),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Recent badges ──
        Row(children: [
          Text('BADGES', style: T.section(context)),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push(Routes.badgeGallery),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('View all',
                    style: T.small(context).copyWith(
                        color: AppColors.coral, fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(width: 2),
                const Icon(Symbols.chevron_right_rounded,
                    size: 16, color: AppColors.coral),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Builder(builder: (ctx) {
          if (badges.isEmpty) {
            return NeuCard(
              depth: 0.5,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Center(
                child: Text(
                  'Complete challenges to earn badges!',
                  style: T.small(context).copyWith(color: AppColors.inkSoft),
                ),
              ),
            );
          }
          final shown = badges.take(3).toList();
          return Row(
            children: [
              for (int i = 0; i < shown.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: _Badge(
                    emoji: shown[i]['emoji'] as String? ?? '',
                    label: shown[i]['name'] as String? ?? 'Badge',
                  ),
                ),
              ],
            ],
          );
        }),
        const SizedBox(height: 24),

        // ── Tools ──
        Text('TOOLS', style: T.section(context)),
        const SizedBox(height: 12),
        _SettingRow(
            icon: Symbols.edit_rounded,
            iconBg: AppColors.coral,
            label: 'Edit profile',
            onTap: () => context.push(Routes.editProfile)),
        _SettingRow(
            icon: Symbols.stars_rounded,
            iconBg: AppColors.coral,
            label: 'Gamification & XP',
            onTap: () => context.push(Routes.gamification)),
        _SettingRow(
            icon: Symbols.bar_chart_rounded,
            iconBg: AppColors.coral,
            label: 'Weekly progress',
            onTap: () => context.push(Routes.weeklyProgress)),
        _SettingRow(
            icon: Symbols.help_outline_rounded,
            iconBg: AppColors.coral,
            label: 'How to play',
            onTap: () => context.push(Routes.gamificationTutorial)),
        _SettingRow(
            icon: Symbols.straighten_rounded,
            iconBg: AppColors.coral,
            label: 'Body measurements',
            onTap: () => context.push(Routes.measurements)),
        _SettingRow(
            icon: Symbols.photo_camera_rounded,
            iconBg: AppColors.coral,
            label: 'Progress photos',
            onTap: () => context.push(Routes.progressPhotos)),
        _SettingRow(
            icon: Symbols.card_giftcard_rounded,
            iconBg: AppColors.coral,
            label: 'Refer & earn',
            onTap: () => context.push(Routes.referral)),
        _SettingRow(
            icon: Symbols.restaurant_menu_rounded,
            iconBg: AppColors.coral,
            label: 'Diet plan',
            onTap: () => context.push(Routes.dietPlan)),
        const SizedBox(height: 24),

        // ── Settings ──
        Text('SETTINGS', style: T.section(context)),
        const SizedBox(height: 12),
        _SettingRow(
            icon: Symbols.notifications_rounded,
            iconBg: AppColors.coral,
            label: 'Notifications',
            onTap: () => context.push(Routes.notifications)),
        _SettingRow(
            icon: Symbols.favorite_rounded,
            iconBg: AppColors.coral,
            label: 'Health goals',
            onTap: () => context.push(Routes.settings)),
        _SettingRow(
            icon: Symbols.help_rounded,
            iconBg: AppColors.coral,
            label: 'Help & support',
            onTap: () => context.push(Routes.settings)),
      ],
    );
  }

  Widget _buildProfileAvatar(String initial, String? photoUrl, double size) {
    final hasBase64 = photoUrl != null && photoUrl.startsWith('data:image');
    if (hasBase64) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: MemoryImage(base64Decode(photoUrl.split(',').last)),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.coralSoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(initial,
          style: TextStyle(
              color: AppColors.coral,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.4)),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color iconBg;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      depth: 0.5,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: iconBg),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: T.h2(context).copyWith(fontSize: 18)),
          const SizedBox(height: 2),
          Text(label,
              style: T.small(context).copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({
    required this.spots,
    required this.minY,
    required this.maxY,
  });
  final List<FlSpot> spots;
  final double minY, maxY;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.coral,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                  radius: 4, color: Colors.white, strokeColor: AppColors.coral, strokeWidth: 2.5),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.coral.withValues(alpha: 0.2), AppColors.coral.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.emoji, required this.label});
  final String emoji;
  final String label;
  @override
  Widget build(BuildContext context) {
    return NeuCard(
      depth: 0.5,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 8),
        Text(label,
            textAlign: TextAlign.center,
            style: T.small(context).copyWith(fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.label, this.onTap, required this.iconBg});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color iconBg;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeuCard(
        depth: 0.5,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: iconBg),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: T.title(context).copyWith(fontSize: 15))),
          const Icon(Symbols.chevron_right_rounded, color: AppColors.inkSoft, size: 20),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, required this.iconBg});
  final IconData icon;
  final String label;
  final String value;
  final Color iconBg;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: iconBg.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: iconBg),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: T.small(context).copyWith(fontSize: 11)),
        const SizedBox(height: 1),
        Text(value, style: T.title(context).copyWith(fontSize: 14)),
      ]),
    ]);
  }
}
