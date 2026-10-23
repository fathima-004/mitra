// Add income (a sale) and add expense, in a few taps. Owner: Hiba.
// Sales: {date, product, qty, via:"app", time}. Expenses: purchases {date, item, item_ml, cat, qty, unit, amount, gst}.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n.dart';
import '../logic/calc.dart';
import '../logic/spend.dart';
import '../main.dart';
import '../strings.dart' show rupees;
import '../ui/kit.dart';
import '../widgets/art.dart';
import 'speak.dart';

String _now() {
  final t = TimeOfDay.now();
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Asks for a number with the phone keypad.
Future<int?> askNumber(BuildContext context, String title, int start) async {
  final c = TextEditingController(text: '$start');
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: ts(18, w: FontWeight.w800)),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
        style: money(28),
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel'), style: ts(15))),
        FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)), child: Text('OK', style: ts(15, c: Colors.white))),
      ],
    ),
  );
}

class _SpeakCard extends StatelessWidget {
  final Color color, bg;
  final String example;
  const _SpeakCard({required this.color, required this.bg, required this.example});

  @override
  Widget build(BuildContext context) => Tint(
        color: bg,
        onTap: () => openSpeak(context),
        child: Row(children: [
          Bubble(Icons.mic_rounded, color: Colors.white, bg: color, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('or_speak'), style: ts(16, w: FontWeight.w700)),
              Text(tr(example), style: ts(14, w: FontWeight.w500, c: K.muted)),
            ]),
          ),
        ]),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(4, 18, 4, 8), child: Text(text, style: ts(16, w: FontWeight.w700)));
}

// ---------------- Income ----------------

class AddIncomeScreen extends StatefulWidget {
  final String? product;
  final int qty;
  const AddIncomeScreen({super.key, this.product, this.qty = 1});
  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  late String? productId = widget.product ?? repo['products'].firstOrNull?['id'] as String?;
  late int qty = widget.qty;

  Rec? get product => repo['products'].where((p) => p['id'] == productId).firstOrNull;

