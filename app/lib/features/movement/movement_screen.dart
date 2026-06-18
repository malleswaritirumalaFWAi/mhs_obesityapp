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
              NeuCard(
                color: done ? AppColors.coralSoft : AppColors.surface,
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: _bounceAnim,
                      child: Text(
                        _loading ? '—' : _formatSteps(_steps),
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                          color: done ? AppColors.coral : AppColors.inkMid,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'of ${_formatSteps(_goal)} steps',
                      style: T.small(context)
                          .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 12,
                        backgroundColor: AppColors.line,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            done ? AppColors.coral : AppColors.sage),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (done)
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Symbols.check_circle_rounded,
                            color: AppColors.coral, fill: 1, size: 20),
                        const SizedBox(width: 6),
                        Text('Daily goal reached!',
                            style: T.title(context)
                                .copyWith(color: AppColors.coral)),
                      ])
                    else
                      Text(
                        '${_formatSteps(remaining)} more steps to goal',
                        style: T.small(context),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Progress milestones ──
              Text('Progress', style: T.title(context)),
              const SizedBox(height: 14),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _MilestoneRow(steps: _steps, goal: _goal),
              const SizedBox(height: 28),

              // ── Add step presets ──
              if (!done) ...[
                Text('Log steps', style: T.title(context)),
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
                NeuCard(
                  color: AppColors.coralSoft,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Symbols.emoji_events_rounded,
                          color: AppColors.gold, fill: 1),
                      const SizedBox(width: 10),
                      Text(
                        '${_formatSteps(_goal)} steps done — amazing!',
                        style: T.title(context).copyWith(color: AppColors.coral),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // ── Tips ──
              _TipsCard(steps: _steps),
            ],
          ),
        ),
      ),
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: reached ? AppColors.coralSoft : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: reached ? AppColors.coral : AppColors.line,
                  width: reached ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Icon(
                  reached
                      ? Symbols.check_circle_rounded
                      : Symbols.radio_button_unchecked_rounded,
                  color: reached ? AppColors.coral : AppColors.inkSoft,
                  fill: 1,
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatSteps(m),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: reached ? AppColors.coral : AppColors.inkSoft,
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
    final w = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.line : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: onTap == null ? AppColors.inkSoft : AppColors.coral,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Movement tips', style: T.title(context)),
        const SizedBox(height: 12),
        NeuCard(
          child: Column(
            children: [
              for (final t in _tips) ...[
                Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.coralSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(t.icon,
                        color: AppColors.coral, size: 18, fill: 1),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(t.tip, style: T.small(context))),
                ]),
                if (t != _tips.last) ...[
                  const SizedBox(height: 10),
                  const Divider(color: AppColors.line, height: 1),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
