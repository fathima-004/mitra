// Home: today's money, four big buttons, this month in one line. Owner: Hiba.
import 'package:flutter/material.dart';

import '../config.dart';
import '../data/services.dart';
import '../i18n.dart';
import '../logic/calc.dart';
import '../logic/insights.dart';
import '../logic/money.dart';
import '../main.dart';
import '../strings.dart' show rupees;
import '../ui/kit.dart';
import 'add.dart';
import 'more.dart';
import 'profit.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final todays = repo['sales'].where((s) => s['date'] == today()).toList();
          final income = salesIncome(todays, repo['products']);
          final m = monthProfit(repo['sales'], repo['products'], repo['bills'], repo['purchases'], thisMonth());
          final goal = repo['goals'].firstOrNull;
          final tips = insights(repo.data).toList();
          final name = L.ml ? (repo.user['name_ml'] ?? repo.user['name']) : (repo.user['name'] ?? repo.user['name_ml']);

          return SafeArea(
            child: RefreshIndicator(
              onRefresh: repo.syncNow,
              color: K.green,
              child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
                // Header
                Row(children: [
                  const Bubble(Icons.eco_rounded, color: Colors.white, bg: K.green, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('app_name'), style: ts(22, w: FontWeight.w800, h: 1.1)),
                      Text(tr('tagline'), style: ts(13, w: FontWeight.w500, c: K.muted)),
                    ]),
                  ),
                  if (cloudConfigured) _LiveDot(online: repo.online),
                  const LangSwitch(),
                  _Bell(count: tips.length, onTap: () => showTips(context, tips)),
                ]),
                const SizedBox(height: 18),
                Text('${tr('hello')}, $name 👋', style: ts(18, w: FontWeight.w600, c: K.muted)),
                Text(tr('todays_business'), style: ts(26, w: FontWeight.w800)),
                const SizedBox(height: 12),

                // Money received today
                Tint(
                  color: K.greenSoft,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  onTap: () => Shell.of(context)?.go(1),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('money_today'), style: ts(16, w: FontWeight.w600, c: K.greenDark)),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: income.toDouble()),
                      duration: const Duration(milliseconds: 600),
                      builder: (_, v, __) => Text(rupees(v), style: money(40, c: K.greenDark)),
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(todays.isEmpty ? Icons.schedule_rounded : Icons.arrow_upward_rounded, size: 18, color: K.green),
                      const SizedBox(width: 4),
                      Text(todays.isEmpty ? tr('no_sales_yet') : tr('from_sales', {'n': todays.length}), style: ts(14.5, w: FontWeight.w600, c: K.green)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 10),

                // Mitra rings her phone: she says what she sold, the app fills in by itself.
                const CallMeButton(),
                const SizedBox(height: 12),

                // Four big buttons
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.08,
                  children: [
                    _Tile(Icons.add_rounded, 'add_income', 'add_income_sub', K.green, K.greenSoft, () => push(context, const AddIncomeScreen())),
                    _Tile(Icons.shopping_bag_rounded, 'add_expense', 'add_expense_sub', K.red, K.redSoft, () => push(context, const AddExpenseScreen())),
                    _Tile(Icons.inventory_2_rounded, 'my_products', 'my_products_sub', K.blue, K.blueSoft, () => Shell.of(context)?.go(3)),
                    _Tile(Icons.bar_chart_rounded, 'my_profit', 'my_profit_sub', K.yellow, K.yellowSoft, () => push(context, const ProfitScreen())),
                  ],
                ),
                const SizedBox(height: 12),

                // This month, one line
                Box(
                  onTap: () => push(context, const ProfitScreen()),
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(children: [
                    const Bubble(Icons.calendar_month_rounded, color: K.yellow, bg: K.yellowSoft, size: 42),
                    const SizedBox(width: 12),
                    Expanded(child: Text(tr('this_month_profit'), style: ts(15.5, w: FontWeight.w700))),
                    Text(rupees(m.profit), style: money(20, c: m.profit >= 0 ? K.green : K.red)),
                    const Icon(Icons.chevron_right_rounded, color: K.muted),
                  ]),
                ),
                if (goal != null) ...[
                  const SizedBox(height: 10),
                  _GoalStrip(goal),
                ],
              ]),
            ),
          );
        },
      );
}

