import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/router.dart';
import '../plan/tasks_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

const _moods = [
  (emoji: '😞', label: 'Low',   color: Color(0xFFE57373)),
  (emoji: '😕', label: 'Meh',   color: Color(0xFFFFB74D)),
  (emoji: '🙂', label: 'Okay',  color: Color(0xFFFFD54F)),
  (emoji: '😀', label: 'Good',  color: Color(0xFF81C784)),
  (emoji: '🤩', label: 'Great', color: Color(0xFF4DB6AC)),
];

class _CheckinEntry {
  _CheckinEntry({
    required this.mood,
    this.weight,
    this.notes,
    required this.createdAt,
  });
  final int mood;
  final double? weight;
  final String? notes;
  final DateTime createdAt;

  bool get isToday {
    final now = DateTime.now();
    return createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
  }

  String get relativeDate {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(
            createdAt.year, createdAt.month, createdAt.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  String get timeLabel =>
      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
}

class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});
  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  int _mood = 2;
  final _weight = TextEditingController();
  final _notes = TextEditingController();
  bool _busy = false;
  bool _loadingHistory = true;
  int _visibleGroups = 2; // today + yesterday by default
  List<_CheckinEntry> _history = [];

  // Derived from profile — populated after load
  double? _startWeight;
  double? _targetWeight;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _weight.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final api = ref.read(apiClientProvider);
    try {
      // Load check-in history and profile in parallel.
      final results = await Future.wait([
        api.getJson('/checkins'),
        api.getJson('/profile'),
      ]);

      final raw = (results[0]['checkins'] as List?) ?? [];
      final entries = raw.map((c) {
        final m = Map<String, dynamic>.from(c as Map);
        return _CheckinEntry(
          mood: (m['mood'] as num?)?.toInt() ?? 2,
          weight: m['weight'] != null
              ? double.tryParse(m['weight'].toString())
              : null,
          notes: m['notes'] as String?,
          createdAt: (DateTime.tryParse(m['created_at'] as String? ?? '') ??
              DateTime.now()).toLocal(),
        );
      }).toList();

      final user = results[1]['user'] as Map?;
      _startWeight = user?['start_weight'] != null
          ? double.tryParse(user!['start_weight'].toString())
          : null;
      _targetWeight = user?['target_weight'] != null
          ? double.tryParse(user!['target_weight'].toString())
          : null;

      if (!mounted) return;
      setState(() {
        _history = entries;
        _loadingHistory = false;
        // Pre-fill form with last recorded values.
        if (entries.isNotEmpty) {
          _mood = entries.first.mood.clamp(0, 4);
          if (entries.first.weight != null) {
            _weight.text = entries.first.weight!.toStringAsFixed(1);
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final res = await ref.read(apiClientProvider).postJson('/checkins', {
        'mood': _mood,
        'weight': double.tryParse(_weight.text.trim()),
        'notes': _notes.text.trim(),
      });
      if (!mounted) return;
      setState(() => _busy = false);
      // Refresh task completion state so the check-in task shows as done.
      ref.invalidate(tasksProvider);
      // Reload history so the new entry shows immediately.
      await _loadData();
      if (!mounted) return;
      if (res['badge_earned'] == true && res['badge'] != null) {
        context.pushReplacement(Routes.badge,
            extra: Map<String, dynamic>.from(res['badge'] as Map));
      } else {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save check-in. Check your connection and try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildHistory(BuildContext context) {
    // Group by relative date
    final Map<String, List<_CheckinEntry>> grouped = {};
    for (final e in _history) {
      (grouped[e.relativeDate] ??= []).add(e);
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
            gradient: AppColors.orangeGrad,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Symbols.history_rounded,
                color: Colors.white, size: 18, fill: 1),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Check-in history',
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
          _CheckinDayHeader(
              dateLabel: dateLabel, entries: grouped[dateLabel]!),
          const SizedBox(height: 8),
          ...grouped[dateLabel]!.map((e) => _HistoryCard(entry: e)),
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

  String _weightProgress(double current) {
    if (_startWeight == null) return '';
    final diff = _startWeight! - current;
    final sign = diff >= 0 ? '↓' : '↑';
    final target =
        _targetWeight != null ? ' · target ${_targetWeight!.toStringAsFixed(0)} kg' : '';
    return '$sign ${diff.abs().toStringAsFixed(1)} kg from start (${_startWeight!.toStringAsFixed(1)} kg)$target';
  }

  @override
  Widget build(BuildContext context) {
    final currentWeight = double.tryParse(_weight.text.trim());
    final progressText =
        currentWeight != null ? _weightProgress(currentWeight) : '';

    // Today's last check-in (if any) shown as a status card
    final todayEntry = _history.isNotEmpty && _history.first.isToday
        ? _history.first
        : null;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        Text('Morning check-in',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900)),
                        Text('Log your mood & weight',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Text('🌅', style: TextStyle(fontSize: 26)),
                ]),
              ),
              const SizedBox(height: 20),

              // ── Today's status card (if already checked in) ──
              if (todayEntry != null) ...[
                NeuCard(
                  color: AppColors.sageSoft,
                  child: Row(children: [
                    Text(_moods[todayEntry.mood.clamp(0, 4)].emoji,
                        style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Today's check-in saved",
                              style: T.title(context)
                                  .copyWith(color: AppColors.sageDark)),
                          Text(
                            [
                              _moods[todayEntry.mood.clamp(0, 4)].label,
                              if (todayEntry.weight != null)
                                '${todayEntry.weight!.toStringAsFixed(1)} kg',
                            ].join(' · '),
                            style: T.small(context),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Symbols.check_circle_rounded,
                        color: AppColors.sage, fill: 1),
                  ]),
                ),
                const SizedBox(height: 14),
                Text('Update today\'s check-in',
                    style: T.small(context)
                        .copyWith(color: AppColors.inkSoft)),
                const SizedBox(height: 10),
              ],

              // ── Mood picker ──
              Text('How do you feel today?', style: T.title(context)),
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
                              ? AppColors.coralSoft
                              : AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _mood == i
                                  ? AppColors.coral
                                  : AppColors.line,
                              width: _mood == i ? 2 : 1),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_moods[i].emoji,
                                style: const TextStyle(fontSize: 22)),
                            if (_mood == i)
                              Text(_moods[i].label,
                                  style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.coral)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Weight ──
              Text('Morning weight', style: T.title(context)),
              const SizedBox(height: 12),
              NeuCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(children: [
                  const Icon(Symbols.scale_rounded, color: AppColors.coral),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: T.h2(context),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter weight',
                        hintStyle: T.body(context)
                            .copyWith(color: AppColors.inkSoft),
                      ),
                    ),
                  ),
                  Text('kg', style: T.body(context)),
                ]),
              ),
              if (progressText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(progressText, style: T.small(context)),
              ],
              const SizedBox(height: 28),

              // ── Coach notes ──
              Text('Notes for your coach', style: T.title(context)),
              const SizedBox(height: 12),
              NeuTextField(
                controller: _notes,
                hint: 'Slept well, felt energetic…',
                maxLines: 3,
              ),
              const SizedBox(height: 28),

              // ── Save button ──
              NeuButton.primary(
                'Save check-in',
                loading: _busy,
                trailing: const Icon(Symbols.check_rounded, size: 20),
                onPressed: _save,
              ),

              // ── Recent history ──
              if (_loadingHistory) ...[
                const SizedBox(height: 32),
                const Center(child: CircularProgressIndicator()),
              ] else if (_history.isNotEmpty) ...[
                const SizedBox(height: 32),
                _buildHistory(context),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckinDayHeader extends StatelessWidget {
  const _CheckinDayHeader({required this.dateLabel, required this.entries});
  final String dateLabel;
  final List<_CheckinEntry> entries;

  @override
  Widget build(BuildContext context) {
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
                color: (isToday || isYesterday) ? Colors.white : AppColors.inkSoft,
                fontWeight: FontWeight.w800,
                fontSize: 12)),
      ),
      const SizedBox(width: 10),
      Text(
        '${entries.length} check-in${entries.length > 1 ? 's' : ''}',
        style: T.small(context).copyWith(color: AppColors.inkSoft, fontSize: 12),
      ),
    ]);
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});
  final _CheckinEntry entry;

  @override
  Widget build(BuildContext context) {
    final mood = _moods[entry.mood.clamp(0, 4)];
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
            // Mood circle with mood color
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: mood.color.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: mood.color.withOpacity(0.5), width: 2),
              ),
              alignment: Alignment.center,
              child: Text(mood.emoji,
                  style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(mood.label,
                        style: T.title(context).copyWith(
                            fontSize: 14, color: mood.color)),
                    const Spacer(),
                    Text(entry.timeLabel,
                        style: T.small(context).copyWith(
                            color: AppColors.coral,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 6),
                  if (entry.weight != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.sageSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Symbols.scale_rounded,
                            size: 13, color: AppColors.sageDark),
                        const SizedBox(width: 4),
                        Text('${entry.weight!.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.sageDark)),
                      ]),
                    ),
                  if (entry.notes != null &&
                      entry.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      entry.notes!,
                      style: T.small(context).copyWith(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ]),
        ),
        // Mood-colored left accent bar
        Positioned(
          left: 0, top: 0, bottom: 0,
          child: Container(
            width: 5,
            decoration: BoxDecoration(
              color: mood.color,
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
