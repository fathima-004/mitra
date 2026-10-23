// Illustrations, same drawings as js/art.js: Kerala auto rickshaw, food, coconut palm.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

String _autoShape(Map<String, String> c) => '''
<path d="M12 44 Q10 12 40 9 H74 Q90 9 94 22 L96 30 H74 V24 H30 Q24 24 24 32 V44 Z" fill="${c['top']}"/>
<rect x="72" y="22" width="4" height="30" fill="${c['top']}"/>
<path d="M30 37 H58 Q62 37 62 41 V46 H30 Z" fill="${c['seat']}"/>
<rect x="30" y="29" width="7" height="14" rx="3" fill="${c['seat']}"/>
<path d="M74 30 H96 Q100 30 102 36 L111 54 Q112 61 105 61 H74 Z" fill="${c['body']}"/>
<path d="M78 31 H95 L100 42 H78 Z" fill="${c['glass']}"/>
<path d="M12 44 H74 V61 H18 Q12 61 12 55 Z" fill="${c['body']}"/>
<rect x="12" y="54" width="99" height="3.5" fill="${c['stripe']}"/>
<circle cx="108" cy="47" r="3" fill="${c['light']}"/>
<path d="M90 63 Q90 53 100 53 Q110 53 110 63" fill="none" stroke="${c['top']}" stroke-width="3"/>
<circle cx="30" cy="66" r="10" fill="${c['tyre']}"/><circle cx="30" cy="66" r="4" fill="${c['hub']}"/>
<circle cx="100" cy="66" r="8.5" fill="${c['tyre']}"/><circle cx="100" cy="66" r="3.5" fill="${c['hub']}"/>''';

const _grey = {
  'top': '#c9c3b5',
  'body': '#e3ddcf',
  'seat': '#bdb6a6',
  'glass': '#ece7dc',
  'stripe': '#d4cdbd',
  'light': '#ece7dc',
  'tyre': '#bdb6a6',
  'hub': '#e3ddcf'
};
const _colour = {
  'top': '#1f2a27',
  'body': '#f2c230',
  'seat': '#b4334d',
  'glass': '#cfe8f0',
  'stripe': '#0d6b5c',
  'light': '#fff7c2',
  'tyre': '#1f2a27',
  'hub': '#9aa59f'
};

/// Auto rickshaw in grey, with the coloured version revealed left to right up to [pct].
class AutoArt extends StatelessWidget {
  final double pct, width;
  const AutoArt({super.key, this.pct = 100, this.width = 150});

  @override
  Widget build(BuildContext context) {
    final w = pct.clamp(0, 100) * 1.2;
    final svg = '''<svg viewBox="0 0 120 80" xmlns="http://www.w3.org/2000/svg">
      <defs><clipPath id="c"><rect x="0" y="0" width="$w" height="80"/></clipPath></defs>
      <ellipse cx="62" cy="77" rx="52" ry="3" fill="#000000" fill-opacity=".12"/>
      ${_autoShape(_grey)}<g clip-path="url(#c)">${_autoShape(_colour)}</g></svg>''';
    return SvgPicture.string(svg, width: width, height: width * 80 / 120);
  }
}

