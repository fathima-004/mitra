// Schemes, support and the buy-together board. Owner: Hiba.
// Scheme and helpline details come only from data/schemes.json and data/support.json (Fathima checks them
// on official sites and stores the source URL and date). Entries without both are not shown, and nothing
// here is ever a loan (CLAUDE.md).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/calc.dart';
import '../main.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Reads a checked content file from assets/data/. Missing file = empty list.
Future<List<Rec>> _checked(String file, String listKey) async {
  try {
    final j = jsonDecode(await rootBundle.loadString('assets/data/$file'));
    final list = j is List ? j : (j as Map)[listKey] as List? ?? const [];
    return [
      for (final x in list)
        if (x is Map && '${x['source_url'] ?? ''}'.startsWith('http') && '${x['date_checked'] ?? ''}'.isNotEmpty) Map<String, dynamic>.from(x),
    ];
  } catch (_) {
    return [];
  }
}

String _s(Rec r, String base, String lang) => '${r['${base}_$lang'] ?? r['${base}_${lang == 'ml' ? 'en' : 'ml'}'] ?? ''}';

class _Page extends StatelessWidget {
  final String titleKey;
  final List<Widget> children;
  const _Page(this.titleKey, this.children);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
            TopBar(titleKey),
            const SizedBox(height: 16),
            ...children,
          ]),
        ),
      );
}

class _Source extends StatelessWidget {
  final Rec r;
  const _Source(this.r);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text('${T.ml('checked_on')} · ${T.en('checked_on')}: ${r['date_checked']}\n${r['source_url']}',
            style: const TextStyle(fontSize: 12, color: C.muted, fontFamily: 'Malayalam')),
      );
}

class _BeingChecked extends StatelessWidget {
  final String ml, en;
  const _BeingChecked(this.ml, this.en);
  @override
  Widget build(BuildContext context) => MCard(
        child: Row(children: [
          const Badge2(Icons.fact_check_outlined, bg: C.goldSoft, fg: Color(0xFF9A6F0E)),
          const SizedBox(width: 12),
          Expanded(child: Bi(ml, en, size: 15)),
        ]),
      );
}

// ---- Schemes ----

class SchemesScreen extends StatelessWidget {
  const SchemesScreen({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Rec>>(
        future: _checked('schemes.json', 'schemes'),
        builder: (context, snap) {
          final list = snap.data ?? const [];
          return _Page('tile_schemes', [
            if (snap.connectionState == ConnectionState.done && list.isEmpty)
              const _BeingChecked('പദ്ധതികളുടെ വിവരങ്ങൾ ഔദ്യോഗിക സൈറ്റുകളിൽ ഉറപ്പാക്കിക്കൊണ്ടിരിക്കുന്നു.',
                  'Scheme details are still being checked on official sites.'),
            for (final s in list) ...[
              MCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Bi(_s(s, 'title', 'ml'), _s(s, 'title', 'en'), size: 18, weight: FontWeight.w800),
                  if (_s(s, 'about', 'ml').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Bi(_s(s, 'about', 'ml'), _s(s, 'about', 'en'), size: 14, weight: FontWeight.w500),
                  ],
                  if ((s['documents'] as List?)?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 12),
                    const Bi('ആവശ്യമുള്ള രേഖകൾ', 'Documents you need', size: 15, weight: FontWeight.w700),
                    for (final d in s['documents'] as List)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.check_box_outline_blank_rounded, size: 20, color: C.brand),
                          const SizedBox(width: 8),
                          Expanded(
                              child: d is Map
                                  ? Bi('${d['ml'] ?? d['en'] ?? ''}', '${d['en'] ?? ''}', size: 14)
                                  : Text('$d', style: const TextStyle(fontFamily: 'Malayalam'))),
                        ]),
                      ),
                  ],
                  _Source(s),
                ]),
              ),
              const SizedBox(height: 12),
            ],
          ]);
        },
      );
}

