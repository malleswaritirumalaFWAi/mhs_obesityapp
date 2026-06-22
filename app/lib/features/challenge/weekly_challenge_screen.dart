import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../models/admin_content_model.dart';
import '../../services/admin_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_misc.dart';

// ─── Phase constants ──────────────────────────────────────────────────────────

class _Phase {
  const _Phase({
    required this.number,
    required this.name,
    required this.grad,
    required this.color,
    required this.soft,
    required this.textColor,
    required this.weeks,
  });
  final int number;
  final String name;
  final LinearGradient grad;
  final Color color;
  final Color soft;
  final Color textColor;
  final List<int> weeks;
}

const _kPhases = [
  _Phase(
    number: 1, name: 'Awareness',
    grad: LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFFB800)]),
    color: Color(0xFFFF6B35), soft: Color(0xFFFFEDE6), textColor: Color(0xFFB84000),
    weeks: [1, 2, 3],
  ),
  _Phase(
    number: 2, name: 'Habit Building',
    grad: LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)]),
    color: Color(0xFF11998E), soft: Color(0xFFDDEFE4), textColor: Color(0xFF0A5C55),
    weeks: [4, 5, 6],
  ),
  _Phase(
    number: 3, name: 'Pushing Limits',
    grad: LinearGradient(colors: [Color(0xFF1B4F72), Color(0xFF2575FC)]),
    color: Color(0xFF1B4F72), soft: Color(0xFFE3F2FD), textColor: Color(0xFF0D2E44),
    weeks: [7, 8, 9],
  ),
  _Phase(
    number: 4, name: 'Identity Shift',
    grad: LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF9B59B6)]),
    color: Color(0xFF6A11CB), soft: Color(0xFFEFE3F7), textColor: Color(0xFF3D0A7A),
    weeks: [10, 11, 12],
  ),
];

_Phase _phaseOf(int week) => _kPhases[(week - 1) ~/ 3];

// ─── Week metadata ────────────────────────────────────────────────────────────

class _WeekMeta {
  const _WeekMeta({
    required this.week,
    required this.title,
    required this.scienceFact,
    required this.howTo,
    required this.whyItWorks,
    required this.type,
    required this.target,
    required this.minValue,
    required this.xp,
  });
  final int week;
  final String title;
  final String scienceFact;
  final List<String> howTo;
  final String whyItWorks;
  final String type;
  final int target;
  final int minValue;
  final int xp;

  String get difficulty => week <= 3
      ? 'Beginner'
      : week <= 6
          ? 'Intermediate'
          : week <= 9
              ? 'Advanced'
              : 'Elite';

  Color get difficultyColor => week <= 3
      ? const Color(0xFF38A169)
      : week <= 6
          ? const Color(0xFFD69E2E)
          : week <= 9
              ? const Color(0xFF3182CE)
              : const Color(0xFF805AD5);
}

