import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/daily_stats_provider.dart';
import '../../core/providers/tasks_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

const _goal = 8;

class _HydrationDay {
  const _HydrationDay({required this.date, required this.glasses});
  final DateTime date;
  final int glasses;

  String get relativeDate {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '$diff days ago';
  }

  String get dateLabel =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

class HydrationScreen extends ConsumerStatefulWidget {
  const HydrationScreen({super.key});

  @override
  ConsumerState<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends ConsumerState<HydrationScreen>
    with SingleTickerProviderStateMixin {
  int _glasses = 0;
  bool _loading = true;
  bool _adding = false;
  List<_HydrationDay> _history = [];
  bool _loadingHistory = true;
  int _visibleGroups = 2;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut),
    );
    _loadGlasses();
    _loadHistory();
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGlasses() async {
    try {
      final res = await ref.read(apiClientProvider).getJson('/hydration');
      if (mounted) {
        setState(() {
          _glasses = (res['glasses'] as num?)?.toInt() ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      // fallback to daily stats provider value
      final stats = ref.read(dailyStatsProvider);
      if (mounted) setState(() { _glasses = stats.water; _loading = false; });
    }
  }

  Future<void> _loadHistory() async {
    try {
      final res =
          await ref.read(apiClientProvider).getJson('/hydration/history');
      final raw = (res['history'] as List?) ?? [];
      final entries = raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _HydrationDay(
          date: (DateTime.tryParse(m['date'] as String? ?? '') ??
                  DateTime.now())
              .toLocal(),
          glasses: (m['glasses'] as num?)?.toInt() ?? 0,
        );
      }).toList();
      if (mounted) setState(() { _history = entries; _loadingHistory = false; });
    } catch (_) {
      // API doesn't have history endpoint yet — show today only
      if (mounted) setState(() { _loadingHistory = false; });
    }
  }

  Future<void> _addGlass() async {
    if (_adding || _glasses >= _goal) return;
    setState(() => _adding = true);
    try {
      final res =
          await ref.read(apiClientProvider).postJson('/hydration/add', {});
      final newGlasses = (res['glasses'] as num?)?.toInt() ?? (_glasses + 1);
      // Update daily stats provider so home screen refreshes.
      ref.read(dailyStatsProvider.notifier).updateWater(newGlasses);
      if (mounted) {
        setState(() { _glasses = newGlasses; _adding = false; });
        _bounceCtrl.forward(from: 0);
        if (newGlasses >= _goal) {
          ref.invalidate(tasksProvider);
          _showGoalReached();
        }
      }
    } catch (_) {
      // Optimistic fallback
      final next = (_glasses + 1).clamp(0, _goal);
      ref.read(dailyStatsProvider.notifier).updateWater(next);
      if (mounted) {
        setState(() { _glasses = next; _adding = false; });
        _bounceCtrl.forward(from: 0);
        if (next >= _goal) {
          ref.invalidate(tasksProvider);
          _showGoalReached();
        }
      }
    }
  }

  void _showGoalReached() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Daily water goal reached! +5 XP'),
        backgroundColor: AppColors.sage,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (_goal - _glasses).clamp(0, _goal);
    final pct = _goal > 0 ? _glasses / _goal : 0.0;
    final done = _glasses >= _goal;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ──
              Container(
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
                        Text('Hydration',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        Text('Track your daily water intake',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Text('💧', style: TextStyle(fontSize: 26)),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Hero card ──
              Container(
                decoration: BoxDecoration(
                  gradient: done
                      ? const LinearGradient(
                          colors: [AppColors.sage, AppColors.sageDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : AppColors.tealGrad,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.tealLight.withOpacity(0.35),
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
                              Text('$_glasses',
                                  style: const TextStyle(
                                      fontSize: 76,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      height: 1)),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10, left: 6),
                                child: Text('/ $_goal',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withOpacity(0.65))),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('glasses today',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ]),
                      // Circular % indicator
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
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
                              color: Colors.white, fontWeight: FontWeight.w700)),
                    ])
                  else
                    Row(children: [
                      const Icon(Symbols.water_drop_rounded,
                          color: Colors.white70, size: 14, fill: 1),
                      const SizedBox(width: 6),
                      Text(
                          '$remaining more glass${remaining == 1 ? '' : 'es'} to go',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ]),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Glass grid ──
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: AppColors.tealGrad,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('YOUR GLASSES TODAY',
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
                  : _GlassGrid(filled: _glasses, total: _goal),
              const SizedBox(height: 28),

              // ── Add button ──
              if (!done)
                NeuButton.primary(
                  _adding
                      ? 'Adding…'
                      : '+ Add a glass  💧',
                  onPressed: _adding ? null : _addGlass,
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.sage, AppColors.sageDark],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sage.withOpacity(0.4),
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
                        'All $_goal glasses done — great work!',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 28),

              // ── Tips card ──
              _TipsCard(glasses: _glasses),
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
    // Always include today's live entry at the top
    final todayEntry = _HydrationDay(date: DateTime.now(), glasses: _glasses);
    final allEntries = [
      todayEntry,
      ..._history.where((e) => e.relativeDate != 'Today'),
    ];

    // Group by relativeDate
    final Map<String, List<_HydrationDay>> grouped = {};
    for (final e in allEntries) {
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
            gradient: AppColors.tealGrad,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Symbols.water_drop_rounded,
                color: Colors.white, size: 18, fill: 1),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Hydration history',
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
              child: Text('${allEntries.length} day${allEntries.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        for (final label in visibleKeys) ...[
          _HistoryDayLabel(
              dateLabel: label, count: grouped[label]!.first.glasses),
          const SizedBox(height: 8),
          _HydrationHistoryCard(entry: grouped[label]!.first),
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

// ── Glass grid ────────────────────────────────────────────────────────────────

class _GlassGrid extends StatelessWidget {
  const _GlassGrid({required this.filled, required this.total});
  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: total,
      itemBuilder: (context, i) {
        final isFilled = i < filled;
        return Container(
          decoration: BoxDecoration(
            gradient: isFilled ? AppColors.tealGrad : null,
            color: isFilled ? null : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isFilled
                  ? AppColors.tealLight.withOpacity(0.4)
                  : const Color(0xFFB3E5FC),
              width: isFilled ? 0 : 1.5,
            ),
            boxShadow: isFilled
                ? [
                    BoxShadow(
                      color: AppColors.tealLight.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Symbols.water_drop_rounded,
                fill: isFilled ? 1 : 0,
                color: isFilled
                    ? Colors.white
                    : const Color(0xFF81D4FA),
                size: 32,
              ),
              const SizedBox(height: 4),
              Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isFilled
                      ? Colors.white
                      : const Color(0xFF81D4FA),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Tips card ─────────────────────────────────────────────────────────────────

class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.glasses});
  final int glasses;

  static const _tips = [
    (icon: Symbols.wb_sunny_rounded, tip: 'Start your morning with 2 glasses'),
    (icon: Symbols.lunch_dining_rounded, tip: 'Drink a glass before each meal'),
    (icon: Symbols.directions_run_rounded, tip: 'Extra glass after exercise'),
    (icon: Symbols.bedtime_rounded, tip: 'Finish your last glass before 8 PM'),
  ];

  static const _tipGradients = [
    LinearGradient(colors: [AppColors.orange, AppColors.amber],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [AppColors.coral, Color(0xFFFF9A8B)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [AppColors.teal, AppColors.tealLight],
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
            gradient: AppColors.tealGrad,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('HYDRATION TIPS',
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

// ── History widgets ────────────────────────────────────────────────────────────

class _HistoryDayLabel extends StatelessWidget {
  const _HistoryDayLabel({required this.dateLabel, required this.count});
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
              ? AppColors.tealGrad
              : isYesterday
                  ? AppColors.orangeGrad
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
      Text('$count / $_goal glasses',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.inkSoft, fontSize: 12)),
    ]);
  }
}

class _HydrationHistoryCard extends StatelessWidget {
  const _HydrationHistoryCard({required this.entry});
  final _HydrationDay entry;

  @override
  Widget build(BuildContext context) {
    final pct = (entry.glasses / _goal).clamp(0.0, 1.0);
    final done = entry.glasses >= _goal;
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
                gradient: AppColors.tealGrad,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text('${entry.glasses}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('${entry.glasses} of $_goal glasses',
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
                              color: const Color(0xFFD6EFF8),
                              borderRadius: BorderRadius.circular(999))),
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: AppColors.tealGrad,
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
            gradient: AppColors.tealGrad,
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
