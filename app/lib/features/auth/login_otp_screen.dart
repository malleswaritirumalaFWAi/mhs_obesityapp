import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/router.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeuTopBar(
                onBack: () => step2
                    ? ref.read(sessionProvider.notifier).resetToPhone()
                    : context.go(Routes.welcome),
                trailing: Text('Step ${step2 ? 2 : 1} of 2', style: T.small(context)),
              ),
              const SizedBox(height: 36),
              if (!step2) ..._phoneStep(context, s) else ..._otpStep(context, s),
              const Spacer(),
              if (s.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(s.error!,
                      style: T.small(context).copyWith(color: AppColors.coral)),
                ),
              NeuButton.primary(
                step2 ? 'Verify & continue' : 'Send OTP',
                loading: s.busy,
                trailing: const Icon(Symbols.arrow_forward_rounded, size: 20),
                onPressed: step2 ? _verify : _sendOtp,
              ),
              const SizedBox(height: 14),
              Center(
                child: Text('🔒 By continuing you agree to our Terms & Privacy Policy.',
                    style: T.small(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneStep(BuildContext context, SessionState s) => [
        Text('Welcome', style: T.label(context).copyWith(color: AppColors.coral)),
        const SizedBox(height: 8),
        Text("Let's get started", style: T.h1(context)),
        const SizedBox(height: 10),
        Text("Enter your phone number — we'll text you a verification code.",
            style: T.body(context)),
        const SizedBox(height: 28),
        Text('PHONE NUMBER', style: T.label(context)),
        const SizedBox(height: 10),
        NeuTextField(
          controller: _phone,
          hint: '98765 43210',
          keyboardType: TextInputType.phone,
          prefix: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🇮🇳 ', style: TextStyle(fontSize: 18)),
            Text('+91',
                style: T.title(context).copyWith(color: AppColors.inkMid)),
          ]),
          style: const TextStyle(
              color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: 1),
        ),
      ];

  List<Widget> _otpStep(BuildContext context, SessionState s) => [
        Text('Verify OTP', style: T.label(context).copyWith(color: AppColors.coral)),
        const SizedBox(height: 8),
        Text('Enter the code', style: T.h1(context)),
        const SizedBox(height: 10),
        Text('Sent to +91 ${s.phone ?? ''}  ·  ', style: T.body(context)),
        const SizedBox(height: 28),
        NeuTextField(
          controller: _otp,
          hint: '• • • • • •',
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 26, letterSpacing: 14),
        ),
        const SizedBox(height: 16),
        Center(
          child: _secs > 0
              ? Text('Resend in 0:${_secs.toString().padLeft(2, '0')}',
                  style: T.small(context))
              : GestureDetector(
                  onTap: () {
                    ref.read(sessionProvider.notifier).requestOtp(s.phone ?? '');
                    _startTimer();
                  },
                  child: Text('Resend code',
                      style: T.small(context).copyWith(
                          color: AppColors.coral, fontWeight: FontWeight.w800)),
                ),
        ),
      ];
}
