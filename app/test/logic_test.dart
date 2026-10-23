// The app's maths must give exactly the same answers as the web app's js/calc.js and js/money.js
// (worked out with node on the same demo data), and the sentence parser must understand the demo phrases.
// Run: flutter test test/logic_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/logic/calc.dart';
import 'package:mitra/logic/money.dart';
import 'package:mitra/logic/parse.dart';
import 'package:mitra/logic/spend.dart';

void main() {
  final d = jsonDecode(File('assets/data/demo.json').readAsStringSync()) as Map<String, dynamic>;
  List<Rec> col(String c) => [for (final r in d[c] as List) Map<String, dynamic>.from(r as Map)];
  final sales = col('sales'), products = col('products'), bills = col('bills'), purchases = col('purchases');
  final history = col('history'), goals = col('goals');

  test('profit, averages, goal and EMI match js/calc.js and js/money.js', () {
    // Expected values printed by node from the web app's JS on assets/data/demo.json.
    final oct = monthProfit(sales, products, bills, purchases, '2026-10');
    expect([oct.income, oct.spending, oct.profit], [40096, 27639, 12457]);
    final sep = monthProfit(sales, products, bills, purchases, '2026-09');
    expect([sep.income, sep.spending, sep.profit], [0, 0, 0]);
    final avg = avgMonthlyProfit(history, 3);
    expect(avg, 15400);
    expect(worstMonth(history)?['month'], '2026-06');
    final g = goalPlan(goals.first, avg);
    expect([g.pct, g.left, g.months], [60, 16000, 4]);
    expect(emiCheck(2000, avg, 5600).level, EmiLevel.ok);
    final best = breakdown(sales, products, bills, purchases, '2026-10').byProduct.map((r) => '${r.product['id']}:${r.qty}:${r.income}').join(',');
    expect(best, 'p1:223:22300,p2:954:7632,p3:617:7404,p4:23:2760');
  });

  test('spending by category adds up to the month\'s spending', () {
    final parts = spendByCat(bills, purchases, '2026-10');
    expect(parts.fold<num>(0, (s, p) => s + p.$2), 27639);
    expect(parts.first.$1.key, 'ingredients');
  });

  test('sentences: sales, expenses, unclear', () {
    expect(understand('innu 12 biriyani poyi', products).sales, [
      {'product': 'p1', 'qty': 12},
    ]);
    expect(understand('30 chapathi and 20 parotta', products).sales, [
      {'product': 'p2', 'qty': 30},
      {'product': 'p3', 'qty': 20},
    ]);
    final e = understand('bought rice for 200', products);
    expect([e.expense?['cat'], e.expense?['amount'], e.sure], ['ingredients', 200, true]);
    expect(understand('gas 900', products).expense?['cat'], 'gas');
    expect(understand('kure biriyani', products).sure, isFalse);
    expect(understand('', products).empty, isTrue);
  });
}
