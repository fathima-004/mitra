// Savings goal + EMI check, GST & tax, government schemes (official RSS), buy together. Owner: Hiba.
// Rules (CLAUDE.md): no loans anywhere; tax screens say "guidance only"; scheme facts only from official
// sources or hand-checked files with their source URL and date.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/services.dart';
import '../i18n.dart';
import '../logic/calc.dart';
import '../logic/money.dart';
import '../main.dart';
import '../strings.dart' show rupees;
import '../ui/kit.dart';
import 'add.dart' show askNumber;

Future<void> openLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _Guidance extends StatelessWidget {
  const _Guidance();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Tint(
          color: const Color(0xFFF3F5F3),
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, color: K.muted, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(tr('guidance'), style: ts(13.5, w: FontWeight.w500, c: K.muted, h: 1.45))),
          ]),
        ),
      );
}

// ---------------- Savings goal + EMI ----------------

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});
  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  final emi = TextEditingController(text: '2000');

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final avg = avgMonthlyProfit(repo['history'], 3);
          final worst = worstMonth(repo['history']);
          final worstProfit = worst == null ? avg : historyProfit(worst);
          final goal = repo['goals'].firstOrNull;
          final amount = int.tryParse(emi.text) ?? 0;
          final check = emiCheck(amount, avg, worstProfit);
          final (vColor, vBg, vKey) = switch (check.level) {
            EmiLevel.ok => (K.green, K.greenSoft, 'emi_ok'),
            EmiLevel.tight => (K.yellow, K.yellowSoft, 'emi_tight'),
            EmiLevel.risky => (K.red, K.redSoft, 'emi_risky'),
          };
          return Page2(
            title: tr('savings'),
            info: 'info_savings',
            children: [
              if (goal != null) ...[
                () {
                  final g = goalPlan(goal, avg);
                  return Tint(
                    color: K.purpleSoft,
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Bubble(Icons.flag_rounded, color: Colors.white, bg: K.purple, size: 46),
                        const SizedBox(width: 12),
                        Expanded(child: Text(tr('savings'), style: ts(20, w: FontWeight.w800))),
                        Text('${g.pct}%', style: money(26, c: K.purple)),
                      ]),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(value: g.pct / 100, minHeight: 12, backgroundColor: Colors.white, color: K.purple),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Text(rupees(goal['saved'] ?? 0), style: money(22, c: K.purple)),
                        Text('  /  ${rupees(goal['target'] ?? 0)}', style: money(16, c: K.muted, w: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        g.left <= 0
                            ? tr('goal_reached')
                            : [
                                tr('per_month', {'amt': rupees(goal['monthly'] ?? 0)}),
                                if (g.ready != null) '${tr('ready_in', {'n': g.months})} · ${monthName(g.ready!)}',
                              ].join(' · '),
                        style: ts(14.5, w: FontWeight.w600, c: K.ink.withValues(alpha: .75)),
                      ),
                      const SizedBox(height: 14),
                      BigBtn(tr('add_saving'), icon: Icons.add_rounded, color: K.purple, onTap: () async {
                        final n = await askNumber(context, tr('add_saving'), 500);
                        if (n != null && n > 0) {
                          await repo.update('goals', goal['id'], {'saved': ((goal['saved'] as num?) ?? 0) + n});
                          if (context.mounted) say(context, tr('saved'));
                        }
                      }),
                    ]),
                  );
                }(),
              ],

              // EMI she is thinking about. Never suggests a lender or a loan.
              Heading(tr('emi_title')),
              TextField(
                controller: emi,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                style: money(26),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: tr('emi_amount'), labelStyle: ts(15, c: K.muted), prefixText: '₹ '),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final v in [1000, 2000, 4000, 8000])
                  ActionChip(
                    label: Text(rupees(v), style: money(14, w: FontWeight.w700)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: K.line),
                    onPressed: () => setState(() => emi.text = '$v'),
                  ),
              ]),
              const SizedBox(height: 10),
              if (amount > 0)
                Tint(
                  color: vBg,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(check.level == EmiLevel.ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded, color: vColor, size: 28),
                      const SizedBox(width: 10),
                      Expanded(child: Text(tr(vKey), style: ts(19, w: FontWeight.w800, c: vColor))),
                      Text(tr('emi_share', {'p': (check.share * 100).round()}), style: ts(13.5, c: K.muted)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: Text(tr('after_usual'), style: ts(14.5, w: FontWeight.w500))),
                      Text(rupees(check.afterAvg), style: money(17, c: check.afterAvg >= 0 ? K.ink : K.red)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(child: Text(tr('after_worst'), style: ts(14.5, w: FontWeight.w500))),
                      Text(rupees(check.afterWorst), style: money(17, c: check.afterWorst >= 0 ? K.ink : K.red)),
                    ]),
                  ]),
                ),
            ],
          );
        },
      );
}

