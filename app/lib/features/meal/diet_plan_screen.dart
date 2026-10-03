import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:convert';

import '../../core/api/api_client.dart';
import '../../core/providers/meal_stats_provider.dart';
import '../../core/providers/tasks_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';
import 'web_camera.dart';

// ─── Main Screen ────────────────────────────────────────────────────────────

class DietPlanScreen extends ConsumerStatefulWidget {
  const DietPlanScreen({super.key});
  @override
  ConsumerState<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends ConsumerState<DietPlanScreen> {
  Map<String, dynamic>? _plan;
  Map<String, dynamic>? _todayNutrition;
  Map<String, dynamic>? _todayMeals;
  Map<String, bool> _completions = {};
  int _todayDay = 1;
  int _todayWeek = 1;
  int _dayInWeek = 1;
  int _totalXpEarned = 0;
  bool _loading = true;
  bool _generating = false;
  final Set<String> _completing = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final d = await ref.read(apiClientProvider).getJson('/diet-plan');
      if (mounted) setState(() {
        _plan           = d['plan'] as Map<String, dynamic>?;
        _todayNutrition = d['today_nutrition'] as Map<String, dynamic>?;
        _todayMeals     = d['today_meals'] as Map<String, dynamic>?;
        _todayDay       = (d['today_day']        as num?)?.toInt() ?? 1;
        _todayWeek      = (d['today_week']       as num?)?.toInt() ?? 1;
        _dayInWeek      = (d['day_in_week']      as num?)?.toInt() ?? _todayDay;
        _totalXpEarned  = (d['total_xp_earned']  as num?)?.toInt() ?? 0;
        final c = d['completions'] as Map<String, dynamic>? ?? {};
        _completions = c.map((k, v) => MapEntry(k, v == true));
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      await ref.read(apiClientProvider).postJson('/diet-plan/generate', {});
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Diet plan refreshed!'),
            backgroundColor: AppColors.coral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not refresh diet plan. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _showCompleteOptions(String mealType) {
    if (_completions[mealType] == true || _completing.contains(mealType)) return;
    final label = mealType[0].toUpperCase() + mealType.substring(1);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Log $label',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink)),
            const SizedBox(height: 4),
            const Text('How would you like to complete this meal?',
                style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: _CompleteOptionTile(
                  icon: Symbols.photo_camera_rounded,
                  label: 'Camera',
                  subtitle: 'Take a photo',
                  onTap: () {
                    Navigator.pop(ctx);
                    _completeMealWithPhoto(mealType, ImageSource.camera);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompleteOptionTile(
                  icon: Symbols.image_rounded,
                  label: 'Album',
                  subtitle: 'Pick a photo',
                  onTap: () {
                    Navigator.pop(ctx);
                    _completeMealWithPhoto(mealType, ImageSource.gallery);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompleteOptionTile(
                  icon: Symbols.skip_next_rounded,
                  label: 'Skip',
                  subtitle: 'No photo',
                  onTap: () {
                    Navigator.pop(ctx);
                    _completeMealOnly(mealType);
                  },
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Future<void> _completeMealWithPhoto(String mealType, ImageSource source) async {
    if (_completing.contains(mealType)) return;
    setState(() => _completing.add(mealType));

    Uint8List? bytes;
    String mime = 'image/jpeg';

    if (kIsWeb && source == ImageSource.camera) {
      final (b, m) = await captureImageFromCamera();
      if (b == null) {
        if (mounted) setState(() => _completing.remove(mealType));
        return;
      }
      bytes = b; mime = m;
    } else {
      final x = await ImagePicker().pickImage(
          source: source, imageQuality: 30, maxWidth: 480);
      if (x == null) {
        if (mounted) setState(() => _completing.remove(mealType));
        return;
      }
      bytes = await x.readAsBytes();
      mime = x.mimeType?.isNotEmpty == true ? x.mimeType! : 'image/jpeg';
    }

    final api = ref.read(apiClientProvider);
    final label = mealType[0].toUpperCase() + mealType.substring(1);

    try {
      // Analyze photo
      final res = await api.postJson('/meals/analyze', {
        'image_base64': base64Encode(bytes!),
        'mime': mime,
      });

      // Save meal to log
      await api.postJson('/meals', {
        'meal_type': label,
        'items': (res['items'] as List?)?.map((e) => e.toString()).toList(),
        'calories': (res['calories'] as num?)?.toInt(),
        'carbs': (res['carbs'] as num?)?.toInt(),
        'protein': (res['protein'] as num?)?.toInt(),
        'fat': (res['fat'] as num?)?.toInt(),
      });

      // Complete diet plan
      final result = await api.postJson('/diet-plan/complete', {'meal_type': mealType});

      if (mounted) {
        ref.read(mealStatsProvider.notifier).addMealType(label);
        ref.invalidate(tasksProvider);
        setState(() {
          _completions[mealType] = true;
          _totalXpEarned += (result['xp'] as num?)?.toInt() ?? 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label logged with photo!'),
            backgroundColor: AppColors.coral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not log meal. Try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _completing.remove(mealType));
    }
  }

  Future<void> _completeMealOnly(String mealType) async {
    if (_completions[mealType] == true || _completing.contains(mealType)) return;
    setState(() => _completing.add(mealType));
    try {
      final result = await ref.read(apiClientProvider)
          .postJson('/diet-plan/complete', {'meal_type': mealType});
      if (mounted) {
        final label = mealType[0].toUpperCase() + mealType.substring(1);
        ref.read(mealStatsProvider.notifier).addMealType(label);
        ref.invalidate(tasksProvider);
        setState(() {
          _completions[mealType] = true;
          _totalXpEarned += (result['xp'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _completing.remove(mealType));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tn = _todayNutrition;
    final mealKeys = const ['breakfast', 'lunch', 'snack', 'dinner'];
    final totalMeals = _todayMeals == null ? 0
        : mealKeys.where((k) => _todayMeals![k] != null).length;
    final completedCount = _completions.values.where((v) => v).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
                          const Text('Diet Plan',
                              style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900)),
                          const Text('Your personalized meal guide',
                              style: TextStyle(
                                  color: AppColors.inkSoft, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.coral.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Symbols.menu_book_rounded,
                          color: AppColors.coral, size: 20, fill: 1),
                    ),
                    const SizedBox(width: 10),
                    Tooltip(
                      message: 'Regenerate diet plan',
                      child: GestureDetector(
                        onTap: _generating ? null : _generate,
                        child: _generating
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral))
                            : const Icon(Symbols.auto_awesome_rounded,
                                color: AppColors.coral, size: 22),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Week / Day progress banner ──
                _WeekProgressBanner(
                  weekNum: _todayWeek,
                  dayInWeek: _dayInWeek,
                  programDay: _todayDay,
                  totalXpEarned: _totalXpEarned,
                  completedCount: completedCount,
                  totalMeals: totalMeals,
                  hasPlan: _plan != null,
                  generating: _generating,
                  onGenerate: _generate,
                ),
                const SizedBox(height: 24),

                // ── Today's nutrition summary ──
                if (tn != null) ...[
                  _NutritionCard(tn: tn),
                  const SizedBox(height: 24),
                ],

                // ── Meal quest cards ──
                if (_plan == null)
                  NeuCard(
                    depth: 0.5,
                    child: Column(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Symbols.menu_book_rounded,
                            size: 20, color: AppColors.coral, fill: 1),
                      ),
                      const SizedBox(height: 12),
                      Text('No diet plan yet', style: T.body(context)),
                      const SizedBox(height: 6),
                      Text('Your coach will create a personalized plan, or generate one with AI',
                          style: T.small(context), textAlign: TextAlign.center),
                    ]),
                  )
                else if (_todayMeals == null)
                  NeuCard(depth: 0.5, child: Center(child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('No meals found for today', style: T.small(context)),
                  )))
                else
                  for (final key in mealKeys)
                    if (_todayMeals![key] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _MealQuestCard(
                          mealType: key,
                          meal: _todayMeals![key] as Map<String, dynamic>,
                          completed: _completions[key] == true,
                          completing: _completing.contains(key),
                          onComplete: () => _showCompleteOptions(key),
                        ),
                      ),
              ],
            ),
      ),
    );
  }
}

// ─── Week Progress Banner ───────────────────────────────────────────────────

class _WeekProgressBanner extends StatelessWidget {
  const _WeekProgressBanner({
    required this.weekNum,
    required this.dayInWeek,
    required this.programDay,
    required this.totalXpEarned,
    required this.completedCount,
    required this.totalMeals,
    required this.hasPlan,
    required this.generating,
    required this.onGenerate,
  });
  final int weekNum, dayInWeek, programDay, totalXpEarned, completedCount, totalMeals;
  final bool hasPlan, generating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.coralSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: AppColors.coral.withValues(alpha: 0.12),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Top row: WEEK badge + XP / Generate ──
        Row(children: [
          // Week badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)),
            ),
            child: Text(
              'WEEK $weekNum',
              style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.w900,
                  fontSize: 11, letterSpacing: 1.4),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Day $dayInWeek of 7  ·  Program day $programDay/84',
              style: const TextStyle(color: AppColors.inkSoft,
                  fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          if (!hasPlan)
            GestureDetector(
              onTap: generating ? null : onGenerate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.coral,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: generating
                  ? const SizedBox(width: 13, height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Generate Plan',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            )
          else if (totalXpEarned > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.coral.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.coral.withValues(alpha: 0.35)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Symbols.star_rounded, color: AppColors.coral, size: 14, fill: 1),
                const SizedBox(width: 4),
                Text('+$totalXpEarned XP',
                    style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.w800, fontSize: 12)),
              ]),
            ),
        ]),

        const SizedBox(height: 18),

        // ── Day dots progress ──
        _DayProgressRow(dayInWeek: dayInWeek),

        const SizedBox(height: 16),

        // ── Meals completion mini-bar ──
        if (hasPlan && totalMeals > 0)
          Row(children: [
            ...List.generate(totalMeals, (i) => Container(
              margin: const EdgeInsets.only(right: 5),
              width: 9, height: 9,
              decoration: BoxDecoration(
                color: i < completedCount
                    ? AppColors.coral
                    : AppColors.line,
                shape: BoxShape.circle,
              ),
            )),
            const SizedBox(width: 8),
            Text(
              completedCount == totalMeals
                  ? 'All meals done!'
                  : '$completedCount / $totalMeals meals completed',
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
            ),
          ]),
      ]),
    );
  }
}

// ─── Day Progress Row ────────────────────────────────────────────────────────

class _DayProgressRow extends StatelessWidget {
  const _DayProgressRow({required this.dayInWeek});
  final int dayInWeek;

  @override
  Widget build(BuildContext context) {
    // 7 dots connected by 6 line segments
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(13, (i) {
        if (i.isOdd) {
          final leftDay = i ~/ 2 + 1;
          final isCompleted = leftDay < dayInWeek;
          return Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.coral : AppColors.line,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }
        final day = i ~/ 2 + 1;
        return _DayDot(day: day, isPast: day < dayInWeek, isCurrent: day == dayInWeek);
      }),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.isPast, required this.isCurrent});
  final int day;
  final bool isPast, isCurrent;

  @override
  Widget build(BuildContext context) {
    if (isCurrent) {
      return Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.coral, Color(0xFF6BAF8F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: AppColors.coral.withValues(alpha: 0.55),
                blurRadius: 10, spreadRadius: 2),
          ],
        ),
        child: Center(
          child: Text('$day',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w900, fontSize: 14)),
        ),
      );
    }
    if (isPast) {
      return Container(
        width: 28, height: 28,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.coral,
        ),
        child: const Center(
          child: Icon(Symbols.check_rounded, color: Colors.white, size: 14, fill: 1),
        ),
      );
    }
    // Future day
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(color: AppColors.line, width: 1.5),
      ),
      child: Center(
        child: Text('$day',
            style: const TextStyle(color: AppColors.inkSoft,
                fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }
}

// ─── Nutrition Card ──────────────────────────────────────────────────────────

class _NutritionCard extends StatelessWidget {
  const _NutritionCard({required this.tn});
  final Map<String, dynamic> tn;

  @override
  Widget build(BuildContext context) {
    final cal = (tn['calories'] as num?)?.toInt() ?? 0;
    const goal = 1500;
    final fraction = (cal / goal).clamp(0.0, 1.0);

    return NeuCard(
      depth: 0.5,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Symbols.local_fire_department_rounded,
                color: AppColors.coral, size: 20, fill: 1),
          ),
          const SizedBox(width: 8),
          Text("TODAY'S NUTRITION", style: T.section(context)),
        ]),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$cal kcal',
              style: T.h2(context).copyWith(color: AppColors.coral, fontSize: 26)),
          Text('Goal: ~$goal kcal', style: T.small(context)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            backgroundColor: AppColors.line,
            valueColor: AlwaysStoppedAnimation<Color>(
              fraction < 0.5 ? AppColors.coral
                  : fraction < 0.9 ? AppColors.coral
                  : AppColors.coral,
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _Macro('Carbs',    '${tn['carbs']   ?? 0}g', AppColors.coral)),
          Expanded(child: _Macro('Protein',  '${tn['protein'] ?? 0}g', AppColors.coral)),
          Expanded(child: _Macro('Fat',      '${tn['fat']     ?? 0}g', AppColors.coral)),
        ]),
      ]),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro(this.label, this.value, this.color);
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: T.title(context).copyWith(color: color, fontSize: 18)),
    Text(label, style: T.small(context).copyWith(fontSize: 11)),
  ]);
}

