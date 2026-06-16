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

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  String? _validationError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _validationError = 'Email and password are required');
      return;
    }
    setState(() => _validationError = null);
    final ok = await ref
        .read(sessionProvider.notifier)
        .signIn(_email.text.trim(), _password.text);
    if (ok && mounted) {
      final onboarded = ref.read(sessionProvider).onboarded;
      context.go(onboarded ? Routes.home : Routes.quiz);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final error = _validationError ?? s.error;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeuTopBar(onBack: () => context.go(Routes.welcome)),
              const SizedBox(height: 28),
              Text('WELCOME BACK',
                  style: T.label(context).copyWith(color: AppColors.coral)),
              const SizedBox(height: 8),
              Text('Sign in', style: T.h1(context)),
              const SizedBox(height: 6),
              Text('Continue your FitQuest journey.', style: T.body(context)),
              const SizedBox(height: 36),

              Text('EMAIL', style: T.label(context)),
              const SizedBox(height: 8),
              NeuTextField(
                controller: _email,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 18),

              Text('PASSWORD', style: T.label(context)),
              const SizedBox(height: 8),
              NeuTextField(
                controller: _password,
                hint: 'Your password',
                obscureText: _obscure,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(
                    _obscure
                        ? Symbols.visibility_rounded
                        : Symbols.visibility_off_rounded,
                    color: AppColors.inkSoft,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(error,
                      style: T.small(context).copyWith(color: AppColors.coral)),
                ),

              NeuButton.primary(
                'Sign in',
                loading: s.busy,
                trailing: const Icon(Symbols.arrow_forward_rounded, size: 20),
                onPressed: s.busy ? null : _submit,
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () => context.go(Routes.signup),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: "Don't have an account? ",
                        style: T.small(context)),
                    TextSpan(
                        text: 'Sign up',
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
    );
  }
}
