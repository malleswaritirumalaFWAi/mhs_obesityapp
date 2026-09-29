import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class _Q {
  const _Q(this.label, this.subtitle, this.options);
  final String label;
  final String subtitle;
  final List<({IconData icon, String title, String sub})> options;
}

const _questions = <_Q>[
  _Q('Your gender?', 'Helps us tailor calorie targets.', [
    (icon: Symbols.man_rounded, title: 'Male', sub: ''),
    (icon: Symbols.woman_rounded, title: 'Female', sub: ''),
    (icon: Symbols.transgender_rounded, title: 'Other', sub: ''),
  ]),
  _Q('Your activity level?', 'Be honest -- we adjust the plan.', [
    (icon: Symbols.chair_rounded, title: 'Mostly sitting', sub: 'Desk job, little movement'),
    (icon: Symbols.directions_walk_rounded, title: 'Lightly active', sub: 'Some walking daily'),
    (icon: Symbols.fitness_center_rounded, title: 'Very active', sub: 'Workout 4+ days/week'),
  ]),
  _Q("What's your main goal?", "We'll personalize the plan around it.", [
    (icon: Symbols.monitor_weight_rounded, title: 'Lose weight', sub: '8-15 kg in 12 weeks'),
    (icon: Symbols.fitness_center_rounded, title: 'Build muscle', sub: 'Strength + lean gains'),
    (icon: Symbols.favorite_rounded, title: 'Better health markers', sub: 'Blood sugar, BP, sleep'),
    (icon: Symbols.bolt_rounded, title: 'More energy', sub: 'Feel sharper through the day'),
  ]),
  _Q('Food preference?', 'We build your meal plan from this.', [
    (icon: Symbols.eco_rounded, title: 'Vegetarian', sub: 'No meat, eggs ok'),
    (icon: Symbols.egg_rounded, title: 'Eggetarian', sub: 'Veg + eggs'),
    (icon: Symbols.lunch_dining_rounded, title: 'Non-vegetarian', sub: 'Everything'),
  ]),
  _Q('Biggest challenge?', 'Your coach will focus here first.', [
    (icon: Symbols.cookie_rounded, title: 'Cravings & snacking', sub: ''),
    (icon: Symbols.bedtime_rounded, title: 'Poor sleep', sub: ''),
    (icon: Symbols.schedule_rounded, title: 'No time', sub: ''),
    (icon: Symbols.sentiment_stressed_rounded, title: 'Stress eating', sub: ''),
  ]),
];

