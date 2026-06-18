import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../plan/tasks_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_misc.dart';

const _moods = [
  (emoji: '😞', label: 'Low',   color: Color(0xFFE57373)),
  (emoji: '😕', label: 'Meh',   color: Color(0xFFFFB74D)),
  (emoji: '🙂', label: 'Okay',  color: Color(0xFFFFD54F)),
  (emoji: '😀', label: 'Good',  color: Color(0xFF81C784)),
  (emoji: '🤩', label: 'Great', color: Color(0xFF4DB6AC)),
];

// Evening-themed gradient — indigo → berry
const _eveningGrad = LinearGradient(
  colors: [Color(0xFF4A148C), AppColors.berry],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class _WeighEntry {
  _WeighEntry({
    required this.weight,
    this.notes,
    required this.createdAt,
    this.eveningMood,
  });
  final double weight;
  final String? notes;
  final DateTime createdAt;
  final int? eveningMood;

  String get dateLabel {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(
            DateTime(createdAt.year, createdAt.month, createdAt.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  String get timeLabel =>
      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
}

class WeighInScreen extends ConsumerStatefulWidget {
  const WeighInScreen({super.key});

  @override
  ConsumerState<WeighInScreen> createState() => _WeighInScreenState();
}

class _WeighInScreenState extends ConsumerState<WeighInScreen> {
  final _weightCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  int _mood = 2;
  bool _busy = false;
  bool _loadingHistory = true;
  int _visibleGroups = 2;
  List<_WeighEntry> _history = [];
  double? _startWeight;
  double? _targetWeight;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.getJson('/weighin');
      final raw = (res['entries'] as List?) ?? [];
      final entries = raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _WeighEntry(
          weight: double.tryParse(m['weight']?.toString() ?? '') ?? 0,
          notes: m['notes'] as String?,
          createdAt:
              (DateTime.tryParse(m['created_at'] as String? ?? '') ??
                  DateTime.now()).toLocal(),
          eveningMood: m['evening_mood'] != null
              ? int.tryParse(m['evening_mood'].toString())
              : null,
        );
      }).toList();

      _startWeight = res['start_weight'] != null
          ? double.tryParse(res['start_weight'].toString())
          : null;
      _targetWeight = res['target_weight'] != null
          ? double.tryParse(res['target_weight'].toString())
          : null;

      if (!mounted) return;
      setState(() {
        _history = entries;
        _loadingHistory = false;
        if (entries.isNotEmpty) {
          _weightCtrl.text = entries.first.weight.toStringAsFixed(1);
          if (entries.first.eveningMood != null) {
            _mood = entries.first.eveningMood!.clamp(0, 4);
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _save() async {
    final w = double.tryParse(_weightCtrl.text.trim());
    if (w == null || w <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your weight first')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).postJson('/weighin', {
        'weight': w,
        'notes': _notesCtrl.text.trim(),
        'evening_mood': _mood,
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save weigh-in. Check your connection and try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(tasksProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Evening weigh-in saved · +5 XP'),
        backgroundColor: AppColors.sage,
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() { _loadingHistory = true; });
    await _loadData();
  }

  String _progressText(double current) {
    if (_startWeight == null) return '';
    final diff = _startWeight! - current;
    final sign = diff >= 0 ? '↓' : '↑';
    final target = _targetWeight != null
        ? ' · target ${_targetWeight!.toStringAsFixed(1)} kg'
        : '';
    return '$sign ${diff.abs().toStringAsFixed(1)} kg from start (${_startWeight!.toStringAsFixed(1)} kg)$target';
  }

  double? get _totalLoss {
    if (_startWeight == null || _history.isEmpty) return null;
    return _startWeight! - _history.first.weight;
  }

  Widget _buildHistory() {
    // Group entries by dateLabel
    final Map<String, List<_WeighEntry>> grouped = {};
    for (final e in _history) {
      (grouped[e.dateLabel] ??= []).add(e);
    }
    final allKeys = grouped.keys.toList();
    final visibleKeys = allKeys.take(_visibleGroups).toList();
    final hiddenDays = allKeys.length - _visibleGroups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gradient section header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            gradient: _eveningGrad,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Symbols.monitor_weight_rounded,
                color: Colors.white, size: 18, fill: 1),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Weigh-in history',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${_history.length} total',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        for (final dateLabel in visibleKeys) ...[
          _WeighDayHeader(
              dateLabel: dateLabel, count: grouped[dateLabel]!.length),
          const SizedBox(height: 8),
          ...grouped[dateLabel]!.asMap().entries.map((e) => _WeighCard(
                entry: e.value,
                prev: e.key < grouped[dateLabel]!.length - 1
                    ? grouped[dateLabel]![e.key + 1]
                    : (_history.indexOf(e.value) + 1 < _history.length
                        ? _history[_history.indexOf(e.value) + 1]
                        : null),
              )),
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

  @override
  Widget build(BuildContext context) {
    final currentW = double.tryParse(_weightCtrl.text.trim());
    final progressText = currentW != null ? _progressText(currentW) : '';
    final loss = _totalLoss;
    final todaySaved =
        _history.isNotEmpty && _history.first.dateLabel == 'Today';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Container(
                decoration: BoxDecoration(
                  gradient: _eveningGrad,
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
                        Text('Evening weigh-in',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900)),
                        Text('Log your weight for today',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Text('⚖️', style: TextStyle(fontSize: 26)),
                ]),
              ),
              const SizedBox(height: 20),

              // ── Progress summary banner ──
              if (loss != null) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    gradient: loss >= 0
                        ? const LinearGradient(
                            colors: [AppColors.sage, AppColors.sageDark],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : const LinearGradient(
                            colors: [AppColors.coral, Color(0xFFFF4500)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: (loss >= 0 ? AppColors.sage : AppColors.coral)
                            .withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(children: [
                    Text(
                      loss >= 0 ? '🎉' : '📈',
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loss >= 0
                                ? '${loss.toStringAsFixed(1)} kg lost so far'
                                : '${loss.abs().toStringAsFixed(1)} kg gained',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15),
                          ),
                          if (_targetWeight != null)
                            Text(
                              'Target: ${_targetWeight!.toStringAsFixed(1)} kg · '
                              '${(_history.first.weight - _targetWeight!).abs().toStringAsFixed(1)} kg to go',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // ── Already saved today ──
              if (todaySaved) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.gold, AppColors.goldDark],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(children: [
                    const Icon(Symbols.check_circle_rounded,
                        color: Colors.white, fill: 1, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Tonight's weigh-in saved",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                          Text(
                            [
                              '${_history.first.weight.toStringAsFixed(1)} kg',
                              if (_history.first.eveningMood != null)
                                _moods[_history.first.eveningMood!.clamp(0, 4)].label,
                              _history.first.timeLabel,
                            ].join(' · '),
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                Text('Log again to update',
                    style: T.small(context).copyWith(color: AppColors.inkSoft)),
                const SizedBox(height: 16),
              ],

              // ── Mood picker ──
              Text('How do you feel tonight?', style: T.title(context)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < _moods.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _mood = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _mood == i
                              ? _moods[i].color.withOpacity(0.15)
                              : AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _mood == i
                                  ? _moods[i].color
                                  : AppColors.line,
                              width: _mood == i ? 2.5 : 1),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_moods[i].emoji,
                                style: const TextStyle(fontSize: 22)),
                            if (_mood == i)
                              Text(_moods[i].label,
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: _moods[i].color)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Weight input ──
              Text('Current weight', style: T.title(context)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: _eveningGrad,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Symbols.scale_rounded,
                        color: Colors.white, size: 20, fill: 1),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: T.h1(context),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '0.0',
                        hintStyle: T.h1(context)
                            .copyWith(color: AppColors.inkSoft),
                      ),
                    ),
                  ),
                  Text('kg',
                      style: T.title(context)
                          .copyWith(color: AppColors.inkSoft)),
                ]),
              ),
              if (progressText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Symbols.trending_down_rounded,
                      size: 16, color: AppColors.sage),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(progressText,
                        style: T.small(context)
                            .copyWith(color: AppColors.sageDark)),
                  ),
                ]),
              ],
              const SizedBox(height: 24),

              // ── Notes ──
              Text('Notes (optional)', style: T.title(context)),
              const SizedBox(height: 12),
              NeuTextField(
                controller: _notesCtrl,
                hint: 'Feeling lighter, skipped dinner…',
                maxLines: 3,
              ),
              const SizedBox(height: 28),

              // ── Save ──
              NeuButton.primary(
                'Save weigh-in · +5 XP',
                loading: _busy,
                trailing: const Icon(Symbols.scale_rounded, size: 20),
                onPressed: _busy ? null : _save,
              ),

              // ── History ──
              if (_loadingHistory) ...[
                const SizedBox(height: 32),
                const Center(child: CircularProgressIndicator()),
              ] else if (_history.isNotEmpty) ...[
                const SizedBox(height: 32),
                _buildHistory(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Day header ─────────────────────────────────────────────────────────────────

class _WeighDayHeader extends StatelessWidget {
  const _WeighDayHeader({required this.dateLabel, required this.count});
  final String dateLabel;
  final int count;

  @override
  Widget build(BuildContext context) {
    final isToday = dateLabel == 'Today';
    final isYesterday = dateLabel == 'Yesterday';
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          gradient: isToday
              ? _eveningGrad
              : isYesterday
                  ? AppColors.tealGrad
                  : null,
          color: (!isToday && !isYesterday) ? AppColors.bg : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(dateLabel,
            style: TextStyle(
                color: (isToday || isYesterday) ? Colors.white : AppColors.inkSoft,
                fontWeight: FontWeight.w800,
                fontSize: 12)),
      ),
      const SizedBox(width: 10),
      Text(
        '$count weigh-in${count > 1 ? 's' : ''}',
        style: T.small(context).copyWith(color: AppColors.inkSoft, fontSize: 12),
      ),
    ]);
  }
}

// ── History card ───────────────────────────────────────────────────────────────

class _WeighCard extends StatelessWidget {
  const _WeighCard({required this.entry, this.prev});
  final _WeighEntry entry;
  final _WeighEntry? prev;

  @override
  Widget build(BuildContext context) {
    final mood = entry.eveningMood != null
        ? _moods[entry.eveningMood!.clamp(0, 4)]
        : null;
    final accentColor = mood?.color ?? AppColors.berry;

    final diff = prev != null ? entry.weight - prev!.weight : 0.0;
    final diffText = prev != null
        ? (diff > 0
            ? '+${diff.toStringAsFixed(1)}'
            : diff.toStringAsFixed(1))
        : '';
    final diffColor = diff < 0
        ? AppColors.sageDark
        : diff > 0
            ? AppColors.coral
            : AppColors.inkSoft;
    final diffBg = diff < 0
        ? AppColors.sageSoft
        : diff > 0
            ? AppColors.coralSoft
            : AppColors.surface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
            // Mood / scale circle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: accentColor.withOpacity(0.45), width: 2),
              ),
              alignment: Alignment.center,
              child: mood != null
                  ? Text(mood.emoji, style: const TextStyle(fontSize: 22))
                  : Icon(Symbols.scale_rounded,
                      color: accentColor, fill: 1, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('${entry.weight.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    if (mood != null) ...[
                      const SizedBox(width: 8),
                      Text(mood.label,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: mood.color)),
                    ],
                    const Spacer(),
                    Text(entry.timeLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accentColor)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    // Weight pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.berrySoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Symbols.scale_rounded,
                            size: 13, color: AppColors.berry),
                        const SizedBox(width: 4),
                        Text('${entry.weight.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.berry)),
                      ]),
                    ),
                    if (diffText.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: diffBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$diffText kg',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: diffColor)),
                      ),
                    ],
                  ]),
                  if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(entry.notes!,
                        style: T.small(context).copyWith(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ]),
        ),
        // Accent bar
        Positioned(
          left: 0, top: 0, bottom: 0,
          child: Container(
            width: 5,
            decoration: BoxDecoration(
              color: accentColor,
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
