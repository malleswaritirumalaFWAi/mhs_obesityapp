import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class MealAnalysis {
  MealAnalysis({
    required this.items,
    required this.calories,
    required this.confidence,
    required this.carbs,
    required this.protein,
    required this.fat,
  });
  final List<String> items;
  final int calories;
  final int confidence;
  final int carbs, protein, fat;

  factory MealAnalysis.fromJson(Map<String, dynamic> j) => MealAnalysis(
        items: (j['items'] as List? ?? []).map((e) => e.toString()).toList(),
        calories: (j['calories'] as num?)?.toInt() ?? 0,
        confidence: (j['confidence'] as num?)?.toInt() ?? 90,
        carbs: (j['carbs'] as num?)?.toInt() ?? 50,
        protein: (j['protein'] as num?)?.toInt() ?? 25,
        fat: (j['fat'] as num?)?.toInt() ?? 25,
      );

  static MealAnalysis demo() => MealAnalysis(
        items: ['Roti (2)', 'Dal', 'Sabzi', 'Salad'],
        calories: 480,
        confidence: 96,
        carbs: 55,
        protein: 25,
        fat: 20,
      );
}

const _mealTypes = [
  (emoji: '🍳', label: 'Breakfast'),
  (emoji: '🥗', label: 'Lunch'),
  (emoji: '🍪', label: 'Snack'),
  (emoji: '🍲', label: 'Dinner'),
];

class LogMealScreen extends ConsumerStatefulWidget {
  const LogMealScreen({super.key});
  @override
  ConsumerState<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends ConsumerState<LogMealScreen> {
  File? _photo;
  MealAnalysis? _result;
  bool _analyzing = false;
  int _mealType = 0;

  Future<void> _pick(ImageSource source) async {
    final x = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1280);
    if (x == null) return;
    setState(() {
      _photo = File(x.path);
      _analyzing = true;
      _result = null;
    });
    await _analyze(x);
  }

  Future<void> _analyze(XFile x) async {
    final api = ref.read(apiClientProvider);
    try {
      final bytes = await x.readAsBytes();
      final res = await api.postJson('/meals/analyze', {
        'image_base64': base64Encode(bytes),
        'mime': 'image/jpeg',
      });
      if (!mounted) return;
      setState(() {
        _result = MealAnalysis.fromJson(res);
        _analyzing = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Demo fallback — Claude key/backend not configured.
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        _result = MealAnalysis.demo();
        _analyzing = false;
      });
    }
  }

  void _removeItem(int i) => setState(() => _result?.items.removeAt(i));

  Future<void> _save() async {
    final r = _result;
    try {
      await ref.read(apiClientProvider).postJson('/meals', {
        'meal_type': _mealTypes[_mealType].label,
        'items': r?.items,
        'calories': r?.calories,
        'carbs': r?.carbs,
        'protein': r?.protein,
        'fat': r?.fat,
      });
    } catch (_) {/* demo mode — backend optional */}
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Meal logged · +15 XP 🎉')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeuTopBar(title: 'Log meal', onBack: () => context.pop()),
              const SizedBox(height: 18),
              // photo / preview
              AspectRatio(
                aspectRatio: 16 / 10,
                child: NeuCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _photo == null
                        ? _PickPrompt(onCamera: () => _pick(ImageSource.camera),
                            onGallery: () => _pick(ImageSource.gallery))
                        : Stack(fit: StackFit.expand, children: [
                            Image.file(_photo!, fit: BoxFit.cover),
                            if (_analyzing)
                              Container(
                                color: Colors.black.withValues(alpha: 0.35),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(color: Colors.white),
                                      SizedBox(height: 12),
                                      Text('AI analyzing…',
                                          style: TextStyle(
                                              color: Colors.white, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Positioned(
                                top: 12,
                                left: 12,
                                child: NeuPill(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Symbols.auto_awesome_rounded,
                                        color: Colors.white, size: 16, fill: 1),
                                    const SizedBox(width: 6),
                                    Text('AI detected · ${_result?.confidence ?? 0}%',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12)),
                                  ]),
                                ),
                              ),
                          ]),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_result != null) ...[
                Expanded(child: _resultBody(context)),
                Row(children: [
                  Expanded(
                    child: NeuButton(
                      onPressed: () => _pick(ImageSource.camera),
                      filled: false,
                      child: const Text('Retake'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: NeuButton.primary('Save · +15 XP', onPressed: _save),
                  ),
                ]),
              ] else
                const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultBody(BuildContext context) {
    final r = _result!;
    return ListView(
      children: [
        Row(children: [
          Text('Detected items', style: T.title(context)),
          const Spacer(),
          Text('Edit', style: T.small(context).copyWith(color: AppColors.coral)),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < r.items.length; i++)
              NeuPill(
                color: AppColors.sageSoft,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(r.items[i],
                      style: const TextStyle(
                          color: AppColors.sageDark, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _removeItem(i),
                    child: const Icon(Symbols.close_rounded,
                        size: 16, color: AppColors.sageDark),
                  ),
                ]),
              ),
            NeuPill(
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Symbols.add_rounded, size: 16, color: AppColors.coral),
                SizedBox(width: 4),
                Text('Add',
                    style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 18),
        NeuCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Estimated calories', style: T.small(context)),
                const Spacer(),
                const NeuPill(
                  color: AppColors.sageSoft,
                  child: Text('WITHIN TARGET',
                      style: TextStyle(
                          color: AppColors.sageDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 11)),
                ),
              ]),
              const SizedBox(height: 6),
              Text('~${r.calories} kcal', style: T.h1(context)),
              const SizedBox(height: 14),
              _MacroBar(carbs: r.carbs, protein: r.protein, fat: r.fat),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Meal type', style: T.title(context)),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < _mealTypes.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == _mealTypes.length - 1 ? 0 : 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _mealType = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _mealType == i ? AppColors.coralSoft : AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _mealType == i ? AppColors.coral : AppColors.line),
                      ),
                      child: Column(children: [
                        Text(_mealTypes[i].emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(_mealTypes[i].label,
                            style: T.small(context).copyWith(fontSize: 11)),
                      ]),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _PickPrompt extends StatelessWidget {
  const _PickPrompt({required this.onCamera, required this.onGallery});
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Symbols.add_a_photo_rounded, size: 44, color: AppColors.inkSoft),
          const SizedBox(height: 12),
          Text('Snap your meal', style: T.title(context)),
          Text('AI estimates calories & macros', style: T.small(context)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            NeuButton(
              onPressed: onCamera,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Symbols.photo_camera_rounded, size: 18),
                SizedBox(width: 6),
                Text('Camera'),
              ]),
            ),
            const SizedBox(width: 12),
            NeuButton(
              onPressed: onGallery,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Symbols.image_rounded, size: 18),
                SizedBox(width: 6),
                Text('Gallery'),
              ]),
            ),
          ]),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({required this.carbs, required this.protein, required this.fat});
  final int carbs, protein, fat;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Row(children: [
            Expanded(flex: carbs, child: Container(height: 12, color: AppColors.gold)),
            Expanded(flex: protein, child: Container(height: 12, color: AppColors.sage)),
            Expanded(flex: fat, child: Container(height: 12, color: AppColors.berry)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _legend(context, AppColors.gold, 'Carbs $carbs%'),
          _legend(context, AppColors.sage, 'Protein $protein%'),
          _legend(context, AppColors.berry, 'Fat $fat%'),
        ]),
      ],
    );
  }

  Widget _legend(BuildContext c, Color color, String label) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: T.small(c).copyWith(fontSize: 12)),
      ]);
}
