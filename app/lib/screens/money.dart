import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/calc.dart';
import '../logic/money.dart';
import '../main.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/insight_tile.dart';

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});
  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  final emi = TextEditingController(text: '2000');
  Map<String, dynamic>? limits;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/data/limits.json').then((s) => setState(() => limits = jsonDecode(s)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final avg = avgMonthlyProfit(repo['history'], 3);
        final w = worstMonth(repo['history']);
        final worst = w == null ? 0 : historyProfit(w);
        final goal = repo['goals'].firstOrNull;
        return SafeArea(
          bottom: false,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 120), children: [
            const TopBar('money_title'),
            const SizedBox(height: 16),
            if (goal != null) _goalHero(goal, avg),
            const SizedBox(height: 14),
            _emiCard(avg, worst),
            const SizedBox(height: 14),
            if (limits != null) _gstCard(limits!),
          ]),
        );
      },
    );
  }

  Widget _goalHero(Rec goal, num avg) {
    final g = goalPlan(goal, avg);
    final ready = g.ready;
    return HeroCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Bi(goal['name_ml'], '${goal['name_en']} · ${T.en('goal_title')}',
                  size: 15, color: Colors.white, enColor: Colors.white70, weight: FontWeight.w700)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0x24FFFFFF), borderRadius: BorderRadius.circular(99)),
            child: Text('${g.pct}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ]),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              Money(goal['saved'], style: numStyle(42, color: Colors.white)),
              Text('${T.ml('goal_saved')} · ${T.en('goal_saved')} / ${rupees(goal['target'])}',
                  style: const TextStyle(fontFamily: 'Jakarta', fontFamilyFallback: fonts, color: Colors.white70, fontSize: 13)),
            ]),
          ),
          AutoArt(pct: g.pct.toDouble(), width: 118),
        ]),
        const SizedBox(height: 12),
        HBar(g.pct / 100, gradient: goldBar, track: const Color(0x26FFFFFF), height: 8),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _darkBox('goal_left', Money(g.left, style: numStyle(18, color: Colors.white)))),
          const SizedBox(width: 10),
          Expanded(
            child: _darkBox(
              'ready_by',
              g.left == 0
                  ? Text(T.ml('goal_done'), style: const TextStyle(fontFamily: 'Malayalam', color: Colors.white, fontWeight: FontWeight.w800))
                  : ready == null
                      ? Text(T.en('goal_no_plan'), style: const TextStyle(color: Colors.white70, fontSize: 12))
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(monthsMlLong[monthIndex(ready)],
                              style: const TextStyle(fontFamily: 'Malayalam', color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                          Text('${monthsEn[monthIndex(ready)]} ${ready.substring(0, 4)} · ${g.months} ${T.en('months_word')}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ]),
            ),
          ),
        ]),
        if (g.share != null) ...[
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.account_balance_wallet_outlined, color: C.goldLight, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Bi('${rupees(goal['monthly'])} ${T.ml('per_month')} = ${T.ml('goal_share')} ${(g.share! * 100).round()}%',
                  '${rupees(goal['monthly'])} ${T.en('per_month').toLowerCase()} = ${(g.share! * 100).round()}% ${T.en('goal_share')} (${rupees(avg)})',
                  size: 14, color: Colors.white, enColor: Colors.white70, weight: FontWeight.w500),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _darkBox(String key, Widget value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${T.ml(key)} · ${T.en(key)}', style: const TextStyle(fontFamily: 'Jakarta', fontFamilyFallback: fonts, color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 2),
          value,
        ]),
      );

  Widget _emiCard(num avg, num worst) {
    final amount = num.tryParse(emi.text) ?? 0;
    final e = amount > 0 && avg > 0 ? emiCheck(amount, avg, worst) : null;
    final emis = repo['bills'].where((b) => b['type'] == 'emi').toList();
    final (bg, fg, ic) = switch (e?.level) {
      EmiLevel.ok => (C.greenSoft, C.green, Icons.check_circle_outline_rounded),
      EmiLevel.tight => (C.goldSoft, C.goldText, Icons.error_outline_rounded),
      _ => (C.redSoft, C.red, Icons.trending_down_rounded),
    };
    return MCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const IconTitle(Icons.receipt_long_outlined, 'emi_title'),
        const SizedBox(height: 10),
        Bi.k('emi_help', size: 14, weight: FontWeight.w600),
        const SizedBox(height: 8),
        TextField(
          controller: emi,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: numStyle(20, weight: FontWeight.w700),
          decoration: const InputDecoration(prefixText: '₹ '),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final n in [1000, 2000, 4000, 8000])
            ChoiceChip(
              label: Text(rupees(n), style: const TextStyle(fontWeight: FontWeight.w700)),
              selected: amount == n,
              selectedColor: C.brandSoft,
              backgroundColor: Colors.white,
              side: BorderSide(color: amount == n ? C.brand : C.line, width: 1.5),
              shape: const StadiumBorder(),
              showCheckmark: false,
              onSelected: (_) => setState(() => emi.text = '$n'),
            ),
        ]),
        if (e != null) ...[
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(ic, color: fg, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Bi(T.ml('emi_${e.level.name}'), '${T.en('emi_${e.level.name}')} · ${(e.share * 100).round()}% ${T.en('emi_takes')}',
                    size: 18, color: fg, enColor: fg, weight: FontWeight.w800),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _lightBox('after_usual', e.afterAvg)),
            const SizedBox(width: 10),
            Expanded(child: _lightBox('after_worst', e.afterWorst)),
          ]),
        ],
        if (emis.isNotEmpty) ...[
          const SizedBox(height: 10),
          Bi(emis.map((b) => '${b['label_ml'] ?? b['label_en']} ${rupees(b['amount'])}').join(', '), T.en('emi_existing'), size: 13, weight: FontWeight.w500),
        ],
        const Divider(height: 24, color: C.line),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.favorite_border_rounded, color: C.brand, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Bi.k('emi_note', size: 13, weight: FontWeight.w500)),
        ]),
      ]),
    );
  }

  Widget _lightBox(String key, num v) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Bi.k(key, size: 13),
          const SizedBox(height: 4),
          Text(rupees(v), style: numStyle(20, color: v < 0 ? C.red : C.ink)),
        ]),
      );

  Widget _gstCard(Map<String, dynamic> limits) {
    final paid = gstPaid(repo['purchases'], fyStart(), repo['history']);
    final s = gstStatus(yearTurnover(repo['sales'], repo['products'], repo['history'], fyStart()), limits);
    final g = limits['gst'] as Map<String, dynamic>;
    return MCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const IconTitle(Icons.description_outlined, 'gst_title'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Bi(T.ml('gst_paid'), T.en('gst_paid_sub'), size: 15)),
          Money(paid, style: numStyle(28, color: C.brand)),
        ]),
        const Divider(height: 24, color: C.line),
        Row(children: [
          Expanded(child: Bi.k('gst_reg', size: 15)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: s.needed ? C.redSoft : C.greenSoft, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(s.needed ? Icons.priority_high_rounded : Icons.check_rounded, size: 14, color: s.needed ? C.red : C.green),
              const SizedBox(width: 4),
              Text(T.ml(s.needed ? 'gst_needed' : 'gst_not_needed'),
                  style: TextStyle(fontFamily: 'Malayalam', fontWeight: FontWeight.w700, fontSize: 12.5, color: s.needed ? C.red : C.green)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        HBar((s.pct / 100).clamp(.01, 1)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Bi('${T.ml('year_sales')} · ${T.en('year_sales')}', rupees(s.turnover), size: 12.5, enColor: C.ink)),
          Bi('${T.ml('limit')} · ${T.en('limit')}', rupees(s.limit), size: 12.5, enColor: C.ink, align: TextAlign.end),
        ]),
        if (!s.needed) ...[
          const SizedBox(height: 8),
          Bi('${T.ml('gst_room')} ${rupees(s.left)}', '${rupees(s.left)} ${T.en('gst_room')} (${s.pct.toStringAsFixed(1)}%)', size: 13.5, weight: FontWeight.w600),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.amberSoft, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Bi.k('gst_disclaimer', size: 13.5),
            const SizedBox(height: 6),
            Row(children: [
              Icon(s.checked ? Icons.verified_outlined : Icons.info_outline_rounded, size: 14, color: C.goldText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.checked ? '${T.en('checked_on')}: ${g['date_checked']} · gst.gov.in' : '${T.en('not_checked')} · gst.gov.in',
                  style: const TextStyle(fontSize: 12, color: C.goldText, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
