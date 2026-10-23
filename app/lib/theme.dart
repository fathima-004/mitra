// "Kasavu" look, same as css/style.css: cream like a Kerala set-saree, deep green, a thin gold border.
import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFFF7F3EA);
  static const bg2 = Color(0xFFEFE8D8);
  static const card = Color(0xFFFFFDF8);
  static const ink = Color(0xFF17231F);
  static const muted = Color(0xFF5E6B66);
  static const line = Color(0xFFE6DFCF);
  static const brand = Color(0xFF0D6B5C);
  static const brandDark = Color(0xFF08483E);
  static const brandDeep = Color(0xFF062F29);
  static const brandSoft = Color(0xFFDFF0EA);
  static const gold = Color(0xFFC9971F);
  static const goldSoft = Color(0xFFFBF0D4);
  static const goldText = Color(0xFF8A6410);
  static const goldLight = Color(0xFFF6DC8C);
  static const green = Color(0xFF0A7A4A);
  static const greenSoft = Color(0xFFE1F5EA);
  static const red = Color(0xFFB3361F);
  static const redSoft = Color(0xFFFBE9E4);
  static const mint = Color(0xFF7EE2C0);
  static const roseSoft = Color(0xFFFDE7EA), rose = Color(0xFFB4334D);
  static const skySoft = Color(0xFFE3EFFD), sky = Color(0xFF2C5FA8);
  static const plumSoft = Color(0xFFEFE6F8), plum = Color(0xFF6B3FA0);

  static const goldLine = LinearGradient(colors: [Color(0xFFA87A12), Color(0xFFF0C95A), gold, goldLight, Color(0xFFA87A12)], stops: [0, .3, .55, .8, 1]);
  static const heroGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [brand, brandDark, brandDeep], stops: [0, .55, 1]);
}

const fonts = ['Malayalam'];

/// Style for big money numbers.
TextStyle numStyle(double size, {Color color = C.ink, FontWeight weight = FontWeight.w800}) => TextStyle(
    fontFamily: 'Jakarta',
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: -size * .02,
    fontFeatures: const [FontFeature.tabularFigures()],
    height: 1.1);
