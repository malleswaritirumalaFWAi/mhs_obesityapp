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

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  String? _validationError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Full name is required';
    if (_phone.text.trim().length < 10) return 'Enter a valid 10-digit phone number';
    final emailRe = RegExp(r'^[\w.+-]+@[\w-]+\.[a-z]{2,}$', caseSensitive: false);
    if (!emailRe.hasMatch(_email.text.trim())) return 'Enter a valid email address';
    if (_password.text.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      setState(() => _validationError = err);
      return;
    }
    setState(() => _validationError = null);
    final ok = await ref.read(sessionProvider.notifier).signUp(
          _name.text.trim(),
          _phone.text.trim(),
          _email.text.trim(),
          _password.text,
        );
    if (ok && mounted) context.go(Routes.quiz);
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
              Text('CREATE ACCOUNT',
                  style: T.label(context).copyWith(color: AppColors.coral)),
              const SizedBox(height: 8),
              Text('Join FitQuest', style: T.h1(context)),
              const SizedBox(height: 6),
              Text('Start your 12-week transformation today.',
                  style: T.body(context)),
              const SizedBox(height: 28),

              Text('FULL NAME', style: T.label(context)),
              const SizedBox(height: 8),
              NeuTextField(
                controller: _name,
                hint: 'Aarav Sharma',
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 18),

              Text('PHONE NUMBER', style: T.label(context)),
              const SizedBox(height: 8),
              NeuTextField(
                controller: _phone,
                hint: '98765 43210',
                keyboardType: TextInputType.phone,
                prefix: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🇮🇳 ', style: TextStyle(fontSize: 18)),
                  Text('+91',
                      style: T.title(context).copyWith(color: AppColors.inkMid)),
                ]),
              ),
              const SizedBox(height: 18),

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
                hint: 'Min. 8 characters',
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
              const SizedBox(height: 28),

              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(error,
                      style: T.small(context).copyWith(color: AppColors.coral)),
                ),

              NeuButton.primary(
                'Create account',
                loading: s.busy,
                trailing: const Icon(Symbols.arrow_forward_rounded, size: 20),
                onPressed: s.busy ? null : _submit,
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () => context.go(Routes.signin),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: 'Already have an account? ',
                        style: T.small(context)),
                    TextSpan(
                        text: 'Sign in',
                        style: T.small(context).copyWith(
                            color: AppColors.coral,
                            fontWeight: FontWeight.w800)),
                  ])),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text('🔒 Your data is safe and never shared.',
                    style: T.small(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
