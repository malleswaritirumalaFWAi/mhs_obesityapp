import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/daily_stats_provider.dart';
import '../../core/providers/tasks_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

const _goal = 8000;

class _MovementDay {
  const _MovementDay({required this.date, required this.steps});
  final DateTime date;
  final int steps;

  String get relativeDate {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '$diff days ago';
  }
}

const _presets = [
  (label: '+500',  steps: 500),
  (label: '+1k',   steps: 1000),
  (label: '+2k',   steps: 2000),
  (label: '+5k',   steps: 5000),
];

class MovementScreen extends ConsumerStatefulWidget {
  const MovementScreen({super.key});

  @override
  ConsumerState<MovementScreen> createState() => _MovementScreenState();
}

class _MovementScreenState extends ConsumerState<MovementScreen>
    with SingleTickerProviderStateMixin {
  int _steps = 0;
  bool _loading = true;
  bool _adding = false;
  List<_MovementDay> _history = [];
  bool _loadingHistory = true;
  int _visibleGroups = 2;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut),
    );
    _loadSteps();
    _loadHistory();
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSteps() async {
    try {
      final res = await ref.read(apiClientProvider).getJson('/movement');
      if (mounted) {
        setState(() {
          _steps = (res['steps'] as num?)?.toInt() ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      final stats = ref.read(dailyStatsProvider);
      if (mounted) setState(() { _steps = stats.steps; _loading = false; });
    }
  }

  Future<void> _loadHistory() async {
    try {
      final res =
          await ref.read(apiClientProvider).getJson('/movement/history');
      final raw = (res['history'] as List?) ?? [];
      final entries = raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _MovementDay(
          date: (DateTime.tryParse(m['date'] as String? ?? '') ??
                  DateTime.now())
              .toLocal(),
          steps: (m['steps'] as num?)?.toInt() ?? 0,
        );
      }).toList();
      if (mounted) setState(() { _history = entries; _loadingHistory = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingHistory = false; });
    }
  }

  Future<void> _addSteps(int amount) async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      final res = await ref.read(apiClientProvider)
          .postJson('/movement/add', {'steps': amount});
      final newSteps = (res['steps'] as num?)?.toInt() ?? (_steps + amount);
      ref.read(dailyStatsProvider.notifier).updateSteps(newSteps);
      if (mounted) {
        setState(() { _steps = newSteps; _adding = false; });
        _bounceCtrl.forward(from: 0);
        if (newSteps >= _goal && (_steps < _goal)) {
          ref.invalidate(tasksProvider);
          _showGoalReached();
        }
      }
    } catch (_) {
      final next = _steps + amount;
      ref.read(dailyStatsProvider.notifier).updateSteps(next);
      if (mounted) {
        setState(() { _steps = next; _adding = false; });
        _bounceCtrl.forward(from: 0);
        if (next >= _goal && (_steps < _goal)) {
          ref.invalidate(tasksProvider);
          _showGoalReached();
        }
      }
    }
  }

  Future<void> _showCustomInput() async {
    final ctrl = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add steps'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'e.g. 3500', suffixText: 'steps'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                final v = int.tryParse(ctrl.text.trim()) ?? 0;
                Navigator.pop(ctx, v > 0 ? v : null);
              },
              child: const Text('Add')),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) _addSteps(result);
  }

  void _showGoalReached() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Daily movement goal reached! +5 XP'),
        backgroundColor: AppColors.coral,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = _steps >= _goal;
    final pct = (_steps / _goal).clamp(0.0, 1.0);
    final remaining = (_goal - _steps).clamp(0, _goal);

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
                        Text('Daily Movement',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        Text('Log your activity & steps',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Text('🏃', style: TextStyle(fontSize: 26)),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Hero card ──
              Container(
                decoration: BoxDecoration(
                  gradient: done
                      ? const LinearGradient(
                          colors: [AppColors.coral, Color(0xFFFF4500)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : AppColors.orangeGrad,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ScaleTransition(
                          scale: _bounceAnim,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _loading ? '—' : _formatSteps(_steps),
                                style: const TextStyle(
                                    fontSize: 76,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10, left: 6),
                                child: Text('/ ${_formatSteps(_goal)}',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withOpacity(0.65))),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('steps today',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ]),
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4), width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text('${(pct * 100).round()}%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (done)
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Symbols.check_circle_rounded,
                          color: Colors.white, fill: 1, size: 18),
                      const SizedBox(width: 6),
                      const Text('Daily goal reached! 🎉',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ])
                  else
                    Row(children: [
                      const Icon(Symbols.directions_run_rounded,
                          color: Colors.white70, size: 14, fill: 1),
                      const SizedBox(width: 6),
                      Text(
                          '${_formatSteps(remaining)} more steps to goal',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ]),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Progress milestones ──
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: AppColors.orangeGrad,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('PROGRESS',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.5)),
                ),
              ]),
              const SizedBox(height: 14),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _MilestoneRow(steps: _steps, goal: _goal),
              const SizedBox(height: 28),

              // ── Add step presets ──
              if (!done) ...[
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: AppColors.orangeGrad,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('LOG STEPS',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.5)),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final p in _presets)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: p == _presets.last ? 0 : 8),
                          child: _PresetButton(
                            label: p.label,
                            onTap: _adding ? null : () => _addSteps(p.steps),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _PresetButton(
                  label: '✏️  Enter custom steps',
                  fullWidth: true,
                  onTap: _adding ? null : _showCustomInput,
                ),
                const SizedBox(height: 28),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: AppColors.orangeGrad,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.orange.withOpacity(0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Symbols.emoji_events_rounded,
                          color: AppColors.gold, fill: 1, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        '${_formatSteps(_goal)} steps done — amazing!',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // ── Tips ──
              _TipsCard(steps: _steps),
              const SizedBox(height: 28),

              // ── History ──
              _buildHistory(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistory(BuildContext context) {
    final todayEntry = _MovementDay(date: DateTime.now(), steps: _steps);
    final allEntries = [
      todayEntry,
      ..._history.where((e) => e.relativeDate != 'Today'),
    ];

    final Map<String, List<_MovementDay>> grouped = {};
    for (final e in allEntries) {
      (grouped[e.relativeDate] ??= []).add(e);
    }

    final allKeys = grouped.keys.toList();
    final visibleKeys = allKeys.take(_visibleGroups).toList();
    final hiddenDays = allKeys.length - _visibleGroups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            gradient: AppColors.orangeGrad,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Symbols.directions_run_rounded,
                color: Colors.white, size: 18, fill: 1),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Movement history',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${allEntries.length} day${allEntries.length != 1 ? 's' : ''}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        for (final label in visibleKeys) ...[
          _MovementDayLabel(
              dateLabel: label, steps: grouped[label]!.first.steps),
          const SizedBox(height: 8),
          _MovementHistoryCard(entry: grouped[label]!.first),
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
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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

String _formatSteps(int n) {
  if (n >= 1000) {
    final k = n / 1000;
    return k == k.truncateToDouble() ? '${k.toInt()}k' : '${k.toStringAsFixed(1)}k';
  }
  return '$n';
}

// ── Milestone row ──────────────────────────────────────────────────────────────

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.steps, required this.goal});
  final int steps;
  final int goal;

  @override
  Widget build(BuildContext context) {
    const milestones = [2000, 4000, 6000, 8000];
    return Row(
      children: milestones.map((m) {
        final reached = steps >= m;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: m == milestones.last ? 0 : 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: reached ? AppColors.orangeGrad : null,
                color: reached ? null : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: reached
                      ? AppColors.orange.withOpacity(0.3)
                      : const Color(0xFFFFD0B0),
                  width: reached ? 0 : 1.5,
                ),
                boxShadow: reached
                    ? [
                        BoxShadow(
                          color: AppColors.orange.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Column(children: [
                Icon(
                  reached
                      ? Symbols.check_circle_rounded
                      : Symbols.radio_button_unchecked_rounded,
                  color: reached ? Colors.white : const Color(0xFFFFB07A),
                  fill: 1,
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatSteps(m),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: reached ? Colors.white : const Color(0xFFFFB07A),
                  ),
                ),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Preset button ─────────────────────────────────────────────────────────────

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.label,
    required this.onTap,
    this.fullWidth = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    final w = GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : AppColors.line,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? AppColors.tealLight : AppColors.line,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.tealLight.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: active ? AppColors.teal : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
    return w;
  }
}

// ── Tips card ─────────────────────────────────────────────────────────────────

class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.steps});
  final int steps;

  static const _tips = [
    (icon: Symbols.directions_walk_rounded, tip: 'Take the stairs instead of the lift'),
    (icon: Symbols.wb_sunny_rounded,        tip: 'A 20-min morning walk = ~2,000 steps'),
    (icon: Symbols.lunch_dining_rounded,    tip: 'Walk after lunch to boost digestion'),
    (icon: Symbols.bedtime_rounded,         tip: 'Evening stroll helps lower blood sugar'),
  ];

  static const _tipGradients = [
    LinearGradient(colors: [AppColors.teal, AppColors.tealLight],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [AppColors.orange, AppColors.amber],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [AppColors.coral, Color(0xFFFF9A8B)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [AppColors.berry, Color(0xFF9B59B6)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            gradient: AppColors.orangeGrad,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('MOVEMENT TIPS',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.5)),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (int i = 0; i < _tips.length; i++) ...[
                Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: _tipGradients[i],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _tipGradients[i].colors.first.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(_tips[i].icon,
                        color: Colors.white, size: 20, fill: 1),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(_tips[i].tip,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkMid)),
                  ),
                ]),
                if (i < _tips.length - 1) ...[
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.line, height: 1),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Movement history widgets ───────────────────────────────────────────────────

class _MovementDayLabel extends StatelessWidget {
  const _MovementDayLabel({required this.dateLabel, required this.steps});
  final String dateLabel;
  final int steps;

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
      Text('${_formatSteps(steps)} steps',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.inkSoft, fontSize: 12)),
    ]);
  }
}

class _MovementHistoryCard extends StatelessWidget {
  const _MovementHistoryCard({required this.entry});
  final _MovementDay entry;

  @override
  Widget build(BuildContext context) {
    final pct = (entry.steps / _goal).clamp(0.0, 1.0);
    final done = entry.steps >= _goal;
    return Stack(children: [
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppColors.orangeGrad,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(_formatSteps(entry.steps),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('${_formatSteps(entry.steps)} of ${_formatSteps(_goal)} steps',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (done)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.sageSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Goal reached!',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.sageDark)),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    Stack(children: [
                      Container(
                          height: 6,
                          decoration: BoxDecoration(
                              color: AppColors.orangeSoft,
                              borderRadius: BorderRadius.circular(999))),
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: AppColors.orangeGrad,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ]),
                  ]),
            ),
          ]),
        ]),
      ),
      Positioned(
        left: 0, top: 0, bottom: 0,
        child: Container(
          width: 5,
          decoration: BoxDecoration(
            gradient: AppColors.orangeGrad,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
        ),
      ),
    ]);
  }
}