// Per-step accent colors for variety
const _stepColors = [AppColors.coral, AppColors.coral, AppColors.coral, AppColors.coral, AppColors.coral];
const _stepSoftColors = [AppColors.coralSoft, AppColors.coralSoft, AppColors.coralSoft, AppColors.coralSoft, AppColors.coralSoft];

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});
  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  // MCQ steps 0-4, then step 5 = body stats, step 6 = medical, step 7 = disclaimer
  static const _totalSteps = 8;
  int _step = 0;
  final _answers = <int, int>{};

  // Body stats (step 5)
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();

  // Medical (step 6)
  final _conditionsCtrl = TextEditingController();
  final _medsCtrl = TextEditingController();

  // Disclaimer (step 7)
  bool _dpdpConsent = false;
  bool _medDisclaimer = false;

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _targetCtrl.dispose();
    _conditionsCtrl.dispose();
    _medsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitAndContinue() async {
    String pick(int i) =>
        _answers.containsKey(i) ? _questions[i].options[_answers[i]!].title : '';
    try {
      await ref.read(apiClientProvider).postJson('/profile/quiz', {
        'gender': pick(0),
        'activity': pick(1),
        'goal': pick(2),
        'food_pref': pick(3),
        'challenge': pick(4),
        'height': double.tryParse(_heightCtrl.text.trim()),
        'start_weight': double.tryParse(_weightCtrl.text.trim()),
        'target_weight': double.tryParse(_targetCtrl.text.trim()),
        'medical_conditions': _conditionsCtrl.text.trim(),
        'medications': _medsCtrl.text.trim(),
        'dpdp_consent': _dpdpConsent,
        'medical_disclaimer_accepted': _medDisclaimer,
      });
    } catch (_) {/* demo mode */}
    if (mounted) context.go(Routes.coach);
  }

  bool _canProceed() {
    if (_step < _questions.length) return _answers.containsKey(_step);
    if (_step == 5) {
      return _heightCtrl.text.trim().isNotEmpty &&
          _weightCtrl.text.trim().isNotEmpty;
    }
    if (_step == 6) return true; // optional fields
    if (_step == 7) return _dpdpConsent && _medDisclaimer;
    return false;
  }

  void _next() {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _submitAndContinue();
    }
  }

  void _back() {
    if (_step == 0) {
      context.go(Routes.welcome);
    } else {
      setState(() => _step--);
    }
  }

  Color get _accent => _step < _stepColors.length ? _stepColors[_step] : AppColors.coral;
  Color get _accentSoft => _step < _stepSoftColors.length ? _stepSoftColors[_step] : AppColors.coralSoft;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeuCard(
                depth: 0.5,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  GestureDetector(
                    onTap: _back,
                    child: const Icon(Symbols.arrow_back_rounded,
                        color: AppColors.inkMid, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('About You',
                        style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _accentSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${_step + 1} of $_totalSteps',
                        style: TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (_step + 1) / _totalSteps,
                  minHeight: 8,
                  backgroundColor: AppColors.line,
                  valueColor: AlwaysStoppedAnimation(_accent),
                ),
              ),
              const SizedBox(height: 24),
              Text('ABOUT YOU', style: T.section(context).copyWith(color: _accent)),
              const SizedBox(height: 10),
              Expanded(
                child: _step < _questions.length
                  ? _buildMCQ()
                  : _step == 5
                    ? _buildBodyStats()
                    : _step == 6
                      ? _buildMedical()
                      : _buildLanguageDisclaimer(),
              ),
              const SizedBox(height: 8),
              NeuButton.primary(
                _step == _totalSteps - 1 ? 'See my plan' : 'Continue',
                trailing: const Icon(Symbols.arrow_forward_rounded, size: 20),
                onPressed: _canProceed() ? _next : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMCQ() {
    final q = _questions[_step];
    final selected = _answers[_step];

    // ── Gender step: three big stacked selection boxes ──
    if (_step == 0) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(q.label, style: T.h1(context).copyWith(fontSize: 26)),
        const SizedBox(height: 8),
        Text(q.subtitle, style: T.body(context)),
        const SizedBox(height: 24),
        for (var i = 0; i < q.options.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          GestureDetector(
            onTap: () => setState(() => _answers[_step] = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
              decoration: BoxDecoration(
                color: selected == i ? _accentSoft : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected == i ? _accent : AppColors.line,
                  width: selected == i ? 2 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected == i
                        ? _accent.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: selected == i ? 16 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: selected == i ? _accent : AppColors.bg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(q.options[i].icon,
                      size: 52,
                      color: selected == i ? Colors.white : AppColors.inkMid,
                      fill: 1),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(q.options[i].title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: selected == i ? _accent : AppColors.ink)),
                ),
                Icon(
                  selected == i
                      ? Symbols.check_circle_rounded
                      : Symbols.radio_button_unchecked_rounded,
                  color: selected == i ? _accent : AppColors.line,
                  fill: selected == i ? 1 : 0,
                  size: 28,
                ),
              ]),
            ),
          ),
        ],
      ]);
    }

    // ── All other MCQ steps: standard list rows ──
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(q.label, style: T.h1(context).copyWith(fontSize: 26)),
      const SizedBox(height: 8),
      Text(q.subtitle, style: T.body(context)),
      const SizedBox(height: 24),
      Expanded(
        child: ListView.separated(
          itemCount: q.options.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final o = q.options[i];
            final on = selected == i;
            return NeuCard(
              depth: 0.5,
              onTap: () => setState(() => _answers[_step] = i),
              padding: const EdgeInsets.all(16),
              color: on ? _accentSoft : null,
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (on ? _accent : AppColors.inkMid).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(o.icon,
                      color: on ? _accent : AppColors.inkMid, fill: on ? 1 : 0, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.title, style: T.title(context).copyWith(fontSize: 15)),
                  if (o.sub.isNotEmpty) Text(o.sub, style: T.small(context)),
                ])),
                Icon(
                  on ? Symbols.check_circle_rounded : Symbols.radio_button_unchecked_rounded,
                  color: on ? _accent : AppColors.line,
                  fill: on ? 1 : 0,
                ),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildBodyStats() {
    // BMI preview
    double? bmi;
    final h = double.tryParse(_heightCtrl.text.trim());
    final w = double.tryParse(_weightCtrl.text.trim());
    if (h != null && w != null && h > 0) {
      final hm = h / 100;
      bmi = w / (hm * hm);
    }

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your body stats', style: T.h1(context).copyWith(fontSize: 26)),
        const SizedBox(height: 8),
        Text('Helps us calculate your calorie needs and BMI.', style: T.body(context)),
        const SizedBox(height: 24),
        _Field(
          controller: _heightCtrl,
          label: 'Height (cm)',
          hint: 'e.g. 165',
          suffix: 'cm',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        _Field(
          controller: _weightCtrl,
          label: 'Current weight (kg)',
          hint: 'e.g. 82',
          suffix: 'kg',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        _Field(
          controller: _targetCtrl,
          label: 'Target weight (kg)',
          hint: 'e.g. 70',
          suffix: 'kg',
          onChanged: (_) => setState(() {}),
        ),
        if (bmi != null) ...[
          const SizedBox(height: 24),
          NeuCard(
            depth: 0.5,
            color: AppColors.coralSoft,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Symbols.monitor_weight_rounded, color: AppColors.coral, size: 20, fill: 1),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your BMI: ${bmi.toStringAsFixed(1)}',
                  style: T.title(context).copyWith(color: AppColors.coral)),
                Text(_bmiLabel(bmi), style: T.small(context)),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildMedical() {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Medical history', style: T.h1(context).copyWith(fontSize: 26)),
        const SizedBox(height: 8),
        Text('Optional -- helps your coach give safe recommendations.', style: T.body(context)),
        const SizedBox(height: 24),
        Text('MEDICAL CONDITIONS', style: T.section(context)),
        const SizedBox(height: 8),
        TextField(
          controller: _conditionsCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'e.g. Diabetes, Hypertension, PCOS (leave blank if none)',
            hintStyle: T.small(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 24),
        Text('CURRENT MEDICATIONS', style: T.section(context)),
        const SizedBox(height: 8),
        TextField(
          controller: _medsCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'e.g. Metformin, blood pressure meds (leave blank if none)',
            hintStyle: T.small(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 12),
        Text('This information is only shared with your coach and kept confidential.',
          style: T.small(context).copyWith(color: AppColors.inkSoft)),
      ]),
    );
  }

  Widget _buildLanguageDisclaimer() {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Almost there!', style: T.h1(context).copyWith(fontSize: 26)),
        const SizedBox(height: 8),
        Text('Review our terms before we build your plan.', style: T.body(context)),
        const SizedBox(height: 24),

        NeuCard(
          depth: 0.5,
          onTap: () => setState(() => _medDisclaimer = !_medDisclaimer),
          color: _medDisclaimer ? AppColors.coralSoft : null,
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(
              value: _medDisclaimer,
              activeColor: AppColors.coral,
              onChanged: (v) => setState(() => _medDisclaimer = v ?? false),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'I understand that FitQuest is a wellness coaching program, '
              'not a medical service. I will consult a doctor before making '
              'significant changes to my diet or exercise routine if I have a medical condition.',
              style: T.small(context).copyWith(fontSize: 13),
            )),
          ]),
        ),
        const SizedBox(height: 12),

        NeuCard(
          depth: 0.5,
          onTap: () => setState(() => _dpdpConsent = !_dpdpConsent),
          color: _dpdpConsent ? AppColors.coralSoft : null,
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(
              value: _dpdpConsent,
              activeColor: AppColors.coral,
              onChanged: (v) => setState(() => _dpdpConsent = v ?? false),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'I consent to FitQuest collecting and processing my personal data '
              '(health metrics, meals, activity) to provide coaching services, '
              'as per the Digital Personal Data Protection Act 2023. '
              'I can export or delete my data at any time from Settings.',
              style: T.small(context).copyWith(fontSize: 13),
            )),
          ]),
        ),
      ]),
    );
  }

  String _bmiLabel(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    if (bmi < 35) return 'Obese (Class I)';
    if (bmi < 40) return 'Obese (Class II)';
    return 'Obese (Class III)';
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.suffix,
    this.onChanged,
  });
  final TextEditingController controller;
  final String label, hint, suffix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: T.title(context).copyWith(fontSize: 14)),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: T.small(context),
          suffixText: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    ]);
  }
}
