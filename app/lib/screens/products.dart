// What she sells and the price. Owner: Hiba.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n.dart';
import '../logic/calc.dart';
import '../main.dart';
import '../strings.dart' show rupees;
import '../ui/kit.dart';
import '../widgets/art.dart';

Future<void> editProduct(BuildContext context, [Rec? p]) async {
  final ml = TextEditingController(text: '${p?['name_ml'] ?? ''}');
  final en = TextEditingController(text: '${p?['name_en'] ?? ''}');
  final price = TextEditingController(text: p == null ? '' : '${p['price']}');
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final ok = (ml.text.trim().isNotEmpty || en.text.trim().isNotEmpty) && (int.tryParse(price.text) ?? 0) > 0;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr(p == null ? 'add_product' : 'edit_product'), style: ts(20, w: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(controller: ml, style: ts(17), onChanged: (_) => setLocal(() {}), decoration: InputDecoration(labelText: tr('name_ml'))),
              const SizedBox(height: 10),
              TextField(controller: en, style: ts(17), onChanged: (_) => setLocal(() {}), decoration: InputDecoration(labelText: tr('name_en'))),
              const SizedBox(height: 10),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                style: money(22),
                onChanged: (_) => setLocal(() {}),
                decoration: InputDecoration(labelText: tr('price'), prefixText: '₹ '),
              ),
              const SizedBox(height: 16),
              BigBtn(tr('save'), icon: Icons.check_circle_rounded, color: K.blue, onTap: ok ? () => Navigator.pop(ctx, true) : null),
            ]),
          ),
        );
      },
    ),
  );
  if (saved != true) return;
  final obj = {
    'name_ml': ml.text.trim().isEmpty ? en.text.trim() : ml.text.trim(),
    'name_en': en.text.trim().isEmpty ? ml.text.trim() : en.text.trim(),
    'price': int.parse(price.text),
  };
  if (p == null) {
    await repo.add('products', obj);
  } else {
    await repo.update('products', p['id'], obj);
  }
  if (context.mounted) say(context, tr('saved'));
}

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: repo,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: Text(tr('my_products'), style: ts(19, w: FontWeight.w800)), actions: const [InfoButton('info_products')]),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            for (final p in repo['products'])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Box(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  onTap: () => editProduct(context, p),
                  child: Row(children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: K.yellowSoft, borderRadius: BorderRadius.circular(14)),
                      alignment: Alignment.center,
                      child: FoodArt(p, size: 52),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(pick(p, 'name'), style: ts(18, w: FontWeight.w700)),
                        Text(rupees(p['price'] ?? 0), style: money(17, c: K.muted, w: FontWeight.w600)),
                      ]),
                    ),
                    IconButton(
                      tooltip: tr('edit_product'),
                      onPressed: () => editProduct(context, p),
                      icon: const Icon(Icons.edit_outlined, color: K.muted),
                      style: IconButton.styleFrom(side: const BorderSide(color: K.line)),
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 6),
            BigBtn(tr('add_product'), icon: Icons.add_rounded, color: K.blue, onTap: () => editProduct(context)),
          ]),
        ),
      );
}
