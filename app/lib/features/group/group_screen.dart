import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class _Member {
  const _Member(this.rank, this.name, this.city, this.xp, this.trend, {this.you = false});
  final int rank;
  final String name;
  final String city;
  final int xp;
  final String trend;
  final bool you;
}

const _top3 = [
  _Member(2, 'Sunita', '', 2150, ''),
  _Member(1, 'Arjun', '', 2450, ''),
  _Member(3, 'Priya', '', 1980, ''),
];

const _members = [
  _Member(4, 'Rajesh Kumar', 'Mumbai', 1950, '↓2'),
  _Member(5, 'Meena Gupta', 'Delhi', 1920, '↑1'),
  _Member(12, 'You', '', 1840, '🔥', you: true),
  _Member(13, 'Vikram S.', 'Bangalore', 1810, '—'),
];

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});
  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  int _tab = 0; // 0 leaderboard, 1 posts, 2 coach updates

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            Row(children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Batch #47 · 50 members', style: T.small(context)),
                  Text('My group', style: T.h2(context)),
                ],
              ),
              const Spacer(),
              const NeuIconButton(icon: Symbols.notifications_rounded),
            ]),
            const SizedBox(height: 16),
            _Tabs(
              index: _tab,
              labels: const ['Leaderboard', 'Posts', 'Coach'],
              onChanged: (i) {
                if (i == 1) {
                  context.push(Routes.feed);
                } else {
                  setState(() => _tab = i);
                }
              },
            ),
            const SizedBox(height: 18),
            if (_tab == 2)
              _coachUpdates(context)
            else ...[
              Row(children: [
                const Text('🏆 ', style: TextStyle(fontSize: 18)),
                Text('Top 3 this week', style: T.title(context)),
                const Spacer(),
                const NeuPill(
                  color: AppColors.goldSoft,
                  child: Text('Win ₹500',
                      style: TextStyle(
                          color: AppColors.goldDark, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _Podium(member: _top3[0], height: 96)),
                  Expanded(child: _Podium(member: _top3[1], height: 124, crown: true)),
                  Expanded(child: _Podium(member: _top3[2], height: 80)),
                ],
              ),
              const SizedBox(height: 24),
              Text('All members', style: T.title(context)),
              const SizedBox(height: 12),
              for (final m in _members) _MemberRow(member: m),
            ],
          ],
        ),
      ),
    );
  }

  Widget _coachUpdates(BuildContext context) => Column(
        children: [
          NeuCard(
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: AppColors.berrySoft, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('P', style: T.title(context).copyWith(color: AppColors.berry)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Coach Priya · 1h ago', style: T.small(context)),
                    const SizedBox(height: 4),
                    Text('Reminder: weigh-in every morning before water. Consistency wins 💪',
                        style: T.body(context)),
                  ],
                ),
              ),
            ]),
          ),
        ],
      );
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.index, required this.labels, required this.onChanged});
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: index == i ? AppColors.coral : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(labels[i],
                    style: TextStyle(
                        color: index == i ? Colors.white : AppColors.inkSoft,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.member, required this.height, this.crown = false});
  final _Member member;
  final double height;
  final bool crown;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (crown) const Text('👑', style: TextStyle(fontSize: 22)),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: crown ? AppColors.coral : AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(color: AppColors.shadowDark, offset: Offset(3, 3), blurRadius: 8),
            ],
          ),
          alignment: Alignment.center,
          child: Text(member.name[0],
              style: TextStyle(
                  color: crown ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
        ),
        const SizedBox(height: 6),
        Text(member.name, style: T.small(context).copyWith(fontWeight: FontWeight.w700)),
        Text('${member.xp}', style: T.small(context).copyWith(fontSize: 11)),
        const SizedBox(height: 6),
        Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: crown ? AppColors.coralSoft : AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            boxShadow: const [
              BoxShadow(color: AppColors.shadowDark, offset: Offset(4, 4), blurRadius: 10),
              BoxShadow(color: AppColors.shadowLight, offset: Offset(-4, -4), blurRadius: 10),
            ],
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          child: Text('#${member.rank}',
              style: T.title(context).copyWith(
                  color: crown ? AppColors.coral : AppColors.inkMid)),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});
  final _Member member;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeuCard(
        color: member.you ? AppColors.coralSoft : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          SizedBox(
            width: 28,
            child: Text('${member.rank}',
                style: T.title(context).copyWith(
                    fontSize: 15, color: member.you ? AppColors.coral : AppColors.inkSoft)),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(member.name[0],
                style: T.title(context).copyWith(fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.you ? 'You' : member.name,
                    style: T.title(context).copyWith(fontSize: 14)),
                Text(
                    member.you
                        ? 'Keep going! 🔥'
                        : '${member.city} · ${member.trend}',
                    style: T.small(context).copyWith(fontSize: 12)),
              ],
            ),
          ),
          Text('${member.xp}',
              style: T.title(context).copyWith(
                  fontSize: 15, color: member.you ? AppColors.coral : AppColors.ink)),
        ]),
      ),
    );
  }
}
