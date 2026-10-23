// My profit and the monthly report. All maths is logic/calc.dart (plain code, never AI). Owner: Hiba.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../i18n.dart';
import '../logic/calc.dart';
import '../logic/insights.dart';
import '../logic/spend.dart';
import '../main.dart';
import '../strings.dart' show rupees;
import '../ui/kit.dart';
import 'home.dart';

/// Months she has data for, newest first.
List<String> knownMonths() {
  final set = <String>{thisMonth()};
  for (final h in repo['history']) {
    set.add('${h['month']}');
  }
  for (final s in repo['sales']) {
    set.add(monthOf('${s['date']}'));
  }
  return set.toList()..sort((a, b) => b.compareTo(a));
}

/// Income and spending for a month: live entries, or the stored totals for older months.
({num income, num spending, bool detailed}) monthTotals(String month) {
  final hasEntries = repo['sales'].any((s) => monthOf('${s['date']}') == month) || month == thisMonth();
  if (hasEntries) {
    final m = monthProfit(repo['sales'], repo['products'], repo['bills'], repo['purchases'], month);
    return (income: m.income, spending: m.spending, detailed: true);
  }
  final h = repo['history'].where((x) => x['month'] == month).firstOrNull;
  return (income: (h?['income'] as num?) ?? 0, spending: (h?['spending'] as num?) ?? 0, detailed: false);
}

class MonthPicker extends StatelessWidget {
  final String month;
  final ValueChanged<String> onChanged;
  const MonthPicker({super.key, required this.month, required this.onChanged});

  @override
  Widget build(BuildContext context) => Box(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: month,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
            style: ts(17, w: FontWeight.w700),
            items: [
              for (final m in knownMonths())
                DropdownMenuItem(value: m, child: Text(m == thisMonth() ? '${tr('this_month')} (${monthName(m)})' : monthName(m))),
            ],
            onChanged: (v) => v == null ? null : onChanged(v),
          ),
        ),
      );
}

class Donut extends StatelessWidget {
  final List<(Cat, num)> parts;
  const Donut(this.parts, {super.key});

  @override
  Widget build(BuildContext context) {
    final total = parts.fold<num>(0, (s, p) => s + p.$2);
    if (total <= 0) return Text(tr('nothing_here'), style: ts(15, c: K.muted));
    return Row(children: [
      SizedBox(
        width: 150,
        height: 150,
        child: PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 38,
          startDegreeOffset: -90,
          sections: [
            for (final (c, v) in parts) PieChartSectionData(value: v.toDouble(), color: c.color, radius: 34, showTitle: false),
          ],
        )),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (c, v) in parts.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(tr('cat_${c.key}'), style: ts(14.5, w: FontWeight.w600))),
                Text('${(v / total * 100).round()}%', style: money(14.5, w: FontWeight.w700, c: K.muted)),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

// ---------------- My profit ----------------

class ProfitScreen extends StatefulWidget {
  const ProfitScreen({super.key});
  @override
  State<ProfitScreen> createState() => _ProfitScreenState();
}

class _ProfitScreenState extends State<ProfitScreen> {
  String month = thisMonth();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final t = monthTotals(month);
          final profit = t.income - t.spending;
          final tips = month == thisMonth() ? insights(repo.data).toList() : <Insight>[];
          return Page2(
            title: tr('my_profit'),
            info: 'info_profit',
            children: [
              MonthPicker(month: month, onChanged: (m) => setState(() => month = m)),
              const SizedBox(height: 12),
              AmountCard(label: tr('total_income'), value: t.income, color: K.green, bg: K.greenSoft, icon: Icons.trending_up_rounded),
              const SizedBox(height: 10),
              AmountCard(label: tr('total_expense'), value: t.spending, color: K.red, bg: K.redSoft, icon: Icons.shopping_basket_rounded),
              const SizedBox(height: 10),
              AmountCard(
                label: profit >= 0 ? tr('my_profit') : tr('loss'),
                value: profit,
                color: profit >= 0 ? K.yellow : K.red,
                bg: K.yellowSoft,
                icon: Icons.bar_chart_rounded,
              ),
              if (t.detailed) ...[
                Heading(tr('where_spent')),
                Box(child: Donut(spendByCat(repo['bills'], repo['purchases'], month))),
              ] else
                Padding(padding: const EdgeInsets.all(16), child: Text(tr('totals_only'), textAlign: TextAlign.center, style: ts(14, c: K.muted))),
              if (tips.isNotEmpty) ...[
                Heading(tr('mitra_noticed')),
                for (final tip in tips.take(3)) TipRow(tip),
              ],
              const SizedBox(height: 8),
              BigBtn(tr('see_report'), icon: Icons.insert_chart_outlined_rounded, color: K.green, outline: true,
                  onTap: () => push(context, ReportScreen(month: month))),
            ],
          );
        },
      );
}

// ---------------- Monthly report ----------------

class ReportScreen extends StatefulWidget {
  final String? month;
  const ReportScreen({super.key, this.month});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late String month = widget.month ?? thisMonth();

