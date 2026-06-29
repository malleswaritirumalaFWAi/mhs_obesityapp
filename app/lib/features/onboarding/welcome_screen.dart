import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Hero section ──
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 64, 28, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 20),
                const Text(
                  'Lose Weight\nLike Playing\na Game',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Real coach · Real science · Real results',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkMid,
                  ),
                ),
              ],
            ),
          ),

          // ── Benefits + CTAs ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WHY FITQUEST',
                      style: T.label(context)
                          .copyWith(color: AppColors.coral, letterSpacing: 1.2)),
                  const SizedBox(height: 16),
                  const _Benefit(
                    emoji: '🩺',
                    color: AppColors.orange,
                    soft: AppColors.orangeSoft,
                    title: 'Personal coach on WhatsApp',
                    sub: 'Certified dietitian, replies in 24h',
                  ),
                  const SizedBox(height: 14),
                  const _Benefit(
                    emoji: '👥',
                    color: AppColors.teal,
                    soft: Color(0xFFE8F4F8),
                    title: 'Group of 50 just like you',
                    sub: 'Same goal, same start, daily motivation',
                  ),
                  const SizedBox(height: 14),
                  const _Benefit(
                    emoji: '🏆',
                    color: Color(0xFFA36F1A),
                    soft: AppColors.goldSoft,
                    title: 'Win up to ₹50,000 cash',
                    sub: 'Top performers earn rewards each batch',
                  ),
                  const SizedBox(height: 32),

                  // ── Primary CTA ──
                  NeuButton.primary(
                    'Start my journey',
                    onPressed: () => context.go(Routes.signup),
                    trailing: const Icon(Symbols.arrow_forward_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go(Routes.signin),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                            text: 'Already a member? ',
                            style: T.small(context)),
                        TextSpan(
                            text: 'Sign in',
                            style: T.small(context).copyWith(
                                color: AppColors.coral,
                                fontWeight: FontWeight.w800)),
                      ])),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.emoji,
    required this.color,
    required this.soft,
    required this.title,
    required this.sub,
  });
  final String emoji;
  final Color color;
  final Color soft;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
            child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: T.title(context).copyWith(
                        fontSize: 15, color: const Color(0xFF1A1A2E))),
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
