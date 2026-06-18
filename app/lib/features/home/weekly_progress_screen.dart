import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/lessons_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

// ─── Main Screen ─────────────────────────────────────────────────────────────

class WeeklyProgressScreen extends ConsumerWidget {
  const WeeklyProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(weeklyProgressProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: progressAsync.when(
          loading: () => Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.tealGrad,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
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
                    child: Text('Weekly Progress',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                  ),
                  const Text('📊', style: TextStyle(fontSize: 26)),
                ]),
              ),
            ),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ]),
          error: (_, __) => Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.tealGrad,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
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
                    child: Text('Weekly Progress',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                  ),
                  const Text('📊', style: TextStyle(fontSize: 26)),
                ]),
              ),
            ),
            const Expanded(child: Center(child: Text('Could not load progress'))),
          ]),
          data: (d) {
            final weekNum      = (d['week_number']  as num?)?.toInt()    ?? 1;
            final weekXp       = (d['week_xp']      as num?)?.toInt()    ?? 0;
            final weekScore    = (d['week_score']   as num?)?.toInt()    ?? 0;
            final stars        = (d['stars']        as num?)?.toInt()    ?? 1;
            final streak       = (d['streak']       as num?)?.toInt()    ?? 0;
            final rank         = (d['rank']         as num?)?.toInt();
            final tasksDone    = (d['tasks_done']   as num?)?.toInt()    ?? 0;
            final tasksTotal   = (d['tasks_total']  as num?)?.toInt()    ?? 0;
            final mealsLogged  = (d['meals_logged'] as num?)?.toInt()    ?? 0;
            final mealsTarget  = (d['meals_target'] as num?)?.toInt()    ?? 21;
            final avgMood      = (d['avg_mood']     as num?)?.toDouble();
            final weightChange = (d['weight_change'] as num?)?.toDouble();
            final dayActivity  = (d['day_activity'] as List? ?? [])
                .cast<Map<String, dynamic>>();
            final nextChallenge = d['next_week_challenge'] as String? ?? '';
            final activeDays   = dayActivity.where((x) => x['active'] == true).length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.orangeGrad,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Symbols.arrow_back_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text('Week $weekNum Report',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                    ),
                    const Text('📈', style: TextStyle(fontSize: 26)),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Game Banner ──
                _GameBanner(
                  weekNum: weekNum,
                  weekScore: weekScore,
                  stars: stars,
                  weekXp: weekXp,
                  rank: rank,
                  weightChange: weightChange,
                ),
                const SizedBox(height: 16),

                // ── Day Activity Dots ──
                if (dayActivity.isNotEmpty) ...[
                  _DayActivityRow(dayActivity: dayActivity),
                  const SizedBox(height: 20),
                ],

                // ── 4 Pillar Cards ──
                Text("This Week's Stats", style: T.title(context)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _PillarCard(
                    icon: Symbols.restaurant_rounded,
                    label: 'Diet',
                    value: '$mealsLogged / $mealsTarget meals',
                    pct: mealsTarget > 0 ? (mealsLogged / mealsTarget).clamp(0.0, 1.0) : 0,
                    color: AppColors.sage,
                    bgColor: AppColors.sageSoft,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _PillarCard(
                    icon: Symbols.directions_run_rounded,
                    label: 'Activity',
                    value: '$activeDays / 7 days active',
                    pct: activeDays / 7,
                    color: AppColors.coral,
                    bgColor: AppColors.coralSoft,
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _PillarCard(
                    icon: Symbols.sentiment_satisfied_rounded,
                    label: 'Mood',
                    value: avgMood != null ? '${avgMood.toStringAsFixed(1)} / 5.0' : 'No data yet',
                    pct: avgMood != null ? (avgMood / 5).clamp(0.0, 1.0) : 0,
                    color: AppColors.berry,
                    bgColor: AppColors.berrySoft,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _PillarCard(
                    icon: Symbols.local_fire_department_rounded,
                    label: 'Streak',
                    value: '$streak day streak',
                    pct: (streak / 7).clamp(0.0, 1.0),
                    color: AppColors.gold,
                    bgColor: AppColors.goldSoft,
                  )),
                ]),
                const SizedBox(height: 16),

                // ── Task completion bar ──
                if (tasksTotal > 0) ...[
                  NeuCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.sageSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Symbols.task_alt_rounded,
                            color: AppColors.sage, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$tasksDone / $tasksTotal tasks completed',
                              style: T.title(context).copyWith(fontSize: 13)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: tasksTotal > 0
                                  ? (tasksDone / tasksTotal).clamp(0.0, 1.0)
                                  : 0,
                              backgroundColor: AppColors.line,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sage),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      )),
                      const SizedBox(width: 12),
                      Text(
                        '${tasksTotal > 0 ? (tasksDone / tasksTotal * 100).round() : 0}%',
                        style: T.title(context).copyWith(color: AppColors.sage, fontSize: 18),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Next Week Challenge ──
                if (nextChallenge.isNotEmpty) ...[
                  _NextWeekChallenge(weekNum: weekNum + 1, challenge: nextChallenge),
                  const SizedBox(height: 16),
                ],

                // ── Share ──
                NeuCard(
                  padding: const EdgeInsets.all(16),
                  onTap: () => _showShareSheet(
                    context,
                    _buildWeekPostText(
                      weekNum: weekNum,
                      weekScore: weekScore,
                      stars: stars,
                      weekXp: weekXp,
                      tasksDone: tasksDone,
                      tasksTotal: tasksTotal,
                      mealsLogged: mealsLogged,
                      avgMood: avgMood,
                      streak: streak,
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.coralSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Symbols.share_rounded,
                          color: AppColors.coral, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Share your progress',
                            style: T.title(context).copyWith(fontSize: 14)),
                        Text('Post to group feed and inspire others',
                            style: T.small(context)),
                      ],
                    )),
                    const Icon(Symbols.chevron_right_rounded,
                        color: AppColors.inkSoft),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Game Banner ─────────────────────────────────────────────────────────────

