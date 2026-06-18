import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
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
  final _notesCtrl = TextEditingController();
  int _mood = 2; // default "Okay"
  bool _busy = false;
  bool _loadingHistory = true;
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
    // Reload history to show the new entry.
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

              // ── Summary banner (if history available) ──
              if (loss != null) ...[
                NeuCard(
                  color: loss >= 0 ? AppColors.sageSoft : AppColors.coralSoft,
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
                            style: T.title(context).copyWith(
                              color: loss >= 0
                                  ? AppColors.sageDark
                                  : AppColors.coral,
                            ),
                          ),
                          if (_targetWeight != null)
                            Text(
                              'Target: ${_targetWeight!.toStringAsFixed(1)} kg · '
                              '${(_history.first.weight - _targetWeight!).abs().toStringAsFixed(1)} kg to go',
                              style: T.small(context),
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
                NeuCard(
                  color: AppColors.goldSoft,
                  child: Row(children: [
                    const Icon(Symbols.check_circle_rounded,
                        color: AppColors.gold, fill: 1),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Tonight's weigh-in saved",
                              style: T.title(context)
                                  .copyWith(color: AppColors.goldDark)),
                          Text(
                            [
                              '${_history.first.weight.toStringAsFixed(1)} kg',
                              if (_history.first.eveningMood != null)
                                _moods[_history.first.eveningMood!.clamp(0, 4)].label,
                              _history.first.timeLabel,
                            ].join(' · '),
                            style: T.small(context),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                Text('Log again to update',
                    style:
                        T.small(context).copyWith(color: AppColors.inkSoft)),
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

              // ── Weight input ──
              Text('Current weight', style: T.title(context)),
              const SizedBox(height: 12),
              NeuCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(children: [
                  const Icon(Symbols.scale_rounded,
                      color: AppColors.coral, size: 28),
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
                Row(children: [
                  Text('Weigh-in history', style: T.title(context)),
                  const Spacer(),
                  Text('${_history.length} entries',
                      style:
                          T.small(context).copyWith(color: AppColors.inkSoft)),
                ]),
                const SizedBox(height: 12),
                ..._history.take(14).map((e) => _WeighCard(
                    entry: e,
                    prev: _history.length > _history.indexOf(e) + 1
                        ? _history[_history.indexOf(e) + 1]
                        : null)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WeighCard extends StatelessWidget {
  const _WeighCard({required this.entry, this.prev});
  final _WeighEntry entry;
  final _WeighEntry? prev;

  @override
  Widget build(BuildContext context) {
    final diff = prev != null ? entry.weight - prev!.weight : 0.0;
    final diffText = prev != null
        ? (diff > 0 ? '+${diff.toStringAsFixed(1)}' : diff.toStringAsFixed(1))
        : '';
    final diffColor = diff < 0
        ? AppColors.sageDark
        : diff > 0
            ? AppColors.coral
            : AppColors.inkSoft;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeuCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.coralSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: entry.eveningMood != null
                ? Text(
                    _moods[entry.eveningMood!.clamp(0, 4)].emoji,
                    style: const TextStyle(fontSize: 22),
                  )
                : const Icon(Symbols.scale_rounded,
                    color: AppColors.coral, fill: 1, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${entry.weight.toStringAsFixed(1)} kg',
                    style: T.title(context).copyWith(fontSize: 16)),
                if (entry.eveningMood != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _moods[entry.eveningMood!.clamp(0, 4)].label,
                    style: T.small(context).copyWith(
                      fontSize: 11,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
                const Spacer(),
                Text(entry.dateLabel,
                    style: T.small(context)
                        .copyWith(color: AppColors.inkSoft, fontSize: 11)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Text(entry.timeLabel,
                    style: T.small(context).copyWith(fontSize: 11)),
                if (diffText.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: diff < 0
                          ? AppColors.sageSoft
                          : diff > 0
                              ? AppColors.coralSoft
                              : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
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
            ]),
          ),
        ]),
      ),
    );
  }
}
