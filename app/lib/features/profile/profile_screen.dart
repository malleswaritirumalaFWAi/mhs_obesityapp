import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                    child: Text('A', style: T.h2(context).copyWith(color: AppColors.coral)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Aarav Sharma', style: T.title(context)),
                        const SizedBox(height: 4),
                        const NeuPill(
                          color: AppColors.goldSoft,
                          child: Text('🔥 23 day streak',
                              style: TextStyle(
                                  color: AppColors.goldDark,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  _Stat(value: '1,840', label: 'XP'),
                  _divider(),
                  _Stat(value: '#12', label: 'Rank'),
                  _divider(),
                  _Stat(value: '7', label: 'Badges'),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            NeuCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Weight progress', style: T.title(context)),
                    const Spacer(),
                    const NeuPill(
                      color: AppColors.sageSoft,
                      child: Text('↓ 1.8 kg',
                          style: TextStyle(
                              color: AppColors.sageDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('74.2 kg', style: T.h1(context)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('from 76.0 · target 68', style: T.small(context)),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  SizedBox(height: 140, child: _WeightChart()),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final l in const ['Wk 1', 'Wk 2', 'Wk 3', 'Now'])
                        Text(l, style: T.small(context).copyWith(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Recent badges', style: T.title(context)),
            const SizedBox(height: 12),
            Row(children: const [
              Expanded(child: _Badge(emoji: '🔥', label: 'Streak')),
              SizedBox(width: 12),
              Expanded(child: _Badge(emoji: '🏃', label: '100K steps')),
              SizedBox(width: 12),
              Expanded(child: _Badge(emoji: '🥗', label: 'Clean wk')),
            ]),
            const SizedBox(height: 20),
            Text('Settings', style: T.title(context)),
            const SizedBox(height: 12),
            _SettingRow(
                icon: Symbols.notifications_rounded,
                label: 'Notifications',
                onTap: () => context.push(Routes.settings)),
            _SettingRow(
                icon: Symbols.favorite_rounded,
                label: 'Health goals',
                onTap: () => context.push(Routes.settings)),
            _SettingRow(
                icon: Symbols.help_rounded,
                label: 'Help & support',
                onTap: () => context.push(Routes.settings)),
          ],
        ),
      ),
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
  @override
  Widget build(BuildContext context) {
    const spots = [
      FlSpot(0, 76.0),
      FlSpot(1, 75.3),
      FlSpot(2, 74.8),
      FlSpot(3, 74.2),
    ];
    return LineChart(
      LineChartData(
        minY: 67,
        maxY: 77,
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
