// Money Health maths, same as js/money.js. No AI, never suggests a loan or lender.
import 'calc.dart';

num _n(Object? v) => v is num ? v : num.tryParse('$v') ?? 0;

String addMonths(String month, int n) {
  final y = int.parse(month.substring(0, 4)), m = int.parse(month.substring(5, 7));
  final d = DateTime(y, m - 1 + n + 1, 1);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

class GoalPlan {
  final int pct;
  final num left;
  final int? months;
  final String? ready;
  final double? share;
  GoalPlan(this.pct, this.left, this.months, this.ready, this.share);
}

GoalPlan goalPlan(Rec goal, num avgProfit) {
  final target = _n(goal['target']), saved = _n(goal['saved']), monthly = _n(goal['monthly']);
  final pct = target > 0 ? ((saved / target) * 100).round().clamp(0, 100) : 0;
  final left = (target - saved).clamp(0, double.infinity);
  final int? months = left == 0 ? 0 : (monthly > 0 ? (left / monthly).ceil() : null);
  return GoalPlan(pct, left, months, months == null ? null : addMonths(thisMonth(), months),
      avgProfit > 0 ? monthly / avgProfit : null);
}

enum EmiLevel { ok, tight, risky }

class EmiResult {
  final num afterAvg, afterWorst;
  final double share;
  final EmiLevel level;
  EmiResult(this.afterAvg, this.afterWorst, this.share, this.level);
}

EmiResult emiCheck(num newEmi, num avgProfit, num worstMonthProfit) {
  final afterAvg = avgProfit - newEmi, afterWorst = worstMonthProfit - newEmi;
  final share = avgProfit > 0 ? newEmi / avgProfit : 1.0;
  final level = afterWorst < 0 || share > 0.4 ? EmiLevel.risky : (share > 0.2 ? EmiLevel.tight : EmiLevel.ok);
  return EmiResult(afterAvg, afterWorst, share.toDouble(), level);
}

class GstStatus {
  final num limit, turnover, left;
  final double pct;
  final bool needed, checked;
  GstStatus(this.limit, this.turnover, this.left, this.pct, this.needed, this.checked);
}

GstStatus gstStatus(num turnover, Map<String, dynamic> limits) {
  final g = limits['gst'] as Map<String, dynamic>;
  final limit = _n(g[g['use']]);
  return GstStatus(
    limit,
    turnover,
    (limit - turnover).clamp(0, double.infinity),
    limit > 0 ? ((turnover / limit) * 100).clamp(0, 100).toDouble() : 0,
    turnover >= limit,
    '${g['checked_by'] ?? ''}'.isNotEmpty && '${g['date_checked'] ?? ''}'.isNotEmpty,
  );
}

num gstPaid(List<Rec> purchases, String fyStart, [List<Rec> history = const []]) {
  final current = thisMonth();
  final past = history
      .where((h) => (h['month'] as String).compareTo(fyStart) >= 0 && (h['month'] as String).compareTo(current) < 0)
      .fold<num>(0, (s, h) => s + _n(h['gst_paid']));
  final now = purchases.where((p) => monthOf(p['date']) == current).fold<num>(0, (s, p) => s + _n(p['gst']));
  return past + now;
}
