import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/meal_stats_provider.dart';
import '../../core/providers/tasks_provider.dart';
import 'web_camera.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

// ── Meal type data ─────────────────────────────────────────────────────────────

const _mealTypes = [
  (emoji: '🍳', label: 'Breakfast'),
  (emoji: '🥗', label: 'Lunch'),
  (emoji: '🍪', label: 'Snacks'),
  (emoji: '🍲', label: 'Dinner'),
];

String _emojiFor(String mealType) {
  switch (mealType.toLowerCase()) {
    case 'breakfast': return '🍳';
    case 'lunch':     return '🥗';
    case 'snacks':
    case 'snack':     return '🍪';
    case 'dinner':    return '🍲';
    default:          return '🍽️';
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

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

class _MealEntry {
  _MealEntry({
    required this.id,
    required this.mealType,
    required this.items,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.createdAt,
  });
  final int id;
  final String mealType;
  final List<String> items;
  final int calories, carbs, protein, fat;
  final DateTime createdAt;

  String get relativeDate {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(createdAt.year, createdAt.month, createdAt.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '$diff days ago';
  }

  String get timeLabel =>
      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
}

// ── Screen ────────────────────────────────────────────────────────────────────

class LogMealScreen extends ConsumerStatefulWidget {
  const LogMealScreen({super.key, this.mealType});
  final String? mealType; // unused for locking; kept for API compatibility
  @override
  ConsumerState<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends ConsumerState<LogMealScreen> {
  // Meal type selector (free — user picks)
  int _mealType = 0; // default Breakfast

  // Photo / analysis
  Uint8List? _photoBytes;
  MealAnalysis? _result;
  bool _analyzing = false;
  String? _analysisError;

  // Save guard
  bool _saving = false;

  // History
  List<_MealEntry> _history = [];
  bool _loadingHistory = true;
  String? _historyError;
  int _visibleGroups = 2; // today + yesterday shown by default

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final res = await ref.read(apiClientProvider).getJson('/meals');
      final raw = (res['meals'] as List?) ?? [];
      final entries = raw.map((m) {
        final map = Map<String, dynamic>.from(m as Map);
        final items = _parseItems(map['items']);
        int toInt(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;
        return _MealEntry(
          id: toInt(map['id']),
          mealType: map['meal_type'] as String? ?? '',
          items: items,
          calories: toInt(map['calories']),
          carbs: toInt(map['carbs']),
          protein: toInt(map['protein']),
          fat: toInt(map['fat']),
          createdAt: (DateTime.tryParse(map['created_at'] as String? ?? '') ??
              DateTime.now()).toLocal(),
        );
      }).toList();
      if (mounted) setState(() { _history = entries; _loadingHistory = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingHistory = false; _historyError = 'Could not load history. Check your connection.'; });
    }
  }

  static List<String> _parseItems(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  Future<void> _pick(ImageSource source) async {
    Uint8List? bytes;
    String mime = 'image/jpeg';

    if (kIsWeb && source == ImageSource.camera) {
      final (b, m) = await captureImageFromCamera();
      if (b == null) return;
      bytes = b; mime = m;
    } else {
      final x = await ImagePicker().pickImage(
          source: source, imageQuality: 30, maxWidth: 480);
      if (x == null) return;
      bytes = await x.readAsBytes();
      mime = x.mimeType?.isNotEmpty == true ? x.mimeType! : 'image/jpeg';
    }

    setState(() {
      _photoBytes = bytes;
      _analyzing = true;
      _result = null;
      _analysisError = null;
    });
    await _analyzeBytes(bytes!, mime);
  }

  Future<void> _analyzeBytes(Uint8List bytes, String mime) async {
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.postJson('/meals/analyze', {
        'image_base64': base64Encode(bytes),
        'mime': mime,
      });
      if (!mounted) return;

      if (res['_mock'] == true) {
        // Dev mode — no API key configured, show mock data with a note.
        setState(() {
          _result = MealAnalysis.fromJson(res);
          _analyzing = false;
          _analysisError = 'Demo mode: no AI key set. Showing sample data.';
        });
      } else {
        // Real Claude response — show it with no error.
        setState(() {
          _result = MealAnalysis.fromJson(res);
          _analyzing = false;
          _analysisError = null;
        });
      }
    } catch (e) {
      // Backend returned an HTTP error (rate limit, overload, auth, etc.) or is unreachable.
      // Do NOT show mock food items — show the real error with a Retry option instead.
      if (!mounted) return;
      String msg = 'Analysis failed. Please try again.';

      if (e is DioException) {
        final status = e.response?.statusCode;
        final data = e.response?.data;
        // Extract actual server error message if available.
        final serverMsg = (data is Map) ? (data['message'] as String?) : null;
        if (serverMsg != null && serverMsg.isNotEmpty) {
          msg = serverMsg;
        } else if (status == 401) {
          msg = 'AI service authentication failed. Please contact support.';
        } else if (status == 429) {
          msg = 'Rate limit reached. Please wait a moment and try again.';
        } else if (status == 529 || status == 503) {
          msg = 'AI service is busy. Please try again in a few seconds.';
        } else if (e.type == DioExceptionType.connectionTimeout ||
                   e.type == DioExceptionType.receiveTimeout) {
          msg = 'Request timed out. Please check your connection and retry.';
        }
      } else {
        final errStr = e.toString();
        if (errStr.contains('rate limit') || errStr.contains('rate_limit')) {
          msg = 'Rate limit reached. Please wait a moment and try again.';
        } else if (errStr.contains('overloaded') || errStr.contains('529')) {
          msg = 'AI service is busy. Please try again in a few seconds.';
        }
      }

      setState(() {
        _result = null;       // no mock data shown
        _analyzing = false;
        _analysisError = msg;
      });
    }
  }

  void _removeItem(int i) => setState(() => _result?.items.removeAt(i));

  /// Shows a simple dialog to enter meal details manually when AI analysis fails.
  Future<void> _enterManually() async {
    final foodCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log manually'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: foodCtrl,
            decoration: const InputDecoration(
              labelText: 'What did you eat?',
              hintText: 'e.g. Idli 3 pcs, Sambar, Chutney',
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: calCtrl,
            decoration: const InputDecoration(
              labelText: 'Estimated calories (optional)',
              hintText: '400',
            ),
            keyboardType: TextInputType.number,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log meal'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final food = foodCtrl.text.trim();
    if (food.isEmpty) return;
    final cal = int.tryParse(calCtrl.text.trim()) ?? 400;
    setState(() {
      _result = MealAnalysis(
        items: food.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        calories: cal,
        confidence: 0,
        carbs: 50,
        protein: 25,
        fat: 25,
      );
      _analysisError = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return; // guard against double-tap / rapid re-submit
    setState(() => _saving = true);

    final r = _result;
    final selectedType = _mealTypes[_mealType].label;
    final api = ref.read(apiClientProvider);

    try {
      await api.postJson('/meals', {
        'meal_type': selectedType,
        'items': r?.items,
        'calories': r?.calories,
        'carbs': r?.carbs,
        'protein': r?.protein,
        'fat': r?.fat,
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save meal. Check your connection and try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    // Optimistically mark this meal type as logged so the progress indicator
    // on Today's Plan updates immediately without waiting for a re-fetch.
    ref.read(mealStatsProvider.notifier).addMealType(selectedType);
    ref.invalidate(tasksProvider);
    setState(() {
      _saving = false;
      _photoBytes = null;
      _result = null;
      _analysisError = null;
      _loadingHistory = true;
      _historyError = null;
    });
    await _loadHistory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$selectedType logged · +5 XP')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealStats = ref.watch(mealStatsProvider);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeuCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Symbols.arrow_back_rounded,
                        color: AppColors.inkMid, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Log meal',
                            style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        Text('Snap a photo to analyze nutrition',
                            style: TextStyle(
                                color: AppColors.inkSoft, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Text('🍽️', style: TextStyle(fontSize: 26)),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Today's meal progress ──────────────────────────────────────
              if (!mealStats.loading) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: mealStats.isComplete
                        ? AppColors.sageSoft
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: mealStats.isComplete
                          ? AppColors.sage.withOpacity(0.4)
                          : AppColors.line,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(
                          mealStats.isComplete
                              ? Symbols.check_circle_rounded
                              : Symbols.restaurant_rounded,
                          size: 15,
                          fill: 1,
                          color: mealStats.isComplete
                              ? AppColors.sageDark
                              : AppColors.inkSoft,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          mealStats.isComplete
                              ? 'All main meals logged today!'
                              : "Today's progress · ${mealStats.progressLabel}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: mealStats.isComplete
                                ? AppColors.sageDark
                                : AppColors.inkMid,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        _TodayMealBadge(
                          emoji: '🍳',
                          label: 'Breakfast',
                          done: mealStats.has('Breakfast'),
                        ),
                        const SizedBox(width: 8),
                        _TodayMealBadge(
                          emoji: '🥗',
                          label: 'Lunch',
                          done: mealStats.has('Lunch'),
                        ),
                        const SizedBox(width: 8),
                        _TodayMealBadge(
                          emoji: '🍲',
                          label: 'Dinner',
                          done: mealStats.has('Dinner'),
                        ),
                        const SizedBox(width: 8),
                        _TodayMealBadge(
                          emoji: '🍪',
                          label: 'Snack',
                          done: mealStats.has('Snacks'),
                          optional: true,
                        ),
                      ]),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: mealStats.mainCount / 3,
                          minHeight: 5,
                          backgroundColor: AppColors.line,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            mealStats.isComplete
                                ? AppColors.sage
                                : AppColors.coral,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ] else
                const SizedBox(height: 4),

              // ── Meal type selector (always free) ──
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
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _mealType == i ? AppColors.coralSoft : AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: _mealType == i ? AppColors.coral : AppColors.line),
                            ),
                            child: Column(children: [
                              Text(_mealTypes[i].emoji,
                                  style: const TextStyle(fontSize: 20)),
                              const SizedBox(height: 4),
                              Text(_mealTypes[i].label,
                                  style: T.small(context).copyWith(
                                      fontSize: 11,
                                      color: _mealType == i
                                          ? AppColors.coral
                                          : AppColors.inkMid,
                                      fontWeight: _mealType == i
                                          ? FontWeight.w700
                                          : FontWeight.w400)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Photo / preview ──
              Text('Snap your meal', style: T.title(context)),
              const SizedBox(height: 10),
              AspectRatio(
                aspectRatio: 16 / 10,
                child: NeuCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _photoBytes == null
                        ? _PickPrompt(
                            onCamera: () => _pick(ImageSource.camera),
                            onGallery: () => _pick(ImageSource.gallery))
                        : Stack(fit: StackFit.expand, children: [
                            Image.memory(_photoBytes!, fit: BoxFit.cover),
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
                                          style: TextStyle(color: Colors.white,
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              )
                            else if (_result != null)
                              Positioned(
                                top: 12, left: 12,
                                child: NeuPill(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Symbols.auto_awesome_rounded,
                                        color: Colors.white, size: 16, fill: 1),
                                    const SizedBox(width: 6),
                                    Text('AI · ${_result!.confidence}%',
                                        style: const TextStyle(color: Colors.white,
                                            fontWeight: FontWeight.w700, fontSize: 12)),
                                  ]),
                                ),
                              ),
                          ]),
                  ),
                ),
              ),

              // ── Error banner / retry ──
              if (_analysisError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_analysisError!,
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
                    ),
                    // Show retry + manual entry when analysis failed (no result)
                    if (_result == null && _photoBytes != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() { _analyzing = true; _analysisError = null; });
                          _analyzeBytes(_photoBytes!, 'image/jpeg');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.coral,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Retry',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _enterManually,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade600,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Manual',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ]),
                ),
              ],

              // ── Analysis result ──
              if (_result != null) ...[
                const SizedBox(height: 18),
                _resultBody(context),
                const SizedBox(height: 16),
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
                    child: NeuButton.primary(
                      'Save · +5 XP',
                      loading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ]),
              ],

              // ── Meal history ──
              const SizedBox(height: 32),
              _buildHistory(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultBody(BuildContext context) {
    final r = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Detected items', style: T.title(context)),
          const Spacer(),
          Text('Edit', style: T.small(context).copyWith(color: AppColors.coral)),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
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
                      style: TextStyle(color: AppColors.sageDark,
                          fontWeight: FontWeight.w800, fontSize: 11)),
                ),
              ]),
              const SizedBox(height: 6),
              Text('~${r.calories} kcal', style: T.h1(context)),
              const SizedBox(height: 14),
              _MacroBar(carbs: r.carbs, protein: r.protein, fat: r.fat),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistory(BuildContext context) {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_history.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _HistorySectionHeader(count: 0),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Center(
            child: Column(children: [
              const Icon(Symbols.no_meals_rounded, size: 36, color: AppColors.inkSoft),
              const SizedBox(height: 8),
              Text('No meals logged yet', style: T.small(context)),
              Text('Snap your first meal above', style: T.small(context)),
            ]),
          ),
        ),
      ]);
    }

    // Group by relative date
    final Map<String, List<_MealEntry>> grouped = {};
    for (final e in _history) {
      (grouped[e.relativeDate] ??= []).add(e);
    }

    final allKeys = grouped.keys.toList();
    final visibleKeys = allKeys.take(_visibleGroups).toList();
    final hiddenDays = allKeys.length - _visibleGroups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HistorySectionHeader(count: _history.length),
        const SizedBox(height: 14),
        for (final dateLabel in visibleKeys) ...[
          _DayHeader(dateLabel: dateLabel, entries: grouped[dateLabel]!),
          const SizedBox(height: 8),
          for (final entry in grouped[dateLabel]!)
            _MealHistoryCard(entry: entry),
          const SizedBox(height: 12),
        ],
        if (hiddenDays > 0)
          GestureDetector(
            onTap: () => setState(() => _visibleGroups++),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Symbols.expand_more_rounded,
                    color: AppColors.inkSoft, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Load older ($hiddenDays more day${hiddenDays > 1 ? 's' : ''})',
                  style: const TextStyle(
                      color: AppColors.inkMid,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

// ── Today meal badge (progress row in log_meal_screen) ───────────────────────

class _TodayMealBadge extends StatelessWidget {
  const _TodayMealBadge({
    required this.emoji,
    required this.label,
    required this.done,
    this.optional = false,
  });
  final String emoji;
  final String label;
  final bool done;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: done
              ? AppColors.sageSoft
              : optional
                  ? AppColors.bg
                  : AppColors.coralSoft.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: done
                ? AppColors.sage.withOpacity(0.5)
                : optional
                    ? AppColors.line
                    : AppColors.coral.withOpacity(0.25),
          ),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: done
                  ? AppColors.sageDark
                  : optional
                      ? AppColors.inkSoft
                      : AppColors.inkMid,
            ),
          ),
          if (optional && !done)
            Text('optional',
                style: const TextStyle(
                    fontSize: 9, color: AppColors.inkSoft)),
          if (done)
            const Icon(Icons.check_circle_rounded,
                size: 12, color: AppColors.sageDark),
        ]),
      ),
    );
  }
}

