import 'dart:math' show min, max;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/providers/gamification_provider.dart';
import '../../core/providers/user_provider.dart';
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
    final xp = (user?.xp as int?) ?? 0;
    final streak = (user?.streak as int?) ?? 0;
    final badges = (user?.badges as List?) ?? [];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final gamState = ref.watch(gamificationProvider);
    final level = gamState.level.name;
    final royalRank = gamState.royalRank;
    final weightAsync = ref.watch(weightHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Profile', style: T.h2(context)),
          const Spacer(),
          NeuIconButton(
              icon: Symbols.settings_rounded,
              onTap: () => context.push(Routes.settings)),
        ]),
        const SizedBox(height: 18),
        NeuCard(
          child: Column(children: [
            Row(children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                    color: AppColors.coralSoft, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(initial,
                    style: T.h2(context).copyWith(color: AppColors.coral)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: T.title(context)),
                    const SizedBox(height: 4),
                    Row(children: [
                    NeuPill(
                      color: AppColors.goldSoft,
                      child: Text('🔥 $streak day streak',
                          style: const TextStyle(
                              color: AppColors.goldDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    NeuPill(
                      color: AppColors.coralSoft,
                      child: Text(level,
                          style: const TextStyle(
                              color: AppColors.coral,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                  ]),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              _Stat(value: xp.toString(), label: 'XP'),
              _divider(),
              _Stat(value: royalRank != null ? '#$royalRank' : '#—', label: 'Rank'),
              _divider(),
              _Stat(value: badges.length.toString(), label: 'Badges'),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        // Contact info card
        NeuCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Account details', style: T.title(context)),
              const SizedBox(height: 14),
              _InfoRow(icon: Symbols.person_rounded, label: 'Name', value: name),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 12),
                _InfoRow(icon: Symbols.mail_rounded, label: 'Email', value: email),
              ],
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 12),
                _InfoRow(icon: Symbols.phone_rounded, label: 'Phone', value: phone),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        weightAsync.when(
          loading: () => NeuCard(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Weight progress', style: T.title(context)),
                    const Spacer(),
                    if (change != null)
                      NeuPill(
                        color: change <= 0 ? AppColors.sageSoft : AppColors.coralSoft,
                        child: Text(
                          '${change > 0 ? '↑' : '↓'} ${change.abs().toStringAsFixed(1)} kg',
                          style: TextStyle(
                            color: change <= 0 ? AppColors.sageDark : AppColors.coral,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(
                      curW != null ? '${curW.toStringAsFixed(1)} kg' : '— kg',
                      style: T.h1(context),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        [
                          if (w.startWeight > 0) 'from ${w.startWeight.toStringAsFixed(1)}',
                          if (w.targetWeight > 0) 'target ${w.targetWeight.toStringAsFixed(0)}',
                        ].join(' · '),
                        style: T.small(context),
                      ),
                    ),
                  ]),
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
        const SizedBox(height: 16),
        Row(children: [
          Text('Recent badges', style: T.title(context)),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push(Routes.badgeGallery),
            child: Text('View all →',
                style: T.small(context).copyWith(
                    color: AppColors.coral, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 12),
        Builder(builder: (ctx) {
          if (badges.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                    emoji: shown[i]['emoji'] as String? ?? '🏅',
                    label: shown[i]['name'] as String? ?? 'Badge',
                  ),
                ),
              ],
            ],
          );
        }),
        const SizedBox(height: 20),
        Text('Tools', style: T.title(context)),
        const SizedBox(height: 12),
        _SettingRow(
            icon: Symbols.stars_rounded,
            label: 'Gamification & XP',
            onTap: () => context.push(Routes.gamification)),
        _SettingRow(
            icon: Symbols.bar_chart_rounded,
            label: 'Weekly progress',
            onTap: () => context.push(Routes.weeklyProgress)),
        _SettingRow(
            icon: Symbols.help_outline_rounded,
            label: 'How to play',
            onTap: () => context.push(Routes.gamificationTutorial)),
        _SettingRow(
            icon: Symbols.straighten_rounded,
            label: 'Body measurements',
            onTap: () => context.push(Routes.measurements)),
        _SettingRow(
            icon: Symbols.photo_camera_rounded,
            label: 'Progress photos',
            onTap: () => context.push(Routes.progressPhotos)),
        _SettingRow(
            icon: Symbols.card_giftcard_rounded,
            label: 'Refer & earn',
            onTap: () => context.push(Routes.referral)),
        _SettingRow(
            icon: Symbols.restaurant_menu_rounded,
            label: 'Diet plan',
            onTap: () => context.push(Routes.dietPlan)),
        const SizedBox(height: 20),
        Text('Settings', style: T.title(context)),
        const SizedBox(height: 12),
        _SettingRow(
            icon: Symbols.notifications_rounded,
            label: 'Notifications',
            onTap: () => context.push(Routes.notifications)),
        _SettingRow(
            icon: Symbols.favorite_rounded,
            label: 'Health goals',
            onTap: () => context.push(Routes.settings)),
        _SettingRow(
            icon: Symbols.help_rounded,
            label: 'Help & support',
            onTap: () => context.push(Routes.settings)),
      ],
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 36, color: AppColors.line, margin: const EdgeInsets.symmetric(horizontal: 8));
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value, style: T.h2(context).copyWith(fontSize: 20)),
        Text(label, style: T.small(context)),
      ]),
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
            barWidth: 4,
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                  radius: 5, color: Colors.white, strokeColor: AppColors.coral, strokeWidth: 3),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.coral.withValues(alpha: 0.25), AppColors.coral.withValues(alpha: 0.0)],
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
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 30)),
        const SizedBox(height: 8),
        Text(label, style: T.small(context).copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeuCard(
        onTap: onTap,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 20, color: AppColors.inkMid),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: T.small(context).copyWith(fontSize: 11)),
        Text(value, style: T.title(context).copyWith(fontSize: 14)),
      ]),
    ]);
  }
}
