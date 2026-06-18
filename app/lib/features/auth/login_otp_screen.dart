import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/router.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_misc.dart';

class LoginOtpScreen extends ConsumerStatefulWidget {
  const LoginOtpScreen({super.key});
  @override
  ConsumerState<LoginOtpScreen> createState() => _LoginOtpScreenState();
}

class _LoginOtpScreenState extends ConsumerState<LoginOtpScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  Timer? _timer;
  int _secs = 24;

  void _startTimer() {
    _secs = 24;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secs == 0) {
        t.cancel();
      } else {
        setState(() => _secs--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_phone.text.trim().length < 10) return;
    await ref.read(sessionProvider.notifier).requestOtp(_phone.text.trim());
    _startTimer();
  }

  Future<void> _verify() async {
    final ok = await ref.read(sessionProvider.notifier).verifyOtp(_otp.text.trim());
    if (ok && mounted) {
      final onboarded = ref.read(sessionProvider).onboarded;
      context.go(onboarded ? Routes.home : Routes.quiz);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final step2 = s.status == AuthStatus.otpSent;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Gradient header ──
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppColors.splashGrad,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.of(context).padding.top + 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => step2
                        ? ref.read(sessionProvider.notifier).resetToPhone()
                        : context.go(Routes.welcome),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Symbols.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Step ${step2 ? 2 : 1} of 2',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                Text(step2 ? '🔐' : '📱',
                    style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text(
                  step2 ? 'Enter the code' : 'Get started',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1.1),
                ),
                const SizedBox(height: 6),
                Text(
                  step2
                      ? 'Sent to +91 ${s.phone ?? ''}'
                      : 'Enter your phone number to receive an OTP.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85), fontSize: 15),
                ),
              ],
            ),
          ),

          // ── Form ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!step2) ...[
                    Text('PHONE NUMBER', style: T.label(context)),
                    const SizedBox(height: 10),
                    NeuTextField(
                      controller: _phone,
                      hint: '98765 43210',
                      keyboardType: TextInputType.phone,
                      prefix: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('🇮🇳 ', style: TextStyle(fontSize: 18)),
                        Text('+91',
                            style: T.title(context)
                                .copyWith(color: AppColors.inkMid)),
                      ]),
                      style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          letterSpacing: 1),
                    ),
                  ] else ...[
                    Text('VERIFICATION CODE', style: T.label(context)),
                    const SizedBox(height: 10),
                    NeuTextField(
                      controller: _otp,
                      hint: '• • • • • •',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                          letterSpacing: 14),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: _secs > 0
                          ? Text(
                              'Resend in 0:${_secs.toString().padLeft(2, '0')}',
                              style: T.small(context))
                          : GestureDetector(
                              onTap: () {
                                ref
                                    .read(sessionProvider.notifier)
                                    .requestOtp(s.phone ?? '');
                                _startTimer();
                              },
                              child: Text('Resend code',
                                  style: T.small(context).copyWith(
                                      color: AppColors.orange,
                                      fontWeight: FontWeight.w800)),
                            ),
                    ),
                  ],

                  if (s.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.coralSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Symbols.error_rounded,
                            color: AppColors.coral, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(s.error!,
                              style: T.small(context)
                                  .copyWith(color: AppColors.coral)),
                        ),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 28),

                  GestureDetector(
                    onTap: s.busy ? null : (step2 ? _verify : _sendOtp),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: s.busy
                            ? null
                            : const LinearGradient(
                                colors: [AppColors.orange, AppColors.amber],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                        color: s.busy ? AppColors.line : null,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: s.busy
                            ? null
                            : [
                                BoxShadow(
                                  color: AppColors.orange.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                      ),
                      child: Center(
                        child: s.busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    step2 ? 'Verify & continue' : 'Send OTP',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Symbols.arrow_forward_rounded,
                                      color: Colors.white, size: 20),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      '🔒 By continuing you agree to our Terms & Privacy Policy.',
                      style: T.small(context),
                      textAlign: TextAlign.center,
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
