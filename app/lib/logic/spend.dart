// Where the money goes: every purchase and bill falls into one simple category. Owner: Hiba.
// New expenses store their category in `cat`; older rows (demo data, the web app) are guessed from their name.
import 'package:flutter/material.dart';

import '../ui/kit.dart';
import 'calc.dart';

class Cat {
  final String key;
  final IconData icon;
  final Color color, bg;
  const Cat(this.key, this.icon, this.color, this.bg);
}

const cats = [
  Cat('ingredients', Icons.shopping_basket_rounded, K.red, K.redSoft),
  Cat('gas', Icons.local_fire_department_rounded, K.orange, K.orangeSoft),
  Cat('packaging', Icons.inventory_2_rounded, K.blue, K.blueSoft),
  Cat('transport', Icons.directions_bus_rounded, K.purple, K.purpleSoft),
  Cat('electricity', Icons.bolt_rounded, K.yellow, K.yellowSoft),
  Cat('rent', Icons.house_rounded, K.teal, K.tealSoft),
  Cat('phone', Icons.phone_android_rounded, K.pink, K.pinkSoft),
  Cat('emi', Icons.event_repeat_rounded, K.muted, Color(0xFFEFF0EF)),
  Cat('other', Icons.more_horiz_rounded, K.muted, Color(0xFFEFF0EF)),
];

Cat catBy(String key) => cats.firstWhere((c) => c.key == key, orElse: () => cats.last);

final _guess = [
  (RegExp(r'packag|box|cover|bottle|കുപ്പി|പാക്ക|കവർ', caseSensitive: false), 'packaging'),
  (RegExp(r'\bgas\b|ഗ്യാസ്|cylinder|refill', caseSensitive: false), 'gas'),
  (RegExp(r'transport|auto|bus|taxi|petrol|യാത്ര|ഓട്ടോ', caseSensitive: false), 'transport'),
  (RegExp(r'electric|current|കറന്റ്', caseSensitive: false), 'electricity'),
  (RegExp(r'\brent\b|വാടക', caseSensitive: false), 'rent'),
  (RegExp(r'phone|recharge|ഫോൺ|റീചാർജ്', caseSensitive: false), 'phone'),
];

String catOfPurchase(Rec p) {
  final c = p['cat'] as String?;
  if (c != null && cats.any((x) => x.key == c)) return c;
  final name = '${p['item'] ?? ''} ${p['item_ml'] ?? ''}';
  return _guess.where((g) => g.$1.hasMatch(name)).map((g) => g.$2).firstOrNull ?? 'ingredients';
}

String catOfBill(Rec b) {
  final t = '${b['type'] ?? ''}';
  return cats.any((x) => x.key == t) ? t : 'other';
}

/// Spending per category for a month, biggest first.
List<(Cat, num)> spendByCat(List<Rec> bills, List<Rec> purchases, String month) {
  final sums = <String, num>{};
  for (final p in purchases.where((x) => monthOf('${x['date']}') == month)) {
    final k = catOfPurchase(p);
    sums[k] = (sums[k] ?? 0) + ((p['amount'] as num?) ?? 0);
  }
  for (final b in bills.where((x) => x['month'] == month)) {
    final k = catOfBill(b);
    sums[k] = (sums[k] ?? 0) + ((b['amount'] as num?) ?? 0);
  }
  final list = [
    for (final e in sums.entries)
      if (e.value > 0) (catBy(e.key), e.value)
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  return list;
}
