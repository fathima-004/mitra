import 'package:flutter/material.dart';

import '../logic/calc.dart';
import '../logic/insights.dart';
import '../main.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/insight_tile.dart';

class ProfitScreen extends StatelessWidget {
  const ProfitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final month = thisMonth();
        final m = monthProfit(repo['sales'], repo['products'], repo['bills'], repo['purchases'], month);
        final avg = avgMonthlyProfit(repo['history'], 3);
        final now = DateTime.now();
        final monthDone = now.day / DateTime(now.year, now.month + 1, 0).day;
        final reached = avg > 0 ? (m.profit / avg * 100).round() : 0;
        final onTrack = avg > 0 && m.profit / avg >= monthDone;
        final b = breakdown(repo['sales'], repo['products'], repo['bills'], repo['purchases'], month);
        final list = insights(repo.data);

        final history = [...repo['history']]..sort((a, b) => (a['month'] as String).compareTo(b['month']));
        final series = [
          for (final h in history.skip(history.length > 6 ? history.length - 6 : 0)) (month: h['month'] as String, profit: historyProfit(h), now: false),
          (month: month, profit: m.profit, now: true),
        ];

        return SafeArea(
          bottom: false,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 120), children: [
            const TopBar('profit_title'),
            const SizedBox(height: 16),
            HeroCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Bi.k('month_profit', size: 15, color: Colors.white, enColor: Colors.white70, weight: FontWeight.w700)),
                  if (avg > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0x24FFFFFF), borderRadius: BorderRadius.circular(99)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(onTrack ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('$reached% ${T.en('of_usual')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                      ]),
                    ),
                ]),
                const SizedBox(height: 8),
                Money(m.profit, style: numStyle(46, color: m.profit >= 0 ? Colors.white : const Color(0xFFFFD2C7))),
                const SizedBox(height: 12),
                HBar(m.income > 0 ? m.profit / m.income : 0, gradient: goldBar, track: const Color(0x26FFFFFF), height: 8),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _Box('income', m.income)),
                  const SizedBox(width: 10),
                  Expanded(child: _Box('spending', m.spending)),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            if (list.isNotEmpty) ...[
              MCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const IconTitle(Icons.auto_awesome_rounded, 'noticed_title'),
                  Rows([for (final i in list) InsightTile(i)]),
                ]),
              ),
              const SizedBox(height: 14),
            ],
            MCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Bi.k('chart_title', size: 16, weight: FontWeight.w700),
                const SizedBox(height: 12),
                _Chart(series),
              ]),
            ),
            const SizedBox(height: 14),
            MCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Bi.k('best_title', size: 16, weight: FontWeight.w700),
                Rows([
                  for (final (i, x) in b.byProduct.indexed)
                    Row(children: [
                      FoodArt(x.product, size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Bi(x.product['name_ml'], '${x.product['name_en']} · ${x.qty} ${T.en('items_sold')}', size: 15)),
                            Text(rupees(x.income), style: numStyle(15, weight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 6),
                          HBar(b.byProduct.first.income > 0 ? x.income / b.byProduct.first.income : 0,
                              gradient: i == 0 ? goldBar : const LinearGradient(colors: [C.brand, Color(0xFF2AA58A)])),
                        ]),
                      ),
                    ]),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            MCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Bi.k('spend_title', size: 16, weight: FontWeight.w700),
                Rows([
                  for (final x in b.bySpend)
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Bi(x.labelMl, x.labelEn, size: 15)),
                        Text(rupees(x.amount), style: numStyle(15, weight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 6),
                      HBar(b.bySpend.first.amount > 0 ? x.amount / b.bySpend.first.amount : 0, gradient: goldBar),
                    ]),
                ]),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class _Box extends StatelessWidget {
  final String keyName;
  final num value;
  const _Box(this.keyName, this.value);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${T.ml(keyName)} · ${T.en(keyName)}', style: const TextStyle(fontFamily: 'Jakarta', fontFamilyFallback: fonts, color: Colors.white70, fontSize: 12)),
          Money(value, style: numStyle(18, color: Colors.white)),
        ]),
      );
}

/// Monthly profit bars: finished months + this month so far (gold).
class _Chart extends StatelessWidget {
  final List<({String month, num profit, bool now})> series;
  const _Chart(this.series);

  @override
  Widget build(BuildContext context) {
    final max = series.map((s) => s.profit.abs()).fold<num>(1, (a, b) => b > a ? b : a);
    final best = series.reduce((a, b) => b.profit > a.profit ? b : a);
    return SizedBox(
      height: 220,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final s in series)
          Expanded(
            child: Tooltip(
              message: '${monthsEn[monthIndex(s.month)]} · ${rupees(s.profit)}',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (s.now || s == best) FittedBox(child: Text(rupees(s.profit), style: numStyle(11, weight: FontWeight.w700))),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: (s.profit.clamp(0, max) / max).toDouble()),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, f, __) => Container(
                      height: 4 + 150 * f,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        gradient: s.now
                            ? const LinearGradient(colors: [Color(0xFFF0D27A), C.gold], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                            : null,
                        color: s.now ? null : const Color(0xFFB9DDD1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(monthsMl[monthIndex(s.month)], style: const TextStyle(fontFamily: 'Malayalam', fontSize: 11, fontWeight: FontWeight.w700)),
                  Text(monthsEn[monthIndex(s.month)], style: const TextStyle(fontSize: 10, color: C.muted)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}
