import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

const _moods = [
  (emoji: '😞', label: 'Low'),
  (emoji: '😕', label: 'Meh'),
  (emoji: '🙂', label: 'Okay'),
  (emoji: '😀', label: 'Good'),
  (emoji: '🤩', label: 'Great'),
];

class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});
  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  int _mood = 3;
  final _weight = TextEditingController(text: '74.2');
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _weight.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).postJson('/checkins', {
        'mood': _mood,
        'weight': double.tryParse(_weight.text.trim()),
        'notes': _notes.text.trim(),
      });
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 500)); // demo fallback
    }
    if (!mounted) return;
    setState(() => _busy = false);
    // Celebrate a streak milestone.
    context.pushReplacement(Routes.badge);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeuTopBar(title: 'Daily check-in', onBack: () => context.pop()),
              const SizedBox(height: 24),
              Text('How do you feel today?', style: T.title(context)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < _moods.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _mood = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _mood == i ? AppColors.coralSoft : AppColors.surface,
                          shape: BoxShape.circle,
                          boxShadow: _mood == i ? null : null,
                          border: Border.all(
                              color: _mood == i ? AppColors.coral : AppColors.line,
                              width: _mood == i ? 2 : 1),
                        ),
                        alignment: Alignment.center,
                        child: Text(_moods[i].emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              Text("Morning weight", style: T.title(context)),
              const SizedBox(height: 12),
              NeuCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Symbols.scale_rounded, color: AppColors.coral),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: T.h2(context),
                        decoration: const InputDecoration(border: InputBorder.none),
                      ),
                    ),
                    Text('kg', style: T.body(context)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('Down 1.8 kg from start (76.0 kg) · target 68 kg', style: T.small(context)),
              const SizedBox(height: 28),
              Text('Notes for your coach', style: T.title(context)),
              const SizedBox(height: 12),
              NeuTextField(
                controller: _notes,
                hint: 'Slept well, felt energetic…',
                maxLines: 3,
              ),
              const Spacer(),
              NeuButton.primary(
                'Save check-in',
                loading: _busy,
                trailing: const Icon(Symbols.check_rounded, size: 20),
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
