// Understands a spoken or typed sentence with word lists only, same rules as js/parse.js (PLAN.md §7a).
// No AI and no maths: it only finds products, quantities and amounts. The result is always shown
// to her to confirm before anything is saved. Owner: Hiba.
import 'calc.dart';

const _productWords = {
  'biriyani': ['biriyani', 'biriyaani', 'biryani', 'beeryani', 'briyani', 'ബിരിയാണി', 'ബിരിയാനി'],
  'chapathi': ['chapathi', 'chapati', 'chappathi', 'chapatti', 'ചപ്പാത്തി'],
  'parotta': ['parotta', 'porotta', 'porota', 'paratha', 'പൊറോട്ട', 'പറോട്ട'],
  'pickle bottle': ['pickle', 'pickles', 'achar', 'achaar', 'അച്ചാർ', 'അച്ചാറ്'],
};

const _numbers = {
  'ഒന്ന്': 1,
  'ഒന്നു': 1,
  'ഒരു': 1,
  'one': 1,
  'oru': 1,
  'onnu': 1,
  'രണ്ട്': 2,
  'രണ്ടു': 2,
  'two': 2,
  'randu': 2,
  'മൂന്ന്': 3,
  'മൂന്നു': 3,
  'three': 3,
  'moonnu': 3,
  'നാല്': 4,
  'നാലു': 4,
  'four': 4,
  'naalu': 4,
  'അഞ്ച്': 5,
  'അഞ്ചു': 5,
  'five': 5,
  'anchu': 5,
  'ആറ്': 6,
  'ആറു': 6,
  'six': 6,
  'aaru': 6,
  'ഏഴ്': 7,
  'ഏഴു': 7,
  'seven': 7,
  'ezhu': 7,
  'എട്ട്': 8,
  'എട്ടു': 8,
  'eight': 8,
  'ettu': 8,
  'ഒമ്പത്': 9,
  'ഒൻപത്': 9,
  'nine': 9,
  'പത്ത്': 10,
  'പത്തു': 10,
  'ten': 10,
  'pathu': 10,
  'പന്ത്രണ്ട്': 12,
  'twelve': 12,
  'പതിനഞ്ച്': 15,
  'fifteen': 15,
  'ഇരുപത്': 20,
  'twenty': 20,
  'irupathu': 20,
  'മുപ്പത്': 30,
  'thirty': 30,
  'muppathu': 30,
  'നാൽപ്പത്': 40,
  'forty': 40,
  'അമ്പത്': 50,
  'fifty': 50,
  'നൂറ്': 100,
  'hundred': 100,
};

// "Bought / spent" words, and words that name an expense.
final _spentWords = RegExp(r'vangi|vaangi|വാങ്ങി|bought|buy|spent|spend|ചെലവ്|ചിലവ്|kodutthu|കൊടുത്തു|paid|refill|bill', caseSensitive: false);
final _expenseItems = [
  (RegExp(r'gas|ഗ്യാസ്|cylinder', caseSensitive: false), 'gas', 'Gas', 'ഗ്യാസ്'),
  (RegExp(r'packag|box|cover|bottle|കുപ്പി|പാക്ക|കവർ', caseSensitive: false), 'packaging', 'Packaging', 'പാക്കിംഗ്'),
  (RegExp(r'auto|bus|taxi|petrol|transport|ഓട്ടോ|ബസ്', caseSensitive: false), 'transport', 'Transport', 'യാത്ര'),
  (RegExp(r'current|electric|കറന്റ്', caseSensitive: false), 'electricity', 'Electricity', 'കറന്റ്'),
  (RegExp(r'rent|വാടക', caseSensitive: false), 'rent', 'Rent', 'വാടക'),
  (RegExp(r'recharge|phone|ഫോൺ|റീചാർജ്', caseSensitive: false), 'phone', 'Phone', 'ഫോൺ'),
  (RegExp(r'rice|അരി|ari\b', caseSensitive: false), 'ingredients', 'Rice', 'അരി'),
  (RegExp(r'oil|എണ്ണ|enna', caseSensitive: false), 'ingredients', 'Cooking oil', 'എണ്ണ'),
  (RegExp(r'chicken|ചിക്കൻ|kozhi|കോഴി', caseSensitive: false), 'ingredients', 'Chicken', 'ചിക്കൻ'),
  (RegExp(r'maida|മൈദ', caseSensitive: false), 'ingredients', 'Maida', 'മൈദ'),
  (RegExp(r'atta|wheat|ആട്ട|ഗോതമ്പ്', caseSensitive: false), 'ingredients', 'Wheat flour', 'ആട്ട'),
  (RegExp(r'vegetable|pachakkari|പച്ചക്കറി|onion|ഉള്ളി|tomato|തക്കാളി', caseSensitive: false), 'ingredients', 'Vegetables', 'പച്ചക്കറി'),
  (RegExp(r'masala|spice|മസാല|മുളക്', caseSensitive: false), 'ingredients', 'Spices', 'മസാല'),
  (RegExp(r'milk|പാൽ|paal', caseSensitive: false), 'ingredients', 'Milk', 'പാൽ'),
  (RegExp(r'sugar|പഞ്ചസാര', caseSensitive: false), 'ingredients', 'Sugar', 'പഞ്ചസാര'),
];

