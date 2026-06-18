import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/providers/lessons_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class LessonViewerScreen extends ConsumerStatefulWidget {
  const LessonViewerScreen({super.key, required this.lessonId});
  final int lessonId;

  @override
  ConsumerState<LessonViewerScreen> createState() => _LessonViewerScreenState();
}

class _LessonViewerScreenState extends ConsumerState<LessonViewerScreen> {
  final PageController _pageCtrl = PageController();
  int _page = 0;
  int? _quizAnswer;
  bool _quizSubmitted = false;
  bool _completed = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lessonsState = ref.watch(lessonsProvider);
    final lesson = lessonsState.lessons
        .cast<LessonItem?>()
        .firstWhere((l) => l?.id == widget.lessonId, orElse: () => null);

    if (lesson == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(children: [
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
                    child: Text('Lesson',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                  ),
                ]),
              ),
            ),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ]),
        ),
      );
    }

    final slides = _buildSlides(lesson);
    final totalPages = slides.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                children: [
                  Container(
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
                      Expanded(
                        child: Text(
                          'Week ${lesson.weekNumber} · ${lesson.lessonType.toUpperCase()}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text('+${lesson.xpReward} XP',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: totalPages > 1 ? (_page + 1) / totalPages : 1.0,
                      minHeight: 6,
                      backgroundColor: AppColors.bg,
                      valueColor: const AlwaysStoppedAnimation(AppColors.berry),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${_page + 1} / $totalPages',
                      style: T.small(context).copyWith(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalPages,
                onPageChanged: (i) => setState(() {
                  _page = i;
                  _quizAnswer = null;
                  _quizSubmitted = false;
                }),
                itemBuilder: (_, i) => slides[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: _page < totalPages - 1
                  ? NeuButton.primary(
                      'Next',
                      trailing: const Icon(Symbols.arrow_forward_rounded, size: 18),
                      onPressed: () => _pageCtrl.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut),
                    )
                  : NeuButton.primary(
                      _completed ? 'Done' : 'Complete Lesson',
                      trailing: Icon(
                          _completed ? Symbols.check_circle_rounded : Symbols.emoji_events_rounded,
                          size: 18),
                      onPressed: () async {
                        if (!_completed) {
                          setState(() => _completed = true);
                          await ref.read(lessonsProvider.notifier).complete(lesson.id);
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSlides(LessonItem lesson) {
    final slides = <Widget>[];

    // Title slide
    slides.add(_TitleSlide(lesson: lesson));

    // Content slides — split by double newlines into paragraphs
    if (lesson.content.isNotEmpty) {
      final paragraphs = lesson.content
          .split(RegExp(r'\n{2,}'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // Group paragraphs into 2-per-slide
      for (var i = 0; i < paragraphs.length; i += 2) {
        final chunk = paragraphs.sublist(i, (i + 2).clamp(0, paragraphs.length));
        slides.add(_ContentSlide(paragraphs: chunk));
      }
    }

    // Quiz slide (if quiz lesson type or quiz_questions present)
    if (lesson.quizQuestions != null && lesson.quizQuestions!.isNotEmpty) {
      final quiz = lesson.quizQuestions!.first as Map<String, dynamic>? ?? {};
      slides.add(_QuizSlide(
        quiz: quiz,
        selectedAnswer: _quizAnswer,
        submitted: _quizSubmitted,
        onAnswer: (i) {
          if (!_quizSubmitted) setState(() => _quizAnswer = i);
        },
        onSubmit: () => setState(() => _quizSubmitted = true),
      ));
    }

    return slides;
  }
}

class _TitleSlide extends StatelessWidget {
  const _TitleSlide({required this.lesson});
  final LessonItem lesson;

  @override
  Widget build(BuildContext context) {
    final icon = lesson.lessonType == 'video'
        ? Symbols.play_circle_rounded
        : lesson.lessonType == 'quiz'
            ? Symbols.psychology_rounded
            : Symbols.article_rounded;
    final color = lesson.lessonType == 'video'
        ? AppColors.coral
        : lesson.lessonType == 'quiz'
            ? AppColors.gold
            : AppColors.berry;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: NeuCard(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, fill: 1, size: 28),
            ),
            const SizedBox(height: 20),
            Text(lesson.title, style: T.h2(context)),
            const SizedBox(height: 10),
            Text('Week ${lesson.weekNumber}',
                style: T.body(context).copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: 20),
            NeuPill(
              color: AppColors.sageSoft,
              child: Text('Complete to earn +${lesson.xpReward} XP',
                  style: const TextStyle(
                      color: AppColors.sageDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentSlide extends StatelessWidget {
  const _ContentSlide({required this.paragraphs});
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: NeuCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in paragraphs) ...[
              Text(p, style: T.body(context)),
              if (paragraphs.last != p) const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuizSlide extends StatelessWidget {
  const _QuizSlide({
    required this.quiz,
    required this.selectedAnswer,
    required this.submitted,
    required this.onAnswer,
    required this.onSubmit,
  });
  final Map<String, dynamic> quiz;
  final int? selectedAnswer;
  final bool submitted;
  final ValueChanged<int> onAnswer;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final question = (quiz['question'] as String?) ?? 'Quiz question';
    final options = (quiz['options'] as List<dynamic>?) ?? [];
    final correct = (quiz['correct'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          NeuCard(
            color: AppColors.goldSoft,
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('🧠', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text('Quick quiz', style: T.title(context).copyWith(color: AppColors.goldDark)),
              ]),
              const SizedBox(height: 14),
              Text(question, style: T.h2(context)),
            ]),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => onAnswer(i),
                child: NeuCard(
                  color: submitted
                      ? i == correct
                          ? AppColors.sageSoft
                          : i == selectedAnswer
                              ? AppColors.coralSoft
                              : null
                      : selectedAnswer == i
                          ? AppColors.berrySoft
                          : null,
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(
                        child: Text(options[i].toString(), style: T.body(context))),
                    if (submitted && i == correct)
                      const Icon(Symbols.check_circle_rounded,
                          color: AppColors.sage, fill: 1)
                    else if (submitted && i == selectedAnswer && i != correct)
                      const Icon(Symbols.cancel_rounded,
                          color: AppColors.coral, fill: 1)
                    else if (selectedAnswer == i)
                      const Icon(Symbols.radio_button_checked_rounded,
                          color: AppColors.berry),
                  ]),
                ),
              ),
            ),
          if (!submitted && selectedAnswer != null) ...[
            const SizedBox(height: 4),
            NeuButton.primary('Submit answer', onPressed: onSubmit),
          ],
          if (submitted) ...[
            const SizedBox(height: 8),
            NeuCard(
              color: selectedAnswer == correct ? AppColors.sageSoft : AppColors.coralSoft,
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Text(selectedAnswer == correct ? '🎉' : '💡',
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selectedAnswer == correct
                        ? 'Correct! Great job!'
                        : 'The correct answer is: ${options[correct]}',
                    style: T.body(context),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}
