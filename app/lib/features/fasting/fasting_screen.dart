import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/providers/fasting_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

// ── Metabolic phase definitions ───────────────────────────────────────────────
class _Phase {
  const _Phase({
    required this.minHours,
    required this.name,
    required this.emoji,
    required this.tip,
    required this.color,
  });
  final int minHours;
  final String name, emoji, tip;
  final Color color;
}

const _phases = [
  _Phase(
    minHours: 0,
    name: 'Fed State',
    emoji: '🍽️',
    tip: 'Digesting. Insulin elevated. Fasting benefits begin after 4h.',
    color: AppColors.inkSoft,
  ),
  _Phase(
    minHours: 4,
    name: 'Early Fasting',
    emoji: '⚡',
    tip: 'Blood sugar stabilising. Liver glycogen depleting. Hunger may peak briefly.',
    color: AppColors.gold,
  ),
  _Phase(
    minHours: 8,
    name: 'Fat Burning',
    emoji: '🔥',
    tip: 'Body switching to fat for fuel. Ketone production rising. Energy will feel steady.',
    color: AppColors.coral,
  ),
  _Phase(
    minHours: 12,
    name: 'Ketosis',
    emoji: '✨',
    tip: 'Peak fat burning. Autophagy starting — cells clearing debris and repairing.',
    color: AppColors.berry,
  ),
  _Phase(
    minHours: 16,
    name: 'Deep Ketosis',
    emoji: '💪',
    tip: 'Maximum fat oxidation. Growth hormone surging. Autophagy at full speed.',
    color: AppColors.sage,
  ),
  _Phase(
    minHours: 18,
    name: 'Extended Fast',
    emoji: '🌟',
    tip: 'Elite level. Metabolic reset, cellular repair and inflammation reduction in full effect.',
    color: AppColors.teal,
  ),
];