class Heard {
  /// Sales found: [{product, qty}].
  final List<Rec> sales;

  /// An expense found: {cat, item, item_ml, amount}, or null.
  final Rec? expense;

  /// True when every product had a number and nothing was left over.
  final bool sure;
  const Heard(this.sales, this.expense, this.sure);

  bool get empty => sales.isEmpty && expense == null;
}

String _clean(String s) => s.toLowerCase().replaceAll(RegExp('[‌‍]'), '');

List<String> _tokens(String text) => _clean(text).split(RegExp(r"[\s,.;:!?()\-₹/]+")).where((t) => t.isNotEmpty).toList();

int? _num(String t) {
  final digits = RegExp(r'^\d{1,6}$');
  if (digits.hasMatch(t)) return int.parse(t);
  final withRs = RegExp(r'^(\d{1,6})(rs|rupees?|രൂപ.*)$').firstMatch(t);
  if (withRs != null) return int.parse(withRs.group(1)!);
  return _numbers[t];
}

String? _productOf(String token, List<Rec> products, List<Rec> words) {
  for (final p in products) {
    final key = _clean('${p['name_en'] ?? ''}');
    final list = [
      ...?_productWords[key],
      key,
      _clean('${p['name_ml'] ?? ''}'),
      ...key.split(' ').where((w) => w.length >= 4),
      ...words.where((w) => w['product'] == p['id']).map((w) => _clean('${w['word']}')),
    ].where((w) => w.isNotEmpty);
    if (list.contains(token)) return p['id'] as String;
    // Longer words also match with a suffix: "ബിരിയാണിയും", "chapathikal".
    if (list.any((w) => w.length >= 4 && token.startsWith(w))) return p['id'] as String;
  }
  return null;
}

Heard understand(String text, List<Rec> products, [List<Rec> words = const []]) {
  final toks = _tokens(text);
  final nums = toks.map(_num).toList();
  final prods = [for (var i = 0; i < toks.length; i++) nums[i] == null ? _productOf(toks[i], products, words) : null];

  // Sales: each product word takes the nearest free number next to it, the word before first.
  final used = <int>{};
  final found = <(String, int?)>[];
  for (var i = 0; i < toks.length; i++) {
    final pid = prods[i];
    if (pid == null) continue;
    int? near;
    for (final d in [-1, 1, -2, 2]) {
      final j = i + d;
      if (j >= 0 && j < toks.length && nums[j] != null && prods[j] == null && !used.contains(j)) {
        near = j;
        break;
      }
    }
    if (near != null) used.add(near);
    found.add((pid, near == null ? null : nums[near]));
  }
  final totals = <String, int>{};
  for (final (pid, qty) in found) {
    if (qty == null || qty < 1 || qty > 999) continue;
    totals[pid] = (totals[pid] ?? 0) + qty;
  }
  final sales = [
    for (final e in totals.entries) <String, dynamic>{'product': e.key, 'qty': e.value}
  ];

  // Expense: a spent word or an expense item, with an amount, and no product sold.
  Rec? expense;
  final lower = _clean(text);
  final item = _expenseItems.where((e) => e.$1.hasMatch(lower)).firstOrNull;
  final amounts = [
    for (var i = 0; i < toks.length; i++)
      if (nums[i] != null && !used.contains(i)) nums[i]!
  ];
  if (sales.isEmpty && amounts.isNotEmpty && (item != null || _spentWords.hasMatch(lower))) {
    final amount = amounts.reduce((a, b) => a > b ? a : b);
    if (amount >= 1 && amount <= 999999) {
      expense = {
        'cat': item?.$2 ?? 'other',
        'item': item?.$3 ?? 'Other',
        'item_ml': item?.$4 ?? 'മറ്റുള്ളവ',
        'amount': amount,
      };
    }
  }

  final missing = found.any((f) => f.$2 == null || f.$2! < 1 || f.$2! > 999);
  final leftover = sales.isNotEmpty &&
      [
        for (var j = 0; j < toks.length; j++)
          if (nums[j] != null && !used.contains(j)) j
      ].isNotEmpty;
  final sure = (sales.isNotEmpty && !missing && !leftover) || (sales.isEmpty && expense != null);
  return Heard(sales, expense, sure);
}