class _GameBanner extends StatelessWidget {
  const _GameBanner({
    required this.weekNum,
    required this.weekScore,
    required this.stars,
    required this.weekXp,
    required this.rank,
    required this.weightChange,
  });
  final int weekNum, weekScore, stars, weekXp;
  final int? rank;
  final double? weightChange;

  Color get _scoreColor => weekScore >= 75
      ? AppColors.sage
      : weekScore >= 45
          ? AppColors.gold
          : AppColors.coral;

  String get _verdict => stars == 3
      ? 'Outstanding!'
      : stars == 2
          ? 'Good progress!'
          : 'Keep going!';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C2E), Color(0xFF2E1B3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C1C2E).withOpacity(0.4),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(children: [
        // Top label row
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gold.withOpacity(0.4)),
            ),
            child: Text(
              'WEEK $weekNum',
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Game Report Card',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 12,
            ),
          ),
        ]),

        const SizedBox(height: 22),

        // Score ring + stats
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          _WeekScoreRing(score: weekScore, color: _scoreColor),
          const SizedBox(width: 22),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stars
              Row(children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Icon(
                  i < stars ? Symbols.star_rounded : Symbols.star_rounded,
                  color: i < stars
                      ? AppColors.gold
                      : Colors.white.withOpacity(0.18),
                  size: 26,
                  fill: i < stars ? 1 : 0,
                ),
              ))),
              const SizedBox(height: 10),
              Text(
                _verdict,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 10),
              // XP
              Row(children: [
                const Icon(Symbols.bolt_rounded,
                    color: AppColors.gold, size: 15, fill: 1),
                const SizedBox(width: 4),
                Text(
                  '$weekXp XP this week',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ]),
              if (rank != null) ...[
                const SizedBox(height: 5),
                Row(children: [
                  Icon(Symbols.military_tech_rounded,
                      color: Colors.white.withOpacity(0.5), size: 14, fill: 1),
                  const SizedBox(width: 4),
                  Text(
                    'Rank #$rank in group',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                ]),
              ],
              if (weightChange != null) ...[
                const SizedBox(height: 5),
                Row(children: [
                  Icon(
                    weightChange! <= 0
                        ? Symbols.trending_down_rounded
                        : Symbols.trending_up_rounded,
                    color: weightChange! <= 0 ? AppColors.sage : AppColors.coral,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${weightChange! > 0 ? '+' : ''}${weightChange!.toStringAsFixed(1)} kg weight',
                    style: TextStyle(
                      color: weightChange! <= 0 ? AppColors.sage : AppColors.coral,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ]),
              ],
            ],
          )),
        ]),
      ]),
    );
  }
}

