// "Mitra noticed": short, personal facts from her own numbers. Same rules as js/insights.js.
// Plain maths, no AI, no loan advice.
import 'package:intl/intl.dart';

import 'calc.dart';
import 'money.dart';

enum InsightTone { gold, rose, leaf, plum, sky }

class Insight {
  final String key, icon, ml, en;
  final InsightTone tone;
  const Insight(this.key, this.icon, this.tone, this.ml, this.en);
}

const _daysMl = ['ഞായറാഴ്ച', 'തിങ്കളാഴ്ച', 'ചൊവ്വാഴ്ച', 'ബുധനാഴ്ച', 'വ്യാഴാഴ്ച', 'വെള്ളിയാഴ്ച', 'ശനിയാഴ്ച'];
const _daysEn = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
final _inr = NumberFormat.decimalPattern('en_IN');
String _rs(num n) => '₹${_inr.format(n.round())}';
num _n(Object? v) => v is num ? v : num.tryParse('$v') ?? 0;
double _mean(List<num> a) => a.isEmpty ? 0 : a.fold<num>(0, (x, y) => x + y) / a.length;

// Her best day of the week for her top product.
Insight? _bestWeekday(List<Rec> sales, Rec top) {
  final days = <String, num>{};
  for (final s in sales) {
    days[s['date']] = (days[s['date']] ?? 0) + (s['product'] == top['id'] ? _n(s['qty']) : 0);
  }
  if (days.length < 10) return null;
  final by = List.generate(7, (_) => <num>[]);
  days.forEach((date, qty) => by[DateTime.parse(date).weekday % 7].add(qty));
  final avgAll = _mean(days.values.toList());
  int? best;
  double bestAvg = 0;
  for (var i = 0; i < 7; i++) {
    if (by[i].length >= 2 && _mean(by[i]) > bestAvg) {
      best = i;
      bestAvg = _mean(by[i]);
    }
  }
  if (best == null || avgAll <= 0) return null;
  final more = ((bestAvg / avgAll - 1) * 100).round();
  if (more < 15) return null;
  final q = bestAvg.round(), usual = avgAll.round();
  return Insight('weekday', 'sparkle', InsightTone.gold,
      '${_daysMl[best]}കളിൽ ${top['name_ml']} $more% കൂടുതൽ പോകുന്നു (ഏകദേശം $q, മറ്റു ദിവസം $usual). അന്ന് കൂടുതൽ ഉണ്ടാക്കാം.',
      '${_daysEn[best]}s sell $more% more ${top['name_en']} (about $q vs $usual). Make extra that day.');
}

// A stock item whose price per kg/L went up across her recent bills.
Insight? _costRise(List<Rec> purchases, DateTime now) {
  final since = isoDate(now.subtract(const Duration(days: 62)));
  final groups = <String, List<Rec>>{};
  for (final p in purchases) {
    if ((p['date'] as String).compareTo(since) < 0 || _n(p['qty']) == 0 || !['kg', 'L'].contains(p['unit'])) continue;
    groups.putIfAbsent(p['item'], () => []).add(p);
  }
  ({Rec p, num first, num last, int up})? pick;
  for (final list in groups.values) {
    if (list.length < 2) continue;
    list.sort((a, b) => (a['date'] as String).compareTo(b['date']));
    final first = _n(list.first['amount']) / _n(list.first['qty']), last = _n(list.last['amount']) / _n(list.last['qty']);
    final up = ((last / first - 1) * 100).round();
    if (up >= 3 && (pick == null || up > pick.up)) pick = (p: list.last, first: first, last: last, up: up);
  }
  if (pick == null) return null;
  final p = pick.p;
  return Insight('cost', 'up', InsightTone.rose,
      '${p['item_ml'] ?? p['item']} വില ${pick.up}% കൂടി: ${_rs(pick.first)} → ${_rs(pick.last)} / ${p['unit']}. വേറെ കടയിൽ നോക്കാം, അല്ലെങ്കിൽ അടുത്തുള്ളവരുമായി ഒരുമിച്ച് വാങ്ങാം.',
      '${p['item']} went up ${pick.up}% (${_rs(pick.first)} → ${_rs(pick.last)} per ${p['unit']}). Try another shop, or buy together with women nearby.');
}

