// Every income (sale) and expense (purchase), day by day. Owner: Hiba.
import 'package:flutter/material.dart';

import '../i18n.dart';
import '../logic/calc.dart';
import '../logic/spend.dart';
import '../main.dart';
import '../strings.dart' show rupees;
import '../ui/kit.dart';

class _Entry {
  final Rec row;
  final bool income;
  final String col, date, time, title;
  final num amount;
  final bool byCall;
  final IconData icon;
  _Entry(this.row, this.income, this.col, this.date, this.time, this.title, this.amount, this.byCall, this.icon);
}

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  int filter = 0; // 0 all, 1 income, 2 expense

  List<_Entry> _entries() {
    final products = {for (final p in repo['products']) p['id']: p};
    final out = <_Entry>[];
    if (filter != 2) {
      for (final s in repo['sales']) {
        final p = products[s['product']];
        final qty = (s['qty'] as num?) ?? 0;
        out.add(_Entry(s, true, 'sales', '${s['date']}', '${s['time'] ?? ''}', '${pick(p, 'name')} ($qty)',
            qty * ((p?['price'] as num?) ?? 0), s['via'] == 'call' || s['via'] == 'web-call', Icons.arrow_downward_rounded));
      }
    }
    if (filter != 1) {
      for (final x in repo['purchases']) {
        final name = pick(x, 'item');
        out.add(_Entry(x, false, 'purchases', '${x['date']}', '${x['time'] ?? ''}', name.isEmpty ? tr('cat_${catOfPurchase(x)}') : name,
            (x['amount'] as num?) ?? 0, false, catBy(catOfPurchase(x)).icon));
      }
    }
    out.sort((a, b) {
      final d = b.date.compareTo(a.date);
      return d != 0 ? d : b.time.compareTo(a.time);
    });
    return out;
  }

  String _dayLabel(String iso) {
    final t = DateTime.now();
    final y = t.subtract(const Duration(days: 1));
    if (iso == isoDate(t)) return '${tr('today')}, ${dayName(iso)}';
    if (iso == isoDate(y)) return '${tr('yesterday')}, ${dayName(iso)}';
    return dayName(iso);
  }

  Future<void> _remove(_Entry e) async {
    final yes = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(e.title, style: ts(19, w: FontWeight.w800)),
            Text('${dayName(e.date)}  ${e.time}', style: ts(14, c: K.muted)),
            const SizedBox(height: 6),
            Text(rupees(e.amount), style: money(28, c: e.income ? K.green : K.red)),
            const SizedBox(height: 18),
            BigBtn(tr('delete'), icon: Icons.delete_outline_rounded, color: K.red, onTap: () => Navigator.pop(ctx, true)),
            const SizedBox(height: 8),
            BigBtn(tr('cancel'), color: K.muted, outline: true, onTap: () => Navigator.pop(ctx, false)),
          ]),
        ),
      ),
    );
    if (yes != true) return;
    final row = Map<String, dynamic>.from(e.row);
    await repo.remove(e.col, row['id']);
    if (!mounted) return;
    say(context, tr('removed'),
        icon: Icons.delete_outline_rounded,
        action: SnackBarAction(label: tr('undo'), textColor: K.yellowSoft, onPressed: () => repo.add(e.col, row)));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final entries = _entries();
          final days = <String, List<_Entry>>{};
          for (final e in entries) {
            days.putIfAbsent(e.date, () => []).add(e);
          }
          return Scaffold(
            appBar: AppBar(title: Text(tr('records'), style: ts(19, w: FontWeight.w800)), actions: const [InfoButton('info_records'), LangSwitch(), SizedBox(width: 8)]),
            body: RefreshIndicator(
              onRefresh: repo.syncNow,
              color: K.green,
              child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
                Row(children: [
                  for (final (i, k) in ['all', 'income', 'expense'].indexed)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(tr(k), style: ts(15, w: FontWeight.w700, c: filter == i ? Colors.white : K.ink)),
                        selected: filter == i,
                        showCheckmark: false,
                        selectedColor: K.green,
                        backgroundColor: Colors.white,
                        side: BorderSide(color: filter == i ? K.green : K.line),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        onSelected: (_) => setState(() => filter = i),
                      ),
                    ),
                ]),
                if (entries.isEmpty) Padding(padding: const EdgeInsets.all(40), child: Text(tr('nothing_here'), textAlign: TextAlign.center, style: ts(16, c: K.muted))),
                for (final day in days.entries) ...[
                  Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 8), child: Text(_dayLabel(day.key), style: ts(15, w: FontWeight.w700, c: K.muted))),
                  for (final e in day.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Tint(
                        color: e.income ? const Color(0xFFF3FAF4) : const Color(0xFFFDF4F3),
                        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                        onTap: () => _remove(e),
                        child: Row(children: [
                          Bubble(e.byCall ? Icons.call_rounded : e.icon,
                              color: e.income ? K.green : K.red, bg: e.income ? K.greenSoft : K.redSoft, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(e.title, style: ts(16, w: FontWeight.w700)),
                              if (e.byCall) Text(tr('by_call'), style: ts(12.5, c: K.green)),
                            ]),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(rupees(e.amount), style: money(17, c: e.income ? K.green : K.red)),
                            if (e.time.isNotEmpty) Text(e.time, style: ts(12.5, c: K.muted)),
                          ]),
                        ]),
                      ),
                    ),
                ],
              ]),
            ),
          );
        },
      );
}