const _kWeeks = [
  // Phase 1 — Awareness
  _WeekMeta(
    week: 1, type: 'weight_and_meals', target: 7, minValue: 0, xp: 50,
    title: 'Know Your Baseline',
    scienceFact: 'People who track food and weight lose 2× more than those who don\'t.',
    howTo: [
      'Log your weight every morning from the Scale task',
      'Log every meal — Breakfast, Lunch, and Dinner',
      'Do this consistently for 7 days to complete',
    ],
    whyItWorks: 'Awareness is the first step to change. Seeing exactly what you eat and weigh daily rewires your brain to make better automatic choices.',
  ),
  _WeekMeta(
    week: 2, type: 'steps_min_days', target: 4, minValue: 5000, xp: 50,
    title: 'Find Your Move',
    scienceFact: 'Just 5,000 steps/day reduces cardiovascular disease risk by 21%.',
    howTo: [
      'Hit 5,000+ steps on any 4 days this week',
      'Log your steps in the Movement screen each day',
      'Any movement counts — walking, stairs, errands',
    ],
    whyItWorks: 'Starting below 10K makes it achievable. One consistent week at 5K is worth more than one great day and six sedentary ones.',
  ),
  _WeekMeta(
    week: 3, type: 'sleep_days', target: 5, minValue: 0, xp: 50,
    title: 'Sleep Foundation',
    scienceFact: 'Sleeping under 6 hours makes you 55% more likely to be obese.',
    howTo: [
      'Get 7+ hours of sleep on 5 nights this week',
      'Log your sleep hours in the Home screen each morning',
      'Set a consistent bedtime — same time every night',
    ],
    whyItWorks: 'Poor sleep raises ghrelin (hunger hormone) 24% and cuts fat-burning during sleep. Good sleep is automatic calorie control.',
  ),
  // Phase 2 — Habit Building
  _WeekMeta(
    week: 4, type: 'morning_checkin', target: 7, minValue: 0, xp: 60,
    title: 'Morning Anchor',
    scienceFact: 'Morning self-monitoring doubles weight loss outcomes in clinical trials.',
    howTo: [
      'Complete Morning Check-in every single day for 7 days',
      'Tap the Morning Check-in task in Today\'s Plan',
      'Log your mood and energy — takes just 30 seconds',
    ],
    whyItWorks: 'Starting the day with intentional self-reflection creates an anchor that carries through food and movement choices all day long.',
  ),
  _WeekMeta(
    week: 5, type: 'steps_and_meals', target: 5, minValue: 5000, xp: 60,
    title: 'Move After Meals',
    scienceFact: 'A 10-minute post-meal walk reduces blood sugar spikes by 30%.',
    howTo: [
      'Hit 5,000+ steps AND log all 3 meals on 5 days',
      'Log Breakfast, Lunch, and Dinner in the Meal Log',
      'A short post-meal walk gets you to the step goal easily',
    ],
    whyItWorks: 'Combining movement with meal logging rewires the neural circuits linking eating with activity — the foundation of long-term weight maintenance.',
  ),
  _WeekMeta(
    week: 6, type: 'weight_daily', target: 7, minValue: 0, xp: 80,
    title: 'Halfway Audit',
    scienceFact: 'Daily weigh-ins lead to 82% more weight loss than weekly weigh-ins.',
    howTo: [
      'Log your weight every single day for 7 days',
      'Weigh yourself first thing in the morning',
      'Use the Evening Weigh-In task in Today\'s Plan',
    ],
    whyItWorks: 'Week 6 is the inflection point. Seeing your trend from Week 1 creates powerful motivation to finish the remaining 6 weeks strong.',
  ),
  // Phase 3 — Pushing Limits
  _WeekMeta(
    week: 7, type: 'steps_min_days', target: 5, minValue: 8000, xp: 70,
    title: 'Step It Up',
    scienceFact: '8,000 steps/day reduces all-cause mortality risk by 51%.',
    howTo: [
      'Hit 8,000+ steps on 5 days this week',
      'That\'s about a 60-minute brisk walk per day',
      'Log steps in the Movement screen each evening',
    ],
    whyItWorks: '8K is the evidence-based sweet spot where fat oxidation maximizes without requiring gym equipment or structured exercise.',
  ),
  _WeekMeta(
    week: 8, type: 'meal_all_days', target: 5, minValue: 0, xp: 70,
    title: 'Eat With Intent',
    scienceFact: 'Consistent meal patterns reduce total daily calorie intake by up to 18%.',
    howTo: [
      'Log all 3 meals — Breakfast, Lunch, Dinner — on 5 days',
      'No skipping allowed — every meal matters',
      'Use meal photos for better logging accountability',
    ],
    whyItWorks: 'People who eat regular structured meals are 50% less likely to overeat at night. Pattern creates predictability and control.',
  ),
  _WeekMeta(
    week: 9, type: 'all_tasks', target: 4, minValue: 0, xp: 80,
    title: 'Full System Week',
    scienceFact: 'Completing all healthy habits in one day creates a compound effect beyond each individual habit.',
    howTo: [
      'Complete ALL 5 daily tasks on 4 days this week',
      'Check-in, meals, hydration, movement, and weigh-in',
      'Track your daily completion in Today\'s Plan',
    ],
    whyItWorks: 'Full-system days create "behavioral coherence" — body and mind align, making weight loss feel effortless rather than forced.',
  ),
  // Phase 4 — Identity Shift
  _WeekMeta(
    week: 10, type: 'steps_min_days', target: 5, minValue: 10000, xp: 90,
    title: '10K Club',
    scienceFact: '10,000 steps burns ~400 extra calories and dramatically improves insulin sensitivity.',
    howTo: [
      'Hit 10,000+ steps on 5 days this week',
      'Split it: morning + evening walk if needed',
      'Track steps in the Movement screen',
    ],
    whyItWorks: 'At 10K you\'re no longer exercising to lose weight — you\'ve become someone who moves daily. That identity shift is permanent.',
  ),
  _WeekMeta(
    week: 11, type: 'all_tasks', target: 7, minValue: 0, xp: 100,
    title: 'Unbreakable Streak',
    scienceFact: 'After 66 consecutive days, behaviors become automatic habits requiring zero willpower.',
    howTo: [
      'Complete ALL 5 daily tasks every single day for 7 days',
      'No rest days — consistency is the challenge',
      'Check Today\'s Plan each morning to stay on track',
    ],
    whyItWorks: 'One perfect week this close to the finish cements the neural pathways permanently. This is how habits become identity.',
  ),
  _WeekMeta(
    week: 12, type: 'transformation_proof', target: 7, minValue: 0, xp: 150,
    title: 'Transformation Proof',
    scienceFact: 'Completing a structured 12-week program reduces obesity-related health risks by up to 30%.',
    howTo: [
      'Log your weight every day for the final 7 days',
      'Complete your morning check-in every day',
      'Complete your evening weigh-in every day',
    ],
    whyItWorks: 'You started 12 weeks ago not knowing if you could do this. This final week is proof that you are someone who follows through.',
  ),
];

_WeekMeta _metaOf(int week) => _kWeeks[week - 1];

// ─── Main Screen ──────────────────────────────────────────────────────────────

class WeeklyChallengeScreen extends ConsumerStatefulWidget {
  const WeeklyChallengeScreen({super.key});
  @override
  ConsumerState<WeeklyChallengeScreen> createState() => _WeeklyChallengeScreenState();
}

