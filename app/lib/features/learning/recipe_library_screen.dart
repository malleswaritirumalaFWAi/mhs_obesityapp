import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class RecipeLibraryScreen extends ConsumerStatefulWidget {
  const RecipeLibraryScreen({super.key});
  @override
  ConsumerState<RecipeLibraryScreen> createState() => _RecipeLibraryScreenState();
}

class _RecipeLibraryScreenState extends ConsumerState<RecipeLibraryScreen> {
  List<Map<String, dynamic>> _recipes = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load([String? dietType]) async {
    setState(() => _loading = true);
    try {
      final params = dietType != null && dietType != 'all' ? '?diet_type=$dietType' : '';
      final d = await ref.read(apiClientProvider).getJson('/recipes$params');
      if (mounted) setState(() {
        _recipes = (d['recipes'] as List? ?? []).cast<Map<String,dynamic>>();
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Container(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recipe Library',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        Text('Healthy meal ideas for you',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Text('🍛', style: TextStyle(fontSize: 26)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                for (final f in [('all','All'), ('veg','Vegetarian'), ('nonveg','Non-veg')])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () { setState(() => _filter = f.$1); _load(f.$1); },
                      child: NeuPill(
                        color: _filter == f.$1 ? AppColors.coral : AppColors.line,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(f.$2,
                          style: TextStyle(
                            color: _filter == f.$1 ? Colors.white : AppColors.inkMid,
                            fontWeight: FontWeight.w700, fontSize: 13,
                          )),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
                    itemCount: _recipes.length,
                    itemBuilder: (_, i) => _RecipeCard(recipe: _recipes[i]),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});
  final Map<String, dynamic> recipe;

  @override
  Widget build(BuildContext context) {
    final isVeg = recipe['diet_type'] == 'veg';
    return NeuCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(isVeg ? '🥦' : '🍗', style: const TextStyle(fontSize: 28)),
          const Spacer(),
          NeuPill(
            color: isVeg ? AppColors.sageSoft : AppColors.coralSoft,
            child: Text(isVeg ? 'Veg' : 'Non-veg',
              style: TextStyle(
                color: isVeg ? AppColors.sageDark : AppColors.coral,
                fontWeight: FontWeight.w700, fontSize: 10)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(recipe['title'] as String? ?? '',
          style: T.title(context).copyWith(fontSize: 14),
          maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Text('${recipe['calories'] ?? '--'} kcal · ${recipe['prep_minutes'] ?? '--'} min',
          style: T.small(context).copyWith(fontSize: 11, color: AppColors.coral)),
        const Spacer(),
        Text(
          (recipe['cuisine'] as String? ?? '').replaceAll('_', ' ').toUpperCase(),
          style: T.label(context).copyWith(fontSize: 10),
        ),
      ]),
    );
  }
}