// ─── Week Score Ring ─────────────────────────────────────────────────────────

class _WeekScoreRing extends StatelessWidget {
  const _WeekScoreRing({required this.score, required this.color});
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108, height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 108, height: 108,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 9,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              '$score',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '/ 100',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Day Activity Row ─────────────────────────────────────────────────────────

class _DayActivityRow extends StatelessWidget {
  const _DayActivityRow({required this.dayActivity});
  final List<Map<String, dynamic>> dayActivity;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Day by Day', style: T.title(context)),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: dayActivity.map((day) {
            final active   = day['active']   == true;
            final isToday  = day['isToday']  == true;
            final isFuture = day['isFuture'] == true;
            final label    = day['label'] as String? ?? '';

            // Determine dot appearance
            final Color dotFill;
            final Color? borderColor;
            final Color labelColor;
            final Widget? dotIcon;
            final List<BoxShadow>? shadows;

            if (isFuture) {
              dotFill    = AppColors.line;
              borderColor = null;
              labelColor = AppColors.inkSoft.withOpacity(0.45);
              dotIcon    = null;
              shadows    = null;
            } else if (active) {
              final c    = isToday ? AppColors.coral : AppColors.sage;
              dotFill    = c;
              borderColor = null;
              labelColor = isToday ? AppColors.coral : AppColors.sageDark;
              dotIcon    = Icon(Symbols.check_rounded,
                  color: Colors.white, size: 15, fill: 1);
              shadows    = [
                BoxShadow(color: c.withOpacity(0.35), blurRadius: 7, spreadRadius: 1)
              ];
            } else {
              // Past day, not active
              dotFill    = isToday ? AppColors.surface : AppColors.line;
              borderColor = isToday ? AppColors.coral : null;
              labelColor = isToday ? AppColors.coral : AppColors.inkSoft;
              dotIcon    = isToday
                  ? null
                  : Icon(Symbols.close_rounded,
                      color: AppColors.inkSoft.withOpacity(0.45), size: 13);
              shadows    = null;
            }

            return Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotFill,
                  border: borderColor != null
                      ? Border.all(color: borderColor, width: 2)
                      : null,
                  boxShadow: shadows,
                ),
                child: dotIcon != null ? Center(child: dotIcon) : null,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 10,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ]);
          }).toList(),
        ),
      ]),
    );
  }
}

// ─── Pillar Card ─────────────────────────────────────────────────────────────

class _PillarCard extends StatelessWidget {
  const _PillarCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.pct,
    required this.color,
    required this.bgColor,
  });
  final IconData icon;
  final String label, value;
  final double pct;
  final Color color, bgColor;

  @override
  Widget build(BuildContext context) {
    final pctInt = (pct * 100).round().clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(top: BorderSide(color: color, width: 3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark.withOpacity(0.5),
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
          const BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 6,
            offset: Offset(-2, -2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 7),
          Expanded(child: Text(label,
              style: T.small(context).copyWith(fontWeight: FontWeight.w700))),
          Text('$pctInt%',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: AppColors.line,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: T.small(context).copyWith(
                fontSize: 11, color: AppColors.inkSoft)),
      ]),
    );
  }
}

// ─── Share helpers ───────────────────────────────────────────────────────────