// ── Pick prompt ───────────────────────────────────────────────────────────────

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

// ── History widgets ───────────────────────────────────────────────────────────

class _HistorySectionHeader extends StatelessWidget {
  const _HistorySectionHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowDark, blurRadius: 6, offset: Offset(2, 2)),
          BoxShadow(color: AppColors.shadowLight, blurRadius: 6, offset: Offset(-2, -2)),
        ],
      ),
      child: Row(children: [
        const Icon(Symbols.restaurant_rounded,
            color: AppColors.coral, size: 18, fill: 1),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('Meal history',
              style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
        ),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.coralSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count logged',
                style: const TextStyle(
                    color: AppColors.coral,
                    fontWeight: FontWeight.w700,
                    fontSize: 11)),
          ),
      ]),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.dateLabel, required this.entries});
  final String dateLabel;
  final List<_MealEntry> entries;

  @override
  Widget build(BuildContext context) {
    final totalCal = entries.fold<int>(0, (sum, e) => sum + e.calories);
    final isToday = dateLabel == 'Today';
    final isYesterday = dateLabel == 'Yesterday';
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          gradient: isToday
              ? AppColors.orangeGrad
              : isYesterday
                  ? AppColors.tealGrad
                  : null,
          color: (!isToday && !isYesterday) ? AppColors.bg : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(dateLabel,
            style: TextStyle(
                color: (isToday || isYesterday)
                    ? Colors.white
                    : AppColors.inkSoft,
                fontWeight: FontWeight.w800,
                fontSize: 12)),
      ),
      const SizedBox(width: 10),
      Text('$totalCal kcal total',
          style: T.small(context)
              .copyWith(color: AppColors.inkSoft, fontSize: 12)),
    ]);
  }
}

