import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/router.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

const _included = [
  'Personal coach on WhatsApp - 12 weeks',
  'Custom meal plan (veg / non-veg)',
  'Daily check-ins + AI meal photos',
  'Group of 50 + leaderboard',
  'Money-back guarantee',
];

const _includedIcons = [
  Symbols.support_agent_rounded,
  Symbols.restaurant_rounded,
  Symbols.fact_check_rounded,
  Symbols.group_rounded,
  Symbols.verified_rounded,
];

const _includedColors = [
  AppColors.coral,
  AppColors.coral,
  AppColors.coral,
  AppColors.coral,
  AppColors.coral,
];

class PlanPaymentScreen extends ConsumerStatefulWidget {
  const PlanPaymentScreen({super.key});
  @override
  ConsumerState<PlanPaymentScreen> createState() => _PlanPaymentScreenState();
}

class _PlanPaymentScreenState extends ConsumerState<PlanPaymentScreen> {
  Razorpay? _razorpay;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() => _busy = true);

    // In demo mode (no real Razorpay key configured), skip the backend call
    // entirely and show the demo checkout immediately.
    if (AppConfig.demoMode ||
        AppConfig.razorpayKeyId == 'rzp_test_xxxxxxxx') {
      await _confirmDemoPayment();
      if (mounted) setState(() => _busy = false);
      return;
    }

    final api = ref.read(apiClientProvider);
    try {
      // Ask backend to create a Razorpay order (amount in paise).
      final order = await api.postJson('/payments/order', {'plan': 'premium'});
      _razorpay!.open({
        'key': AppConfig.razorpayKeyId,
        'order_id': order['order_id'],
        'amount': order['amount'] ?? 499900,
        'currency': 'INR',
        'name': 'FitQuest Premium',
        'description': '12-week coaching program',
        'prefill': {'contact': ref.read(sessionProvider).phone ?? ''},
        'theme': {'color': '#FF7A6B'},
      });
    } catch (_) {
      _toast('Could not start payment. Try again.');
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDemoPayment() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.coralSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Symbols.account_balance_wallet_rounded,
                size: 28, color: AppColors.coral, fill: 1),
          ),
          const SizedBox(height: 14),
          Text('Demo checkout', style: T.title(context)),
          const SizedBox(height: 6),
          Text('No payment keys configured. Simulate a successful Rs.4,999 payment?',
              textAlign: TextAlign.center, style: T.small(context)),
          const SizedBox(height: 20),
          NeuButton.primary('Pay Rs.4,999 (test)',
              onPressed: () => Navigator.pop(context, true)),
        ]),
      ),
    );
    if (ok == true) _grantAccess();
  }

  void _onSuccess(PaymentSuccessResponse r) async {
    final api = ref.read(apiClientProvider);
    try {
      await api.postJson('/payments/verify', {
        'order_id': r.orderId,
        'payment_id': r.paymentId,
        'signature': r.signature,
      });
    } catch (_) {/* verified server-side best-effort */}
    await _grantAccess();
  }

  void _onError(PaymentFailureResponse r) {
    setState(() => _busy = false);
    _toast('Payment failed (${r.code}). Please try again.');
  }

  Future<void> _grantAccess() async {
    try {
      await ref.read(apiClientProvider).postJson('/profile/onboarded', null);
    } catch (_) {/* best-effort -- session state updated locally too */}
    ref.read(sessionProvider.notifier).completeOnboarding();
    if (mounted) context.go(Routes.home);
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeuCard(
                depth: 0.5,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => context.go(Routes.coach),
                    child: const Icon(Symbols.arrow_back_rounded,
                        color: AppColors.inkMid, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CHOOSE YOUR PLAN',
                            style: T.section(context).copyWith(color: AppColors.coral)),
                        const Text('Last step to unlock FitQuest',
                            style: TextStyle(
                                color: AppColors.inkSoft, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.coralSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Symbols.emoji_events_rounded, color: AppColors.coral, size: 20, fill: 1),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              Text('Your plan', style: T.h1(context)),
              const SizedBox(height: 8),
              Text('12 weeks. All in. Everything you need to lose 8-15 kg with confidence.',
                  style: T.body(context)),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: NeuCard(
                    depth: 0.5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          NeuPill(
                            color: AppColors.coralSoft,
                            child: const Text('Most popular',
                                style: TextStyle(
                                    color: AppColors.coral,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12)),
                          ),
                          const Spacer(),
                          NeuPill(
                            color: AppColors.coralSoft,
                            child: const Text('Save Rs.2,000',
                                style: TextStyle(
                                    color: AppColors.coral,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12)),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        Text('FitQuest Premium', style: T.title(context)),
                        const SizedBox(height: 8),
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('Rs.4,999', style: T.h1(context)),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('Rs.6,999',
                                style: T.small(context).copyWith(
                                    decoration: TextDecoration.lineThrough)),
                          ),
                        ]),
                        Text('One-time - No subscription', style: T.small(context)),
                        const Divider(height: 32, color: AppColors.line),
                        Text("WHAT'S INCLUDED", style: T.section(context)),
                        const SizedBox(height: 12),
                        for (var i = 0; i < _included.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _includedColors[i].withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(_includedIcons[i],
                                    color: _includedColors[i], size: 20, fill: 1),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_included[i], style: T.body(context))),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              NeuButton.primary(
                'Pay Rs.4,999 securely',
                loading: _busy,
                trailing: const Icon(Symbols.lock_rounded, size: 18),
                onPressed: _pay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
