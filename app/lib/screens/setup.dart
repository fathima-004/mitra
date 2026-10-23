// Products, this month's bills (EMIs she already pays included) and stock bought, like setup.html.
// Owner: Hiba. Same shapes as PLAN.md §5, so the web app and the call read them too.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/calc.dart';
import '../main.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';

const billTypes = ['gas', 'electricity', 'rent', 'transport', 'phone', 'packaging', 'emi', 'other'];

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: repo,
          builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
            const TopBar('setup_title'),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final (i, k) in ['tab_products', 'tab_bills', 'tab_purchases'].indexed)
                  ButtonSegment(value: i, label: Text(T.ml(k), style: const TextStyle(fontFamily: 'Malayalam', fontWeight: FontWeight.w700))),
              ],
              selected: {tab},
              onSelectionChanged: (s) => setState(() => tab = s.first),
            ),
            const SizedBox(height: 14),
            [const _Products(), const _Bills(), const _Purchases()][tab],
          ]),
        ),
      ),
    );
  }
}

// ---- Small form helpers ----

class _Field extends StatelessWidget {
  final String keyName;
  final TextEditingController c;
  final bool number;
  const _Field(this.keyName, this.c, {this.number = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
          style: const TextStyle(fontFamily: 'Malayalam', fontSize: 18, fontFamilyFallback: fonts),
          decoration: InputDecoration(
            labelText: '${T.ml(keyName)} · ${T.en(keyName)}',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            filled: true,
            fillColor: C.card,
          ),
        ),
      );
}

/// Bottom sheet with fields and a big save button. Returns true when saved.
Future<bool?> _sheet(BuildContext context, String titleKey, List<Widget> fields, Future<bool> Function() onSave) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
      decoration: const BoxDecoration(color: C.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(9)))),
          const SizedBox(height: 14),
          Bi.k(titleKey, size: 20, weight: FontWeight.w800),
          const SizedBox(height: 14),
          ...fields,
          const SizedBox(height: 4),
          BigButton('save', icon: Icons.check_rounded, onPressed: () async {
            if (await onSave()) {
              if (ctx.mounted) Navigator.pop(ctx, true);
            } else if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('${T.ml('fill_all')} · ${T.en('fill_all')}')));
            }
          }),
        ]),
      ),
    ),
  );
}

int? _num(TextEditingController c) => int.tryParse(c.text.trim());

class _Help extends StatelessWidget {
  final String keyName;
  const _Help(this.keyName);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 10), child: Bi.k(keyName, size: 14, weight: FontWeight.w500));
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton(this.onTap);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 14), child: BigButton('add', icon: Icons.add_rounded, onPressed: onTap));
}

Widget _deleteButton(VoidCallback onPressed) => IconButton(
      tooltip: T.en('delete'),
      icon: const Icon(Icons.delete_outline_rounded, color: C.red),
      onPressed: onPressed,
    );

// ---- Products ----

class _Products extends StatelessWidget {
  const _Products();

  Future<void> _edit(BuildContext context, [Rec? p]) async {
    final ml = TextEditingController(text: p?['name_ml'] ?? '');
    final en = TextEditingController(text: p?['name_en'] ?? '');
    final price = TextEditingController(text: p == null ? '' : '${p['price']}');
    final saved = await _sheet(context, 'tab_products', [_Field('name_ml', ml), _Field('name_en', en), _Field('price', price, number: true)],
        () async {
      final rs = _num(price);
      if (ml.text.trim().isEmpty || en.text.trim().isEmpty || rs == null || rs <= 0) return false;
      final obj = {'name_ml': ml.text.trim(), 'name_en': en.text.trim(), 'price': rs};
      if (p == null) {
        await repo.add('products', obj);
      } else {
        await repo.update('products', p['id'], obj);
      }
      return true;
    });
    if (saved == true && context.mounted) toast(context, 'saved');
  }

  @override
  Widget build(BuildContext context) {
    final products = repo['products'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Help('products_help'),
      MCard(
        child: products.isEmpty
            ? Bi.k('nothing_yet')
            : Rows([
                for (final p in products)
                  Row(children: [
                    FoodArt(p, size: 40),
                    const SizedBox(width: 12),
                    Expanded(child: Bi(p['name_ml'] ?? '', p['name_en'] ?? '', size: 16, weight: FontWeight.w700)),
                    Text(rupees(p['price'] ?? 0), style: numStyle(16, weight: FontWeight.w700)),
                    IconButton(tooltip: T.en('edit'), icon: const Icon(Icons.edit_outlined, color: C.brand), onPressed: () => _edit(context, p)),
                  ]),
              ]),
      ),
      _AddButton(() => _edit(context)),
    ]);
  }
}

// ---- Bills ----

class _Bills extends StatelessWidget {
  const _Bills();

