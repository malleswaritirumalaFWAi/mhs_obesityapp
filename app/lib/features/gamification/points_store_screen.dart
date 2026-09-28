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
          content: Text('$name redeemed!'),
          backgroundColor: AppColors.coral,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.coral));
    }
  }

  static const _itemColors = [AppColors.coral, AppColors.coral, AppColors.coral, AppColors.coral];
  static const _itemSoftColors = [AppColors.coralSoft, AppColors.coralSoft, AppColors.coralSoft, AppColors.coralSoft];
  static const _itemIcons = [Symbols.bolt_rounded, Symbols.restaurant_rounded, Symbols.ac_unit_rounded, Symbols.redeem_rounded];

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gamificationProvider);

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
                    children: const [
                      Text('Points Store',
                          style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                      Text('Redeem your XP for rewards',
                          style: TextStyle(
                              color: AppColors.inkSoft, fontSize: 12)),
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
                  child: const Icon(Symbols.shopping_bag_rounded, color: AppColors.coral, size: 20, fill: 1),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            Text('YOUR BALANCE', style: T.section(context)),
            const SizedBox(height: 12),
            NeuCard(
              depth: 0.5,
              color: AppColors.coralSoft,
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Symbols.bolt_rounded, color: AppColors.coral, size: 20, fill: 1),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${g.xp} XP available', style: T.h2(context).copyWith(color: AppColors.coral)),
                  Text('Earn more by completing tasks', style: T.small(context)),
                ]),
              ]),
            ),
            // ── Active perks banner ──────────────────────────────────────
            if (g.doubleXpActive || g.cheatMealPasses > 0) ...[
              const SizedBox(height: 24),
              Text('ACTIVE PERKS', style: T.section(context)),
              const SizedBox(height: 12),
              NeuCard(
                depth: 0.5,
                color: AppColors.coralSoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (g.doubleXpActive) ...[
                      Row(children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.coral.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Symbols.bolt_rounded, color: AppColors.coral, size: 20, fill: 1),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Double XP is ON', style: T.body(context).copyWith(
                            fontWeight: FontWeight.w700, color: AppColors.coral)),
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
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.coral.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Symbols.fastfood_rounded, color: AppColors.coral, size: 20, fill: 1),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${g.cheatMealPasses} Cheat Meal Pass${g.cheatMealPasses > 1 ? "es" : ""} ready',
                          style: T.body(context).copyWith(
                            fontWeight: FontWeight.w700, color: AppColors.coral),
                        ),
                      ]),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            Text('REWARDS', style: T.section(context)),
            const SizedBox(height: 12),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              ..._items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final itemId = item['id'] as String;
                final cost = (item['cost'] as num?)?.toInt() ?? 0;
                final canAfford = g.xp >= cost;
                final accent = _itemColors[idx % _itemColors.length];
                final softAccent = _itemSoftColors[idx % _itemSoftColors.length];
                final itemIcon = _itemIcons[idx % _itemIcons.length];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: NeuCard(
                    depth: 0.5,
                    child: Row(children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: softAccent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(itemIcon, color: accent, size: 28, fill: 1),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item['name'] as String? ?? '', style: T.title(context)),
                        const SizedBox(height: 4),
                        Text(item['description'] as String? ?? '', style: T.small(context)),
                        const SizedBox(height: 8),
                        Row(children: [
                          NeuPill(
                            color: softAccent,
                            child: Text('$cost XP', style: TextStyle(
                              color: accent, fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                          if (itemId == 'double_xp_day' && g.doubleXpActive) ...[
                            const SizedBox(width: 6),
                            NeuPill(
                              color: AppColors.coralSoft,
                              child: Text('Active', style: T.small(context).copyWith(
                                color: AppColors.coral, fontWeight: FontWeight.w700)),
                            ),
                          ],
                          if (itemId == 'cheat_meal' && g.cheatMealPasses > 0) ...[
                            const SizedBox(width: 6),
                            NeuPill(
                              color: AppColors.coralSoft,
                              child: Text('x${g.cheatMealPasses}', style: T.small(context).copyWith(
                                color: AppColors.coral, fontWeight: FontWeight.w700)),
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
                            color: canAfford ? accent : AppColors.line,
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
