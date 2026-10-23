import 'package:flutter/material.dart';

import '../logic/insights.dart';
import '../theme.dart';
import 'common.dart';

const _tones = {
  InsightTone.gold: (C.goldSoft, Color(0xFF9A6F0E)),
  InsightTone.rose: (C.roseSoft, C.rose),
  InsightTone.leaf: (C.greenSoft, C.green),
  InsightTone.plum: (C.plumSoft, C.plum),
  InsightTone.sky: (C.skySoft, C.sky),
};
const _icons = {
  'up': Icons.arrow_upward_rounded,
  'down': Icons.arrow_downward_rounded,
  'sparkle': Icons.auto_awesome_rounded,
  'wallet': Icons.account_balance_wallet_outlined,
};

class InsightTile extends StatelessWidget {
  final Insight insight;
  const InsightTile(this.insight, {super.key});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _tones[insight.tone]!;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Badge2(_icons[insight.icon] ?? Icons.auto_awesome_rounded, bg: bg, fg: fg, size: 40),
      const SizedBox(width: 12),
      Expanded(child: Bi(insight.ml, insight.en, size: 15)),
    ]);
  }
}

/// Card title with an icon in front.
class IconTitle extends StatelessWidget {
  final IconData icon;
  final String keyName;
  const IconTitle(this.icon, this.keyName, {super.key});

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 20, color: C.ink)),
        const SizedBox(width: 8),
        Expanded(child: Bi.k(keyName, size: 16, weight: FontWeight.w700)),
      ]);
}