  Future<void> _add(BuildContext context) async {
    var type = billTypes.first;
    final other = TextEditingController();
    final amount = TextEditingController();
    final due = TextEditingController();
    final saved = await _sheet(
      context,
      'tab_bills',
      [
        StatefulBuilder(
          builder: (context, setLocal) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: type,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: '${T.ml('bill_type')} · ${T.en('bill_type')}',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: C.card,
                ),
                items: [
                  for (final t in billTypes)
                    DropdownMenuItem(
                        value: t,
                        child: Text('${T.ml('bill_$t')} · ${T.en('bill_$t')}',
                            overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Malayalam'))),
                ],
                onChanged: (v) => setLocal(() => type = v ?? type),
              ),
            ),
            if (type == 'other') _Field('item', other),
          ]),
        ),
        _Field('amount', amount, number: true),
        _Field('due_day', due, number: true),
      ],
      () async {
        final rs = _num(amount);
        final day = _num(due);
        if (rs == null || rs <= 0 || (day != null && (day < 1 || day > 31))) return false;
        final custom = type == 'other' && other.text.trim().isNotEmpty ? other.text.trim() : null;
        await repo.add('bills', {
          'month': thisMonth(),
          'type': type,
          'label_ml': custom ?? T.ml('bill_$type'),
          'label_en': custom ?? T.en('bill_$type'),
          'amount': rs,
          if (day != null) 'due_day': day,
        });
        return true;
      },
    );
    if (saved == true && context.mounted) toast(context, 'saved');
  }

  @override
  Widget build(BuildContext context) {
    final month = thisMonth();
    final bills = repo['bills'].where((b) => b['month'] == month).toList();
    final total = bills.fold<num>(0, (s, b) => s + (b['amount'] as num? ?? 0));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Help('bills_help'),
      MCard(
        child: bills.isEmpty
            ? Bi.k('nothing_yet')
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Rows([
                  for (final b in bills)
                    Row(children: [
                      Badge2(b['type'] == 'emi' ? Icons.event_repeat_rounded : Icons.receipt_rounded, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Bi(b['label_ml'] ?? T.ml('bill_${b['type']}'),
                              '${b['label_en'] ?? T.en('bill_${b['type']}')}${b['due_day'] != null ? ' · ${T.en('due_day')}: ${b['due_day']}' : ''}',
                              size: 15)),
                      Text(rupees(b['amount'] ?? 0), style: numStyle(15, weight: FontWeight.w700)),
                      _deleteButton(() => repo.remove('bills', b['id'])),
                    ]),
                ]),
                const Divider(color: C.line),
                Row(children: [
                  Expanded(child: Bi.k('total', size: 15, weight: FontWeight.w700)),
                  Text(rupees(total), style: numStyle(18)),
                ]),
              ]),
      ),
      _AddButton(() => _add(context)),
    ]);
  }
}

// ---- Purchases ----

class _Purchases extends StatelessWidget {
  const _Purchases();

  Future<void> _add(BuildContext context) async {
    final item = TextEditingController();
    final qty = TextEditingController();
    final unit = TextEditingController(text: 'kg');
    final amount = TextEditingController();
    final gst = TextEditingController();
    final saved = await _sheet(
      context,
      'tab_purchases',
      [
        _Field('item', item),
        Row(children: [
          Expanded(child: _Field('qty', qty, number: true)),
          const SizedBox(width: 10),
          Expanded(child: _Field('unit', unit)),
        ]),
        _Field('amount', amount, number: true),
        _Field('gst_on_bill', gst, number: true),
      ],
      () async {
        final rs = _num(amount);
        final q = _num(qty);
        if (item.text.trim().isEmpty || rs == null || rs <= 0 || q == null || q <= 0) return false;
        await repo.add('purchases', {
          'date': today(),
          'item': item.text.trim(),
          'qty': q,
          'unit': unit.text.trim(),
          'amount': rs,
          'gst': _num(gst) ?? 0,
        });
        return true;
      },
    );
    if (saved == true && context.mounted) toast(context, 'saved');
  }

  @override
  Widget build(BuildContext context) {
    final month = thisMonth();
    final list = repo['purchases'].where((p) => monthOf(p['date']) == month).toList()
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    final total = list.fold<num>(0, (s, p) => s + (p['amount'] as num? ?? 0));
    final gst = list.fold<num>(0, (s, p) => s + (p['gst'] as num? ?? 0));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Help('purchases_help'),
      MCard(
        child: list.isEmpty
            ? Bi.k('nothing_yet')
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Rows([
                  for (final p in list)
                    Row(children: [
                      const Badge2(Icons.shopping_bag_outlined, bg: C.goldSoft, fg: Color(0xFF9A6F0E), size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Bi(p['item_ml'] ?? p['item'] ?? '',
                              '${p['item']} · ${p['qty']} ${p['unit'] ?? ''} · ${(p['date'] as String).substring(8)}/${(p['date'] as String).substring(5, 7)}'
                              '${(p['gst'] ?? 0) > 0 ? ' · GST ${rupees(p['gst'])}' : ''}',
                              size: 15)),
                      Text(rupees(p['amount'] ?? 0), style: numStyle(15, weight: FontWeight.w700)),
                      _deleteButton(() => repo.remove('purchases', p['id'])),
                    ]),
                ]),
                const Divider(color: C.line),
                Row(children: [
                  Expanded(child: Bi.k('total', size: 15, weight: FontWeight.w700)),
                  Text(rupees(total), style: numStyle(18)),
                ]),
                if (gst > 0)
                  Row(children: [
                    const Expanded(child: Text('GST', style: TextStyle(color: C.muted))),
                    Text(rupees(gst), style: numStyle(14, color: C.muted, weight: FontWeight.w600)),
                  ]),
              ]),
      ),
      _AddButton(() => _add(context)),
    ]);
  }
}