// ---- Support ----

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Rec>>(
        future: _checked('support.json', 'helplines'),
        builder: (context, snap) {
          final list = snap.data ?? const [];
          return _Page('tile_support', [
            const HeroCard(
              child: Bi('ബിസിനസും വീടും ഒരുമിച്ച് നോക്കുന്നത് എളുപ്പമല്ല. സംസാരിക്കാൻ ഒരാളെ വേണമെങ്കിൽ വിളിക്കൂ, സൗജന്യമാണ്.',
                  'Running a business and a home is hard. If you want someone to talk to, call. It is free.',
                  size: 16, color: Colors.white, enColor: Colors.white70),
            ),
            const SizedBox(height: 14),
            if (snap.connectionState == ConnectionState.done && list.isEmpty)
              const _BeingChecked('ഹെൽപ്‌ലൈൻ നമ്പറുകൾ ഔദ്യോഗിക സൈറ്റിൽ ഉറപ്പാക്കിക്കൊണ്ടിരിക്കുന്നു.',
                  'Helpline numbers are still being checked on official sites.'),
            for (final h in list) ...[
              MCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Bi(_s(h, 'name', 'ml'), _s(h, 'name', 'en'), size: 17, weight: FontWeight.w800),
                  const SizedBox(height: 6),
                  SelectableText('${h['number']}', style: numStyle(40, color: C.brand)),
                  if (_s(h, 'about', 'ml').isNotEmpty) Bi(_s(h, 'about', 'ml'), _s(h, 'about', 'en'), size: 14, weight: FontWeight.w500),
                  _Source(h),
                ]),
              ),
              const SizedBox(height: 12),
            ],
          ]);
        },
      );
}

// ---- Buy together ----

class BulkScreen extends StatelessWidget {
  const BulkScreen({super.key});

  Future<void> _join(BuildContext context, Rec sample) async {
    final c = TextEditingController();
    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Bi('${sample['item_ml'] ?? sample['item']} എത്ര വേണം?', 'How much ${sample['item']} do you need?', size: 17),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: numStyle(28),
          decoration: InputDecoration(suffixText: '${sample['unit'] ?? ''}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('${T.ml('cancel')} · ${T.en('cancel')}')),
          FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)), child: Text('${T.ml('add')} · ${T.en('add')}')),
        ],
      ),
    );
    if (qty == null || qty <= 0 || qty > 9999) return;
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
    if (context.mounted) toast(context, 'saved');
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: repo,
        builder: (context, _) {
          // One group per item and month, like the bulk board on the web.
          final groups = <String, List<Rec>>{};
          for (final r in repo.bulk) {
            groups.putIfAbsent('${r['month']}|${r['item']}', () => []).add(r);
          }
          final keys = groups.keys.toList()..sort();
          return _Page('tile_bulk', [
            Padding(padding: const EdgeInsets.only(left: 4, bottom: 12), child: Bi.k('tile_bulk_sub', size: 14, weight: FontWeight.w500)),
            if (keys.isEmpty) MCard(child: Bi.k('nothing_yet')),
            for (final k in keys) ...[
              Builder(builder: (context) {
                final rows = groups[k]!;
                final first = rows.first;
                final total = rows.fold<num>(0, (s, r) => s + (r['qty'] as num? ?? 0));
                final mine = rows.any((r) => r['user'] == 'demo1');
                final month = '${first['month'] ?? ''}';
                final when = month.length == 7 ? '${monthsMlLong[monthIndex(month)]} · ${monthsEn[monthIndex(month)]}' : month;
                return MCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Badge2(Icons.groups_rounded, bg: C.brandSoft, fg: C.brand, size: 46),
                      const SizedBox(width: 12),
                      Expanded(child: Bi('${first['item_ml'] ?? first['item']}', '${first['item']} · $when', size: 17, weight: FontWeight.w800)),
                      Text('$total ${first['unit'] ?? ''}', style: numStyle(20, color: C.brand)),
                    ]),
                    const SizedBox(height: 10),
                    Bi('${rows.length} പേർ ഒരുമിച്ച് വാങ്ങുന്നു', '${rows.length} women buying together · ${first['place'] ?? ''}', size: 14),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final r in rows)
                        Chip(
                          label: Text('${r['name'] ?? ''} · ${r['qty']} ${r['unit'] ?? ''}'),
                          backgroundColor: r['user'] == 'demo1' ? C.goldSoft : C.bg,
                          side: const BorderSide(color: C.line),
                        ),
                    ]),
                    const SizedBox(height: 10),
                    mine
                        ? const Row(children: [
                            Icon(Icons.check_circle_rounded, color: C.green),
                            SizedBox(width: 8),
                            Expanded(child: Bi('നിങ്ങളും ഇതിലുണ്ട്', "You're in this group", size: 14)),
                          ])
                        : SizedBox(
                            width: double.infinity,
                            child: BigButton('add', icon: Icons.add_rounded, onPressed: () => _join(context, first)),
                          ),
                  ]),
                );
              }),
              const SizedBox(height: 12),
            ],
          ]);
        },
      );
}