// Window presets: [hours, recommended]
const _windows = [
  (8,  false),
  (12, false),
  (14, false),
  (16, true),
  (20, false),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class FastingScreen extends ConsumerStatefulWidget {
  const FastingScreen({super.key});
  @override
  ConsumerState<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends ConsumerState<FastingScreen> {
  int _targetHours = 16;
  bool _customMode = false;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _fmtShort(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _fmtTime(DateTime dt) {
    final hour = dt.hour;
    final min  = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12  = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(fastingProvider);
    final phase = _phases[f.phaseIndex];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            // ── Header ──────────────────────────────────────────────────────
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Fasting Timer',
                        style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    Text('Intermittent fasting tracker',
                        style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                  ]),
                ),
                const Text('⏰', style: TextStyle(fontSize: 26)),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Stats row ───────────────────────────────────────────────────
            if (!f.loading) ...[
              Row(children: [
                _StatCard(
                  label: 'Completed',
                  value: '${f.stats.totalCompleted}',
                  icon: Symbols.check_circle_rounded,
                  iconColor: AppColors.sage,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  label: 'Total Hours',
                  value: '${f.stats.totalHours.toStringAsFixed(0)}h',
                  icon: Symbols.timer_rounded,
                  iconColor: AppColors.coral,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  label: 'This Week',
                  value: '${f.stats.thisWeek}',
                  icon: Symbols.calendar_today_rounded,
                  iconColor: AppColors.berry,
                ),
              ]),
              const SizedBox(height: 20),
            ],

            // ── Timer ring ──────────────────────────────────────────────────
            Center(
              child: SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(240, 240),
                      painter: _RingPainter(
                        progress: f.active ? f.progress : 0,
                        targetHours: f.active ? f.targetHours : _targetHours,
                      ),
                    ),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      if (f.active) ...[
                        Text(
                          _fmt(f.elapsed),
                          style: T.h1(context).copyWith(
                              fontSize: 34, color: AppColors.coral),
                        ),
                        Text('elapsed of ${f.targetHours}h',
                            style: T.small(context)),
                        const SizedBox(height: 6),
                        NeuPill(
                          color: f.completed
                              ? AppColors.sageSoft
                              : AppColors.goldSoft,
                          child: Text(
                            f.completed
                                ? '✅ Goal reached!'
                                : '${(f.progress * 100).toInt()}%',
                            style: TextStyle(
                              color: f.completed
                                  ? AppColors.sageDark
                                  : AppColors.goldDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ] else ...[
                        const Icon(Symbols.timer_rounded,
                            size: 48, color: AppColors.inkSoft),
                        const SizedBox(height: 8),
                        Text('Not fasting', style: T.body(context)),
                      ],
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Break-fast end time (active only) ───────────────────────────
            if (f.active) ...[
              NeuCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  const Icon(Symbols.restaurant_rounded,
                      color: AppColors.coral, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                        f.completed
                            ? 'Eating window is open!'
                            : 'Eating window opens at ${_fmtTime(f.breakFastAt!)}',
                        style: T.title(context).copyWith(fontSize: 14),
                      ),
                      Text(
                        f.completed
                            ? 'You reached your ${f.targetHours}h goal. Break your fast mindfully.'
                            : '${_fmtShort(f.remaining)} remaining',
                        style: T.small(context),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Current metabolic phase ──────────────────────────────────
              NeuCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text(phase.emoji,
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                          'Phase ${f.phaseIndex + 1} of ${_phases.length} — ${phase.name}',
                          style: T.title(context).copyWith(fontSize: 14),
                        ),
                        Text(
                          _phaseMilestoneText(f),
                          style: T.small(context),
                        ),
                      ]),
                    ),
                    NeuPill(
                      color: AppColors.coralSoft,
                      child: Text(
                        '${f.elapsed.inHours}h in',
                        style: const TextStyle(
                            color: AppColors.coral,
                            fontWeight: FontWeight.w700,
                            fontSize: 11),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  // Phase progress bar across all phases
                  _PhaseBar(phaseIndex: f.phaseIndex, progress: f.progress),
                  const SizedBox(height: 10),
                  Text(
                    phase.tip,
                    style: T.small(context)
                        .copyWith(color: AppColors.inkMid, fontSize: 12),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
            ],

            // ── Window picker (not active) ───────────────────────────────────
            if (!f.active) ...[
              Text('Choose your fasting window', style: T.title(context)),
              const SizedBox(height: 6),
              Text(
                'Longer fasts earn more XP. 16h is recommended for beginners.',
                style: T.small(context),
              ),
              const SizedBox(height: 12),

              // Preset chips + Custom chip
              Row(children: [
                for (final (hours, recommended) in _windows) ...[
                  Expanded(
                    child: _WindowChip(
                      hours: hours,
                      recommended: recommended,
                      selected: !_customMode && _targetHours == hours,
                      xp: _xpForHours(hours),
                      onTap: () => setState(() {
                        _targetHours = hours;
                        _customMode = false;
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: _WindowChip(
                    hours: _customMode ? _targetHours : 0,
                    recommended: false,
                    selected: _customMode,
                    xp: _customMode ? _xpForHours(_targetHours) : 0,
                    isCustom: true,
                    onTap: () => setState(() {
                      _customMode = true;
                      if (_targetHours < 8 || _windows.any((w) => w.$1 == _targetHours && !_customMode)) {
                        _targetHours = 20;
                      }
                    }),
                  ),
                ),
              ]),

              // Custom slider — shown when Custom chip is selected
              if (_customMode) ...[
                const SizedBox(height: 16),
                NeuCard(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('Custom window',
                            style: T.title(context).copyWith(fontSize: 14)),
                        const Spacer(),
                        Text(
                          '${_targetHours}h  ·  +${_xpForHours(_targetHours)} XP',
                          style: T.title(context).copyWith(
                              fontSize: 14, color: AppColors.coral),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.coral,
                          inactiveTrackColor: AppColors.line,
                          thumbColor: AppColors.coral,
                          overlayColor: AppColors.coralSoft,
                          trackHeight: 4,
                        ),
                        child: Slider(
                          min: 8,
                          max: 24,
                          divisions: 16,
                          value: _targetHours.toDouble(),
                          onChanged: (v) =>
                              setState(() => _targetHours = v.round()),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('8h', style: T.small(context)),
                          Text('16h', style: T.small(context)),
                          Text('24h', style: T.small(context)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],

            // ── Start / Stop button ─────────────────────────────────────────
            if (!f.active)
              _BigButton(
                label: 'Start  ${_targetHours}h Fast  ·  +${_xpForHours(_targetHours)} XP',
                icon: Symbols.play_circle_rounded,
                color: AppColors.coral,
                onTap: () =>
                    ref.read(fastingProvider.notifier).start(_targetHours),
              )
            else
              _BigButton(
                label: 'Stop Fast',
                icon: Symbols.stop_circle_rounded,
                color: AppColors.berry,
                onTap: () => _confirmStop(context),
              ),
            const SizedBox(height: 28),

            // ── History ─────────────────────────────────────────────────────
            if (f.history.isNotEmpty) ...[
              Text('History', style: T.title(context)),
              const SizedBox(height: 12),
              ...f.history.take(10).map((s) => _HistoryCard(session: s)),
            ],
          ],
        ),
      ),
    );
  }

  String _phaseMilestoneText(FastingState f) {
    final idx = f.phaseIndex;
    if (idx >= _phases.length - 1) return 'You are in the final phase';
    final nextPhase = _phases[idx + 1];
    final hoursToNext = nextPhase.minHours - f.elapsed.inHours;
    if (hoursToNext <= 0) return 'Entering ${nextPhase.name} soon';
    return '${hoursToNext}h until ${nextPhase.emoji} ${nextPhase.name}';
  }

  int _xpForHours(int h) {
    const map = {8: 8, 10: 10, 12: 15, 14: 25, 16: 40, 18: 60, 20: 80};
    return map[h] ?? (h * 4);
  }

  Future<void> _confirmStop(BuildContext context) async {
    final f = ref.read(fastingProvider);
    final h = f.elapsed.inHours;
    final m = f.elapsed.inMinutes.remainder(60);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Stop your fast?',
            style: TextStyle(
                color: AppColors.ink, fontWeight: FontWeight.w800)),
        content: Text(
          'You have fasted for ${h}h ${m}m out of ${f.targetHours}h target. '
          '${f.completed ? "You've hit your goal! 🎉" : "This will be saved to your history."}',
          style: const TextStyle(color: AppColors.inkMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going',
                style: TextStyle(
                    color: AppColors.sage, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Stop',
                style: TextStyle(
                    color: AppColors.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final notifier = ref.read(fastingProvider.notifier);
      final result = await notifier.stop();
      if (context.mounted) {
        final xp = (result['xp_awarded'] as num?)?.toInt() ?? 0;
        final completed = result['completed'] as bool? ?? false;
        _showResult(context, completed, xp, notifier);
      }
    }
  }

  void _showResult(BuildContext context, bool completed, int xp,
      FastingNotifier notifier) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(completed
          ? '🎉 Fast completed! +$xp XP earned'
          : 'Fast stopped early. No XP awarded.'),
      backgroundColor: completed ? AppColors.sage : AppColors.inkMid,
      duration: const Duration(seconds: 10),
      action: completed
          ? null
          : SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () async {
                final ok = await notifier.resume();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok
                        ? 'Fast resumed!'
                        : 'Could not resume — too much time has passed.'),
                    backgroundColor:
                        ok ? AppColors.sage : AppColors.coral,
                    duration: const Duration(seconds: 3),
                  ));
                }
              },
            ),
    ));
  }
}

// ── Window chip ───────────────────────────────────────────────────────────────

class _WindowChip extends StatelessWidget {
  const _WindowChip({
    required this.hours,
    required this.recommended,
    required this.selected,
    required this.xp,
    required this.onTap,
    this.isCustom = false,
  });
  final int hours;
  final bool recommended, selected, isCustom;
  final int xp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = isCustom ? 'Custom' : '${hours}h';
    final subLabel = isCustom
        ? (selected ? '+$xp XP' : 'set')
        : '+$xp XP';

    return GestureDetector(
      onTap: onTap,
      child: NeuCard(
        color: selected ? AppColors.coralSoft : null,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.coral : AppColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            if (recommended) ...[
              const SizedBox(width: 3),
              const Text('★',
                  style: TextStyle(
                      color: AppColors.sage,
                      fontSize: 9,
                      fontWeight: FontWeight.w900)),
            ],
          ]),
          const SizedBox(height: 2),
          Text(
            subLabel,
            style: TextStyle(
              color: selected ? AppColors.coral : AppColors.inkSoft,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Phase progress bar ────────────────────────────────────────────────────────

class _PhaseBar extends StatelessWidget {
  const _PhaseBar({required this.phaseIndex, required this.progress});
  final int phaseIndex;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_phases.length, (i) {
        final filled = i <= phaseIndex;
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(right: i < _phases.length - 1 ? 3 : 0),
            decoration: BoxDecoration(
              color: filled ? AppColors.coral : AppColors.line,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });
  final String label, value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: NeuCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(children: [
          Icon(icon, color: iconColor, size: 20, fill: 1),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
          Text(label,
              style: const TextStyle(
                  color: AppColors.inkSoft, fontSize: 10),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ── History card ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.session});
  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    final started =
        DateTime.parse(session['started_at'] as String).toLocal();
    final ended = session['ended_at'] != null
        ? DateTime.parse(session['ended_at'] as String).toLocal()
        : null;
    final hours =
        ended != null ? ended.difference(started).inMinutes / 60.0 : null;
    final completed = session['completed'] as bool? ?? false;
    final target = (session['target_hours'] as num?)?.toInt() ?? 16;
    final xpAwarded = (session['xp_awarded'] as num?)?.toInt() ?? 0;

    final dayStr = '${started.day}/${started.month}/${started.year % 100}';
    final protocol = _protocolName(target);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeuCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(
            completed
                ? Symbols.check_circle_rounded
                : Symbols.cancel_rounded,
            color: completed ? AppColors.sage : AppColors.inkSoft,
            fill: 1,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                '$dayStr · $protocol window',
                style: T.title(context).copyWith(fontSize: 13),
              ),
              Text(
                hours != null
                    ? '${hours.toStringAsFixed(1)}h fasted'
                        '${completed ? '' : ' (stopped early)'}'
                    : 'In progress',
                style: T.small(context),
              ),
            ]),
          ),
          if (completed && xpAwarded > 0)
            NeuPill(
              color: AppColors.sageSoft,
              child: Text('+$xpAwarded XP',
                  style: const TextStyle(
                      color: AppColors.sageDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 11)),
            )
          else if (!completed)
            const NeuPill(
              color: AppColors.coralSoft,
              child: Text('Incomplete',
                  style: TextStyle(
                      color: AppColors.coral,
                      fontWeight: FontWeight.w700,
                      fontSize: 11)),
            ),
        ]),
      ),
    );
  }

  String _protocolName(int h) => '${h}h';
}

// ── Big action button ─────────────────────────────────────────────────────────

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
        ]),
      ),
    );
  }
}

// ── Ring painter with phase milestone ticks ───────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.targetHours});
  final double progress;
  final int targetHours;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.line
        ..strokeWidth = 16
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..color = progress >= 1 ? AppColors.sage : AppColors.coral
          ..strokeWidth = 16
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    // Phase milestone tick marks
    final tickPaint = Paint()
      ..color = AppColors.surface
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (final phase in _phases) {
      if (phase.minHours <= 0 || phase.minHours >= targetHours) continue;
      final pct = phase.minHours / targetHours;
      final angle = -pi / 2 + 2 * pi * pct;
      final inner = center +
          Offset(cos(angle) * (radius - 10), sin(angle) * (radius - 10));
      final outer = center +
          Offset(cos(angle) * (radius + 10), sin(angle) * (radius + 10));
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.targetHours != targetHours;
}
