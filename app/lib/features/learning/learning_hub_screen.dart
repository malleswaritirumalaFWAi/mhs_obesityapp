import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/providers/lessons_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class LearningHubScreen extends ConsumerWidget {
  const LearningHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lessonsProvider);
    final active = state.activeLesson;
    final activeWeekLessons = state.activeWeekLessons;
    final upNext = state.upNext;
    final modules = state.weekModules;

    // Progress within the active week
    final totalInWeek = activeWeekLessons.length;
    final lessonPosInWeek = active != null
        ? activeWeekLessons.indexOf(active) + 1
        : 0;
    final weekProgress =
        totalInWeek > 0 ? lessonPosInWeek / totalInWeek : 0.0;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // Top bar
            Row(children: [
              NeuIconButton(
                  icon: Symbols.arrow_back_rounded,
                  onTap: () => context.pop()),
              const SizedBox(width: 12),
              const Text('Learn 📚', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const Spacer(),
              NeuIconButton(icon: Symbols.notifications_rounded),
            ]),
            const SizedBox(height: 20),

            // ── Active lesson hero card ──────────────────────────────────────
            if (state.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (active != null) ...[
              NeuCard(
                color: AppColors.berrySoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NeuPill(
                      color: AppColors.berry,
                      child: Text(
                          'Week ${active.weekNumber} · +${active.xpReward} XP',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                    const SizedBox(height: 14),
                    Text(active.title,
                        style: T.h2(context).copyWith(fontSize: 20)),
                    const SizedBox(height: 6),
                    if (totalInWeek > 0)
                      Text(
                        'Lesson $lessonPosInWeek of $totalInWeek · ${(weekProgress * 100).round()}% complete',
                        style: T.small(context),
                      ),
                    const SizedBox(height: 12),
                    if (totalInWeek > 0) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: weekProgress,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.5),
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.berry),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    NeuButton.primary(
                      active.completed ? 'Review lesson' : 'Continue lesson',
                      trailing: const Icon(Symbols.arrow_forward_rounded,
                          size: 18, color: Colors.white),
                      onPressed: () => context.push('/lesson/${active.id}'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Up next ──────────────────────────────────────────────────────
            if (upNext.isNotEmpty) ...[
              Text('Up next', style: T.title(context)),
              const SizedBox(height: 12),
              for (final lesson in upNext)
                _UpNextRow(lesson: lesson),
              const SizedBox(height: 24),
            ],

            // ── Your journey ─────────────────────────────────────────────────
            Text('Your journey', style: T.title(context)),
            const SizedBox(height: 12),

            if (modules.isEmpty && !state.loading)
              const NeuCard(
                padding: EdgeInsets.all(24),
                child: Center(
                    child:
                        Text('No lessons available yet. Check back soon!')),
              )
            else
              for (final module in modules)
                _WeekModuleRow(module: module),
          ],
        ),
      ),
    );
  }
}

// ── Up next row ───────────────────────────────────────────────────────────────

class _UpNextRow extends StatelessWidget {
  const _UpNextRow({required this.lesson});
  final LessonItem lesson;

  @override
  Widget build(BuildContext context) {
    final isVideo = lesson.lessonType == 'video';
    final isQuiz = lesson.lessonType == 'quiz';
    final iconColor =
        isQuiz ? AppColors.gold : isVideo ? AppColors.coral : AppColors.berry;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeuCard(
        onTap: () => context.push('/lesson/${lesson.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isQuiz
                  ? AppColors.goldSoft
                  : isVideo
                      ? AppColors.coralSoft
                      : AppColors.berrySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isQuiz
                  ? Symbols.psychology_rounded
                  : isVideo
                      ? Symbols.play_circle_rounded
                      : Symbols.article_rounded,
              color: iconColor,
              fill: 1,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lesson.title,
                    style: T.title(context).copyWith(fontSize: 14)),
                Text(lesson.upNextSubtitle,
                    style: T.small(context).copyWith(fontSize: 12)),
              ],
            ),
          ),
          const Icon(Symbols.chevron_right_rounded,
              color: AppColors.inkSoft, size: 20),
        ]),
      ),
    );
  }
}

// ── Week module row ───────────────────────────────────────────────────────────

class _WeekModuleRow extends StatelessWidget {
  const _WeekModuleRow({required this.module});
  final WeekModule module;

  @override
  Widget build(BuildContext context) {
    final completed = module.isCompleted;
    final locked = module.isLocked;
    final active = module.isActive;

    Color cardColor = AppColors.surface;
    if (active) cardColor = AppColors.coralSoft;

    Widget statusIcon;
    if (completed) {
      statusIcon = Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
            color: AppColors.sageSoft, shape: BoxShape.circle),
        child: const Icon(Symbols.check_circle_rounded,
            color: AppColors.sage, size: 20, fill: 1),
      );
    } else if (locked) {
      statusIcon = Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
            color: AppColors.bg, shape: BoxShape.circle),
        child: const Icon(Symbols.lock_rounded,
            color: AppColors.inkSoft, size: 18, fill: 1),
      );
    } else {
      // active
      statusIcon = Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
            color: AppColors.coral, shape: BoxShape.circle),
        child: const Icon(Symbols.play_arrow_rounded,
            color: Colors.white, size: 20, fill: 1),
      );
    }

    String statusLabel;
    Color statusColor;
    if (completed) {
      statusLabel = 'Completed';
      statusColor = AppColors.sageDark;
    } else if (active) {
      statusLabel = 'Active now';
      statusColor = AppColors.coral;
    } else {
      statusLabel = 'Unlocks soon';
      statusColor = AppColors.inkSoft;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeuCard(
        color: cardColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          statusIcon,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Week ${module.weekNumber} · ${module.weekName}',
                  style: T.title(context).copyWith(fontSize: 14),
                ),
                Text(
                  statusLabel,
                  style: T.small(context)
                      .copyWith(color: statusColor, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!locked)
            const Icon(Symbols.chevron_right_rounded,
                color: AppColors.inkSoft, size: 20),
        ]),
      ),
    );
  }
}
