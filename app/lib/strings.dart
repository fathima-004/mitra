// Malayalam + English text from assets/data/ml.json (the same file the web app uses).
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class T {
  static Map<String, dynamic> _s = {};

  static Future<void> load() async {
    _s = jsonDecode(await rootBundle.loadString('assets/data/ml.json')) as Map<String, dynamic>;
  }

  /// Malayalam for a key. Falls back to English, then to the key itself.
  static String ml(String key) {
    final v = _s[key] as Map?;
    final m = v?['ml'] as String?;
    return (m == null || m.isEmpty) ? (v?['en'] as String? ?? key) : m;
  }

  static String en(String key) => (_s[key] as Map?)?['en'] as String? ?? key;
}

final _inr = NumberFormat.decimalPattern('en_IN');
String rupees(num n) => '${n < 0 ? '−' : ''}₹${_inr.format(n.abs().round())}';
