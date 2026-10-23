// Profit maths, same as js/calc.js (PLAN.md §5). Pure functions, no data access.
typedef Rec = Map<String, dynamic>;

String isoDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String today([DateTime? now]) => isoDate(now ?? DateTime.now());
String thisMonth([DateTime? now]) => today(now).substring(0, 7);
String monthOf(String isoDate) => isoDate.substring(0, 7);

num _n(Object? v) => v is num ? v : num.tryParse('$v') ?? 0;

Map<String, num> _prices(List<Rec> products) => {for (final p in products) p['id'] as String: _n(p['price'])};

num salesIncome(List<Rec> sales, List<Rec> products) {
  final price = _prices(products);
  return sales.fold<num>(0, (sum, s) => sum + _n(s['qty']) * (price[s['product']] ?? 0));
}

num monthIncome(List<Rec> sales, List<Rec> products, String month) => salesIncome(sales.where((s) => monthOf(s['date']) == month).toList(), products);

num monthSpending(List<Rec> bills, List<Rec> purchases, String month) {
  final b = bills.where((x) => x['month'] == month).fold<num>(0, (s, x) => s + _n(x['amount']));
  final p = purchases.where((x) => monthOf(x['date']) == month).fold<num>(0, (s, x) => s + _n(x['amount']));
  return b + p;
}

class MonthTotals {
  final num income, spending;
  const MonthTotals(this.income, this.spending);
  num get profit => income - spending;
}

MonthTotals monthProfit(List<Rec> sales, List<Rec> products, List<Rec> bills, List<Rec> purchases, String month) =>
    MonthTotals(monthIncome(sales, products, month), monthSpending(bills, purchases, month));

class ProductLine {
  final Rec product;
  final num qty, income;
  ProductLine(this.product, this.qty, this.income);
}

class SpendLine {
  final String labelMl, labelEn;
  num amount;
  SpendLine(this.labelMl, this.labelEn, this.amount);
}

({List<ProductLine> byProduct, List<SpendLine> bySpend}) breakdown(List<Rec> sales, List<Rec> products, List<Rec> bills, List<Rec> purchases, String month) {
  final byProduct = products.map((p) {
    final qty = sales.where((s) => s['product'] == p['id'] && monthOf(s['date']) == month).fold<num>(0, (sum, s) => sum + _n(s['qty']));
    return ProductLine(p, qty, qty * _n(p['price']));
  }).toList()
    ..sort((a, b) => b.income.compareTo(a.income));

  final spend = <String, SpendLine>{};
  for (final b in bills.where((x) => x['month'] == month)) {
    final key = (b['label_en'] ?? b['type']) as String;
    spend.putIfAbsent(key, () => SpendLine((b['label_ml'] ?? key) as String, key, 0)).amount += _n(b['amount']);
  }
  for (final p in purchases.where((x) => monthOf(x['date']) == month)) {
    final key = p['item'] as String;
    spend.putIfAbsent(key, () => SpendLine((p['item_ml'] ?? key) as String, key, 0)).amount += _n(p['amount']);
  }
  final bySpend = spend.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
  return (byProduct: byProduct, bySpend: bySpend);
}

List<Rec> _sortedHistory(List<Rec> history) => [...history]..sort((a, b) => (a['month'] as String).compareTo(b['month'] as String));

num historyProfit(Rec h) => _n(h['income']) - _n(h['spending']);

num avgMonthlyProfit(List<Rec> history, [int months = 3]) {
  final all = _sortedHistory(history);
  final last = all.sublist(all.length > months ? all.length - months : 0);
  if (last.isEmpty) return 0;
  return (last.fold<num>(0, (s, h) => s + historyProfit(h)) / last.length).round();
}

Rec? worstMonth(List<Rec> history) {
  if (history.isEmpty) return null;
  return ([...history]..sort((a, b) => historyProfit(a).compareTo(historyProfit(b)))).first;
}

String fyStart([DateTime? now]) {
  final d = now ?? DateTime.now();
  final y = d.month >= 4 ? d.year : d.year - 1;
  return '$y-04';
}

num yearTurnover(List<Rec> sales, List<Rec> products, List<Rec> history, [String? start]) {
  final current = thisMonth();
  final s = start ?? fyStart();
  final past = history
      .where((h) => (h['month'] as String).compareTo(s) >= 0 && (h['month'] as String).compareTo(current) < 0)
      .fold<num>(0, (sum, h) => sum + _n(h['income']));
  return past + monthIncome(sales, products, current);
}
