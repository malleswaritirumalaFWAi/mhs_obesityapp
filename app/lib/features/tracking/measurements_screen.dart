import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class MeasurementsScreen extends ConsumerStatefulWidget {
  const MeasurementsScreen({super.key});
  @override
  ConsumerState<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends ConsumerState<MeasurementsScreen> {
  final _waist  = TextEditingController();
  final _hips   = TextEditingController();
  final _chest  = TextEditingController();
  final _arms   = TextEditingController();
  final _weight = TextEditingController();
  bool _saving = false;
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _latest;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _waist.dispose(); _hips.dispose(); _chest.dispose(); _arms.dispose(); _weight.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(apiClientProvider).getJson('/measurements');
      final latest = d['latest'] as Map<String, dynamic>?;
      final history = (d['history'] as List? ?? []).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _latest = latest;
          _history = history;
          if (latest != null) {
            _waist.text  = (latest['waist']  ?? '').toString();
            _hips.text   = (latest['hips']   ?? '').toString();
            _chest.text  = (latest['chest']  ?? '').toString();
            _arms.text   = (latest['arms']   ?? '').toString();
            _weight.text = (latest['weight'] ?? '').toString();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).postJson('/measurements', {
        if (_waist.text.isNotEmpty)  'waist':  double.tryParse(_waist.text),
        if (_hips.text.isNotEmpty)   'hips':   double.tryParse(_hips.text),
        if (_chest.text.isNotEmpty)  'chest':  double.tryParse(_chest.text),
        if (_arms.text.isNotEmpty)   'arms':   double.tryParse(_arms.text),
        if (_weight.text.isNotEmpty) 'weight': double.tryParse(_weight.text),
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Measurements saved! +10 XP'), backgroundColor: AppColors.sage));
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.tealGrad,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Symbols.arrow_back_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Body Measurements',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                      Text('Track your physical changes',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const Text('📏', style: TextStyle(fontSize: 26)),
              ]),
            ),
            const SizedBox(height: 20),

            if (_latest != null)
              NeuCard(
                color: AppColors.sageSoft,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Last recorded', style: T.label(context).copyWith(color: AppColors.sageDark)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 16, runSpacing: 8, children: [
                    for (final e in [
                      ('Waist', '${_latest!['waist'] ?? '--'} cm'),
                      ('Hips',  '${_latest!['hips']  ?? '--'} cm'),
                      ('Chest', '${_latest!['chest'] ?? '--'} cm'),
                      ('Arms',  '${_latest!['arms']  ?? '--'} cm'),
                    ])
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.$1, style: T.small(context).copyWith(fontSize: 11)),
                        Text(e.$2, style: T.title(context).copyWith(fontSize: 16)),
                      ]),
                  ]),
                ]),
              ),
            const SizedBox(height: 20),

            Text('Log measurements', style: T.title(context)),
            const SizedBox(height: 12),
            _Field(ctrl: _waist,  label: 'Waist (cm)',   icon: Symbols.straighten_rounded),
            _Field(ctrl: _hips,   label: 'Hips (cm)',    icon: Symbols.straighten_rounded),
            _Field(ctrl: _chest,  label: 'Chest (cm)',   icon: Symbols.straighten_rounded),
            _Field(ctrl: _arms,   label: 'Arms (cm)',    icon: Symbols.fitness_center_rounded),
            _Field(ctrl: _weight, label: 'Weight (kg)',  icon: Symbols.scale_rounded),
            const SizedBox(height: 8),

            NeuButton.primary(
              'Save measurements',
              trailing: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Symbols.save_rounded, size: 20),
              onPressed: _saving ? null : _save,
            ),

            if (_history.length > 1) ...[
              const SizedBox(height: 24),
              Text('History', style: T.title(context)),
              const SizedBox(height: 12),
              ..._history.take(5).map((m) {
                final dt = DateTime.tryParse(m['created_at'] as String? ?? '');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: NeuCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Expanded(child: Text(
                        dt != null ? '${dt.day}/${dt.month}/${dt.year}' : '',
                        style: T.title(context).copyWith(fontSize: 14),
                      )),
                      for (final e in [
                        ('W', m['waist']), ('H', m['hips']),
                        ('C', m['chest']), ('A', m['arms']),
                      ])
                        if (e.$2 != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text('${e.$1}: ${e.$2}', style: T.small(context)),
                          ),
                    ]),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.ctrl, required this.label, required this.icon});
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuCard(
        padding: EdgeInsets.zero,
        child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: AppColors.coral, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }
}