String _buildWeekPostText({
  required int weekNum,
  required int weekScore,
  required int stars,
  required int weekXp,
  required int tasksDone,
  required int tasksTotal,
  required int mealsLogged,
  required double? avgMood,
  required int streak,
}) {
  final starEmojis = '${'⭐' * stars}${'☆' * (3 - stars)}';
  final taskPct = tasksTotal > 0 ? (tasksDone / tasksTotal * 100).round() : 0;
  final buf = StringBuffer();
  buf.writeln('$starEmojis Week $weekNum Report · $weekScore/100');
  buf.writeln('');
  buf.writeln('✅ $tasksDone/$tasksTotal tasks done ($taskPct%)');
  buf.writeln('🍽 $mealsLogged meals logged');
  if (avgMood != null) buf.writeln('😊 Mood ${avgMood.toStringAsFixed(1)} / 5.0');
  buf.writeln('🔥 $streak day streak  ⚡$weekXp XP');
  buf.writeln('');
  buf.write('#FitQuest #WeeklyProgress');
  return buf.toString();
}

void _showShareSheet(BuildContext context, String postText) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShareSheet(postText: postText),
  );
}

// ─── Share Sheet ─────────────────────────────────────────────────────────────

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.postText});
  final String postText;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final _noteCtrl = TextEditingController();
  bool _posting = false;
  bool _posted  = false;
  String? _error;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    setState(() { _posting = true; _error = null; });
    try {
      final note = _noteCtrl.text.trim();
      final body = note.isNotEmpty
          ? '${widget.postText}\n\n$note'
          : widget.postText;
      await ref.read(apiClientProvider).postJson('/posts', {
        'body': body,
        'emoji': '⭐',
        'post_type': 'progress_share',
      });
      setState(() { _posted = true; _posting = false; });
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _posting = false; _error = 'Could not post. Try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        const SizedBox(height: 12),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: AppColors.line,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 18),

        // Title
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.coralSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Symbols.share_rounded,
                color: AppColors.coral, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Share to Group Feed',
                style: T.title(context).copyWith(fontSize: 16)),
            Text('Your group will see this post',
                style: T.small(context)),
          ])),
        ]),
        const SizedBox(height: 18),

        // Success state
        if (_posted) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: AppColors.sageSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Symbols.check_rounded,
                    color: AppColors.sage, size: 28, fill: 1),
              ),
              const SizedBox(height: 12),
              Text('Posted!', style: T.title(context).copyWith(color: AppColors.sage, fontSize: 18)),
              const SizedBox(height: 4),
              Text('Your progress is now in the group feed',
                  style: T.small(context), textAlign: TextAlign.center),
            ]),
          ),
        ] else ...[
          // Post preview card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1C1C2E), Color(0xFF2E1B3D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              widget.postText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Personal note field
          Container(
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: AppColors.shadowDark.withOpacity(0.5),
                    blurRadius: 4, offset: const Offset(2, 2)),
                const BoxShadow(color: AppColors.shadowLight,
                    blurRadius: 4, offset: Offset(-2, -2)),
              ],
            ),
            child: TextField(
              controller: _noteCtrl,
              maxLines: 2,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'Add a personal note (optional)...',
                hintStyle: T.small(context).copyWith(color: AppColors.inkSoft),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
                counterStyle: T.small(context).copyWith(fontSize: 10),
              ),
              style: T.body(context).copyWith(fontSize: 13),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: T.small(context).copyWith(color: AppColors.coral)),
          ],
          const SizedBox(height: 16),

          // Post button
          GestureDetector(
            onTap: _posting ? null : _post,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.coral, Color(0xFFFF4D3B)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _posting
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text(
                        'Post to Group Feed',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Cancel
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('Cancel',
                    style: T.small(context).copyWith(
                        color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── Next Week Challenge ──────────────────────────────────────────────────────

class _NextWeekChallenge extends StatelessWidget {
  const _NextWeekChallenge({required this.weekNum, required this.challenge});
  final int weekNum;
  final String challenge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C2E), Color(0xFF2E1B3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Symbols.flag_rounded,
              color: AppColors.gold, size: 22, fill: 1),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WEEK $weekNum MISSION',
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              challenge,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        )),
      ]),
    );
  }
}
