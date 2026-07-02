import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class _Slide {
  const _Slide({
    required this.emoji,
    required this.title,
    required this.body,
    required this.color,
    required this.items,
  });
  final String emoji, title, body;
  final Color color;
  final List<String> items;
}

const _slides = [
  _Slide(
    emoji: '⚡',
    title: 'Earn XP',
    body: 'Complete daily tasks to earn Experience Points. The more you do, the faster you level up!',
    color: AppColors.gold,
    items: [
      'Check in daily → +10 XP',
      'Log a meal → +5 XP',
      'Complete a lesson → +30-50 XP',
      'Evening reflection → +10 XP',
      'Fasting session → +15 XP',
    ],
  ),
  _Slide(
    emoji: '🔥',
    title: 'Build Streaks',
    body: 'Log in every day to build your streak. Longer streaks give bonus XP multipliers!',
    color: AppColors.coral,
    items: [
      '7 days → 1.5× XP bonus',
      '14 days → 2× XP bonus',
      '30 days → 2.5× XP bonus',
      'Every 7 days → free streak freeze',
      'Missed a day? Use a freeze to protect it!',
    ],
  ),
  _Slide(
    emoji: '🏆',
    title: 'Level Up',
    body: 'Your total XP determines your level. Higher levels unlock special badges and perks!',
    color: AppColors.berry,
    items: [
      '🥉 Bronze — 0 XP (starter)',
      '🥈 Silver — 1,000 XP',
      '🥇 Gold — 3,000 XP',
      '💎 Platinum — 6,000 XP',
      '👑 Diamond — 10,000 XP',
    ],
  ),
  _Slide(
    emoji: '🏅',
    title: 'Earn Badges',
    body: 'Complete milestones to unlock badges. Show them off on your profile!',
    color: AppColors.sage,
    items: [
      'First check-in → Early Bird',
      '7-day streak → Week Warrior',
      '10 meals logged → Food Logger',
      '3 referrals → Star Recruiter',
      'Complete 12 weeks → FitQuest Champion',
    ],
  ),
  _Slide(
    emoji: '👥',
    title: 'Group Leaderboard',
    body: 'Compete with your cohort group. Top 3 weekly performers win special prizes!',
    color: AppColors.goldDark,
    items: [
      'Weekly XP resets every Sunday',
      'Top 3 get winner badges',
      'Royal leaderboard shows all-time rank',
      'Use group chat to motivate each other',
      'Coach broadcasts keep you on track',
    ],
  ),
];

class GamificationTutorialScreen extends StatefulWidget {
  const GamificationTutorialScreen({super.key});

  @override
  State<GamificationTutorialScreen> createState() =>
      _GamificationTutorialScreenState();
}

class _GamificationTutorialScreenState
    extends State<GamificationTutorialScreen> {
  final PageController _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: NeuCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Symbols.close_rounded,
                        color: AppColors.inkMid, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('How to play',
                        style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                  ),
                  Row(
                    children: List.generate(_slides.length, (i) => Container(
                      width: i == _page ? 18 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _page
                            ? AppColors.coral
                            : AppColors.line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    )),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _SlidePage(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Row(children: [
                if (_page > 0) ...[
                  NeuButton(
                    onPressed: () => _ctrl.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut),
                    child: const Icon(Symbols.arrow_back_rounded, size: 20),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _page < _slides.length - 1
                      ? NeuButton.primary(
                          'Next',
                          trailing: const Icon(Symbols.arrow_forward_rounded, size: 18),
                          onPressed: () => _ctrl.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut),
                        )
                      : NeuButton.primary(
                          "Let's go!",
                          trailing: const Icon(Symbols.rocket_launch_rounded, size: 18),
                          onPressed: () => context.go(Routes.home),
                        ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          NeuCard(
            color: slide.color.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slide.emoji, style: const TextStyle(fontSize: 52)),
                const SizedBox(height: 16),
                Text(slide.title, style: T.h1(context).copyWith(color: slide.color)),
                const SizedBox(height: 10),
                Text(slide.body, style: T.body(context)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          NeuCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: slide.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: slide.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(item, style: T.body(context))),
                ]),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
