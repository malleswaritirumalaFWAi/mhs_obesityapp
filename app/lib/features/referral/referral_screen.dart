import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});
  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  String? _code;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _leaderboard = [];
  bool _loading = true;
  final _applyCtrl = TextEditingController();
  bool _applying = false;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _applyCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final d = await ref.read(apiClientProvider).getJson('/referral');
      if (mounted) setState(() {
        _code = d['referral_code'] as String?;
        _stats = (d['stats'] as Map<String, dynamic>?) ?? {};
        _leaderboard = (d['leaderboard'] as List? ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _apply() async {
    final code = _applyCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _applying = true);
    try {
      await ref.read(apiClientProvider).postJson('/referral/apply', {'code': code});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referral applied! +500 XP bonus'), backgroundColor: AppColors.coral));
        _applyCtrl.clear();
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.coral));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
          children: [
            NeuCard(
              depth: 0.5,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: const Icon(Symbols.arrow_back_rounded,
                      color: AppColors.inkMid, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Refer & Earn',
                          style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                      Text('INVITE FRIENDS, EARN REWARDS',
                          style: T.section(context)),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.coralSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Symbols.redeem_rounded,
                      color: AppColors.coral, size: 20, fill: 1),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // My referral code
            Text('YOUR REFERRAL CODE', style: T.section(context)),
            const SizedBox(height: 12),
            NeuCard(
              depth: 0.5,
              color: AppColors.coralSoft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.coral.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(_code ?? '---',
                        style: T.h2(context).copyWith(letterSpacing: 4, color: AppColors.coral)),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (_code != null) {
                          Clipboard.setData(ClipboardData(text: _code!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied!')));
                        }
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Symbols.copy_all_rounded,
                            color: AppColors.coral, size: 20, fill: 1),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                Text('Both you and your friend get +500 XP when they join!',
                  style: T.small(context).copyWith(color: AppColors.coral)),
              ]),
            ),
            const SizedBox(height: 24),

            // Stats
            Text('YOUR STATS', style: T.section(context)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _StatCard(
                icon: Symbols.group_rounded,
                iconColor: AppColors.coral,
                iconBg: AppColors.coralSoft,
                label: 'Friends joined',
                value: _stats['joined']?.toString() ?? '0',
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                icon: Symbols.redeem_rounded,
                iconColor: AppColors.coral,
                iconBg: AppColors.coralSoft,
                label: 'Rewards given',
                value: _stats['rewarded']?.toString() ?? '0',
              )),
            ]),
            const SizedBox(height: 24),

            // Apply a code
            Text('APPLY A FRIEND\'S CODE', style: T.section(context)),
            const SizedBox(height: 12),
            NeuCard(
              depth: 0.5,
              padding: EdgeInsets.zero,
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _applyCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter referral code (e.g. FQ123ABCD)',
                      hintStyle: T.small(context),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: _applying ? null : _apply,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.coral,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _applying
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ]),
            ),

            if (_leaderboard.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('REFERRAL LEADERBOARD', style: T.section(context)),
              const SizedBox(height: 12),
              ..._leaderboard.take(5).map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NeuCard(
                  depth: 0.5,
                  color: m['you'] == true ? AppColors.coralSoft : null,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: m['rank'] == 1
                            ? AppColors.coralSoft
                            : AppColors.coralSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text('#${m['rank']}',
                            style: T.title(context).copyWith(
                                fontSize: 13,
                                color: m['rank'] == 1
                                    ? AppColors.coral
                                    : AppColors.coral)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(m['name'] as String? ?? 'Member', style: T.title(context).copyWith(fontSize: 14))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.coralSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${m['referrals']} referrals',
                          style: T.small(context).copyWith(color: AppColors.coral, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label, value;
  @override
  Widget build(BuildContext context) {
    return NeuCard(
      depth: 0.5,
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20, fill: 1),
        ),
        const SizedBox(height: 10),
        Text(value, style: T.h2(context).copyWith(fontSize: 24)),
        Text(label, style: T.small(context), textAlign: TextAlign.center),
      ]),
    );
  }
}
