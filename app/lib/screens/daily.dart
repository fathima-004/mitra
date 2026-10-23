import 'package:flutter/material.dart';

import '../logic/calc.dart';
import '../main.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});
  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  DateTime day = DateTime.now();
  static const _tints = [C.goldSoft, C.amberSoft, Color(0xFFFDEBD8), C.roseSoft];

  Future<void> _pickDay() async {
    final d = await showDatePicker(context: context, initialDate: day, firstDate: DateTime(2025), lastDate: DateTime.now());
    if (d != null) setState(() => day = d);
  }

  Future<void> _sell(Rec p) async {
    final qty = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _Keypad(product: p),
    );
    if (qty == null || qty <= 0) return;
    await repo.add('sales', {'date': isoDate(day), 'product': p['id'], 'qty': qty, 'via': 'app'});
    if (mounted) toast(context, 'added_sale');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final iso = isoDate(day);
        final daySales = repo['sales'].where((s) => s['date'] == iso).toList();
        Rec? product(String id) => repo['products'].where((p) => p['id'] == id).firstOrNull;
        return SafeArea(
          bottom: false,
          // Swipe down to check Firestore now (PLAN.md §11: if the live update fails, refresh).
          child: RefreshIndicator(
            onRefresh: repo.syncNow,
            color: C.brand,
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 12, 16, 120), children: [
              const TopBar('daily_title'),
              const SizedBox(height: 16),
              MCard(
                onTap: _pickDay,
                child: Row(children: [
                  Expanded(child: Bi.k('sold_on', size: 15, weight: FontWeight.w700)),
                  Text('${day.day} ${monthsMl[day.month - 1]} ${day.year}', style: const TextStyle(fontFamily: 'Malayalam', fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  const Icon(Icons.calendar_month_rounded, color: C.brand),
                ]),
              ),
              const SizedBox(height: 16),
              Padding(padding: const EdgeInsets.only(left: 4, bottom: 10), child: Bi.k('tap_product', size: 15, weight: FontWeight.w700)),
              GridView.count(
                padding: EdgeInsets.zero, // no extra safe-area gap inside the page list
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: .95,
                children: [
                  for (final (i, p) in repo['products'].indexed)
                    _ProductTile(
                      product: p,
                      tint: _tints[i % _tints.length],
                      qty: daySales.where((s) => s['product'] == p['id']).fold<num>(0, (n, s) => n + s['qty']),
                      onTap: () => _sell(p),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              MCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Bi.k('entries', size: 15, weight: FontWeight.w700),
                  const SizedBox(height: 4),
                  Money(salesIncome(daySales, repo['products']), style: numStyle(34)),
                  if (daySales.isEmpty)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Bi.k('no_sales_today', size: 15, weight: FontWeight.w500))
                  else
                    Rows([
                      for (final s in daySales.reversed)
                        Row(children: [
                          FoodArt(product(s['product']), size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Bi('${product(s['product'])?['name_ml'] ?? s['product']} × ${s['qty']}',
                                  '${product(s['product'])?['name_en'] ?? ''}${s['via'] == 'call' || s['via'] == 'web-call' ? ' · ${T.en('via_call')}' : ''}',
                                  size: 15)),
                          if (s['via'] == 'call' || s['via'] == 'web-call') const Icon(Icons.call_rounded, size: 16, color: C.brand),
                          const SizedBox(width: 8),
                          Text(rupees(s['qty'] * (product(s['product'])?['price'] ?? 0)), style: numStyle(15, weight: FontWeight.w700)),
                          IconButton(
                            tooltip: T.en('undo'),
                            icon: const Icon(Icons.undo_rounded, color: C.red, size: 20),
                            onPressed: () => repo.remove('sales', s['id']),
                          ),
                        ]),
                    ]),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Rec product;
  final Color tint;
  final num qty;
  final VoidCallback onTap;
  const _ProductTile({required this.product, required this.tint, required this.qty, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: C.card,
        borderRadius: BorderRadius.circular(20),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 66,
                height: 66,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(18)),
                child: FoodArt(product, size: 52),
              ),
              const Spacer(),
              Bi(product['name_ml'], product['name_en'], size: 16, weight: FontWeight.w700),
              const SizedBox(height: 4),
              Row(children: [
                Text(rupees(product['price']), style: const TextStyle(color: C.muted, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (qty > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: C.greenSoft, borderRadius: BorderRadius.circular(99)),
                    child: Text('$qty', style: const TextStyle(color: C.green, fontWeight: FontWeight.w800)),
                  ),
              ]),
            ]),
          ),
        ),
      );
}

/// Big number keypad: how many did she sell?
class _Keypad extends StatefulWidget {
  final Rec product;
  const _Keypad({required this.product});
  @override
  State<_Keypad> createState() => _KeypadState();
}

class _KeypadState extends State<_Keypad> {
  String v = '';

  void _tap(String k) => setState(() {
        if (k == '⌫') {
          if (v.isNotEmpty) v = v.substring(0, v.length - 1);
        } else if (v.length < 3) {
          v = v == '0' ? k : v + k;
        }
      });

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final qty = int.tryParse(v) ?? 0;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(color: C.card, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 44, height: 5, decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(9))),
        const SizedBox(height: 14),
        Row(children: [
          FoodArt(p, size: 48),
          const SizedBox(width: 12),
          Expanded(child: Bi(p['name_ml'], '${p['name_en']} · ${T.en('how_many')}', size: 18, weight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        Text(v.isEmpty ? '0' : v, style: numStyle(56, color: v.isEmpty ? C.faint : C.ink)),
        Text(rupees(qty * (p['price'] as num)), style: numStyle(16, color: C.muted, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        GridView.count(
          padding: EdgeInsets.zero, // no extra safe-area gap inside the page list
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.9,
          children: [
            for (final k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'])
              k.isEmpty
                  ? const SizedBox()
                  : Material(
                      color: C.bg,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _tap(k),
                        child: Center(
                            child: k == '⌫' ? const Icon(Icons.backspace_outlined, color: C.ink) : Text(k, style: numStyle(26, weight: FontWeight.w700))),
                      ),
                    ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: BigButton('save', icon: Icons.check_rounded, onPressed: qty > 0 ? () => Navigator.pop(context, qty) : null)),
      ]),
    );
  }
}