// ---------------- GST & tax ----------------

class GstScreen extends StatefulWidget {
  const GstScreen({super.key});
  @override
  State<GstScreen> createState() => _GstScreenState();
}

class _GstScreenState extends State<GstScreen> {
  final amount = TextEditingController(text: '1000');
  final custom = TextEditingController();
  num rate = 5;
  bool adding = true;
  Map<String, dynamic>? limits;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/data/limits.json').then((s) => setState(() => limits = jsonDecode(s) as Map<String, dynamic>));
  }

  @override
  Widget build(BuildContext context) {
    final a = num.tryParse(amount.text) ?? 0;
    // Plain arithmetic: price × rate, or the GST inside a price that already includes it.
    final base = adding ? a : a * 100 / (100 + rate);
    final gst = adding ? a * rate / 100 : a - base;
    final total = adding ? a + gst : a;
    final paid = gstPaid(repo['purchases'], fyStart(), repo['history']);
    final status = limits == null ? null : gstStatus(yearTurnover(repo['sales'], repo['products'], repo['history'], fyStart()), limits!);
    final g = limits?['gst'] as Map<String, dynamic>?;

    return Page2(
      title: tr('gst'),
      info: 'info_gst',
      children: [
        // Calculator
        Text(tr('gst_calc'), style: ts(18, w: FontWeight.w800)),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: true, label: Text(tr('gst_add'), textAlign: TextAlign.center, style: ts(13.5, w: FontWeight.w700))),
            ButtonSegment(value: false, label: Text(tr('gst_remove'), textAlign: TextAlign.center, style: ts(13.5, w: FontWeight.w700))),
          ],
          selected: {adding},
          onSelectionChanged: (s) => setState(() => adding = s.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]')), LengthLimitingTextInputFormatter(10)],
          style: money(26),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: adding ? tr('price_before') : tr('price_after'), labelStyle: ts(15, c: K.muted), prefixText: '₹ '),
        ),
        const SizedBox(height: 10),
        Text(tr('gst_rate'), style: ts(14.5, w: FontWeight.w700, c: K.muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final r in [0, 5, 18, 40])
            ChoiceChip(
              label: Text('$r%', style: money(15, w: FontWeight.w700, c: rate == r && custom.text.isEmpty ? Colors.white : K.ink)),
              selected: rate == r && custom.text.isEmpty,
              showCheckmark: false,
              selectedColor: K.green,
              backgroundColor: Colors.white,
              side: const BorderSide(color: K.line),
              onSelected: (_) => setState(() {
                rate = r;
                custom.clear();
              }),
            ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: custom,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]')), LengthLimitingTextInputFormatter(5)],
              style: money(15, w: FontWeight.w700),
              onChanged: (v) => setState(() => rate = num.tryParse(v) ?? 0),
              decoration: InputDecoration(hintText: tr('other_rate'), hintStyle: ts(14, c: K.muted), suffixText: '%', isDense: true),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Tint(
          color: K.greenSoft,
          child: Column(children: [
            for (final (k, v, big) in [('price_before', base, false), ('gst_amount', gst, false), ('price_after', total, true)])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(k == 'gst_amount' ? '${tr(k)} ($rate%)' : tr(k), style: ts(15, w: big ? FontWeight.w800 : FontWeight.w600))),
                  Text('₹${v.toStringAsFixed(2)}', style: money(big ? 22 : 17, c: big ? K.greenDark : K.ink)),
                ]),
              ),
          ]),
        ),

        // GST she already paid
        Heading(tr('gst_paid_year')),
        AmountCard(label: tr('gst_paid_note'), value: paid, color: K.blue, bg: K.blueSoft, icon: Icons.receipt_long_rounded),

        // Registration
        if (status != null && g != null) ...[
          Heading(tr('gst_reg')),
          Box(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(status.needed ? Icons.warning_amber_rounded : Icons.check_circle_rounded, color: status.needed ? K.red : K.green, size: 28),
                const SizedBox(width: 10),
                Text(tr(status.needed ? 'gst_needed' : 'gst_not_needed'), style: ts(19, w: FontWeight.w800, c: status.needed ? K.red : K.green)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Text(tr('year_sales'), style: ts(14.5, w: FontWeight.w500))),
                Text('${rupees(status.turnover)} / ${rupees(status.limit)}', style: money(15, w: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: status.pct / 100, minHeight: 10, backgroundColor: K.greenSoft, color: status.needed ? K.red : K.green),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Icon(status.checked ? Icons.verified_outlined : Icons.info_outline_rounded, size: 16, color: status.checked ? K.green : K.yellow),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(status.checked ? '${tr('checked_on')}: ${g['date_checked']} · gst.gov.in' : '${tr('limit_unchecked')} · gst.gov.in',
                      style: ts(12.5, w: FontWeight.w500, c: K.muted)),
                ),
              ]),
            ]),
          ),
        ],
        const _Guidance(),
      ],
    );
  }
}

