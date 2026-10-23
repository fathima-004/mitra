import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/calc.dart';
import '../logic/insights.dart';
import '../logic/money.dart';
import '../main.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/insight_tile.dart';
import 'call.dart';
import 'join.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final user = repo.user;
        final month = thisMonth();
        final m = monthProfit(repo['sales'], repo['products'], repo['bills'], repo['purchases'], month);
        final todays = repo['sales'].where((s) => s['date'] == today()).toList();
        final list = insights(repo.data).take(2).toList();
        final shell = Shell.of(context);

        return SafeArea(
          bottom: false,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 120), children: [
            // Hello
            Row(children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [C.goldLight, C.gold]),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Text('${user['name_ml'] ?? 'M'}'.characters.first,
                    style: const TextStyle(fontFamily: 'Malayalam', fontSize: 20, fontWeight: FontWeight.w800, color: C.brandDeep)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Bi('${T.ml('hello')}, ${user['name_ml'] ?? ''}', '${T.en('hello')}, ${user['name'] ?? ''}', size: 21, weight: FontWeight.w800),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: C.muted),
                    const SizedBox(width: 3),
                    Text('${user['place_ml'] ?? ''} · ${user['place'] ?? ''}', style: const TextStyle(fontSize: 13, color: C.muted)),
                  ]),
                ]),
              ),
              const Text('MITRA', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2, color: C.brand, fontSize: 13)),
            ]),
            const SizedBox(height: 16),

            // This month's profit
            HeroCard(
              onTap: () => shell?.go(3),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Bi.k('month_profit', size: 15, color: Colors.white, enColor: Colors.white70, weight: FontWeight.w700)),
                  const _LiveChip(),
                ]),
                const SizedBox(height: 8),
                Money(m.profit, style: numStyle(46, color: m.profit >= 0 ? Colors.white : const Color(0xFFFFD2C7))),
                const SizedBox(height: 12),
                HBar(m.income > 0 ? m.profit / m.income : 0, gradient: goldBar, track: const Color(0x26FFFFFF), height: 8),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _Split('income', m.income, C.mint)),
                  const SizedBox(width: 10),
                  Expanded(child: _Split('spending', m.spending, C.goldLight)),
                ]),
              ]),
            ),
            const SizedBox(height: 14),

            // Savings goal on the road
            if (repo['goals'].isNotEmpty) _GoalRoad(repo['goals'].first, onTap: () => shell?.go(4)),
            if (repo['goals'].isNotEmpty) const SizedBox(height: 14),

            // Today's sales
            MCard(
              onTap: () => shell?.go(1),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Badge2(Icons.receipt_long_rounded, bg: C.goldSoft, fg: Color(0xFF9A6F0E), size: 50),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Bi(T.ml('today_sales'),
                          todays.isEmpty ? T.en('no_sales_today') : '${todays.fold<num>(0, (n, s) => n + s['qty'])} ${T.en('items_sold')}',
                          size: 16, weight: FontWeight.w700)),
                  Money(salesIncome(todays, repo['products']), style: numStyle(28)),
                ]),
                if (todays.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final p in repo['products'])
                      if (todays.any((s) => s['product'] == p['id']))
                        Container(
                          padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
                          decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(99), border: Border.all(color: C.line)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            FoodArt(p, size: 26),
                            const SizedBox(width: 6),
                            Text('${todays.where((s) => s['product'] == p['id']).fold<num>(0, (n, s) => n + s['qty'])} ',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: C.brand)),
                            Text(p['name_ml'], style: const TextStyle(fontFamily: 'Malayalam', fontWeight: FontWeight.w600)),
                          ]),
                        ),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 14),

            // Mitra, call me
            const CallMeCard(),
            const SizedBox(height: 14),

            // Mitra noticed
            if (list.isNotEmpty)
              MCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const IconTitle(Icons.auto_awesome_rounded, 'noticed_title'),
                  Rows([for (final i in list) InsightTile(i)]),
                  TextButton.icon(
                    onPressed: () => shell?.go(3),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text('${T.ml('see_all')} · ${T.en('see_all')}'),
                  ),
                ]),
              ),
            const SizedBox(height: 18),

            Center(
              child: Wrap(alignment: WrapAlignment.center, children: [
                TextButton.icon(
                  onPressed: () async {
                    await repo.loadDemo();
                    if (context.mounted) toast(context, 'reset_done', icon: Icons.restart_alt_rounded);
                  },
                  icon: const Icon(Icons.restart_alt_rounded, size: 16, color: C.muted),
                  label: Text('${T.ml('reset_demo')} · ${T.en('reset_demo')}', style: const TextStyle(color: C.muted)),
                ),
                TextButton.icon(
                  onPressed: () async {
                    (await SharedPreferences.getInstance()).setBool('joined', false);
                    if (context.mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const JoinScreen()));
                  },
                  icon: const Icon(Icons.group_outlined, size: 16, color: C.muted),
                  label: Text('${T.ml('join_link')} · ${T.en('join_link')}', style: const TextStyle(color: C.muted)),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: const Color(0x24FFFFFF), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: C.mint, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(T.en('live'), style: const TextStyle(color: C.mint, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      );
}

class _Split extends StatelessWidget {
  final String keyName;
  final num value;
  final Color dot;
  const _Split(this.keyName, this.value, this.dot);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Flexible(child: Text('${T.ml(keyName)} · ${T.en(keyName)}', overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Jakarta', fontFamilyFallback: fonts, color: Colors.white70, fontSize: 12))),
          ]),
          const SizedBox(height: 2),
          Money(value, style: numStyle(18, color: Colors.white)),
        ]),
      );
}

/// The auto drives towards the flag as she saves.
class _GoalRoad extends StatelessWidget {
  final Map<String, dynamic> goal;
  final VoidCallback onTap;
  const _GoalRoad(this.goal, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final g = goalPlan(goal, avgMonthlyProfit(repo['history'], 3));
    return MCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${goal['name_ml']} ', style: const TextStyle(fontFamily: 'Malayalam', fontWeight: FontWeight.w700, fontSize: 16)),
          Text('${g.pct}%', style: numStyle(17, color: C.brand)),
        ]),
        Text('${(goal['name_en'] as String).split(' (').first} · ${rupees(goal['saved'])} / ${rupees(goal['target'])}',
            style: const TextStyle(color: C.muted, fontSize: 13)),
        SizedBox(
          height: 78,
          child: LayoutBuilder(builder: (context, box) {
            final road = box.maxWidth - 92;
            return Stack(children: [
              Positioned(left: 0, right: 92, bottom: 6, child: HBar(g.pct / 100, gradient: C.goldLine, track: C.line, height: 6)),
              TweenAnimationBuilder<double>(
                tween: Tween(end: g.pct / 100),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (_, f, child) => Positioned(left: (road - 92).clamp(0, double.infinity) * f, bottom: 8, child: child!),
                child: AutoArt(pct: g.pct.toDouble(), width: 92),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Icon(Icons.flag_rounded, color: C.gold, size: 24),
                  Text(rupees(g.left), style: numStyle(16)),
                  Text(T.ml('goal_left'), style: const TextStyle(fontFamily: 'Malayalam', fontSize: 11, color: C.muted)),
                ]),
              ),
            ]);
          }),
        ),
      ]),
    );
  }
}