  /// Income and spending per week of the month (days 1–7, 8–14, 15–21, 22–end).
  List<(num, num)> _weeks() {
    final price = {for (final p in repo['products']) p['id']: (p['price'] as num?) ?? 0};
    final inc = List<num>.filled(4, 0), out = List<num>.filled(4, 0);
    int w(String iso) => ((int.parse(iso.substring(8, 10)) - 1) ~/ 7).clamp(0, 3);
    for (final s in repo['sales'].where((s) => monthOf('${s['date']}') == month)) {
      inc[w('${s['date']}')] += ((s['qty'] as num?) ?? 0) * (price[s['product']] ?? 0);
    }
    for (final p in repo['purchases'].where((p) => monthOf('${p['date']}') == month)) {
      out[w('${p['date']}')] += (p['amount'] as num?) ?? 0;
    }
    for (final b in repo['bills'].where((b) => b['month'] == month)) {
      final due = ((b['due_day'] as num?) ?? 1).toInt().clamp(1, 31);
      out[((due - 1) ~/ 7).clamp(0, 3)] += (b['amount'] as num?) ?? 0;
    }
    return [for (var i = 0; i < 4; i++) (inc[i], out[i])];
  }

  Widget _bars(List<(String, num, num)> groups, {double height = 190}) {
    final maxY = groups.fold<num>(1, (m, g) => [m, g.$2, g.$3].reduce((a, b) => a > b ? a : b)).toDouble() * 1.15;
    return SizedBox(
      height: height,
      child: BarChart(BarChartData(
        maxY: maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(rupees(rod.toY), money(13, c: Colors.white)),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(groups[v.toInt()].$1, style: ts(12.5, c: K.muted)),
              ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < groups.length; i++)
            BarChartGroupData(x: i, barsSpace: 4, barRods: [
              BarChartRodData(toY: groups[i].$2.toDouble(), color: K.green, width: 14, borderRadius: BorderRadius.circular(4)),
              BarChartRodData(toY: groups[i].$3.toDouble(), color: K.red, width: 14, borderRadius: BorderRadius.circular(4)),
            ]),
        ],
      )),
    );
  }

  Widget _legend() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final (c, k) in [(K.green, 'income'), (K.red, 'expense')]) ...[
          Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(tr(k), style: ts(13.5, c: K.muted)),
          const SizedBox(width: 18),
        ],
      ]);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final t = monthTotals(month);
          final profit = t.income - t.spending;
          final months = knownMonths().take(6).toList().reversed.toList();
          final best = t.detailed
              ? breakdown(repo['sales'], repo['products'], repo['bills'], repo['purchases'], month).byProduct.where((r) => r.qty > 0).toList()
              : <ProductLine>[];
          return Page2(
            title: tr('monthly_report'),
            info: 'info_report',
            children: [
              MonthPicker(month: month, onChanged: (m) => setState(() => month = m)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _small(tr('income'), t.income, K.green, K.greenSoft)),
                const SizedBox(width: 10),
                Expanded(child: _small(tr('expense'), t.spending, K.red, K.redSoft)),
              ]),
              const SizedBox(height: 10),
              AmountCard(
                label: profit >= 0 ? tr('profit') : tr('loss'),
                value: profit,
                color: profit >= 0 ? K.yellow : K.red,
                bg: K.yellowSoft,
                icon: Icons.bar_chart_rounded,
              ),
              if (t.detailed) ...[
                const SizedBox(height: 14),
                Box(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                  child: Column(children: [
                    _legend(),
                    const SizedBox(height: 8),
                    _bars([for (final (i, w) in _weeks().indexed) (tr('week_n', {'n': i + 1}), w.$1, w.$2)]),
                  ]),
                ),
                if (best.isNotEmpty) ...[
                  Heading(tr('best_sellers')),
                  Box(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Column(children: [
                      for (final (i, r) in best.indexed)
                        RowItem(
                          leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: i == 0 ? K.yellowSoft : const Color(0xFFF0F1F0),
                              child: Text('${i + 1}', style: money(14, c: i == 0 ? K.yellow : K.muted))),
                          title: pick(r.product, 'name'),
                          sub: '${r.qty}',
                          trailing: Text(rupees(r.income), style: money(16, c: K.green)),
                        ),
                    ]),
                  ),
                ],
              ] else
                Padding(padding: const EdgeInsets.all(16), child: Text(tr('totals_only'), textAlign: TextAlign.center, style: ts(14, c: K.muted))),
              Heading(tr('last_6_months')),
              Box(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                child: Column(children: [
                  _legend(),
                  const SizedBox(height: 8),
                  _bars([
                    for (final m in months)
                      (monthName(m, short: true), monthTotals(m).income, monthTotals(m).spending),
                  ], height: 170),
                ]),
              ),
            ],
          );
        },
      );

  Widget _small(String label, num v, Color c, Color bg) => Tint(
        color: bg,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: ts(14.5, w: FontWeight.w600, c: c)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(rupees(v), style: money(24, c: c))),
        ]),
      );
}