// Where this month is heading compared with a usual month, and what that means for her goal.
Insight? _pace(Map<String, List<Rec>> d, Rec? top, DateTime now) {
  final month = thisMonth(now);
  final m = monthProfit(d['sales']!, d['products']!, d['bills']!, d['purchases']!, month);
  final avg = avgMonthlyProfit(d['history']!, 3);
  if (avg <= 0) return null;
  final daysIn = DateTime(now.year, now.month + 1, 0).day;
  final soldToday = d['sales']!.any((s) => s['date'] == today(now));
  final done = (now.day - (soldToday ? 0 : 1)).clamp(1, 31);
  if (done < 5) return null;
  final billsTotal = d['bills']!.where((b) => b['month'] == month).fold<num>(0, (s, b) => s + _n(b['amount']));
  final bought = d['purchases']!.where((p) => monthOf(p['date']) == month).fold<num>(0, (s, p) => s + _n(p['amount']));
  final projected = (m.income / done) * daysIn - billsTotal - (bought / done) * daysIn;
  final gap = avg - projected;

  if (gap > 0 && top != null) {
    final n = (gap / _n(top['price'])).ceil();
    return Insight('pace', 'down', InsightTone.gold,
        'ഈ പോക്കിൽ ഈ മാസം ഏകദേശം ${_rs(projected)} ലാഭം. $n ${top['name_ml']} കൂടി വിറ്റാൽ സാധാരണ മാസം (${_rs(avg)}) എത്തും.',
        'At this pace, about ${_rs(projected)} profit this month. $n more ${top['name_en']} gets you to a usual month (${_rs(avg)}).');
  }
  final extra = -gap;
  final goals = d['goals'] ?? const [];
  var soonerMl = '', soonerEn = '';
  if (goals.isNotEmpty && extra >= 500) {
    final goal = goals.first;
    final now1 = goalPlan(goal, avg), with1 = goalPlan({...goal, 'saved': _n(goal['saved']) + extra}, avg);
    final gain = (now1.months ?? 0) - (with1.months ?? 0);
    if (gain >= 1) {
      soonerMl = ' ആ ${_rs(extra)} മാറ്റിവെച്ചാൽ സമ്പാദ്യ ലക്ഷ്യം $gain മാസം നേരത്തെ എത്തും.';
      soonerEn = ' Put that ${_rs(extra)} aside and you reach your savings goal $gain month${gain > 1 ? 's' : ''} sooner.';
    }
  }
  return Insight('pace', 'up', InsightTone.leaf,
      'നല്ല മാസം! ഈ പോക്കിൽ ഏകദേശം ${_rs(projected)} ലാഭം, സാധാരണയേക്കാൾ ${_rs(extra)} കൂടുതൽ.$soonerMl',
      'Good month! At this pace, about ${_rs(projected)} profit: ${_rs(extra)} more than usual.$soonerEn');
}

// A high-price item she sells only a little of: one more a day adds up.
Insight? _smallButValuable(List<Rec> sales, List<Rec> products, DateTime now) {
  final month = thisMonth(now);
  final days = sales.where((s) => monthOf(s['date']) == month).map((s) => s['date']).toSet().length;
  if (days < 5) return null;
  final list = products
      .map((p) => (
            p: p,
            perDay: sales
                    .where((s) => s['product'] == p['id'] && monthOf(s['date']) == month)
                    .fold<num>(0, (n, s) => n + _n(s['qty'])) /
                days
          ))
      .where((x) => x.perDay < 3)
      .toList()
    ..sort((a, b) => _n(b.p['price']).compareTo(_n(a.p['price'])));
  if (list.isEmpty || _n(list.first.p['price']) < 50) return null;
  final pick = list.first, price = _n(pick.p['price']), add = price * 30;
  final per = pick.perDay < 1 ? '1-ൽ താഴെ' : 'ഏകദേശം ${pick.perDay.round()}';
  return Insight('small', 'sparkle', InsightTone.plum,
      '${pick.p['name_ml']} ദിവസം $per മാത്രം. ഓരോന്നിനും ${_rs(price)}. ദിവസം ഒന്ന് കൂടി വിറ്റാൽ മാസം ${_rs(add)} കൂടുതൽ വരുമാനം.',
      '${pick.p['name_en']}: only about ${pick.perDay.round().clamp(1, 99)} a day, at ${_rs(price)} each. One more a day = ${_rs(add)} more sales a month.');
}

// Biggest single cost this month and its share of spending.
Insight? _bigCost(Map<String, List<Rec>> d, DateTime now) {
  final b = breakdown(d['sales']!, d['products']!, d['bills']!, d['purchases']!, thisMonth(now)).bySpend;
  final total = b.fold<num>(0, (s, x) => s + x.amount);
  if (b.isEmpty || total == 0) return null;
  final top = b.first, share = (top.amount / total * 100).round();
  return Insight('bigcost', 'wallet', InsightTone.sky,
      'ഏറ്റവും വലിയ ചെലവ്: ${top.labelMl}, ${_rs(top.amount)} (ആകെ ചെലവിന്റെ $share%). ഇവിടെ ലാഭിച്ചാൽ ഏറ്റവും കൂടുതൽ ഗുണം.',
      '$share% of your spending is ${top.labelEn.toLowerCase()} (${_rs(top.amount)}). Saving here helps the most.');
}

List<Insight> insights(Map<String, List<Rec>> d, [DateTime? at]) {
  final now = at ?? DateTime.now();
  final month = thisMonth(now);
  num income(Rec p) => d['sales']!
      .where((s) => monthOf(s['date']) == month && s['product'] == p['id'])
      .fold<num>(0, (n, s) => n + _n(s['qty']) * _n(p['price']));
  final products = [...d['products']!]..sort((a, b) => income(b).compareTo(income(a)));
  final top = products.isEmpty ? null : products.first;
  return [
    _pace(d, top, now),
    if (top != null) _bestWeekday(d['sales']!, top),
    _costRise(d['purchases']!, now),
    _smallButValuable(d['sales']!, d['products']!, now),
    _bigCost(d, now),
  ].whereType<Insight>().toList();
}
