// Mitra's look (Hiba): white pages, soft coloured cards (green = money in, red = money out,
// blue = products, yellow = profit), big rounded buttons, very little text on screen.
// Explanations sit behind a "?" (InfoButton) instead of on the page.
import 'package:flutter/material.dart';

import '../i18n.dart';
import '../strings.dart' show rupees;

class K {
  static const bg = Color(0xFFF7F8F6);
  static const card = Colors.white;
  static const ink = Color(0xFF1B1F1D);
  static const muted = Color(0xFF6B726E);
  static const line = Color(0xFFE8EBE8);

  static const green = Color(0xFF1E8E3E);
  static const greenDark = Color(0xFF176E30);
  static const greenSoft = Color(0xFFE8F5EA);
  static const red = Color(0xFFC0392B);
  static const redDark = Color(0xFFA42E22);
  static const redSoft = Color(0xFFFDECEA);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFE6EEFD);
  static const yellow = Color(0xFFC08A00);
  static const yellowSoft = Color(0xFFFFF5D6);
  static const purple = Color(0xFF7C4DCC);
  static const purpleSoft = Color(0xFFF0EAFB);
  static const teal = Color(0xFF0E8C7F);
  static const tealSoft = Color(0xFFE2F4F1);
  static const orange = Color(0xFFE07A1F);
  static const orangeSoft = Color(0xFFFDEEDF);
  static const pink = Color(0xFFD63F6B);
  static const pinkSoft = Color(0xFFFCE8EE);

  static const r = 18.0;
}

/// Text style in the chosen language's font (Malayalam letters need the Malayalam font).
TextStyle ts(double size, {FontWeight w = FontWeight.w600, Color c = K.ink, double h = 1.3}) => TextStyle(
      fontFamily: L.ml ? 'Malayalam' : 'Jakarta',
      fontFamilyFallback: const ['Malayalam', 'Jakarta'],
      fontSize: L.ml ? size * .94 : size,
      fontWeight: w,
      color: c,
      height: h,
    );

/// Money and numbers: always the number font.
TextStyle money(double size, {Color c = K.ink, FontWeight w = FontWeight.w800}) => TextStyle(
    fontFamily: 'Jakarta', fontSize: size, fontWeight: w, color: c, letterSpacing: -size * .02, height: 1.1,
    fontFeatures: const [FontFeature.tabularFigures()]);

ThemeData mitraTheme2() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: K.green, primary: K.green, surface: Colors.white),
    scaffoldBackgroundColor: K.bg,
    fontFamily: 'Jakarta',
    fontFamilyFallback: const ['Malayalam'],
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
        backgroundColor: K.bg, surfaceTintColor: Colors.transparent, elevation: 0, centerTitle: true, foregroundColor: K.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.line, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.line, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.green, width: 2)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: K.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// Page with a centred title, a back arrow when it was pushed, and an optional "?".
class Page2 extends StatelessWidget {
  final String title;
  final String? info;
  final List<Widget> children;
  final Widget? bottom;
  final Color? tint;
  final List<Widget> actions;
  const Page2({super.key, required this.title, this.info, required this.children, this.bottom, this.tint, this.actions = const []});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: tint ?? K.bg,
        appBar: AppBar(
          backgroundColor: tint ?? K.bg,
          title: Text(title, style: ts(19, w: FontWeight.w800)),
          actions: [...actions, if (info != null) InfoButton(info!), const LangSwitch(), const SizedBox(width: 8)],
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: children),
        bottomNavigationBar: bottom == null ? null : SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: bottom)),
      );
}

/// One tap between Malayalam and English. Shows the language you'd switch to.
class LangSwitch extends StatelessWidget {
  const LangSwitch({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.white,
          shape: const StadiumBorder(side: BorderSide(color: K.line, width: 1.4)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => L.set(L.ml ? 'en' : 'ml'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.translate_rounded, size: 17, color: K.green),
                const SizedBox(width: 5),
                Text(L.ml ? 'EN' : 'മല',
                    style: TextStyle(
                        fontFamily: L.ml ? 'Jakarta' : 'Malayalam', fontSize: 14, fontWeight: FontWeight.w800, color: K.green)),
              ]),
            ),
          ),
        ),
      );
}

