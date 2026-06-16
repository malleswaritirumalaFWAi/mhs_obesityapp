import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
            NeuTopBar(title: 'Points Store 🛍️', onBack: () => context.pop()),
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
            const SizedBox(height: 24),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              ..._items.map((item) {
                final cost = (item['cost'] as num?)?.toInt() ?? 0;
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
                        NeuPill(
                          color: AppColors.goldSoft,
                          child: Text('$cost XP', style: const TextStyle(
                            color: AppColors.goldDark, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                      ])),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: canAfford ? () => _redeem(item['id'] as String, item['name'] as String, cost) : null,
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
