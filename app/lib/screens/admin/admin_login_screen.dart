import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_misc.dart';
import '../../services/admin_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailCtrl.text.trim().isEmpty || _pwCtrl.text.isEmpty) {
      setState(() => _error = 'Email and password are required');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await AdminService.login(_emailCtrl.text, _pwCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      context.go('/admin-dashboard');
    } else {
      setState(() => _error = 'Invalid admin credentials. Check email and password.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
              boxShadow: [
                BoxShadow(color: AppColors.shadowDark, blurRadius: 12, offset: Offset(4, 4)),
                BoxShadow(color: AppColors.shadowLight, blurRadius: 12, offset: Offset(-4, -4)),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.of(context).padding.top + 20, 24, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Admin shield icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.coralSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Symbols.admin_panel_settings_rounded,
                    color: AppColors.coral,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'FitQuest — Restricted Access',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 14),
                ),
              ],
            ),
          ),

          // ── Form ─────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 32, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ADMIN EMAIL', style: T.label(context)),
                  const SizedBox(height: 8),
                  NeuTextField(
                    controller: _emailCtrl,
                    hint: 'admin@gmail.com',
                    keyboardType: TextInputType.emailAddress,
                    prefix: const Icon(Symbols.alternate_email_rounded,
                        color: AppColors.inkSoft, size: 20),
                  ),
                  const SizedBox(height: 20),

                  Text('PASSWORD', style: T.label(context)),
                  const SizedBox(height: 8),
                  NeuTextField(
                    controller: _pwCtrl,
                    hint: 'Admin password',
                    obscureText: _obscure,
                    prefix: const Icon(Symbols.lock_rounded,
                        color: AppColors.inkSoft, size: 20),
                    suffix: GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Icon(
                        _obscure
                            ? Symbols.visibility_rounded
                            : Symbols.visibility_off_rounded,
                        color: AppColors.inkSoft,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Error banner
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
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
                          child: Text(_error!,
                              style: T.small(context)
                                  .copyWith(color: AppColors.coral)),
                        ),
                      ]),
                    ),

                  // Login button
                  GestureDetector(
                    onTap: _loading ? null : _submit,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: _loading ? AppColors.line : AppColors.coral,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: _loading
                            ? null
                            : [
                                BoxShadow(
                                  color: AppColors.coral.withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Login as Admin',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16)),
                                  SizedBox(width: 10),
                                  Icon(Symbols.arrow_forward_rounded,
                                      color: Colors.white, size: 20),
                                ],
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go('/'),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                            text: 'Not an admin? ',
                            style: T.small(context)),
                        TextSpan(
                            text: 'Go to App',
                            style: T.small(context).copyWith(
                                color: AppColors.teal,
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
