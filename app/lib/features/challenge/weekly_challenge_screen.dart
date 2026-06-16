import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

// ── Challenge metadata (12-week programme) ────────────────────────────────────

class _ChallengeInfo {
  const _ChallengeInfo({
    required this.week,
    required this.title,
    required this.description,
    required this.type,
    required this.target,
    required this.xp,
    required this.emoji,
    required this.howTo,
    required this.tip,
  });
  final int week;
  final String title;
  final String description;
  final String type;
  final int target;
  final int xp;
  final String emoji;
  final String howTo;
  final String tip; // weekly health tip for this challenge
}

const _challenges = [
  _ChallengeInfo(
    week: 1, emoji: '👟', type: 'steps', target: 3, xp: 40,
    title: 'Step Starter',
    description: 'Hit 8,000 steps/day for 3 days this week. Walk after meals — it counts!',
    howTo: 'Log your daily steps in the Movement screen each evening. 8,000 steps ≈ a 60-minute brisk walk.',
    tip: 'Walking 8,000 steps a day reduces all-cause mortality risk by 51% compared to 4,000 steps.',
  ),
  _ChallengeInfo(
    week: 2, emoji: '😴', type: 'sleep', target: 5, xp: 40,
    title: 'Sleep Champion',
    description: 'Get 7+ hours of sleep on 5 nights. Poor sleep raises hunger hormones by 24%.',
    howTo: 'Log sleep hours on the Home screen each morning when you wake up.',
    tip: 'People who sleep less than 6 hours are 55% more likely to be obese than those who sleep 7–9 hours.',
  ),
  _ChallengeInfo(
    week: 3, emoji: '🏃', type: 'steps', target: 10000, xp: 60,
    title: 'Step Warrior',
    description: 'Hit 10,000 steps in a single day. One big walk can reset your whole week!',
    howTo: 'Log steps in the Movement screen. A 90-minute evening walk gets you there.',
    tip: 'A single day of 10,000 steps burns approximately 400–500 extra calories.',
  ),
  _ChallengeInfo(
    week: 4, emoji: '🍱', type: 'meals', target: 5, xp: 40,
    title: 'Meal Mastery',
    description: 'Log all 4 meals — breakfast, lunch, snack, dinner — every day for 5 days.',
    howTo: 'Tap "Log a meal" in Today\'s Plan and choose your meal type after eating.',
    tip: 'People who eat breakfast are 50% less likely to be obese. Consistent meal timing regulates hunger hormones.',
  ),
  _ChallengeInfo(
    week: 5, emoji: '💧', type: 'water', target: 5, xp: 40,
    title: 'Hydration Hero',
    description: 'Drink 8 glasses of water every day for 5 days. Water before meals cuts calories.',
    howTo: 'Tap the Water stat on the Home screen and update your glass count throughout the day.',
    tip: 'Drinking 500ml water 30 minutes before meals reduces calorie intake by 13% in overweight adults.',
  ),
  _ChallengeInfo(
    week: 6, emoji: '⏰', type: 'fasting', target: 4, xp: 50,
    title: 'Fasting Focus',
    description: 'Complete a 14-hour fasting window on 4 different days this week.',
    howTo: 'Start a fasting timer in the Fasting screen after your last meal of the day.',
    tip: 'Intermittent fasting reduces insulin levels by 20–31%, unlocking fat-burning mode overnight.',
  ),
  _ChallengeInfo(
    week: 7, emoji: '☀️', type: 'streak', target: 6, xp: 50,
    title: 'Check-in Streak',
    description: 'Complete your Morning Check-in 6 days in a row for mental clarity & accountability.',
    howTo: 'Tap "Morning check-in" in Today\'s Plan every morning to log mood and weight.',
    tip: 'Daily self-monitoring doubles weight loss success. Tracking creates awareness and accountability.',
  ),
  _ChallengeInfo(
    week: 8, emoji: '🎯', type: 'tasks', target: 3, xp: 80,
    title: 'Midpoint Madness',
    description: 'Complete ALL daily tasks on 3 consecutive days — the halfway milestone!',
    howTo: 'Complete every task in Today\'s Plan — check-in, meals, steps, water, and weigh-in.',
    tip: 'You are halfway through your 12-week programme. Consistency now predicts your final outcome.',
  ),
  _ChallengeInfo(
    week: 9, emoji: '⚖️', type: 'streak', target: 7, xp: 50,
    title: 'Weigh-in Week',
    description: 'Log your weight every morning for 7 days. Seeing data creates change.',
    howTo: 'Tap the Scale task in Today\'s Plan each morning to log your weight.',
    tip: 'Daily weigh-ins lead to 82% more weight loss than weekly weigh-ins in clinical studies.',
  ),
  _ChallengeInfo(
    week: 10, emoji: '🏆', type: 'steps', target: 60000, xp: 60,
    title: 'Step Master',
    description: 'Accumulate 60,000 steps across the whole week — that\'s 8,500/day average.',
    howTo: 'Log steps daily. Every walk counts — stairs, errands, everything adds up.',
    tip: 'Walking 60,000 steps per week burns roughly 2,500 extra calories — nearly a pound of fat.',
  ),
  _ChallengeInfo(
    week: 11, emoji: '🔥', type: 'streak', target: 7, xp: 50,
    title: 'Streak Keeper',
    description: 'Maintain your activity streak all 7 days this week without missing a single day.',
    howTo: 'Complete at least one logged activity (steps, meal, or check-in) every single day.',
    tip: 'Streaks create identity. After 7 consecutive days, healthy habits become part of who you are.',
  ),
  _ChallengeInfo(
    week: 12, emoji: '🎓', type: 'tasks', target: 5, xp: 100,
    title: 'Grand Finale',
    description: 'The final week! Complete all daily tasks perfectly for 5 days to earn your badge.',
    howTo: 'Hit 100% on Today\'s Plan for 5 days — you\'ve come this far, finish strong!',
    tip: 'Completing a structured 12-week programme reduces obesity-related health risk by up to 30%.',
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class WeeklyChallengeScreen extends ConsumerStatefulWidget {
  const WeeklyChallengeScreen({super.key});
  @override
  ConsumerState<WeeklyChallengeScreen> createState() => _WeeklyChallengeScreenState();
}

class _WeeklyChallengeScreenState extends ConsumerState<WeeklyChallengeScreen> {
  Map<String, dynamic>? _apiChallenge;
  Map<String, dynamic>? _entry;
  List<dynamic> _allChallenges = [];
  Map<int, Map<String, dynamic>> _entriesByChallenge = {}; // challenge_id → entry
  int _currentWeek = 1;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(apiClientProvider).getJson('/challenge/current');
      if (!mounted) return;
      // Build entries map by challenge_id
      final entries = (d['all_entries'] as List?) ?? [];
      final entriesMap = <int, Map<String, dynamic>>{};
      for (final e in entries) {
        final m = Map<String, dynamic>.from(e as Map);
        entriesMap[_safeInt(m['challenge_id'])] = m;
      }
      setState(() {
        _apiChallenge = d['challenge'] as Map<String, dynamic>?;
        _entry = d['entry'] as Map<String, dynamic>?;
        _currentWeek = _safeInt(d['current_week'], 1);
        _allChallenges = (d['all_challenges'] as List?) ?? [];
        _entriesByChallenge = entriesMap;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static int _safeInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  // Get entry for a given API challenge (matched by id)
  Map<String, dynamic>? _entryFor(Map<String, dynamic> apiC) {
    final id = _safeInt(apiC['id']);
    return _entriesByChallenge[id];
  }

  @override
  Widget build(BuildContext context) {
    final activeInfo = (_currentWeek >= 1 && _currentWeek <= 12)
        ? _challenges[_currentWeek - 1]
        : _challenges[0];

    final completed = _entry?['completed'] == true;
    final progress = _safeInt(_entry?['progress']);
    final target = _apiChallenge != null
        ? _safeInt(_apiChallenge!['target'], activeInfo.target)
        : activeInfo.target;
    final xpReward = _apiChallenge != null
        ? _safeInt(_apiChallenge!['xp_reward'], activeInfo.xp)
        : activeInfo.xp;
    final pct = target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? Column(children: [
                _topBar(context),
                const Expanded(child: Center(child: CircularProgressIndicator())),
              ])
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    _topBar(context),
                    const SizedBox(height: 20),

                    // ── Active challenge card ──────────────────────────────
                    _ActiveCard(
                      info: activeInfo,
                      apiChallenge: _apiChallenge,
                      completed: completed,
                      progress: progress,
                      target: target,
                      xpReward: xpReward,
                      pct: pct.toDouble(),
                      currentWeek: _currentWeek,
                    ),
                    const SizedBox(height: 16),

                    // ── Health tip ─────────────────────────────────────────
                    NeuCard(
                      color: AppColors.sageSoft,
                      padding: const EdgeInsets.all(14),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('💡', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(activeInfo.tip,
                            style: T.body(context).copyWith(fontSize: 13, color: AppColors.sageDark))),
                      ]),
                    ),
                    const SizedBox(height: 24),

                    // ── How to complete ────────────────────────────────────
                    Text('How to complete', style: T.title(context)),
                    const SizedBox(height: 12),
                    NeuCard(
                      child: Column(children: [
                        _HowTo(icon: _typeIcon(activeInfo.type), text: activeInfo.howTo),
                        const SizedBox(height: 10),
                        _HowTo(icon: Symbols.stars_rounded, text: 'Earn +$xpReward XP on completion'),
                        const SizedBox(height: 10),
                        _HowTo(icon: Symbols.emoji_events_rounded,
                            text: 'Progress is tracked automatically as you log your daily activities'),
                      ]),
                    ),
                    const SizedBox(height: 28),

                    // ── All 12 weeks list ──────────────────────────────────
                    Text('All challenges', style: T.title(context)),
                    const SizedBox(height: 4),
                    Text('12-week weight-loss programme', style: T.small(context)),
                    const SizedBox(height: 14),
                    for (int i = 0; i < _challenges.length; i++)
                      _buildChallengeRow(context, i),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildChallengeRow(BuildContext context, int i) {
    final info = _challenges[i];
    // Find matching API challenge
    final apiC = _allChallenges.cast<Map<String, dynamic>?>().firstWhere(
      (c) => _safeInt(c!['week_number']) == info.week,
      orElse: () => null,
    );
    final entry = apiC != null ? _entryFor(apiC) : null;
    final isActive = info.week == _currentWeek;
    final isLocked = info.week > _currentWeek;
    final isCompleted = entry?['completed'] == true || info.week < _currentWeek && entry != null && entry['completed'] == true;
    final entryProgress = _safeInt(entry?['progress']);
    final entryTarget = apiC != null ? _safeInt(apiC['target'], info.target) : info.target;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _showChallengeDetail(context, info, apiC, entry, isActive, isLocked, isCompleted, entryProgress, entryTarget),
        child: _ChallengeRow(
          info: info,
          currentWeek: _currentWeek,
          isCompleted: isCompleted,
          progress: entryProgress,
          target: entryTarget,
        ),
      ),
    );
  }

  void _showChallengeDetail(
    BuildContext context,
    _ChallengeInfo info,
    Map<String, dynamic>? apiC,
    Map<String, dynamic>? entry,
    bool isActive,
    bool isLocked,
    bool isCompleted,
    int progress,
    int target,
  ) {
    final xp = apiC != null ? _safeInt(apiC['xp_reward'], info.xp) : info.xp;
    final description = apiC?['description'] as String? ?? info.description;
    final pct = target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // Handle
              Center(child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.inkSoft.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),

              // Header
              Row(children: [
                Text(info.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Week ${info.week} · ${info.title}',
                      style: T.h2(context).copyWith(fontSize: 18)),
                  const SizedBox(height: 2),
                  Row(children: [
                    NeuPill(
                      color: isCompleted ? AppColors.sage : isActive ? AppColors.coral : AppColors.inkSoft,
                      child: Text(
                        isCompleted ? 'Completed ✓' : isActive ? 'Active now' : 'Locked 🔒',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    NeuPill(
                      color: AppColors.goldSoft,
                      child: Text('+$xp XP',
                          style: const TextStyle(color: AppColors.goldDark, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ])),
                IconButton(
                  icon: const Icon(Symbols.close_rounded, size: 22),
                  color: AppColors.inkSoft,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ]),
              const SizedBox(height: 16),

              // Description
              NeuCard(
                color: isCompleted ? AppColors.sageSoft : isLocked ? AppColors.surface : AppColors.coralSoft,
                child: Text(description, style: T.body(context)),
              ),
              const SizedBox(height: 16),

              // Progress bar (active or completed)
              if (!isLocked) ...[
                NeuCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('Progress', style: T.title(context)),
                      const Spacer(),
                      Text(isCompleted ? 'Done! 🎉' : '$progress / $target',
                          style: T.title(context).copyWith(
                              color: isCompleted ? AppColors.sage : AppColors.coral)),
                    ]),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: isCompleted ? 1.0 : pct,
                        minHeight: 10,
                        backgroundColor: AppColors.bg,
                        valueColor: AlwaysStoppedAnimation(
                            isCompleted ? AppColors.sage : AppColors.coral),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isCompleted
                          ? 'Challenge complete! You earned +$xp XP 🏅'
                          : '${((isCompleted ? 1.0 : pct) * 100).toInt()}% complete — keep going!',
                      style: T.small(context).copyWith(
                          color: isCompleted ? AppColors.sageDark : AppColors.inkSoft),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // Lock info for future weeks
              if (isLocked) ...[
                NeuCard(
                  child: Row(children: [
                    const Icon(Symbols.lock_clock_rounded, color: AppColors.inkSoft, size: 24),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      'Unlocks in ${info.week - _currentWeek} week${info.week - _currentWeek > 1 ? 's' : ''}. Complete earlier weeks to progress.',
                      style: T.body(context).copyWith(color: AppColors.inkSoft),
                    )),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // How to complete
              Text('How to complete', style: T.title(context)),
              const SizedBox(height: 10),
              NeuCard(
                child: Column(children: [
                  _HowTo(icon: _typeIcon(info.type), text: info.howTo),
                  const SizedBox(height: 10),
                  _HowTo(icon: Symbols.stars_rounded, text: 'Earn +$xp XP on completion'),
                ]),
              ),
              const SizedBox(height: 16),

              // Science tip
              NeuCard(
                color: AppColors.sageSoft,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('💡', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(info.tip,
                      style: T.body(context).copyWith(fontSize: 13, color: AppColors.sageDark))),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Row(children: [
      NeuIconButton(icon: Symbols.arrow_back_rounded, onTap: () => context.pop()),
      const SizedBox(width: 12),
      Text('Weekly Challenge 🏅', style: T.h2(context).copyWith(fontSize: 18)),
      const Spacer(),
      NeuIconButton(icon: Symbols.refresh_rounded, onTap: _load),
    ]);
  }

  IconData _typeIcon(String type) => switch (type) {
    'steps'   => Symbols.directions_walk_rounded,
    'sleep'   => Symbols.bedtime_rounded,
    'meals'   => Symbols.restaurant_rounded,
    'fasting' => Symbols.timer_rounded,
    'water'   => Symbols.water_drop_rounded,
    _         => Symbols.task_alt_rounded,
  };
}

// ── Active challenge card ─────────────────────────────────────────────────────

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
    required this.info,
    required this.apiChallenge,
    required this.completed,
    required this.progress,
    required this.target,
    required this.xpReward,
    required this.pct,
    required this.currentWeek,
  });
  final _ChallengeInfo info;
  final Map<String, dynamic>? apiChallenge;
  final bool completed;
  final int progress, target, xpReward, currentWeek;
  final double pct;

  @override
  Widget build(BuildContext context) {
    final title       = apiChallenge?['title'] as String? ?? info.title;
    final description = apiChallenge?['description'] as String? ?? info.description;

    String progressLabel;
    if (info.type == 'steps' && target > 30) {
      // Show raw number (e.g. "4,200 / 10,000 steps")
      progressLabel = '${_fmt(progress)} / ${_fmt(target)} steps';
    } else {
      progressLabel = '$progress / $target';
    }

    return NeuCard(
      color: completed ? AppColors.sageSoft : AppColors.coralSoft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          NeuPill(
            color: completed ? AppColors.sage : AppColors.coral,
            child: Text('Week $currentWeek',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Text(info.emoji, style: const TextStyle(fontSize: 18)),
          const Spacer(),
          NeuPill(
            color: AppColors.goldSoft,
            child: Text('+$xpReward XP',
                style: const TextStyle(color: AppColors.goldDark, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 14),
        Text(title, style: T.h2(context)),
        const SizedBox(height: 8),
        Text(description, style: T.body(context)),
        const SizedBox(height: 18),
        if (completed) ...[
          Row(children: [
            const Icon(Symbols.check_circle_rounded, color: AppColors.sage, fill: 1),
            const SizedBox(width: 8),
            Text('Challenge completed! 🎉',
                style: T.title(context).copyWith(color: AppColors.sageDark)),
          ]),
        ] else ...[
          Row(children: [
            Text(progressLabel, style: T.title(context)),
            const Spacer(),
            Text('${(pct * 100).toInt()}%', style: T.small(context)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation(AppColors.coral),
            ),
          ),
        ],
      ]),
    );
  }

  static String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    return '$n';
  }
}

// ── Challenge row (full list) ─────────────────────────────────────────────────

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({
    required this.info,
    required this.currentWeek,
    required this.isCompleted,
    this.progress = 0,
    this.target = 1,
  });
  final _ChallengeInfo info;
  final int currentWeek;
  final bool isCompleted;
  final int progress, target;

  @override
  Widget build(BuildContext context) {
    final isActive = info.week == currentWeek;
    final isLocked = info.week > currentWeek;
    final pct = (target > 0 && !isCompleted && isActive)
        ? (progress / target).clamp(0.0, 1.0)
        : null;

    Color cardColor = AppColors.surface;
    if (isActive) cardColor = AppColors.coralSoft;
    if (isCompleted) cardColor = AppColors.sageSoft;

    return NeuCard(
      color: cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(children: [
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.sage : isActive ? AppColors.coral : AppColors.bg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: isCompleted
                ? const Icon(Symbols.check_rounded, color: Colors.white, size: 18, fill: 1)
                : isActive
                    ? const Icon(Symbols.play_arrow_rounded, color: Colors.white, size: 18, fill: 1)
                    : Text(info.emoji, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Week ${info.week} · ${info.title}',
                  style: T.title(context).copyWith(fontSize: 14)),
              Text(
                isCompleted
                    ? 'Completed · +${info.xp} XP earned'
                    : isActive
                        ? 'Active now · +${info.xp} XP'
                        : isLocked
                            ? 'Unlocks in ${info.week - currentWeek} week${info.week - currentWeek > 1 ? 's' : ''}'
                            : '+${info.xp} XP',
                style: T.small(context).copyWith(
                  fontSize: 12,
                  color: isCompleted ? AppColors.sageDark : isActive ? AppColors.coral : AppColors.inkSoft,
                ),
              ),
            ]),
          ),
          if (isLocked)
            const Icon(Symbols.lock_rounded, color: AppColors.inkSoft, size: 18, fill: 1)
          else
            const Icon(Symbols.chevron_right_rounded, color: AppColors.inkSoft, size: 20),
        ]),
        // Inline progress bar for active week
        if (pct != null && pct > 0) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation(AppColors.coral),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── How-to row ────────────────────────────────────────────────────────────────

class _HowTo extends StatelessWidget {
  const _HowTo({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: AppColors.coral, size: 20),
    const SizedBox(width: 10),
    Expanded(child: Text(text, style: T.body(context).copyWith(fontSize: 14))),
  ]);
}
