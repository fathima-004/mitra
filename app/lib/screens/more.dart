// More: everything that isn't a daily task, as one simple list. Owner: Hiba.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/services.dart';
import '../i18n.dart';
import '../logic/calc.dart';
import '../logic/spend.dart';
import '../main.dart';
import '../strings.dart' show rupees;
import '../ui/kit.dart';
import 'home.dart' show push;
import 'profit.dart';
import 'tools.dart';

export 'tools.dart';

class _Item {
  final IconData icon;
  final Color color;
  final String title, sub;
  final void Function(BuildContext) onTap;
  const _Item(this.icon, this.color, this.title, this.sub, this.onTap);
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static final _groups = <List<_Item>>[
    [
      _Item(Icons.insert_chart_rounded, K.green, 'monthly_report', 'last_6_months', (c) => push(c, const ReportScreen())),
      _Item(Icons.receipt_rounded, K.red, 'monthly_bills', 'monthly_bills_sub', (c) => push(c, const BillsScreen())),
      _Item(Icons.flag_rounded, K.purple, 'savings', 'savings_sub', (c) => push(c, const SavingsScreen())),
      _Item(Icons.calculate_rounded, K.blue, 'gst', 'gst_sub', (c) => push(c, const GstScreen())),
    ],
    [
      _Item(Icons.account_balance_rounded, K.teal, 'schemes', 'schemes_sub', (c) => push(c, const SchemesScreen())),
      _Item(Icons.groups_rounded, K.orange, 'bulk', 'bulk_sub', (c) => push(c, const BulkScreen())),
      const _Item(Icons.call_rounded, K.green, 'call_me', 'call_me_sub', _callMe),
      _Item(Icons.favorite_rounded, K.pink, 'support', 'support_sub', (c) => push(c, const SupportScreen())),
    ],
    [
      _Item(Icons.storefront_rounded, K.blue, 'business_details', 'business_details_sub', (c) => push(c, const BusinessScreen())),
      const _Item(Icons.translate_rounded, K.orange, 'language', '', _language),
      _Item(Icons.help_rounded, K.yellow, 'help', 'help_sub', (c) => push(c, const HelpScreen())),
    ],
  ];

  static Future<void> _callMe(BuildContext context) async {
    say(context, tr('calling'), icon: Icons.call_rounded);
    final ok = await callMe();
    if (context.mounted) say(context, tr(ok ? 'call_started' : 'call_unavailable'), icon: Icons.call_rounded);
  }

  static void _language(BuildContext context) => L.set(L.ml ? 'en' : 'ml');

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr('more'), style: ts(19, w: FontWeight.w800)), actions: const [LangSwitch(), SizedBox(width: 8)]),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          for (final group in _groups) ...[
            Box(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(children: [
                for (final (i, it) in group.indexed) ...[
                  if (i > 0) const Divider(height: 1, color: K.line),
                  RowItem(
                    leading: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: it.color, borderRadius: BorderRadius.circular(13)),
                      child: Icon(it.icon, color: Colors.white, size: 26),
                    ),
                    title: tr(it.title),
                    sub: it.title == 'language' ? (L.ml ? 'മലയാളം  →  English' : 'English  →  മലയാളം') : tr(it.sub),
                    trailing: const Icon(Icons.chevron_right_rounded, color: K.muted),
                    onTap: () => it.onTap(context),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 14),
          ],
          TextButton.icon(
            onPressed: () async {
              await repo.loadDemo();
              if (context.mounted) say(context, tr('reset_done'), icon: Icons.restart_alt_rounded);
            },
            icon: const Icon(Icons.restart_alt_rounded, color: K.muted),
            label: Text(tr('reset_demo'), style: ts(15, c: K.muted)),
          ),
          TextButton.icon(
            onPressed: () => logOut(context),
            icon: const Icon(Icons.logout_rounded, color: K.red),
            label: Text(tr('logout'), style: ts(15, c: K.red)),
          ),
        ]),
      );
}

// ---------------- Business details ----------------

