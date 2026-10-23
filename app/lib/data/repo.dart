// App data (same shapes as PLAN.md §5 and js/data.js). Kept on the phone with shared_preferences,
// so the demo works without Wi-Fi. Firestore can be added behind these same methods later.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/calc.dart';

const collections = ['products', 'bills', 'purchases', 'sales', 'history', 'goals', 'words'];

class Repo extends ChangeNotifier {
  static const _key = 'mitra:demo1';
  late SharedPreferences _prefs;
  Map<String, dynamic> user = {};
  final Map<String, List<Rec>> data = {for (final c in collections) c: <Rec>[]};
  List<Rec> bulk = [];

  /// The id of the newest sale saved by a phone call, so screens can flash it.
  String? lastCallSale;

  List<Rec> operator [](String col) => data[col] ?? const [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_key);
    if (raw == null) {
      await loadDemo();
    } else {
      _read(jsonDecode(raw) as Map<String, dynamic>);
    }
  }

  void _read(Map<String, dynamic> j) {
    user = Map<String, dynamic>.from(j['user'] ?? {});
    for (final c in collections) {
      data[c] = [for (final r in (j[c] as List? ?? const [])) Map<String, dynamic>.from(r as Map)];
    }
    bulk = [for (final r in (j['bulk_requests'] as List? ?? const [])) Map<String, dynamic>.from(r as Map)];
  }

  Future<void> _save() async {
    await _prefs.setString(_key, jsonEncode({'user': user, ...data, 'bulk_requests': bulk}));
    notifyListeners();
  }

  /// Reset to Sheela's example month (assets/data/demo.json).
  Future<void> loadDemo() async {
    _read(jsonDecode(await rootBundle.loadString('assets/data/demo.json')) as Map<String, dynamic>);
    lastCallSale = null;
    await _save();
  }

  String _newId(String col) => '${col.substring(0, 1)}${DateTime.now().microsecondsSinceEpoch}';

  Future<String> add(String col, Rec obj) async {
    final id = (obj['id'] as String?) ?? _newId(col);
    data[col] = [...this[col], {...obj, 'id': id}];
    if (col == 'sales' && (obj['via'] == 'call' || obj['via'] == 'web-call')) lastCallSale = id;
    await _save();
    return id;
  }

  Future<void> update(String col, String id, Rec obj) async {
    data[col] = [for (final r in this[col]) r['id'] == id ? {...r, ...obj} : r];
    await _save();
  }

  Future<void> remove(String col, String id) async {
    data[col] = this[col].where((r) => r['id'] != id).toList();
    await _save();
  }
}
