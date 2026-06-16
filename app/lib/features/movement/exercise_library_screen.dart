import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

const _categoryIcons = <String, IconData>{
  'cardio':    Symbols.directions_run_rounded,
  'strength':  Symbols.fitness_center_rounded,
  'yoga':      Symbols.self_improvement_rounded,
  'stretch':   Symbols.accessibility_new_rounded,
};
const _categoryColors = <String, Color>{
  'cardio':   AppColors.coral,
  'strength': AppColors.gold,
  'yoga':     AppColors.berry,
  'stretch':  AppColors.sage,
};

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});
  @override
  ConsumerState<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  List<Map<String, dynamic>> _exercises = [];
  bool _loading = true;
  String _category = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load([String? category]) async {
    setState(() => _loading = true);
    try {
      final params = category != null && category != 'all' ? '?category=$category' : '';
      final d = await ref.read(apiClientProvider).getJson('/exercises$params');
      if (mounted) setState(() {
        _exercises = (d['exercises'] as List? ?? []).cast<Map<String,dynamic>>();
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
              child: NeuTopBar(title: 'Exercise Library 💪', onBack: () => context.pop()),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                for (final cat in ['all', 'cardio', 'strength', 'yoga', 'stretch'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () { setState(() => _category = cat); _load(cat); },
                      child: NeuPill(
                        color: _category == cat ? (_categoryColors[cat] ?? AppColors.coral) : AppColors.line,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Text(cat[0].toUpperCase() + cat.substring(1),
                          style: TextStyle(
                            color: _category == cat ? Colors.white : AppColors.inkMid,
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
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: _exercises.length,
                    itemBuilder: (_, i) => _ExerciseCard(exercise: _exercises[i]),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  const _ExerciseCard({required this.exercise});
  final Map<String, dynamic> exercise;
  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    final category = e['category'] as String? ?? '';
    final icon = _categoryIcons[category] ?? Symbols.fitness_center_rounded;
    final color = _categoryColors[category] ?? AppColors.coral;
    final instructions = (e['instructions'] is String ? <String>[] : e['instructions'] as List? ?? []).cast<String>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, fill: 1),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e['title'] as String? ?? '', style: T.title(context).copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '${e['duration_min'] ?? '--'} min · ~${e['calories_est'] ?? '--'} cal · ${e['level'] ?? ''}',
                  style: T.small(context).copyWith(fontSize: 12),
                ),
              ])),
              Icon(_expanded ? Symbols.keyboard_arrow_up_rounded : Symbols.keyboard_arrow_down_rounded,
                color: AppColors.inkSoft),
            ]),
          ),
          if (_expanded && instructions.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...instructions.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('${e.key + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(e.value, style: T.body(context).copyWith(fontSize: 14))),
              ]),
            )),
          ],
        ]),
      ),
    );
  }
}