const _food = {
  'biriyani': '''<path d="M17 9 q2 -4 0 -7 M24 8 q2 -4 0 -7 M31 9 q2 -4 0 -7" stroke="#c9b9a0" stroke-width="2" fill="none" stroke-linecap="round"/>
    <ellipse cx="24" cy="19" rx="16" ry="7" fill="#f5d77a"/>
    <circle cx="18" cy="17" r="1.4" fill="#d9822b"/><circle cx="27" cy="15" r="1.4" fill="#b4334d"/><circle cx="31" cy="19" r="1.4" fill="#0a7a4a"/><circle cx="22" cy="21" r="1.2" fill="#d9822b"/>
    <path d="M6 21 H42 Q43 40 24 42 Q5 40 6 21 Z" fill="#b8743a"/>
    <path d="M6 21 H42" stroke="#8f5626" stroke-width="3" stroke-linecap="round"/>
    <path d="M10 30 Q24 34 38 30" stroke="#d99a5e" stroke-width="1.6" fill="none"/>''',
  'chapathi': '''<ellipse cx="24" cy="38" rx="19" ry="4" fill="#e6dfcf"/>
    <circle cx="24" cy="24" r="17" fill="#ebc78e"/>
    <circle cx="17" cy="19" r="2.4" fill="#c79552"/><circle cx="29" cy="16" r="1.8" fill="#c79552"/><circle cx="31" cy="28" r="2.6" fill="#b9823f"/><circle cx="19" cy="30" r="1.6" fill="#c79552"/><circle cx="24" cy="23" r="1.3" fill="#b9823f"/>''',
  'parotta': '''<ellipse cx="24" cy="38" rx="19" ry="4" fill="#e6dfcf"/>
    <circle cx="24" cy="24" r="17" fill="#eab765"/>
    <path d="M24 24 m-3 0 a3 3 0 1 1 6 0 a6 6 0 1 1 -12 0 a9 9 0 1 1 18 0 a12 12 0 1 1 -24 0" stroke="#b9813c" stroke-width="1.8" fill="none"/>''',
  'pickle': '''<rect x="14" y="5" width="20" height="7" rx="2" fill="#0d6b5c"/>
    <path d="M12 13 H36 Q38 13 38 16 V40 Q38 44 34 44 H14 Q10 44 10 40 V16 Q10 13 12 13 Z" fill="#f7efe0" stroke="#d9cfbb" stroke-width="1.5"/>
    <path d="M12 22 H36 V40 Q36 42 34 42 H14 Q12 42 12 40 Z" fill="#c8442e"/>
    <circle cx="18" cy="28" r="2" fill="#e4704f"/><circle cx="27" cy="33" r="2.2" fill="#9e2f1e"/><circle cx="30" cy="26" r="1.6" fill="#f2c230"/>
    <rect x="15" y="26" width="18" height="9" rx="2" fill="#fbf0d4" fill-opacity=".9"/>''',
  'plate': '''<ellipse cx="24" cy="26" rx="20" ry="14" fill="#ffffff" stroke="#e6dfcf" stroke-width="2"/>
    <ellipse cx="24" cy="25" rx="11" ry="7" fill="#f5d77a"/>''',
};

final _foodWords = [
  (RegExp(r'biri|ബിരിയാണി', caseSensitive: false), 'biriyani'),
  (RegExp(r'chapat|chapp|ചപ്പാത്തി', caseSensitive: false), 'chapathi'),
  (RegExp(r'parot|porot|പൊറോട്ട', caseSensitive: false), 'parotta'),
  (RegExp(r'pickle|achar|അച്ചാർ', caseSensitive: false), 'pickle'),
];

/// Picture for a product, guessed from its name.
class FoodArt extends StatelessWidget {
  final Map<String, dynamic>? product;
  final double size;
  const FoodArt(this.product, {super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final name = '${product?['name_en'] ?? ''} ${product?['name_ml'] ?? ''}';
    final key = _foodWords.where((w) => w.$1.hasMatch(name)).map((w) => w.$2).firstOrNull ?? 'plate';
    return SvgPicture.string('<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">${_food[key]}</svg>', width: size, height: size);
  }
}

/// Coconut palm silhouette for the green hero cards.
class PalmArt extends StatelessWidget {
  final double size;
  final Color color;
  const PalmArt({super.key, this.size = 170, this.color = const Color(0x12FFFFFF)});

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        '''<svg viewBox="0 0 130 130" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="#ffffff" stroke-linecap="round">
        <path d="M74 130 Q66 88 80 42" stroke-width="5"/>
        <path d="M80 42 Q58 30 38 46 M80 42 Q66 20 46 18 M80 42 Q84 18 102 12 M80 42 Q104 28 122 44 M80 42 Q100 46 108 68 M80 42 Q60 48 52 70" stroke-width="5"/>
        </g><circle cx="78" cy="48" r="4" fill="#ffffff"/><circle cx="85" cy="47" r="4" fill="#ffffff"/></svg>''',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}
