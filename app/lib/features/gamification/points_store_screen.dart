import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/gamification_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class PointsStoreScreen extends ConsumerStatefulWidget {
  const PointsStoreScreen({super.key});
  @override
  ConsumerState<PointsStoreScreen> createState() => _PointsStoreScreenState();
}

class _PointsStoreScreenState extends ConsumerState<PointsStoreScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final d = await ref.read(apiClientProvider).getJson('/gamification/points-store');
      if (mounted) setState(() { _items = (d['items'] as List? ?? []).cast<Map<String,dynamic>>(); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _redeem(String itemId, String name, int cost) async {
    final g = ref.read(gamificationProvider);
    if (g.xp < cost) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Need $cost XP (you have ${g.xp})'),
        backgroundColor: AppColors.coral,
      ));
      return;
    }
    try {
      await ref.read(apiClientProvider).postJson('/gamification/points-store/redeem', {'item_id': itemId});
      await ref.read(gamificationProvider.notifier).load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ $name redeemed!'),
          backgroundColor: AppColors.sage,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.coral));
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gamificationProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.orangeGrad,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Points Store',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                      Text('Redeem your XP for rewards',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const Text('🛍️', style: TextStyle(fontSize: 26)),
              ]),
            ),
            const SizedBox(height: 16),

            NeuCard(
              color: AppColors.goldSoft,
              child: Row(children: [
                const Text('⚡', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${g.xp} XP available', style: T.h2(context).copyWith(color: AppColors.goldDark)),
                  Text('Earn more by completing tasks', style: T.small(context)),
                ]),
              ]),
            ),
            // ── Active perks banner ──────────────────────────────────────
            if (g.doubleXpActive || g.cheatMealPasses > 0) ...[
              const SizedBox(height: 4),
              NeuCard(
                color: const Color(0xFFE8F5E9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Perks', style: T.title(context).copyWith(color: AppColors.sage)),
                    const SizedBox(height: 8),
                    if (g.doubleXpActive) ...[
                      Row(children: [
                        const Text('⚡', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Double XP is ON', style: T.body(context).copyWith(
                            fontWeight: FontWeight.w700, color: AppColors.sage)),
                          if (g.doubleXpExpiresAt != null)
                            Text(
                              'Expires ${DateFormat('MMM d, h:mm a').format(g.doubleXpExpiresAt!.toLocal())}',
                              style: T.small(context),
                            ),
                        ])),
                      ]),
                    ],
                    if (g.doubleXpActive && g.cheatMealPasses > 0)
                      const SizedBox(height: 6),
                    if (g.cheatMealPasses > 0)
                      Row(children: [
                        const Text('🍕', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          '${g.cheatMealPasses} Cheat Meal Pass${g.cheatMealPasses > 1 ? "es" : ""} ready',
                          style: T.body(context).copyWith(
                            fontWeight: FontWeight.w700, color: AppColors.orange),
                        ),
                      ]),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              ..._items.map((item) {
                final itemId = item['id'] as String;
                final cost = (item['cost'] as num?)?.toInt() ?? 0;
                // Double XP stacks (adds 24h to existing timer), so always redeemable if affordable
                final canAfford = g.xp >= cost;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: NeuCard(
                    child: Row(children: [
                      Text(item['emoji'] as String? ?? '🎁', style: const TextStyle(fontSize: 40)),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item['name'] as String? ?? '', style: T.title(context)),
                        const SizedBox(height: 4),
                        Text(item['description'] as String? ?? '', style: T.small(context)),
                        const SizedBox(height: 8),
                        Row(children: [
                          NeuPill(
                            color: AppColors.goldSoft,
                            child: Text('$cost XP', style: const TextStyle(
                              color: AppColors.goldDark, fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                          if (itemId == 'double_xp_day' && g.doubleXpActive) ...[
                            const SizedBox(width: 6),
                            NeuPill(
                              color: const Color(0xFFE8F5E9),
                              child: Text('Active', style: T.small(context).copyWith(
                                color: AppColors.sage, fontWeight: FontWeight.w700)),
                            ),
                          ],
                          if (itemId == 'cheat_meal' && g.cheatMealPasses > 0) ...[
                            const SizedBox(width: 6),
                            NeuPill(
                              color: const Color(0xFFFFF3E0),
                              child: Text('x${g.cheatMealPasses}', style: T.small(context).copyWith(
                                color: AppColors.orange, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ]),
                      ])),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: canAfford ? () => _redeem(itemId, item['name'] as String, cost) : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: canAfford ? AppColors.coral : AppColors.line,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text('Redeem',
                            style: TextStyle(
                              color: canAfford ? Colors.white : AppColors.inkSoft,
                              fontWeight: FontWeight.w700, fontSize: 13,
                            )),
                        ),
                      ),
                    ]),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