class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key});
  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  late final name = TextEditingController(text: pick(repo.user, 'name').isEmpty ? '${repo.user['name'] ?? ''}' : pick(repo.user, 'name'));
  late final place = TextEditingController(text: pick(repo.user, 'place').isEmpty ? '${repo.user['place'] ?? ''}' : pick(repo.user, 'place'));

  @override
  Widget build(BuildContext context) => Page2(
        title: tr('business_details'),
        bottom: BigBtn(tr('save'), icon: Icons.check_circle_rounded, onTap: () async {
          final suffix = L.ml ? '_ml' : '';
          await repo.setUser({'name$suffix': name.text.trim(), 'place$suffix': place.text.trim()});
          if (context.mounted) {
            say(context, tr('saved'));
            Navigator.pop(context);
          }
        }),
        children: [
          const Center(child: Bubble(Icons.storefront_rounded, color: Colors.white, bg: K.blue, size: 84)),
          const SizedBox(height: 20),
          TextField(controller: name, style: ts(18), decoration: InputDecoration(labelText: tr('your_name'), prefixIcon: const Icon(Icons.person_rounded))),
          const SizedBox(height: 12),
          TextField(controller: place, style: ts(18), decoration: InputDecoration(labelText: tr('your_place'), prefixIcon: const Icon(Icons.place_rounded))),
          const SizedBox(height: 12),
          Box(
            child: RowItem(
              leading: const Icon(Icons.phone_rounded, color: K.muted),
              title: '+91 98765 43210',
              sub: tr('phone'),
            ),
          ),
        ],
      );
}