class _WeeklyChallengeScreenState extends ConsumerState<WeeklyChallengeScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  int _selectedPhase = 0;
  Map<String, bool> _adminUnlocks = {};

  late final AnimationController _shimmer;
  late final Animation<double> _shimmerAnim;
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _shimmerAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _shimmer, curve: Curves.easeInOut));

    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    _load();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _pulse.dispose();
    super.dispose();
  }

  bool _isAdminUnlocked(int week) =>
      _adminUnlocks['unlock_challenge_week$week'] == true;

  Future<void> _load() async {
    setState(() => _loading = true);
    // Load admin unlock overrides (runs regardless of API success)
    final adminKeys = kChallengeWeeks.map((w) => w.unlockKey).toList();
    _adminUnlocks = await AdminService.loadGlobalUnlockStates(adminKeys);
    try {
      final d = await ref.read(apiClientProvider).getJson('/challenge/current');
      if (!mounted) return;
      final currentWeek = _safeInt(d['current_week'], 1);
      setState(() {
        _data = Map<String, dynamic>.from(d as Map);
        _loading = false;
        _selectedPhase = ((currentWeek - 1) ~/ 3).clamp(0, 3);
      });
      // Show milestone if just completed week 6 or 12
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkMilestone());
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _checkMilestone() {
    if (_data == null || !mounted) return;
    final currentWeek = _safeInt(_data!['current_week'], 1);
    final entry = _data!['entry'] as Map<String, dynamic>?;
    if (entry?['completed'] != true) return;
    if (currentWeek == 6) {
      _showMilestone6();
    } else if (currentWeek == 12) {
      _showMilestone12();
    }
  }

  static int _safeInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static double _safeDouble(dynamic v, [double fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  List<bool> get _dayProgress {
    final raw = _data?['day_progress'];
    if (raw == null) return List.filled(7, false);
    return (raw as List).map((e) => e == true).toList();
  }

  Map<int, Map<String, dynamic>> get _entriesMap {
    final raw = (_data?['all_entries'] as List?) ?? [];
    final allChallenges = (_data?['all_challenges'] as List?) ?? [];
    final map = <int, Map<String, dynamic>>{};
    for (final e in raw) {
      final em = Map<String, dynamic>.from(e as Map);
      final cId = _safeInt(em['challenge_id']);
      final ch = allChallenges.cast<Map<String, dynamic>?>().firstWhere(
          (c) => _safeInt(c!['id']) == cId, orElse: () => null);
      if (ch != null) {
        map[_safeInt(ch['week_number'])] = em;
      }
    }
    return map;
  }

  void _showDetailSheet(int week) {
    final currentWeek = _safeInt(_data?['current_week'], 1);
    final entry = _entriesMap[week];
    final isActive = week == currentWeek;
    final isLocked = week > currentWeek && !_isAdminUnlocked(week);
    final isCompleted = entry?['completed'] == true;
    final progress = _safeInt(entry?['progress']);
    final meta = _metaOf(week);
    final allChallenges = (_data?['all_challenges'] as List?) ?? [];
    final apiCh = allChallenges.cast<Map<String, dynamic>?>().firstWhere(
        (c) => _safeInt(c!['week_number']) == week, orElse: () => null);
    final xp = apiCh != null ? _safeInt(apiCh['xp_reward'], meta.xp) : meta.xp;
    final target = apiCh != null ? _safeInt(apiCh['target'], meta.target) : meta.target;
    final days = isActive ? _dayProgress : List.filled(7, isCompleted);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChallengeDetailSheet(
        meta: meta,
        xp: xp,
        target: target,
        progress: progress,
        isActive: isActive,
        isLocked: isLocked,
        isCompleted: isCompleted,
        dayProgress: days,
        weeksUntilUnlock: isLocked ? week - currentWeek : 0,
      ),
    );
  }

  void _showMilestone6() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => _Week6MilestoneDialog(
        startWeight: _safeDouble(_data?['start_weight']),
        currentWeight: _safeDouble(_data?['current_weight']),
        weightHistory: _weightHistory,
        onContinue: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _showMilestone12() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => _Week12MilestoneDialog(
        startWeight: _safeDouble(_data?['start_weight']),
        currentWeight: _safeDouble(_data?['current_weight']),
        totalXp: _safeInt(_data?['total_xp']),
        totalSteps: _safeInt(_data?['total_steps']),
        longestStreak: _safeInt(_data?['longest_streak']),
        weightHistory: _weightHistory,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  List<FlSpot> get _weightHistory {
    final raw = (_data?['weight_history'] as List?) ?? [];
    return raw.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return FlSpot(
        _safeDouble(m['week_num']),
        _safeDouble(m['avg_weight']),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentWeek = _safeInt(_data?['current_week'], 1);
    final phase = _kPhases[_selectedPhase];
    final phaseWeeks = phase.weeks;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: CustomScrollView(
                  slivers: [
                    // App bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(children: [
                          NeuIconButton(
                            icon: Symbols.arrow_back_rounded,
                            onTap: () => context.pop(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('12-Week Challenge', style: T.title(context)),
                              Text('Weight loss transformation', style: T.small(context)),
                            ]),
                          ),
                          NeuIconButton(icon: Symbols.refresh_rounded, onTap: _load),
                        ]),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // Hero banner for active week
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AnimatedBuilder(
                          animation: _shimmerAnim,
                          builder: (context, _) => _HeroBanner(
                            currentWeek: currentWeek,
                            dayProgress: _dayProgress,
                            shimmerValue: _shimmerAnim.value,
                            pulseValue: _pulseAnim.value,
                            entry: _data?['entry'] as Map<String, dynamic>?,
                            allChallenges: (_data?['all_challenges'] as List?) ?? [],
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),

                    // Phase tab bar
                    SliverToBoxAdapter(
                      child: _PhaseTabBar(
                        selected: _selectedPhase,
                        currentWeek: currentWeek,
                        onSelect: (i) => setState(() => _selectedPhase = i),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // Phase label
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(children: [
                          Text('Phase ${phase.number}: ${phase.name}',
                              style: T.title(context).copyWith(fontSize: 16)),
                          const Spacer(),
                          Text('Weeks ${phaseWeeks.first}–${phaseWeeks.last}',
                              style: T.small(context)),
                        ]),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    // Week cards for selected phase
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final week = phaseWeeks[index];
                          final entry = _entriesMap[week];
                          final isActive = week == currentWeek;
                          final isLocked = week > currentWeek && !_isAdminUnlocked(week);
                          final isCompleted = entry?['completed'] == true;
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: GestureDetector(
                              onTap: () => _showDetailSheet(week),
                              child: AnimatedBuilder(
                                animation: _pulseAnim,
                                builder: (context, _) => _WeekCard(
                                  week: week,
                                  isActive: isActive,
                                  isLocked: isLocked,
                                  isCompleted: isCompleted,
                                  progress: _safeInt(entry?['progress']),
                                  dayProgress: isActive ? _dayProgress : null,
                                  shimmerValue: isActive ? _shimmerAnim.value : 0,
                                  pulseValue: isActive ? _pulseAnim.value : 0,
                                  completedAt: entry?['completed_at'] as String?,
                                  currentWeek: currentWeek,
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: phaseWeeks.length,
                      ),
                    ),

                    // Mini 12-week timeline
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _MiniTimeline(
                          currentWeek: currentWeek,
                          entriesMap: _entriesMap,
                          adminUnlocks: _adminUnlocks,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─── Hero Banner ──────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.currentWeek,
    required this.dayProgress,
    required this.shimmerValue,
    required this.pulseValue,
    required this.entry,
    required this.allChallenges,
  });
  final int currentWeek;
  final List<bool> dayProgress;
  final double shimmerValue;
  final double pulseValue;
  final Map<String, dynamic>? entry;
  final List<dynamic> allChallenges;

  @override
  Widget build(BuildContext context) {
    final meta = _metaOf(currentWeek);
    final phase = _phaseOf(currentWeek);
    final isCompleted = entry?['completed'] == true;
    final apiCh = allChallenges.cast<Map<String, dynamic>?>().firstWhere(
        (c) => (c!['week_number'] as num?)?.toInt() == currentWeek, orElse: () => null);
    final target = apiCh != null ? (apiCh['target'] as num?)?.toInt() ?? meta.target : meta.target;
    final xp = apiCh != null ? (apiCh['xp_reward'] as num?)?.toInt() ?? meta.xp : meta.xp;

    final daysCompleted = dayProgress.where((d) => d).length;
    final daysRemaining = (target - daysCompleted).clamp(0, 7);

    // Shimmer gradient — subtle brightness sweep
    final gradColors = [
      phase.grad.colors[0],
      Color.lerp(phase.grad.colors[0], Colors.white, 0.25 * shimmerValue)!,
      phase.grad.colors[1],
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradColors,
            stops: const [0, 0.5, 1],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: phase.color.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top white shine
            Positioned(
              top: 0, left: 0, right: 0,
              height: 60,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withOpacity(0.18), Colors.transparent],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Phase + XP row
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Phase ${phase.number}: ${phase.name}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700,
                            letterSpacing: 0.5)),
                  ),
                  const Spacer(),
                  // XP chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB800),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: const Color(0xFFFFB800).withOpacity(0.5),
                          blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('⭐', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text('+$xp XP',
                          style: const TextStyle(
                              color: Color(0xFF5C3A00), fontSize: 12, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),

                // Week + Title
                Text('Week $currentWeek', style: TextStyle(
                    color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(meta.title, style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
                const SizedBox(height: 16),

                // Day dots
                Row(children: [
                  for (int i = 0; i < 7; i++) ...[
                    _DayDot(
                      dayNum: i + 1,
                      filled: i < dayProgress.length ? dayProgress[i] : false,
                      phaseColor: phase.color,
                    ),
                    if (i < 6) const SizedBox(width: 6),
                  ],
                ]),
                const SizedBox(height: 14),

                // Progress bar
                if (!isCompleted) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: target > 0 ? (daysCompleted / target).clamp(0.0, 1.0) : 0,
                      minHeight: 6,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Text('$daysCompleted / $target days complete',
                        style: TextStyle(color: Colors.white.withOpacity(0.9),
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (daysRemaining > 0)
                      Text('$daysRemaining days left',
                          style: TextStyle(color: Colors.white.withOpacity(0.75),
                              fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                ] else
                  Row(children: [
                    const Text('✅ ', style: TextStyle(fontSize: 16)),
                    Text('Challenge Complete!',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('+$xp XP earned 🏅',
                        style: TextStyle(color: Colors.white.withOpacity(0.85),
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),

                const SizedBox(height: 14),
                // Science fact
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('💡', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(meta.scienceFact,
                        style: TextStyle(color: Colors.white.withOpacity(0.9),
                            fontSize: 12, fontWeight: FontWeight.w500, height: 1.4))),
                  ]),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Day Dot ──────────────────────────────────────────────────────────────────

class _DayDot extends StatelessWidget {
  const _DayDot({required this.dayNum, required this.filled, required this.phaseColor});
  final int dayNum;
  final bool filled;
  final Color phaseColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      width: filled ? 32 : 28,
      height: filled ? 32 : 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? Colors.white : Colors.white.withOpacity(0.2),
        border: Border.all(
          color: filled ? Colors.white : Colors.white.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: filled
            ? [BoxShadow(color: Colors.white.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)]
            : null,
      ),
      child: Center(
        child: filled
            ? Icon(Symbols.check_rounded, size: 14, color: phaseColor,
                weight: 700, fill: 1)
            : Text('$dayNum',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 10, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ─── Phase Tab Bar ────────────────────────────────────────────────────────────

class _PhaseTabBar extends StatelessWidget {
  const _PhaseTabBar({
    required this.selected,
    required this.currentWeek,
    required this.onSelect,
  });
  final int selected;
  final int currentWeek;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        itemBuilder: (context, i) {
          final phase = _kPhases[i];
          final isSelected = i == selected;
          final isActive = currentWeek >= phase.weeks.first && currentWeek <= phase.weeks.last;

          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: isSelected ? phase.grad : null,
                color: isSelected ? null : AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                boxShadow: isSelected
                    ? [BoxShadow(color: phase.color.withOpacity(0.35),
                        blurRadius: 12, offset: const Offset(0, 4))]
                    : [BoxShadow(color: AppColors.shadowDark, blurRadius: 6,
                        offset: const Offset(2, 2)),
                       const BoxShadow(color: AppColors.shadowLight, blurRadius: 6,
                           offset: Offset(-2, -2))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (isActive)
                  Container(
                    width: 6, height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? Colors.white : phase.color,
                    ),
                  ),
                Text('P${phase.number}: ${phase.name}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.inkMid,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ─── Week Card ────────────────────────────────────────────────────────────────

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.week,
    required this.isActive,
    required this.isLocked,
    required this.isCompleted,
    required this.progress,
    required this.currentWeek,
    this.dayProgress,
    this.shimmerValue = 0,
    this.pulseValue = 0,
    this.completedAt,
  });
  final int week;
  final bool isActive, isLocked, isCompleted;
  final int progress;
  final int currentWeek;
  final List<bool>? dayProgress;
  final double shimmerValue;
  final double pulseValue;
  final String? completedAt;

  @override
  Widget build(BuildContext context) {
    final meta = _metaOf(week);
    final phase = _phaseOf(week);
    final daysCompleted = dayProgress?.where((d) => d).length ?? 0;

    if (isCompleted) return _buildCompleted(context, meta, phase);
    if (isActive) return _buildActive(context, meta, phase, daysCompleted);
    if (isLocked) return _buildLocked(context, meta, phase);
    return _buildCompleted(context, meta, phase); // past but entry missing — treat as done
  }

  Widget _buildCompleted(BuildContext context, _WeekMeta meta, _Phase phase) {
    String dateStr = '';
    if (completedAt != null) {
      try {
        final dt = DateTime.parse(completedAt!).toLocal();
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: phase.color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.shadowDark, blurRadius: 8, offset: const Offset(3, 3)),
          const BoxShadow(color: AppColors.shadowLight, blurRadius: 8, offset: Offset(-3, -3)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: phase.grad,
            shape: BoxShape.circle,
          ),
          child: const Icon(Symbols.check_rounded, color: Colors.white, size: 22, fill: 1, weight: 700),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Week $week', style: T.small(context).copyWith(
                color: phase.color, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: phase.soft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(meta.difficulty, style: TextStyle(
                  color: phase.textColor, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 3),
          Text(meta.title, style: T.title(context).copyWith(fontSize: 14)),
          if (dateStr.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Completed $dateStr · +${meta.xp} XP',
                style: T.small(context).copyWith(fontSize: 11, color: phase.color)),
          ],
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3DC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('+${meta.xp} XP',
              style: const TextStyle(color: Color(0xFFA36F1A),
                  fontSize: 11, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Widget _buildActive(BuildContext context, _WeekMeta meta, _Phase phase, int daysCompleted) {
    // Shimmer color sweep on gradient
    final c0 = Color.lerp(phase.grad.colors[0], Colors.white, 0.2 * shimmerValue)!;
    final c1 = Color.lerp(phase.grad.colors[1], Colors.white, 0.1 * shimmerValue)!;

    // Pulse border opacity
    final borderOpacity = 0.5 + 0.5 * pulseValue;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: phase.color.withOpacity(0.25 + 0.15 * pulseValue),
            blurRadius: 16 + 8 * pulseValue,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c0, c1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(borderOpacity),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(children: [
            // Shine
            Positioned(
              top: 0, left: 0, right: 0, height: 40,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.white.withOpacity(0.2), Colors.transparent],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('ACTIVE NOW',
                        style: TextStyle(color: Colors.white, fontSize: 10,
                            fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB800),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('+${meta.xp} XP',
                        style: const TextStyle(color: Color(0xFF5C3A00),
                            fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Text('Week $week', style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 12,
                      fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(meta.difficulty, style: const TextStyle(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(meta.title, style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                // Day dots mini
                if (dayProgress != null)
                  Row(children: [
                    for (int i = 0; i < 7; i++) ...[
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (i < dayProgress!.length && dayProgress![i])
                              ? Colors.white
                              : Colors.white.withOpacity(0.2),
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                        ),
                        child: Center(
                          child: (i < dayProgress!.length && dayProgress![i])
                              ? Icon(Symbols.check_rounded, size: 12,
                                  color: phase.color, weight: 700, fill: 1)
                              : Text('${i + 1}', style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      if (i < 6) const SizedBox(width: 4),
                    ],
                  ]),
                const SizedBox(height: 10),
                Row(children: [
                  Text('$daysCompleted / ${meta.target} days',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('View Details',
                        style: TextStyle(
                            color: phase.color, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildLocked(BuildContext context, _WeekMeta meta, _Phase phase) {
    final weeksUntil = week - currentWeek;
    return Opacity(
      opacity: 0.55,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: AppColors.shadowDark, blurRadius: 6, offset: const Offset(2, 2)),
            const BoxShadow(color: AppColors.shadowLight, blurRadius: 6, offset: Offset(-2, -2)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.bg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(Symbols.lock_rounded, color: AppColors.inkSoft, size: 20, fill: 1),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Week $week', style: T.small(context)),
            Text(meta.title, style: T.title(context).copyWith(fontSize: 14, color: AppColors.inkMid)),
            Text(
              weeksUntil == 1 ? 'Unlocks next week' : 'Unlocks in $weeksUntil weeks',
              style: T.small(context).copyWith(fontSize: 11),
            ),
          ])),
          Text('+${meta.xp} XP',
              style: T.small(context).copyWith(
                  fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
          const SizedBox(width: 4),
          Icon(Symbols.chevron_right_rounded, color: AppColors.inkSoft, size: 18),
        ]),
      ),
    );
  }
}

// ─── Mini Timeline ────────────────────────────────────────────────────────────

class _MiniTimeline extends StatelessWidget {
  const _MiniTimeline({
    required this.currentWeek,
    required this.entriesMap,
    this.adminUnlocks = const {},
  });
  final int currentWeek;
  final Map<int, Map<String, dynamic>> entriesMap;
  final Map<String, bool> adminUnlocks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.shadowDark, blurRadius: 8, offset: const Offset(3, 3)),
          const BoxShadow(color: AppColors.shadowLight, blurRadius: 8, offset: Offset(-3, -3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your 12-Week Journey', style: T.title(context).copyWith(fontSize: 14)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(12, (i) {
            final week = i + 1;
            final phase = _phaseOf(week);
            final isActive = week == currentWeek;
            final isCompleted = entriesMap[week]?['completed'] == true;
            final isLocked = week > currentWeek &&
                !(adminUnlocks['unlock_challenge_week$week'] == true);

            return Expanded(
              child: Column(children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isCompleted
                        ? phase.grad
                        : isActive
                            ? phase.grad
                            : null,
                    color: isLocked ? AppColors.bg : null,
                    border: isActive
                        ? Border.all(color: phase.color, width: 2)
                        : isLocked
                            ? Border.all(color: AppColors.line, width: 1.5)
                            : null,
                    boxShadow: isActive
                        ? [BoxShadow(color: phase.color.withOpacity(0.4),
                            blurRadius: 8, spreadRadius: 1)]
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Symbols.check_rounded, size: 11, color: Colors.white,
                            fill: 1, weight: 700)
                        : Text('$week',
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : isLocked
                                      ? AppColors.inkSoft
                                      : Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            )),
                  ),
                ),
                const SizedBox(height: 3),
                Text('W$week', style: TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w600,
                    color: isActive ? phase.color : AppColors.inkSoft)),
              ]),
            );
          }),
        ),
        const SizedBox(height: 10),
        // Phase legend
        Row(children: _kPhases.map((p) => Expanded(
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(
                gradient: p.grad, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Flexible(child: Text('P${p.number}', style: TextStyle(
                fontSize: 9, color: p.color, fontWeight: FontWeight.w700))),
          ]),
        )).toList()),
      ]),
    );
  }
}

// ─── Challenge Detail Sheet ───────────────────────────────────────────────────

class _ChallengeDetailSheet extends StatelessWidget {
  const _ChallengeDetailSheet({
    required this.meta,
    required this.xp,
    required this.target,
    required this.progress,
    required this.isActive,
    required this.isLocked,
    required this.isCompleted,
    required this.dayProgress,
    required this.weeksUntilUnlock,
  });
  final _WeekMeta meta;
  final int xp, target, progress, weeksUntilUnlock;
  final bool isActive, isLocked, isCompleted;
  final List<bool> dayProgress;

  @override
  Widget build(BuildContext context) {
    final phase = _phaseOf(meta.week);
    final pct = target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          children: [
            // Handle
            Center(child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.inkSoft.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2)),
            )),

            // Header gradient strip
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(gradient: phase.grad),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Phase ${phase.number} · Week ${meta.week}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    const Spacer(),
                    // Status pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isCompleted ? '✅ Done' : isActive ? '⚡ Active' : '🔒 Locked',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(meta.title, style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
                  const SizedBox(height: 10),
                  Row(children: [
                    // XP badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB800),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text('⭐ +$xp XP',
                          style: const TextStyle(color: Color(0xFF5C3A00),
                              fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    // Difficulty badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(meta.difficulty,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Progress (active or completed)
            if (!isLocked) ...[
              Text('Day Tracker', style: T.title(context).copyWith(fontSize: 15)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: AppColors.shadowDark, blurRadius: 6, offset: const Offset(2, 2)),
                    const BoxShadow(color: AppColors.shadowLight, blurRadius: 6, offset: Offset(-2, -2)),
                  ],
                ),
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (i) {
                      final filled = i < dayProgress.length ? dayProgress[i] : false;
                      final isFuture = isActive && !filled && i >= progress;
                      return Column(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? phase.color
                                : isFuture
                                    ? AppColors.bg
                                    : AppColors.bg,
                            border: Border.all(
                              color: filled ? phase.color : AppColors.line,
                              width: filled ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: filled
                                ? const Icon(Symbols.check_rounded, size: 16,
                                    color: Colors.white, fill: 1, weight: 700)
                                : isCompleted
                                    ? const Icon(Symbols.check_rounded, size: 16,
                                        color: Colors.white, fill: 1, weight: 700)
                                    : Text('${i + 1}', style: TextStyle(
                                        color: AppColors.inkSoft,
                                        fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                            style: TextStyle(
                              fontSize: 10,
                              color: filled ? phase.color : AppColors.inkSoft,
                              fontWeight: FontWeight.w700,
                            )),
                      ]);
                    }),
                  ),
                  if (!isCompleted) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: AppColors.bg,
                        valueColor: AlwaysStoppedAnimation(phase.color),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('$progress / $target days complete · ${(pct * 100).toInt()}%',
                        style: T.small(context).copyWith(color: phase.color,
                            fontWeight: FontWeight.w700)),
                  ],
                ]),
              ),
              const SizedBox(height: 20),
            ],

            // Locked info
            if (isLocked) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: AppColors.shadowDark, blurRadius: 6, offset: const Offset(2, 2)),
                    const BoxShadow(color: AppColors.shadowLight, blurRadius: 6, offset: Offset(-2, -2)),
                  ],
                ),
                child: Row(children: [
                  Icon(Symbols.lock_clock_rounded, color: AppColors.inkSoft, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    weeksUntilUnlock == 1
                        ? 'Unlocks next week! Complete the active challenge first.'
                        : 'Unlocks in $weeksUntilUnlock weeks. Keep completing your weekly challenges.',
                    style: T.body(context).copyWith(color: AppColors.inkSoft),
                  )),
                ]),
              ),
              const SizedBox(height: 20),
            ],

            // How to complete
            Text('How to Complete', style: T.title(context).copyWith(fontSize: 15)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: AppColors.shadowDark, blurRadius: 6, offset: const Offset(2, 2)),
                  const BoxShadow(color: AppColors.shadowLight, blurRadius: 6, offset: Offset(-2, -2)),
                ],
              ),
              child: Column(children: [
                for (int i = 0; i < meta.howTo.length; i++) ...[
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        gradient: phase.grad,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${i + 1}', style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(meta.howTo[i], style: T.body(context).copyWith(fontSize: 14))),
                  ]),
                  if (i < meta.howTo.length - 1) const SizedBox(height: 12),
                ],
              ]),
            ),
            const SizedBox(height: 20),

            // Why it works
            Text('Why It Works', style: T.title(context).copyWith(fontSize: 15)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: phase.soft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('🧠', style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(meta.whyItWorks, style: T.body(context).copyWith(
                      color: phase.textColor, fontSize: 13, height: 1.5)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Text('💡', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(meta.scienceFact, style: TextStyle(
                          color: phase.textColor, fontSize: 12,
                          fontWeight: FontWeight.w600, height: 1.4))),
                    ]),
                  ),
                ])),
              ]),
            ),
            const SizedBox(height: 24),

            // CTA button
            NeuButton(
              expand: true,
              gradient: isCompleted ? null : isLocked ? null : phase.grad,
              color: isCompleted
                  ? AppColors.sageSoft
                  : isLocked
                      ? AppColors.surface
                      : null,
              foreground: isCompleted ? AppColors.sageDark : isLocked ? AppColors.inkSoft : Colors.white,
              onPressed: isLocked ? null : () => Navigator.of(context).pop(),
              child: Text(
                isCompleted ? '✅ Challenge Completed!' : isActive ? '⚡ Keep Going!' : '🔒 Locked',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isCompleted ? AppColors.sageDark : isLocked ? AppColors.inkSoft : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Week 6 Milestone Dialog ──────────────────────────────────────────────────

class _Week6MilestoneDialog extends StatefulWidget {
  const _Week6MilestoneDialog({
    required this.startWeight,
    required this.currentWeight,
    required this.weightHistory,
    required this.onContinue,
  });
  final double startWeight;
  final double currentWeight;
  final List<FlSpot> weightHistory;
  final VoidCallback onContinue;

  @override
  State<_Week6MilestoneDialog> createState() => _Week6MilestoneDialogState();
}

class _Week6MilestoneDialogState extends State<_Week6MilestoneDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
    _anim.forward();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final lost = (widget.startWeight - widget.currentWeight);
    final lostStr = lost > 0 ? '−${lost.toStringAsFixed(1)} kg' : '${lost.abs().toStringAsFixed(1)} kg';

    return ScaleTransition(
      scale: _scale,
      child: Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF11998E), Color(0xFF38EF7D), Color(0xFF1B4F72)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Text('🎉', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                const Text('Halfway There!', style: TextStyle(
                    color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('You\'ve completed Phase 1 & 2', style: TextStyle(
                    color: Colors.white.withOpacity(0.85), fontSize: 14)),
                const SizedBox(height: 24),

                // Weight stats
                Row(children: [
                  Expanded(child: _StatCard(
                    label: 'Start Weight',
                    value: '${widget.startWeight.toStringAsFixed(1)} kg',
                    icon: '⚖️',
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(
                    label: 'Now',
                    value: '${widget.currentWeight.toStringAsFixed(1)} kg',
                    icon: '📉',
                  )),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    Text(lostStr, style: const TextStyle(
                        color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                    Text('lost in 6 weeks', style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 20),

                // Weight chart
                if (widget.weightHistory.isNotEmpty) ...[
                  Container(
                    height: 140,
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _WeightChart(spots: widget.weightHistory, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                ],

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'You\'ve built the habits that make lasting change possible. '
                    'The next 6 weeks will push you further — but you\'re ready. 💪',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.9),
                        fontSize: 13, height: 1.5),
                  ),
                ),
                const SizedBox(height: 20),

                GestureDetector(
                  onTap: widget.onContinue,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2),
                            blurRadius: 12, offset: const Offset(0, 4))
                      ],
                    ),
                    child: const Text('Continue to Phase 3 →',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF11998E),
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Week 12 Milestone Dialog ─────────────────────────────────────────────────

class _Week12MilestoneDialog extends StatefulWidget {
  const _Week12MilestoneDialog({
    required this.startWeight,
    required this.currentWeight,
    required this.totalXp,
    required this.totalSteps,
    required this.longestStreak,
    required this.weightHistory,
    required this.onClose,
  });
  final double startWeight, currentWeight;
  final int totalXp, totalSteps, longestStreak;
  final List<FlSpot> weightHistory;
  final VoidCallback onClose;

  @override
  State<_Week12MilestoneDialog> createState() => _Week12MilestoneDialogState();
}

class _Week12MilestoneDialogState extends State<_Week12MilestoneDialog>
    with TickerProviderStateMixin {
  late final AnimationController _confettiAnim;
  late final AnimationController _entryAnim;
  late final Animation<double> _scale;
  final _rng = math.Random();
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    _confettiAnim = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
    _entryAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scale = CurvedAnimation(parent: _entryAnim, curve: Curves.elasticOut);
    _entryAnim.forward();

    _particles = List.generate(60, (i) => _ConfettiParticle(
      x: _rng.nextDouble(),
      y: -_rng.nextDouble() * 0.5,
      vx: (_rng.nextDouble() - 0.5) * 0.003,
      vy: 0.003 + _rng.nextDouble() * 0.004,
      size: 4 + _rng.nextDouble() * 7,
      rotation: _rng.nextDouble() * math.pi * 2,
      vRotation: (_rng.nextDouble() - 0.5) * 0.1,
      color: [
        const Color(0xFFFFB800), const Color(0xFFFF6B35), const Color(0xFF6A11CB),
        const Color(0xFF11998E), const Color(0xFF2575FC), const Color(0xFFFF416C),
        Colors.white, const Color(0xFF38EF7D),
      ][i % 8],
    ));
  }

  @override
  void dispose() {
    _confettiAnim.dispose();
    _entryAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lost = (widget.startWeight - widget.currentWeight);
    final lostStr = lost > 0 ? '${lost.toStringAsFixed(1)} kg' : '0 kg';
    final stepsK = widget.totalSteps >= 1000
        ? '${(widget.totalSteps / 1000).toStringAsFixed(0)}K'
        : '${widget.totalSteps}';

    return Stack(children: [
      // Confetti layer
      AnimatedBuilder(
        animation: _confettiAnim,
        builder: (context, _) {
          // Advance particles
          for (final p in _particles) {
            p.x += p.vx;
            p.y += p.vy;
            p.rotation += p.vRotation;
            if (p.y > 1.1) {
              p.y = -0.1;
              p.x = _rng.nextDouble();
            }
          }
          return CustomPaint(
            painter: _ConfettiPainter(_particles),
            size: MediaQuery.of(context).size,
          );
        },
      ),

      ScaleTransition(
        scale: _scale,
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A0533), Color(0xFF6A11CB), Color(0xFF2575FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const Text('🏆', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 8),
                  const Text('Transformation Complete!', style: TextStyle(
                      color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('You did it. 12 weeks of consistency.',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                  const SizedBox(height: 24),

                  // Stats grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.2,
                    children: [
                      _StatCard(label: 'Started At', value: '${widget.startWeight.toStringAsFixed(1)} kg', icon: '⚖️'),
                      _StatCard(label: 'Finished At', value: '${widget.currentWeight.toStringAsFixed(1)} kg', icon: '🎯'),
                      _StatCard(label: 'Total Lost', value: lostStr, icon: '📉'),
                      _StatCard(label: 'XP Earned', value: '${widget.totalXp}', icon: '⭐'),
                      _StatCard(label: 'Total Steps', value: '$stepsK steps', icon: '👟'),
                      _StatCard(label: 'Best Streak', value: '${widget.longestStreak} days', icon: '🔥'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Weight trend chart
                  if (widget.weightHistory.isNotEmpty) ...[
                    Container(
                      height: 150,
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('12-Week Weight Trend',
                            style: TextStyle(color: Colors.white.withOpacity(0.8),
                                fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Expanded(child: _WeightChart(
                            spots: widget.weightHistory, color: const Color(0xFF38EF7D))),
                      ]),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Achievement card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFFB800), Color(0xFFFF6B35)]),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(
                          color: const Color(0xFFFFB800).withOpacity(0.4),
                          blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Row(children: [
                      const Text('🎓', style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('FitQuest Graduate', style: TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                        Text('12-Week Challenge · ${lost.toStringAsFixed(1)} kg lost',
                            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Close',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF6A11CB),
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});
  final String label, value, icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 8),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(
              color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      )),
    ]),
  );
}

// ─── Weight Chart ─────────────────────────────────────────────────────────────

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.spots, required this.color});
  final List<FlSpot> spots;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) return const SizedBox.shrink();
    final minY = spots.map((s) => s.y).reduce(math.min) - 1;
    final maxY = spots.map((s) => s.y).reduce(math.max) + 1;

    return LineChart(LineChartData(
      minY: minY,
      maxY: maxY,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (val, _) {
              final w = val.toInt();
              if (w < 1 || w > 12) return const SizedBox.shrink();
              return Text('W$w', style: TextStyle(
                  color: color.withOpacity(0.7), fontSize: 8, fontWeight: FontWeight.w600));
            },
            interval: 2,
            reservedSize: 16,
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 2.5,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
              radius: 3, color: color,
              strokeWidth: 1.5, strokeColor: Colors.white.withOpacity(0.8),
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [color.withOpacity(0.35), color.withOpacity(0.0)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    ));
  }
}

// ─── Confetti ─────────────────────────────────────────────────────────────────

class _ConfettiParticle {
  _ConfettiParticle({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.size, required this.rotation,
    required this.vRotation, required this.color,
  });
  double x, y, vx, vy, size, rotation, vRotation;
  Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles);
  final List<_ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()..color = p.color.withOpacity(0.85);
      canvas.save();
      canvas.translate(p.x * size.width, p.y * size.height);
      canvas.rotate(p.rotation);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}
