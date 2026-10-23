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

const monthsMl = ['ജനു', 'ഫെബ്', 'മാർ', 'ഏപ്രി', 'മേയ്', 'ജൂൺ', 'ജൂലൈ', 'ഓഗ', 'സെപ്', 'ഒക്', 'നവം', 'ഡിസം'];
const monthsMlLong = ['ജനുവരി', 'ഫെബ്രുവരി', 'മാർച്ച്', 'ഏപ്രിൽ', 'മേയ്', 'ജൂൺ', 'ജൂലൈ', 'ഓഗസ്റ്റ്', 'സെപ്റ്റംബർ', 'ഒക്ടോബർ', 'നവംബർ', 'ഡിസംബർ'];
const monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
int monthIndex(String month) => int.parse(month.substring(5, 7)) - 1;