// ─── Meal Quest Card ─────────────────────────────────────────────────────────

class _MealQuestCard extends StatelessWidget {
  const _MealQuestCard({
    required this.mealType,
    required this.meal,
    required this.completed,
    required this.completing,
    required this.onComplete,
  });
  final String mealType;
  final Map<String, dynamic> meal;
  final bool completed;
  final bool completing;
  final VoidCallback onComplete;

  static const _mealColor = <String, Color>{
    'breakfast': AppColors.coral,
    'lunch':     AppColors.coral,
    'snack':     AppColors.coral,
    'dinner':    AppColors.coral,
  };
  static const _mealBg = <String, Color>{
    'breakfast': AppColors.coralSoft,
    'lunch':     AppColors.coralSoft,
    'snack':     AppColors.coralSoft,
    'dinner':    AppColors.coralSoft,
  };
  static const _mealIcon = <String, IconData>{
    'breakfast': Symbols.wb_sunny_rounded,
    'lunch':     Symbols.lunch_dining_rounded,
    'snack':     Symbols.local_cafe_rounded,
    'dinner':    Symbols.bedtime_rounded,
  };
  static const _xp = 15;

  @override
  Widget build(BuildContext context) {
    final items = meal['items'] as List? ?? [];
    final cal   = (meal['cal'] as num?)?.toInt() ?? 0;
    final label = mealType[0].toUpperCase() + mealType.substring(1);
    final color = _mealColor[mealType] ?? AppColors.coral;
    final bg    = _mealBg[mealType]    ?? AppColors.coralSoft;
    final icon  = _mealIcon[mealType]  ?? Symbols.restaurant_rounded;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(color: AppColors.shadowDark.withValues(alpha: 0.5),
              blurRadius: 8, offset: const Offset(3, 3)),
          const BoxShadow(color: AppColors.shadowLight,
              blurRadius: 8, offset: Offset(-3, -3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header ──
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20, fill: 1),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: T.title(context).copyWith(fontSize: 15)),
              Text('$_xp XP quest',
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            ])),
            // Calorie badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
              child: Text('$cal kcal',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ]),

          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.line),
          const SizedBox(height: 12),

          // ── Food items with quantity ──
          ...items.map((item) {
            final name = item is Map ? (item['name'] as String? ?? '') : item.toString();
            final qty  = item is Map ? (item['qty']  as String? ?? '') : '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name,
                      style: T.body(context).copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                  if (qty.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(qty,
                          style: T.small(context).copyWith(color: AppColors.inkSoft, fontSize: 11)),
                    ),
                ])),
              ]),
            );
          }),

          const SizedBox(height: 4),
          Container(height: 1, color: AppColors.line),
          const SizedBox(height: 12),

          // ── Completion button / status ──
          if (completed)
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.coralSoft, shape: BoxShape.circle),
                child: const Icon(Symbols.check_rounded, color: AppColors.coral, size: 16, fill: 1),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Meal Complete!',
                    style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w800, fontSize: 13)),
                Text('+$_xp XP earned', style: T.small(context).copyWith(color: AppColors.coral)),
              ])),
              const Icon(Symbols.military_tech_rounded, color: AppColors.coral, size: 26, fill: 1),
            ])
          else
            GestureDetector(
              onTap: completing ? null : onComplete,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (completing)
                    const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  else
                    const Icon(Symbols.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    completing ? 'Logging...' : 'Complete Meal  +$_xp XP',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Complete option tile (bottom sheet) ────────────────────────────────────

class _CompleteOptionTile extends StatelessWidget {
  const _CompleteOptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String label, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.coral, size: 22, fill: 1),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(fontSize: 10, color: AppColors.inkSoft)),
        ]),
      ),
    );
  }
}
