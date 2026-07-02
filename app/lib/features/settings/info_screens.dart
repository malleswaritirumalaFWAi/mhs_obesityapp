import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';

// ── Health Goals ─────────────────────────────────────────────────────────────

class HealthGoalsScreen extends StatelessWidget {
  const HealthGoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      title: 'Health Goals',
      icon: Symbols.favorite_rounded,
      children: [
        _Section(title: 'Your Programme', children: [
          _Item(label: 'Duration', value: '12 weeks'),
          _Item(label: 'Daily check-in', value: 'Morning mood & weight'),
          _Item(label: 'Step goal', value: '8,000 steps/day'),
          _Item(label: 'Water goal', value: '8 glasses/day'),
        ]),
        const SizedBox(height: 16),
        _Section(title: 'Nutrition', children: [
          _Item(label: 'Meal logging', value: '4 meals/day'),
          _Item(label: 'Diet tracking', value: 'Calorie & macro aware'),
        ]),
        const SizedBox(height: 16),
        _Section(title: 'Activity', children: [
          _Item(label: 'Movement', value: 'Daily steps + exercises'),
          _Item(label: 'Fasting', value: 'Optional intermittent fasting'),
        ]),
        const SizedBox(height: 16),
        NeuCard(
          color: AppColors.coralSoft,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Symbols.info_rounded, color: AppColors.coral, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'To update your target weight or personal goals, speak to your coach in the group chat.',
                style: T.small(context),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

// ── Help & Support ────────────────────────────────────────────────────────────

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      title: 'Help & Support',
      icon: Symbols.help_rounded,
      children: [
        _Section(title: 'Frequently Asked Questions', children: [
          _Faq(
            q: 'How do I log my meals?',
            a: 'Tap the + button on Today\'s Plan or go to the Meal section. You can take a photo and our AI will analyse it for you.',
          ),
          _Faq(
            q: 'Why did my streak reset?',
            a: 'Streaks require a daily morning check-in (mood + weight). Missing a day reduces your streak by 1.',
          ),
          _Faq(
            q: 'How do I earn XP?',
            a: 'Complete daily tasks, log meals, check in each morning, hit your step goal, finish lessons, and participate in group chat.',
          ),
          _Faq(
            q: 'What is the Royal Challenge?',
            a: 'The Royal leaderboard shows all-time XP across all FitQuest members. Weekly resets every Sunday — Royal never resets.',
          ),
          _Faq(
            q: 'How do I contact my coach?',
            a: 'Use the Group Chat tab in the Group screen to message your coach directly.',
          ),
        ]),
        const SizedBox(height: 16),
        _Section(title: 'Contact Us', children: [
          _Item(label: 'Email', value: 'support@fitquest.in'),
          _Item(label: 'Response time', value: 'Within 24 hours'),
        ]),
      ],
    );
  }
}

// ── Terms & Conditions ────────────────────────────────────────────────────────

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      title: 'Terms & Conditions',
      icon: Symbols.description_rounded,
      children: [
        Text('Last updated: January 2025', style: T.small(context)),
        const SizedBox(height: 16),
        _TermsSection(
          title: '1. Acceptance of Terms',
          body:
              'By using FitQuest, you agree to these Terms & Conditions. If you do not agree, please do not use the app.',
        ),
        _TermsSection(
          title: '2. Health Disclaimer',
          body:
              'FitQuest is a wellness coaching tool and is not a substitute for professional medical advice, diagnosis, or treatment. Always consult a qualified healthcare provider before starting any diet or exercise programme.',
        ),
        _TermsSection(
          title: '3. User Responsibilities',
          body:
              'You are responsible for providing accurate health information. FitQuest is intended for adults aged 18 and above. Do not share your account credentials with others.',
        ),
        _TermsSection(
          title: '4. Privacy & Data (DPDP Act 2023)',
          body:
              'Your data is processed in accordance with India\'s Digital Personal Data Protection Act 2023. You may export or delete your data at any time from the Settings screen.',
        ),
        _TermsSection(
          title: '5. Payments & Refunds',
          body:
              'Programme fees are charged once at enrolment. Refund requests may be submitted within 7 days of purchase by contacting support.',
        ),
        _TermsSection(
          title: '6. Intellectual Property',
          body:
              'All content, branding, and features within FitQuest are the intellectual property of MHS Obesity App and may not be reproduced without permission.',
        ),
        _TermsSection(
          title: '7. Changes to Terms',
          body:
              'We may update these terms from time to time. Continued use of FitQuest after changes constitutes your acceptance of the revised terms.',
        ),
        _TermsSection(
          title: '8. Contact',
          body: 'For any questions regarding these terms, contact us at legal@fitquest.in.',
        ),
      ],
    );
  }
}

// ── Shared internal widgets ───────────────────────────────────────────────────

class _InfoScaffold extends StatelessWidget {
  const _InfoScaffold({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: NeuCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: const Icon(Symbols.arrow_back_rounded,
                      color: AppColors.inkMid, size: 22),
                ),
                const SizedBox(width: 14),
                Icon(icon, color: AppColors.coral, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                ),
              ]),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: children,
            ),
          ),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(),
          style: T.label(context)),
      const SizedBox(height: 10),
      NeuCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(children: children),
      ),
    ]);
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Text(label, style: T.body(context))),
        Text(value,
            style: T.body(context).copyWith(
                color: AppColors.inkMid, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _Faq extends StatefulWidget {
  const _Faq({required this.q, required this.a});
  final String q;
  final String a;

  @override
  State<_Faq> createState() => _FaqState();
}

class _FaqState extends State<_Faq> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => setState(() => _open = !_open),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Expanded(
                child: Text(widget.q,
                    style: T.body(context)
                        .copyWith(fontWeight: FontWeight.w600))),
            Icon(
              _open
                  ? Symbols.keyboard_arrow_up_rounded
                  : Symbols.keyboard_arrow_down_rounded,
              color: AppColors.inkSoft,
              size: 20,
            ),
          ]),
        ),
      ),
      if (_open) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(widget.a,
              style: T.small(context).copyWith(color: AppColors.inkMid)),
        ),
      ],
      const Divider(color: AppColors.line, height: 1),
    ]);
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: T.title(context).copyWith(fontSize: 15)),
        const SizedBox(height: 6),
        Text(body, style: T.body(context).copyWith(color: AppColors.inkMid)),
      ]),
    );
  }
}