// ---------------- Government schemes ----------------

class SchemesScreen extends StatefulWidget {
  const SchemesScreen({super.key});
  @override
  State<SchemesScreen> createState() => _SchemesScreenState();
}

class _SchemesScreenState extends State<SchemesScreen> {
  late Future<NewsResult> news = governmentNews();
  late final Future<List<Rec>> open = openSchemes();
  bool all = false;

  /// Non-loan schemes she can join now (assets/data/schemes.json): only entries checked on the official page
  /// (source_url + date_checked), and whose last date to apply (open_until) hasn't passed.
  static Future<List<Rec>> openSchemes() async {
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/data/schemes.json'));
      final list = j is List ? j : (j as Map)['schemes'] as List? ?? const [];
      final day = today();
      return [
        for (final x in list)
          if (x is Map &&
              '${x['source_url'] ?? ''}'.startsWith('http') &&
              '${x['date_checked'] ?? ''}'.isNotEmpty &&
              x['loan'] != true &&
              (x['open_until'] == null || '${x['open_until']}'.compareTo(day) >= 0))
            Map<String, dynamic>.from(x),
      ];
    } catch (_) {
      return [];
    }
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 19, color: K.teal),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: ts(14.5, w: FontWeight.w500, h: 1.45))),
        ]),
      );

  Widget _scheme(Rec s) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Box(
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              leading: const Bubble(Icons.verified_user_rounded, color: K.teal, bg: K.tealSoft, size: 44),
              title: Text(pick(s, 'title'), style: ts(16.5, w: FontWeight.w800)),
              subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(pick(s, 'about'), style: ts(14, w: FontWeight.w500, c: K.muted))),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pick(s, 'cost').isNotEmpty) _line(Icons.payments_outlined, pick(s, 'cost')),
                if (pick(s, 'who').isNotEmpty) _line(Icons.person_outline_rounded, pick(s, 'who')),
                if ((s['documents'] as List?)?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 10),
                  Text(tr('documents'), style: ts(14.5, w: FontWeight.w800)),
                  for (final d in s['documents'] as List)
                    _line(Icons.check_box_outline_blank_rounded, d is Map ? '${(L.ml ? d['ml'] ?? d['en'] : d['en'] ?? d['ml']) ?? ''}' : '$d'),
                ],
                if (pick(s, 'how').isNotEmpty) _line(Icons.place_outlined, pick(s, 'how')),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => openLink('${s['source_url']}'),
                  child: Text('${tr('checked_on')}: ${dayName('${s['date_checked']}')} · ${Uri.tryParse('${s['source_url']}')?.host ?? ''}',
                      style: ts(12.5, c: K.blue)),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Page2(
        title: tr('schemes'),
        info: 'info_schemes',
        children: [
          FutureBuilder<List<Rec>>(
            future: open,
            builder: (context, snap) {
              final list = snap.data ?? const [];
              if (list.isEmpty) return const SizedBox();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Heading(tr('open_schemes')),
                for (final s in list) _scheme(s),
              ]);
            },
          ),
          FutureBuilder<NewsResult>(
            future: news,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const SizedBox();
              final r = snap.data!;
              final items = all ? r.items : r.items.where((n) => n.relevant).toList();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (items.isNotEmpty) ...[
                  Heading(tr('from_govt')),
                  if (r.fromCache && r.fetched != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('${tr('offline_saved')} ${dayName(isoDate(r.fetched!))}', style: ts(13, c: K.yellow)),
                    ),
                  for (final n in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Box(
                        onTap: () => openLink(n.link),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Bubble(n.relevant ? Icons.campaign_rounded : Icons.article_outlined, color: K.blue, bg: K.blueSoft, size: 42),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(n.title, style: const TextStyle(fontFamily: 'Jakarta', fontSize: 15, fontWeight: FontWeight.w700, height: 1.35)),
                              const SizedBox(height: 4),
                              Text(tr('pib_source'), style: ts(12.5, c: K.muted)),
                            ]),
                          ),
                          const Icon(Icons.open_in_new_rounded, size: 18, color: K.muted),
                        ]),
                      ),
                    ),
                ],
                if (r.items.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => all = !all),
                    child: Text(all ? tr('schemes_only') : tr('show_all_news'), style: ts(15, w: FontWeight.w700, c: K.green)),
                  ),
              ]);
            },
          ),
        ],
      );
}