// ---------------- Monthly bills (gas, rent, EMIs she already pays) ----------------

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  static const _types = ['gas', 'electricity', 'rent', 'transport', 'phone', 'emi', 'other'];

  Future<void> _add(BuildContext context) async {
    var type = 'gas';
    final amount = TextEditingController();
    final due = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr('add_bill'), style: ts(20, w: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in _types)
                  ChoiceChip(
                    avatar: Icon(catBy(t).icon, size: 18, color: type == t ? Colors.white : catBy(t).color),
                    label: Text(tr('cat_$t'), style: ts(14, w: FontWeight.w700, c: type == t ? Colors.white : K.ink)),
                    selected: type == t,
                    showCheckmark: false,
                    selectedColor: K.red,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: K.line),
                    onSelected: (_) => setLocal(() => type = t),
                  ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                style: money(24),
                onChanged: (_) => setLocal(() {}),
                decoration: InputDecoration(labelText: tr('amount'), prefixText: '₹ '),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: due,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                style: money(18, w: FontWeight.w600),
                decoration: InputDecoration(labelText: tr('due_day')),
              ),
              const SizedBox(height: 16),
              BigBtn(tr('save'), icon: Icons.check_circle_rounded, color: K.red,
                  onTap: (int.tryParse(amount.text) ?? 0) > 0 ? () => Navigator.pop(ctx, true) : null),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    final day = int.tryParse(due.text);
    await repo.add('bills', {
      'month': thisMonth(),
      'type': type,
      'label_ml': L.ml ? tr('cat_$type') : null,
      'label_en': L.ml ? null : tr('cat_$type'),
      'amount': int.parse(amount.text),
      if (day != null && day >= 1 && day <= 31) 'due_day': day,
    }..removeWhere((k, v) => v == null));
    if (context.mounted) say(context, tr('saved'));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final bills = repo['bills'].where((b) => b['month'] == thisMonth()).toList();
          final total = bills.fold<num>(0, (s, b) => s + ((b['amount'] as num?) ?? 0));
          return Page2(
            title: tr('monthly_bills'),
            bottom: BigBtn(tr('add_bill'), icon: Icons.add_rounded, color: K.red, onTap: () => _add(context)),
            children: [
              AmountCard(label: '${tr('total')} · ${monthName(thisMonth())}', value: total, color: K.red, bg: K.redSoft, icon: Icons.receipt_rounded),
              const SizedBox(height: 12),
              for (final b in bills)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Box(
                    padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                    child: RowItem(
                      leading: Bubble(catBy(catOfBill(b)).icon, color: catBy(catOfBill(b)).color, bg: catBy(catOfBill(b)).bg, size: 42),
                      title: pick(b, 'label').isEmpty ? tr('cat_${catOfBill(b)}') : pick(b, 'label'),
                      sub: b['due_day'] == null ? null : '${tr('due_day')}: ${b['due_day']}',
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(rupees(b['amount'] ?? 0), style: money(17)),
                        IconButton(
                          tooltip: tr('delete'),
                          icon: const Icon(Icons.close_rounded, color: K.muted),
                          onPressed: () async {
                            final row = Map<String, dynamic>.from(b);
                            await repo.remove('bills', row['id']);
                            if (context.mounted) {
                              say(context, tr('removed'),
                                  action: SnackBarAction(label: tr('undo'), textColor: K.yellowSoft, onPressed: () => repo.add('bills', row)));
                            }
                          },
                        ),
                      ]),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

// ---------------- Someone to talk to ----------------

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  // Helplines only from data/support.json, checked on the official site with URL and date (CLAUDE.md).
  static Future<List<Rec>> _helplines() async {
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/data/support.json'));
      final list = j is List ? j : (j as Map)['helplines'] as List? ?? const [];
      return [
        for (final x in list)
          if (x is Map && '${x['source_url'] ?? ''}'.startsWith('http') && '${x['date_checked'] ?? ''}'.isNotEmpty && x['number'] != null)
            Map<String, dynamic>.from(x),
      ];
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) => Page2(
        title: tr('support'),
        children: [
          Tint(
            color: K.pinkSoft,
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              const Bubble(Icons.favorite_rounded, color: Colors.white, bg: K.pink, size: 52),
              const SizedBox(width: 14),
              Expanded(child: Text(tr('support_line'), style: ts(16, w: FontWeight.w600, h: 1.45))),
            ]),
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<Rec>>(
            future: _helplines(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const SizedBox();
              final list = snap.data ?? const [];
              if (list.isEmpty) {
                return Tint(
                  color: const Color(0xFFF3F5F3),
                  child: Row(children: [
                    const Icon(Icons.fact_check_outlined, color: K.muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(tr('being_checked'), style: ts(15, c: K.muted))),
                  ]),
                );
              }
              return Column(children: [
                for (final h in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Box(
                      onTap: () => openLink('tel:${'${h['number']}'.replaceAll(' ', '')}'),
                      child: Row(children: [
                        const Bubble(Icons.call_rounded, color: Colors.white, bg: K.green, size: 50),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(pick(h, 'name'), style: ts(17, w: FontWeight.w800)),
                            Text('${h['number']}', style: money(24, c: K.green)),
                            Text('${tr('checked_on')}: ${h['date_checked']}', style: ts(12, c: K.muted)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
              ]);
            },
          ),
        ],
      );
}

// ---------------- Help ----------------

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) => Page2(
        title: tr('help'),
        children: [
          Tint(
            color: K.greenSoft,
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              const Bubble(Icons.face_3_rounded, color: Colors.white, bg: K.green, size: 76),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Text(tr('help_sub'), style: ts(18, w: FontWeight.w800)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          for (final (k, color, bg) in [
            ('how_income', K.green, K.greenSoft),
            ('how_expense', K.red, K.redSoft),
            ('how_profit', K.yellow, K.yellowSoft),
            ('how_speak', K.blue, K.blueSoft),
            ('how_call', K.purple, K.purpleSoft),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: bg,
                borderRadius: BorderRadius.circular(K.r),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  shape: const RoundedRectangleBorder(),
                  leading: Icon(Icons.play_circle_fill_rounded, color: color, size: 34),
                  title: Text(tr(k), style: ts(16.5, w: FontWeight.w700)),
                  childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  children: [Text(tr('${k}_a'), style: ts(15, w: FontWeight.w500, h: 1.5))],
                ),
              ),
            ),
        ],
      );
}
