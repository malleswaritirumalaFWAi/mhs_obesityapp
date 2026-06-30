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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final emailRe = RegExp(r'^[\w.+-]+@[\w-]+\.[a-z]{2,}$', caseSensitive: false);
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _validationError = 'Email and password are required');
      return;
    }
    if (!emailRe.hasMatch(_email.text.trim())) {
      setState(() => _validationError = 'Enter a valid email address');
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
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Header ──
          Padding(
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.of(context).padding.top + 20, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => context.go(Routes.welcome),
                  child: const Icon(Symbols.arrow_back_rounded,
                      color: AppColors.inkMid, size: 24),
                ),
                const SizedBox(height: 20),
                const Text('👋', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                const Text(
                  'Welcome Back',
                  style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1.1),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Continue your FitQuest journey.',
                  style: TextStyle(color: AppColors.inkMid, fontSize: 15),
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
                  const SizedBox(height: 28),

                  if (error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
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
                          child: Text(error,
                              style: T.small(context)
                                  .copyWith(color: AppColors.coral)),
                        ),
                      ]),
                    ),

                  NeuButton.primary(
                    'Sign in',
                    loading: s.busy,
                    onPressed: s.busy ? null : _submit,
                    trailing: const Icon(Symbols.arrow_forward_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(height: 20),
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
        ],
      ),
    );
  }
}
