import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/providers/reminders_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});
  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  static const _types = [
    _ReminderDef('water', 'Water', 'Hydration reminder', Symbols.water_drop_rounded, '08:00'),
    _ReminderDef('meal', 'Meal', 'Log your meals', Symbols.restaurant_rounded, '12:00'),
    _ReminderDef('weighin', 'Weigh-in', 'Daily weight check', Symbols.monitor_weight_rounded, '07:00'),
    _ReminderDef('fasting', 'Fasting', 'Fasting window check', Symbols.timer_rounded, '20:00'),
    _ReminderDef('steps', 'Steps', 'Movement reminder', Symbols.directions_walk_rounded, '18:00'),
  ];

  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(remindersProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            NeuCard(
              depth: 0.5,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: const Icon(Symbols.arrow_back_rounded,
                      color: AppColors.inkMid, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text('Reminders',
                      style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                ),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Symbols.alarm_rounded,
                      color: AppColors.coral, size: 20, fill: 1),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            Text('DAILY REMINDERS', style: T.section(context)),
            const SizedBox(height: 4),
            Text('Set times for your health reminders',
                style: T.small(context)),
            const SizedBox(height: 16),
            ..._types.map((def) {
              final match = reminders.where((r) => r.type == def.type).toList();
              final reminder = match.isNotEmpty ? match.first : null;
              final enabled = reminder?.enabled ?? false;
              final time = reminder?.time ?? def.defaultTime;
              return _ReminderRow(
                def: def,
                enabled: enabled,
                time: time,
                onToggle: (v) {
                  ref.read(remindersProvider.notifier).save(def.type, time, v);
                },
                onTimeTap: () => _pickTime(def.type, time, enabled),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime(String type, String currentTime, bool enabled) async {
    final parts = currentTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: AppColors.coral,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      ref.read(remindersProvider.notifier).save(type, '$hh:$mm', true);
    }
  }
}

class _ReminderDef {
  const _ReminderDef(this.type, this.label, this.subtitle, this.icon, this.defaultTime);
  final String type;
  final String label;
  final String subtitle;
  final IconData icon;
  final String defaultTime;
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.def,
    required this.enabled,
    required this.time,
    required this.onToggle,
    required this.onTimeTap,
  });
  final _ReminderDef def;
  final bool enabled;
  final String time;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTimeTap;

  String _format12h(String t) {
    final parts = t.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? parts[1] : '00';
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuCard(
        depth: 0.5,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(def.icon, color: AppColors.coral, size: 22, fill: 1),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(def.label, style: T.title(context).copyWith(fontSize: 15)),
              const SizedBox(height: 2),
              Text(def.subtitle, style: T.small(context)),
            ],
          )),
          GestureDetector(
            onTap: onTimeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: enabled
                    ? AppColors.coral.withValues(alpha: 0.10)
                    : AppColors.line,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _format12h(time),
                style: TextStyle(
                  color: enabled ? AppColors.coral : AppColors.inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: enabled,
            onChanged: onToggle,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.coral,
            inactiveTrackColor: AppColors.line,
          ),
        ]),
      ),
    );
  }
}