  Future<void> _pickProduct() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(12), children: [
          for (final p in repo['products'])
            RowItem(
              leading: FoodArt(p, size: 46),
              title: pick(p, 'name'),
              trailing: Text(rupees(p['price'] ?? 0), style: money(16)),
              onTap: () => Navigator.pop(ctx, p['id'] as String),
            ),
        ]),
      ),
    );
    if (id != null) setState(() => productId = id);
  }

  Future<void> _save() async {
    final p = product;
    if (p == null) return;
    await repo.add('sales', {'date': today(), 'time': _now(), 'product': p['id'], 'qty': qty, 'via': 'app'});
    if (!mounted) return;
    say(context, '${tr('saved')} · $qty ${pick(p, 'name')} · ${rupees(qty * ((p['price'] as num?) ?? 0))}');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = product;
    final total = qty * ((p?['price'] as num?) ?? 0);
    return Page2(
      title: tr('add_income'),
      children: [
        Row(children: [
          const Bubble(Icons.payments_rounded, color: K.green, bg: K.greenSoft, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('what_sold'), style: ts(19, w: FontWeight.w800)),
              Text(tr('choose_or_speak'), style: ts(14, w: FontWeight.w500, c: K.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Box(
          onTap: _pickProduct,
          padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
          child: Row(children: [
            FoodArt(p, size: 46),
            const SizedBox(width: 12),
            Expanded(child: Text(p == null ? '—' : pick(p, 'name'), style: ts(18, w: FontWeight.w700))),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: K.muted),
          ]),
        ),
        _Label(tr('how_many')),
        Stepper2(
          value: qty,
          onChanged: (v) => setState(() => qty = v),
          onTapNumber: () async {
            final n = await askNumber(context, tr('how_many'), qty);
            if (n != null && n >= 1 && n <= 999) setState(() => qty = n);
          },
        ),
        _Label(tr('total_amount')),
        Tint(
          color: K.greenSoft,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text(rupees(total), style: money(32, c: K.greenDark)),
        ),
        const SizedBox(height: 18),
        BigBtn(tr('save'), icon: Icons.check_circle_rounded, onTap: p == null ? null : _save),
        const SizedBox(height: 14),
        const _SpeakCard(color: K.green, bg: K.greenSoft, example: 'speak_income_eg'),
      ],
    );
  }
}

// ---------------- Expense ----------------

const _expenseCats = ['ingredients', 'gas', 'packaging', 'transport', 'electricity', 'rent', 'phone', 'other'];

class AddExpenseScreen extends StatefulWidget {
  final String cat;
  final int? amount;
  final String? item, itemMl;
  const AddExpenseScreen({super.key, this.cat = 'ingredients', this.amount, this.item, this.itemMl});
  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  late String cat = widget.cat;
  late final amount = TextEditingController(text: widget.amount?.toString() ?? '');
  late final item = TextEditingController(text: L.ml ? (widget.itemMl ?? '') : (widget.item ?? ''));
  final gst = TextEditingController();
  DateTime day = DateTime.now();
  bool details = false;

  Future<void> _pickCat() async {
    final k = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(12), children: [
          for (final k in _expenseCats)
            RowItem(
              leading: Bubble(catBy(k).icon, color: catBy(k).color, bg: catBy(k).bg),
              title: tr('cat_$k'),
              onTap: () => Navigator.pop(ctx, k),
            ),
        ]),
      ),
    );
    if (k != null) setState(() => cat = k);
  }

  Future<void> _save() async {
    final rs = int.tryParse(amount.text);
    if (rs == null || rs <= 0) return;
    final typed = item.text.trim();
    await repo.add('purchases', {
      'date': isoDate(day),
      'time': _now(),
      'cat': cat,
      'item': typed.isNotEmpty && !L.ml ? typed : (widget.item ?? (cat == 'ingredients' ? 'Ingredients' : tr('cat_$cat'))),
      'item_ml': typed.isNotEmpty && L.ml ? typed : (widget.itemMl ?? (L.ml ? tr('cat_$cat') : '')),
      'qty': 1,
      'unit': '',
      'amount': rs,
      'gst': int.tryParse(gst.text) ?? 0,
    });
    if (!mounted) return;
    say(context, '${tr('saved')} · ${tr('cat_$cat')} · ${rupees(rs)}');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = catBy(cat);
    return Page2(
      title: tr('add_expense'),
      tint: const Color(0xFFFFF8F7),
      children: [
        Row(children: [
          const Bubble(Icons.shopping_basket_rounded, color: K.red, bg: K.redSoft, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('what_spent'), style: ts(19, w: FontWeight.w800)),
              Text(tr('choose_or_speak'), style: ts(14, w: FontWeight.w500, c: K.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Box(
          onTap: _pickCat,
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(children: [
            Bubble(c.icon, color: c.color, bg: c.bg, size: 44),
            const SizedBox(width: 12),
            Expanded(child: Text(tr('cat_$cat'), style: ts(18, w: FontWeight.w700))),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: K.muted),
          ]),
        ),
        if (cat == 'ingredients' || cat == 'other') ...[
          const SizedBox(height: 10),
          TextField(controller: item, style: ts(17), decoration: InputDecoration(hintText: tr('what_item'), hintStyle: ts(15, c: K.muted))),
        ],
        _Label(tr('amount')),
        TextField(
          controller: amount,
          autofocus: widget.amount == null,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          style: money(30, c: K.redDark),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixText: '₹  ',
            prefixStyle: money(30, c: K.redDark),
            fillColor: K.redSoft,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.red, width: 2)),
          ),
        ),
        _Label(tr('date')),
        Box(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: day, firstDate: DateTime(2025), lastDate: DateTime.now());
            if (d != null) setState(() => day = d);
          },
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded, color: K.muted),
            const SizedBox(width: 12),
            Expanded(child: Text(dayName(isoDate(day)), style: ts(17, w: FontWeight.w700))),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: K.muted),
          ]),
        ),
        // GST is rarely needed, so it stays folded away.
        TextButton.icon(
          onPressed: () => setState(() => details = !details),
          icon: Icon(details ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: K.muted),
          label: Text(tr('more_details'), style: ts(14.5, c: K.muted)),
        ),
        if (details)
          TextField(
            controller: gst,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: money(18, w: FontWeight.w600),
            decoration: InputDecoration(labelText: tr('gst_on_bill'), labelStyle: ts(14, c: K.muted), prefixText: '₹ '),
          ),
        const SizedBox(height: 14),
        BigBtn(tr('save'), icon: Icons.check_circle_rounded, color: K.red, onTap: (int.tryParse(amount.text) ?? 0) > 0 ? _save : null),
        const SizedBox(height: 14),
        const _SpeakCard(color: K.red, bg: K.redSoft, example: 'speak_expense_eg'),
      ],
    );
  }
}