void push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final Color color, bg;
  final VoidCallback onTap;
  const _Tile(this.icon, this.title, this.sub, this.color, this.bg, this.onTap);

  @override
  Widget build(BuildContext context) => Tint(
        color: bg,
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Bubble(icon, color: Colors.white, bg: color, size: 54),
          const SizedBox(height: 10),
          Text(tr(title), textAlign: TextAlign.center, maxLines: 2, style: ts(17, w: FontWeight.w800, c: color, h: 1.15)),
          const SizedBox(height: 2),
          Text(tr(sub), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, w: FontWeight.w500, c: K.muted)),
        ]),
      );
}

class _GoalStrip extends StatelessWidget {
  final Map<String, dynamic> goal;
  const _GoalStrip(this.goal);

  @override
  Widget build(BuildContext context) {
    final g = goalPlan(goal, avgMonthlyProfit(repo['history'], 3));
    return Box(
      onTap: () => push(context, const SavingsScreen()),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Bubble(Icons.flag_rounded, color: K.purple, bg: K.purpleSoft, size: 42),
          const SizedBox(width: 12),
          Expanded(child: Text(tr('savings'), style: ts(15.5, w: FontWeight.w700))),
          Text('${g.pct}%', style: money(20, c: K.purple)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: g.pct / 100, minHeight: 10, backgroundColor: K.purpleSoft, color: K.purple),
        ),
        const SizedBox(height: 6),
        Text(
          [
            tr('goal_left', {'amt': rupees(g.left)}),
            if (g.ready != null && g.left > 0) tr('ready_by', {'when': monthName(g.ready!)})
          ].join(' · '),
          style: ts(13.5, w: FontWeight.w500, c: K.muted),
        ),
      ]),
    );
  }
}

class _LiveDot extends StatelessWidget {
  final bool online;
  const _LiveDot({required this.online});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: online ? K.green : K.muted, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(tr(online ? 'live' : 'offline'), style: ts(12, c: online ? K.green : K.muted)),
        ]),
      );
}

class _Bell extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _Bell({required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tr('mitra_noticed'),
        onPressed: onTap,
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          backgroundColor: K.red,
          child: const Icon(Icons.notifications_none_rounded, size: 28, color: K.ink),
        ),
      );
}

/// "Mitra noticed": the tips, in a sheet (they are not needed on the home page itself).
void showTips(BuildContext context, List<Insight> tips) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .75),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 18, 20, 20), children: [
          Text(tr('mitra_noticed'), style: ts(20, w: FontWeight.w800)),
          const SizedBox(height: 10),
          if (tips.isEmpty) Text(tr('nothing_here'), style: ts(15, c: K.muted)),
          for (final t in tips) TipRow(t),
        ]),
      ),
    ),
  );
}

class TipRow extends StatelessWidget {
  final Insight tip;
  const TipRow(this.tip, {super.key});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (tip.tone) {
      InsightTone.leaf => (K.green, K.greenSoft),
      InsightTone.gold => (K.yellow, K.yellowSoft),
      InsightTone.rose => (K.red, K.redSoft),
      _ => (K.blue, K.blueSoft),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Tint(
        color: bg,
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.auto_awesome_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(L.ml ? tip.ml : tip.en, style: ts(15, w: FontWeight.w600, h: 1.45))),
        ]),
      ),
    );
  }
}

class CallMeButton extends StatefulWidget {
  const CallMeButton({super.key});
  @override
  State<CallMeButton> createState() => _CallMeButtonState();
}

class _CallMeButtonState extends State<CallMeButton> {
  bool busy = false;

  Future<void> _call() async {
    setState(() => busy = true);
    final ok = await callMe();
    if (!mounted) return;
    setState(() => busy = false);
    say(context, tr(ok ? 'call_started' : 'call_unavailable'), icon: Icons.call_rounded);
  }

  @override
  Widget build(BuildContext context) => Box(
        onTap: busy ? null : _call,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          const Bubble(Icons.call_rounded, color: Colors.white, bg: K.green, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(busy ? 'calling' : 'call_me'), style: ts(16.5, w: FontWeight.w800, c: K.greenDark)),
              Text(tr('call_me_sub'), style: ts(13, w: FontWeight.w500, c: K.muted)),
            ]),
          ),
          busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: K.green))
              : const Icon(Icons.arrow_forward_rounded, color: K.green),
        ]),
      );
}