/// "?" that opens a short explanation. Keeps the page itself free of long text.
class InfoButton extends StatelessWidget {
  final String infoKey;
  const InfoButton(this.infoKey, {super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tr('help'),
        icon: const Icon(Icons.help_outline_rounded, color: K.muted),
        onPressed: () => showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.lightbulb_outline_rounded, color: K.yellow, size: 28),
                const SizedBox(width: 14),
                Expanded(child: Text(tr(infoKey), style: ts(16, w: FontWeight.w500, h: 1.5))),
              ]),
            ),
          ),
        ),
      );
}

/// Soft coloured card.
class Tint extends StatelessWidget {
  final Color color;
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? border;
  const Tint({super.key, required this.color, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.border});

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(K.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(K.r),
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: border == null
                ? null
                : BoxDecoration(borderRadius: BorderRadius.circular(K.r), border: Border.all(color: border!, width: 1.2)),
            child: child,
          ),
        ),
      );
}

/// White card with a hairline border.
class Box extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const Box({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  Widget build(BuildContext context) => Tint(color: Colors.white, border: K.line, padding: padding, onTap: onTap, child: child);
}

/// Round icon in a soft circle.
class Bubble extends StatelessWidget {
  final IconData icon;
  final Color color, bg;
  final double size;
  const Bubble(this.icon, {super.key, required this.color, required this.bg, this.size = 48});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: size * .52),
      );
}

/// Big full-width button.
class BigBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;
  final bool outline;
  const BigBtn(this.label, {super.key, this.icon, this.color = K.green, this.onTap, this.outline = false});

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? .45 : 1,
        child: Material(
          color: outline ? Colors.white : color,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: outline ? BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: color, width: 1.6)) : null,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[Icon(icon, color: outline ? color : Colors.white, size: 24), const SizedBox(width: 10)],
                Flexible(
                    child: Text(label,
                        textAlign: TextAlign.center, style: ts(18, w: FontWeight.w800, c: outline ? color : Colors.white))),
              ]),
            ),
          ),
        ),
      );
}

/// Row in a list: icon, title, optional subtitle, trailing widget.
class RowItem extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? sub;
  final Widget? trailing;
  final VoidCallback? onTap;
  const RowItem({super.key, required this.leading, required this.title, this.sub, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: ts(16.5, w: FontWeight.w700)),
                if (sub != null && sub!.isNotEmpty) Text(sub!, style: ts(13.5, w: FontWeight.w500, c: K.muted)),
              ]),
            ),
            if (trailing != null) trailing!,
          ]),
        ),
      );
}

/// Section title.
class Heading extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const Heading(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Row(children: [
          Expanded(child: Text(text, style: ts(17, w: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Label + big amount inside a coloured card.
class AmountCard extends StatelessWidget {
  final String label;
  final num value;
  final Color color, bg;
  final IconData icon;
  final Widget? extra;
  const AmountCard({super.key, required this.label, required this.value, required this.color, required this.bg, required this.icon, this.extra});

  @override
  Widget build(BuildContext context) => Tint(
        color: bg,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: ts(15, w: FontWeight.w600, c: K.ink.withValues(alpha: .8))),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: value.toDouble()),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Text(rupees(v), style: money(30, c: color)),
                ),
              ),
            ]),
          ),
          if (extra != null) extra!,
        ]),
      );
}

void say(BuildContext context, String text, {IconData icon = Icons.check_circle_rounded, SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 10), Expanded(child: Text(text, style: ts(15, c: Colors.white)))]),
      action: action,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
}

/// - 10 + stepper.
class Stepper2 extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final VoidCallback? onTapNumber;
  const Stepper2({super.key, required this.value, required this.onChanged, this.onTapNumber});

  Widget _btn(IconData i, Color bg, Color fg, VoidCallback? f) => Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(customBorder: const CircleBorder(), onTap: f, child: SizedBox(width: 54, height: 54, child: Icon(i, color: fg, size: 28))),
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), border: Border.all(color: K.line)),
        child: Row(children: [
          _btn(Icons.remove_rounded, const Color(0xFFF0F1F0), K.ink, value > 1 ? () => onChanged(value - 1) : null),
          Expanded(
            child: GestureDetector(
              onTap: onTapNumber,
              child: Text('$value', textAlign: TextAlign.center, style: money(30)),
            ),
          ),
          _btn(Icons.add_rounded, K.green, Colors.white, value < 999 ? () => onChanged(value + 1) : null),
        ]),
      );
}