// ---------------- Buy together ----------------

class BulkScreen extends StatelessWidget {
  const BulkScreen({super.key});

  Future<void> _join(BuildContext context, Rec sample) async {
    final qty = await askNumber(context, '${pick(sample, 'item')} · ${tr('how_much_need')} (${sample['unit'] ?? ''})', 10);
    if (qty == null || qty <= 0) return;
    await repo.addBulk({
      'user': 'demo1',
      'name': repo.user['name'] ?? '',
      'month': sample['month'],
      'item': sample['item'],
      'item_ml': sample['item_ml'],
      'qty': qty,
      'unit': sample['unit'],
      'place': repo.user['place'] ?? sample['place'],
    });
    if (context.mounted) say(context, tr('saved'));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final groups = <String, List<Rec>>{};
          for (final r in repo.bulk) {
            groups.putIfAbsent('${r['month']}|${r['item']}', () => []).add(r);
          }
          return Page2(
            title: tr('bulk'),
            info: 'info_bulk',
            children: [
              if (groups.isEmpty) Text(tr('nothing_here'), style: ts(15, c: K.muted)),
              for (final rows in groups.values) ...[
                Box(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Bubble(Icons.groups_rounded, color: K.orange, bg: K.orangeSoft, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(pick(rows.first, 'item'), style: ts(18, w: FontWeight.w800)),
                          Text('${monthName('${rows.first['month']}')} · ${rows.first['place'] ?? ''}', style: ts(13, c: K.muted)),
                        ]),
                      ),
                      Text('${rows.fold<num>(0, (s, r) => s + ((r['qty'] as num?) ?? 0))} ${rows.first['unit'] ?? ''}', style: money(20, c: K.orange)),
                    ]),
                    const SizedBox(height: 10),
                    Text(tr('women_together', {'n': rows.length}), style: ts(14.5, w: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final r in rows)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: r['user'] == 'demo1' ? K.greenSoft : const Color(0xFFF3F5F3), borderRadius: BorderRadius.circular(20)),
                          child: Text('${r['name'] ?? ''} · ${r['qty']} ${r['unit'] ?? ''}', style: ts(13, w: FontWeight.w600)),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    if (rows.any((r) => r['user'] == 'demo1'))
                      Row(children: [
                        const Icon(Icons.check_circle_rounded, color: K.green),
                        const SizedBox(width: 8),
                        Text(tr('you_are_in'), style: ts(15, w: FontWeight.w700, c: K.green)),
                      ])
                    else
                      BigBtn(tr('join_group'), icon: Icons.add_rounded, color: K.orange, onTap: () => _join(context, rows.first)),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      );
}
