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
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
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
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Full name is required';
    final digits = _phone.text.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return 'Enter a valid 10-digit phone number';
    final emailRe = RegExp(r'^[\w.+-]+@[\w-]+\.[a-z]{2,}$', caseSensitive: false);
    if (!emailRe.hasMatch(_email.text.trim())) return 'Enter a valid email address';
    if (_password.text.length < 8) return 'Password must be at least 8 characters';
    if (_password.text != _confirm.text) return 'Passwords do not match';
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
          _phone.text.trim().replaceAll(RegExp(r'\D'), ''),
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
                const Text('🏆', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                const Text(
                  'Join FitQuest',
                  style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1.1),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Start your 12-week transformation today.',
                  style: TextStyle(color: AppColors.inkMid, fontSize: 15),
                ),
              ],
            ),
          ),

          // ── Form ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FULL NAME', style: T.label(context)),
                  const SizedBox(height: 8),
                  NeuTextField(
                    controller: _name,
                    hint: 'Aarav Sharma',
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  Text('PHONE NUMBER', style: T.label(context)),
                  const SizedBox(height: 8),
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
                  ),
                  const SizedBox(height: 16),

                  Text('EMAIL', style: T.label(context)),
                  const SizedBox(height: 8),
                  NeuTextField(
                    controller: _email,
                    hint: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

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
                  const SizedBox(height: 16),

                  Text('CONFIRM PASSWORD', style: T.label(context)),
                  const SizedBox(height: 8),
                  NeuTextField(
                    controller: _confirm,
                    hint: 'Re-enter password',
                    obscureText: _obscureConfirm,
                    suffix: GestureDetector(
                      onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      child: Icon(
                        _obscureConfirm
                            ? Symbols.visibility_rounded
                            : Symbols.visibility_off_rounded,
                        color: AppColors.inkSoft,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

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
                    'Create account',
                    loading: s.busy,
                    onPressed: s.busy ? null : _submit,
                    trailing: const Icon(Symbols.arrow_forward_rounded,
                        color: Colors.white, size: 20),
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
                  const SizedBox(height: 12),
                  Center(
                    child: Text('🔒 Your data is safe and never shared.',
                        style: T.small(context)),
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
