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

class FastingScreen extends ConsumerStatefulWidget {
  const FastingScreen({super.key});
  @override
  ConsumerState<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends ConsumerState<FastingScreen> {
  int _targetHours = 16;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(fastingProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            NeuTopBar(title: 'Fasting Timer ⏰', onBack: () => context.pop()),
            const SizedBox(height: 24),

            // Timer ring
            Center(
              child: SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(240, 240),
                      painter: _RingPainter(progress: f.active ? f.progress : 0),
                    ),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      if (f.active) ...[
                        Text(
                          f.elapsed.inHours >= 1 ? _fmt(f.elapsed) : _fmt(f.elapsed),
                          style: T.h1(context).copyWith(fontSize: 36, color: AppColors.coral),
                        ),
                        Text('of ${f.targetHours}h fasted', style: T.small(context)),
                        const SizedBox(height: 8),
                        NeuPill(
                          color: f.completed ? AppColors.sageSoft : AppColors.goldSoft,
                          child: Text(
                            f.completed ? '✅ Goal reached!' : '${(f.progress * 100).toInt()}%',
                            style: TextStyle(
                              color: f.completed ? AppColors.sageDark : AppColors.goldDark,
                              fontWeight: FontWeight.w800, fontSize: 12,
                            ),
                          ),
                        ),
                      ] else ...[
                        const Icon(Symbols.timer_rounded, size: 48, color: AppColors.inkSoft),
                        const SizedBox(height: 8),
                        Text('Not fasting', style: T.body(context)),
                      ],
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            if (!f.active) ...[
              Text('Target window', style: T.title(context)),
              const SizedBox(height: 12),
              Row(children: [
                for (final h in [12, 14, 16, 18, 20])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _targetHours = h),
                        child: NeuCard(
                          color: _targetHours == h ? AppColors.coralSoft : null,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text('${h}h',
                              style: T.title(context).copyWith(
                                fontSize: 14,
                                color: _targetHours == h ? AppColors.coral : AppColors.ink,
                              )),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 20),
              _BigButton(
                label: 'Start Fasting',
                icon: Symbols.play_circle_rounded,
                color: AppColors.coral,
                onTap: () => ref.read(fastingProvider.notifier).start(_targetHours),
              ),
            ] else ...[
              _BigButton(
                label: 'Stop Fast',
                icon: Symbols.stop_circle_rounded,
                color: AppColors.berry,
                onTap: () async {
                  final result = await ref.read(fastingProvider.notifier).stop();
                  if (context.mounted) {
                    final xp = (result['xp_awarded'] as num?)?.toInt() ?? 0;
                    final completed = result['completed'] as bool? ?? false;
                    _showResult(context, completed, xp);
                  }
                },
              ),
            ],
            const SizedBox(height: 24),

            if (f.history.isNotEmpty) ...[
              Text('History', style: T.title(context)),
              const SizedBox(height: 12),
              ...f.history.take(7).map((s) {
                final started = DateTime.parse(s['started_at'] as String);
                final ended = s['ended_at'] != null ? DateTime.parse(s['ended_at'] as String) : null;
                final hours = ended != null ? ended.difference(started).inMinutes / 60.0 : null;
                final completed = s['completed'] as bool? ?? false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: NeuCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Icon(
                        completed ? Symbols.check_circle_rounded : Symbols.cancel_rounded,
                        color: completed ? AppColors.sage : AppColors.inkSoft,
                        fill: 1,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            '${started.day}/${started.month} — ${s['target_hours']}h window',
                            style: T.title(context).copyWith(fontSize: 14),
                          ),
                          Text(
                            hours != null ? '${hours.toStringAsFixed(1)}h fasted' : 'Incomplete',
                            style: T.small(context),
                          ),
                        ]),
                      ),
                      if (completed)
                        const NeuPill(
                          color: AppColors.sageSoft,
                          child: Text('+15 XP', style: TextStyle(
                            color: AppColors.sageDark, fontWeight: FontWeight.w700, fontSize: 11)),
                        ),
                    ]),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  void _showResult(BuildContext context, bool completed, int xp) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(completed
        ? '🎉 Fast completed! +$xp XP earned'
        : 'Fast ended early. Keep going next time!'),
      backgroundColor: completed ? AppColors.sage : AppColors.inkMid,
      duration: const Duration(seconds: 3),
    ));
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.icon, required this.color, required this.onTap});
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
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    final bgPaint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fgPaint = Paint()
      ..color = progress >= 1 ? AppColors.sage : AppColors.coral
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
