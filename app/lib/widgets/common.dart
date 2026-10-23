// Shared building blocks: two-line labels, cards, the green hero, count-up money, bars.
import 'package:flutter/material.dart';

import '../strings.dart';
import '../theme.dart';
import 'art.dart';

/// Malayalam first, English smaller under it.
class Bi extends StatelessWidget {
  final String ml, en;
  final double size;
  final Color? color, enColor;
  final FontWeight weight;
  final TextAlign align;
  const Bi(this.ml, this.en,
      {super.key, this.size = 16, this.color, this.enColor, this.weight = FontWeight.w600, this.align = TextAlign.start});

  /// From a ml.json key.
  factory Bi.k(String key, {double size = 16, Color? color, Color? enColor, FontWeight weight = FontWeight.w600, TextAlign align = TextAlign.start}) =>
      Bi(T.ml(key), T.en(key), size: size, color: color, enColor: enColor, weight: weight, align: align);

  @override
  Widget build(BuildContext context) {
    final cross = align == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    return Column(crossAxisAlignment: cross, mainAxisSize: MainAxisSize.min, children: [
      Text(ml, textAlign: align, style: TextStyle(fontFamily: 'Malayalam', fontSize: size, fontWeight: weight, color: color ?? C.ink, height: 1.45)),
      if (en.isNotEmpty && en != ml)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(en, textAlign: align, style: TextStyle(fontSize: size * .78, fontWeight: FontWeight.w500, color: enColor ?? C.muted, height: 1.35)),
        ),
    ]);
  }
}

class MCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;
  final Border? border;
  const MCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.color = C.card, this.border});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: border ?? Border.all(color: C.line.withValues(alpha: .7)),
        boxShadow: const [BoxShadow(color: Color(0x1417231F), blurRadius: 20, offset: Offset(0, 6), spreadRadius: -6)],
      ),
      child: child,
    );
    return onTap == null ? box : GestureDetector(onTap: onTap, child: box);
  }
}

/// Deep green card with a palm and the gold kasavu border along the bottom.
class HeroCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool palm;
  const HeroCard({super.key, required this.child, this.onTap, this.palm = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: C.heroGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x59062F29), blurRadius: 40, offset: Offset(0, 20), spreadRadius: -12)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(right: -60, top: -60, child: Container(width: 220, height: 220,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x0DFFFFFF), width: 28)))),
          if (palm) const Positioned(right: -18, bottom: -6, child: PalmArt()),
          Padding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 26), child: child),
          Positioned(left: 0, right: 0, bottom: 0, child: Container(height: 7, decoration: const BoxDecoration(gradient: C.goldLine))),
        ]),
      ),
    );
  }
}

/// Money that counts up to its new value.
class Money extends StatelessWidget {
  final num value;
  final TextStyle style;
  const Money(this.value, {super.key, required this.style});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: value.toDouble()),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text(rupees(v), style: style),
      );
}

/// Thin progress bar.
class HBar extends StatelessWidget {
  final double fraction;
  final Gradient gradient;
  final Color track;
  final double height;
  const HBar(this.fraction,
      {super.key,
      this.gradient = const LinearGradient(colors: [C.brand, Color(0xFF2AA58A)]),
      this.track = C.bg2,
      this.height = 10});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Container(
          height: height,
          color: track,
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: fraction.clamp(0, 1)),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, f, __) => FractionallySizedBox(
                widthFactor: f, child: Container(decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(99)))),
          ),
        ),
      );
}

const goldBar = LinearGradient(colors: [C.goldLight, C.gold]);

/// Rounded icon tile.
class Badge2 extends StatelessWidget {
  final IconData icon;
  final Color bg, fg;
  final double size;
  const Badge2(this.icon, {super.key, this.bg = C.brandSoft, this.fg = C.brand, this.size = 42});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * .3)),
        child: Icon(icon, color: fg, size: size * .5),
      );
}

/// Section of a card: list rows separated by dashed-looking lines.
class Rows extends StatelessWidget {
  final List<Widget> children;
  const Rows(this.children, {super.key});

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < children.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: C.line))),
            child: children[i],
          ),
      ]);
}

/// Page title with a back button.
class TopBar extends StatelessWidget {
  final String keyName;
  const TopBar(this.keyName, {super.key});

  @override
  Widget build(BuildContext context) => Row(children: [
        if (Navigator.of(context).canPop()) ...[
          Material(
            color: C.card,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox(width: 46, height: 46, child: Icon(Icons.arrow_back_rounded, color: C.ink)),
            ),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(child: Bi.k(keyName, size: 24, weight: FontWeight.w800)),
      ]);
}

void toast(BuildContext context, String key, {IconData icon = Icons.check_rounded}) {
  final text = T.ml(key) == key ? key : '${T.ml(key)} · ${T.en(key)}';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [Icon(icon, color: C.goldLight, size: 18), const SizedBox(width: 10), Expanded(child: Text(text))]),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
    ));
}

/// Primary button: green gradient, Malayalam + English.
class BigButton extends StatelessWidget {
  final String keyName;
  final VoidCallback? onPressed;
  final bool gold;
  final IconData? icon;
  const BigButton(this.keyName, {super.key, this.onPressed, this.gold = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final fg = gold ? C.brandDeep : Colors.white;
    return Opacity(
      opacity: onPressed == null ? .5 : 1,
      child: Material(
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gold
                ? const LinearGradient(colors: [Color(0xFFF0C95A), C.gold])
                : const LinearGradient(colors: [C.brand, C.brandDeep], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: InkWell(
            onTap: onPressed,
            child: Container(
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              alignment: Alignment.center,
              // One text, so a long label wraps onto a second line instead of being cut off.
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, color: fg, size: 20), const SizedBox(width: 8)],
                Flexible(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: T.ml(keyName), style: TextStyle(fontFamily: 'Malayalam', color: fg, fontWeight: FontWeight.w800, fontSize: 17)),
                      TextSpan(text: '  ${T.en(keyName)}', style: TextStyle(color: fg.withValues(alpha: .8), fontWeight: FontWeight.w600, fontSize: 14)),
                    ]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
