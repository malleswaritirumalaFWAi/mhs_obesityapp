import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const NeuPill(
                    color: AppColors.sageSoft,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Symbols.eco_rounded, size: 18, color: AppColors.sageDark, fill: 1),
                      SizedBox(width: 6),
                      Text('FitQuest',
                          style: TextStyle(
                              color: AppColors.sageDark, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go(Routes.login),
                    child: Text('Skip', style: T.small(context)),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text('YOUR PROMISE', style: T.label(context).copyWith(color: AppColors.coral)),
              const SizedBox(height: 12),
              Text('Lose 8–15 kg\nin 12 weeks.', style: T.h1(context)),
              const SizedBox(height: 12),
              Text('Real coach. Real science. Real results — guaranteed or money back.',
                  style: T.body(context)),
              const SizedBox(height: 28),
              const _Benefit(
                icon: Symbols.medical_services_rounded,
                color: AppColors.coral,
                soft: AppColors.coralSoft,
                title: 'Personal coach on WhatsApp',
                sub: 'Certified dietitian, replies in 24h',
              ),
              const SizedBox(height: 14),
              const _Benefit(
                icon: Symbols.groups_rounded,
                color: AppColors.sageDark,
                soft: AppColors.sageSoft,
                title: 'Group of 50 just like you',
                sub: 'Same goal, same start, daily motivation',
              ),
              const SizedBox(height: 14),
              const _Benefit(
                icon: Symbols.emoji_events_rounded,
                color: AppColors.goldDark,
                soft: AppColors.goldSoft,
                title: 'Win up to ₹50,000 cash',
                sub: 'Top performers earn rewards each batch',
              ),
              const Spacer(),
              NeuButton.primary(
                'Start my journey',
                trailing: const Icon(Symbols.arrow_forward_rounded, size: 20),
                onPressed: () => context.go(Routes.login),
              ),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: () => context.go(Routes.login),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: 'Already a member? ', style: T.small(context)),
                    TextSpan(
                        text: 'Log in',
                        style: T.small(context).copyWith(
                            color: AppColors.coral, fontWeight: FontWeight.w800)),
                  ])),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.color,
    required this.soft,
    required this.title,
    required this.sub,
  });
  final IconData icon;
  final Color color;
  final Color soft;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
            child: Icon(icon, color: color, fill: 1),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.title(context).copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(sub, style: T.small(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
