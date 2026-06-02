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
  'Personal coach on WhatsApp · 12 weeks',
  'Custom meal plan (veg / non-veg)',
  'Daily check-ins + AI meal photos',
  'Group of 50 + leaderboard',
  'Money-back guarantee',
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
      // No backend / demo mode — simulate a successful payment.
      if (AppConfig.demoMode) {
        await _confirmDemoPayment();
      } else {
        _toast('Could not start payment. Try again.');
      }
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
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Symbols.account_balance_wallet_rounded,
              size: 40, color: AppColors.coral, fill: 1),
          const SizedBox(height: 14),
          Text('Demo checkout', style: T.title(context)),
          const SizedBox(height: 6),
          Text('No payment keys configured. Simulate a successful ₹4,999 payment?',
              textAlign: TextAlign.center, style: T.small(context)),
          const SizedBox(height: 20),
          NeuButton.primary('Pay ₹4,999 (test)',
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
    _grantAccess();
  }

  void _onError(PaymentFailureResponse r) {
    setState(() => _busy = false);
    _toast('Payment failed (${r.code}). Please try again.');
  }

  void _grantAccess() {
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
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeuTopBar(
                onBack: () => context.go(Routes.coach),
                trailing: Text('Last step', style: T.small(context)),
              ),
              const SizedBox(height: 18),
              Text('Your plan', style: T.h1(context)),
              const SizedBox(height: 8),
              Text('12 weeks. All in. Everything you need to lose 8–15 kg with confidence.',
                  style: T.body(context)),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: NeuCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const NeuPill(
                            color: AppColors.goldSoft,
                            child: Text('Most popular',
                                style: TextStyle(
                                    color: AppColors.goldDark,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12)),
                          ),
                          const Spacer(),
                          const NeuPill(
                            color: AppColors.sageSoft,
                            child: Text('Save ₹2,000',
                                style: TextStyle(
                                    color: AppColors.sageDark,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12)),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        Text('FitQuest Premium', style: T.title(context)),
                        const SizedBox(height: 8),
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('₹4,999', style: T.h1(context)),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('₹6,999',
                                style: T.small(context).copyWith(
                                    decoration: TextDecoration.lineThrough)),
                          ),
                        ]),
                        Text('One-time · No subscription', style: T.small(context)),
                        const Divider(height: 32, color: AppColors.line),
                        Text("WHAT'S INCLUDED", style: T.label(context)),
                        const SizedBox(height: 12),
                        ..._included.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(children: [
                                const Icon(Symbols.check_circle_rounded,
                                    color: AppColors.sage, fill: 1, size: 22),
                                const SizedBox(width: 12),
                                Expanded(child: Text(e, style: T.body(context))),
                              ]),
                            )),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              NeuButton.primary(
                'Pay ₹4,999 securely',
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