class _MealHistoryCard extends StatelessWidget {
  const _MealHistoryCard({required this.entry});
  final _MealEntry entry;

  static LinearGradient _gradientFor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'lunch':
      case 'snacks':
      case 'snack':
        return AppColors.tealGrad;
      default:
        return AppColors.orangeGrad;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _gradientFor(entry.mealType);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Gradient emoji circle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: gradient,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(_emojiFor(entry.mealType),
                  style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(entry.mealType,
                          style: T.title(context).copyWith(fontSize: 14)),
                      const Spacer(),
                      Text(entry.timeLabel,
                          style: T.small(context).copyWith(
                              color: AppColors.inkSoft, fontSize: 11)),
                    ]),
                    const SizedBox(height: 4),
                    if (entry.items.isNotEmpty)
                      Text(
                        entry.items.take(4).join(', ') +
                            (entry.items.length > 4
                                ? ' +${entry.items.length - 4} more'
                                : ''),
                        style: T.small(context).copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Row(children: [
                      _Chip(
                          color: AppColors.coralSoft,
                          text: '${entry.calories} kcal',
                          textColor: AppColors.coral),
                      const SizedBox(width: 6),
                      _Chip(
                          color: AppColors.goldSoft,
                          text: 'C ${entry.carbs}%',
                          textColor: AppColors.goldDark),
                      const SizedBox(width: 6),
                      _Chip(
                          color: AppColors.sageSoft,
                          text: 'P ${entry.protein}%',
                          textColor: AppColors.sageDark),
                      const SizedBox(width: 6),
                      _Chip(
                          color: AppColors.berrySoft,
                          text: 'F ${entry.fat}%',
                          textColor: AppColors.berry),
                    ]),
                  ]),
            ),
          ]),
        ),
        // Gradient left accent bar
        Positioned(
          left: 0, top: 0, bottom: 0,
          child: Container(
            width: 5,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.color, required this.text, required this.textColor});
  final Color color, textColor;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: textColor)),
      );
}

// ── Macro bar ─────────────────────────────────────────────────────────────────

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
            Expanded(flex: carbs.clamp(1, 100),   child: Container(height: 12, color: AppColors.gold)),
            Expanded(flex: protein.clamp(1, 100), child: Container(height: 12, color: AppColors.sage)),
            Expanded(flex: fat.clamp(1, 100),     child: Container(height: 12, color: AppColors.berry)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _legend(context, AppColors.gold,  'Carbs $carbs%'),
          _legend(context, AppColors.sage,  'Protein $protein%'),
          _legend(context, AppColors.berry, 'Fat $fat%'),
        ]),
      ],
    );
  }

  Widget _legend(BuildContext c, Color color, String label) => Row(children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: T.small(c).copyWith(fontSize: 12)),
      ]);
}
