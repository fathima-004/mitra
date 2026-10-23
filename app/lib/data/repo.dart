// App data (same shapes as PLAN.md §5 and js/data.js). Owner: Hiba.
// The phone keeps a full copy (shared_preferences), so the demo works without Wi-Fi.
// When Firestore is configured (lib/config.dart), the copy follows Firestore: today's sales are checked
// every few seconds, so a sale saved by the phone call shows up live, and every change made here is sent
// to Firestore. Changes made offline wait in an outbox and are sent when the connection returns.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../logic/calc.dart';
import 'cloud.dart' as cloud;

const collections = ['products', 'bills', 'purchases', 'sales', 'history', 'goals', 'words'];

class Repo extends ChangeNotifier with WidgetsBindingObserver {
  static const _key = 'mitra:demo1';
  static const _outboxKey = 'mitra:outbox';
  static const _poll = Duration(seconds: 4);

  late SharedPreferences _prefs;
  Map<String, dynamic> user = {};
  final Map<String, List<Rec>> data = {for (final c in collections) c: <Rec>[]};
  List<Rec> bulk = [];

  /// The id of the newest sale saved by a phone call, so screens can flash it.
  String? lastCallSale;

  /// Goes up by one each time a sale from the phone call arrives from Firestore.
  final callSales = ValueNotifier<int>(0);

  /// Whether the last talk with Firestore worked. Always false when Firestore isn't configured.
  bool online = false;

  List<Rec> _outbox = [];
  Timer? _timer;
  bool _disposed = false;
  bool _pulledAll = false;
  bool _active = true;

  List<Rec> operator [](String col) => data[col] ?? const [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_key);
    if (raw == null) {
      await _loadDemoLocal();
    } else {
      _read(jsonDecode(raw) as Map<String, dynamic>);
    }
    _outbox = [
      for (final r in (jsonDecode(_prefs.getString(_outboxKey) ?? '[]') as List)) Map<String, dynamic>.from(r as Map),
    ];
    if (cloudConfigured) {
      WidgetsBinding.instance.addObserver(this);
      unawaited(_tick());
      _timer = Timer.periodic(_poll, (_) => _tick());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      _pulledAll = false; // something may have changed while the app was closed
      unawaited(_tick());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _read(Map<String, dynamic> j) {
    user = Map<String, dynamic>.from(j['user'] ?? {});
    for (final c in collections) {
      data[c] = [for (final r in (j[c] as List? ?? const [])) Map<String, dynamic>.from(r as Map)];
    }
    bulk = [for (final r in (j['bulk_requests'] as List? ?? const [])) Map<String, dynamic>.from(r as Map)];
  }

  Map<String, dynamic> _snapshot() => {'user': user, ...data, 'bulk_requests': bulk};

  Future<void> _save() async {
    await _prefs.setString(_key, jsonEncode(_snapshot()));
    if (!_disposed) notifyListeners();
  }

  Future<Map<String, dynamic>> _demo() async =>
      jsonDecode(await rootBundle.loadString('assets/data/demo.json')) as Map<String, dynamic>;

  Future<void> _loadDemoLocal() async {
    _read(await _demo());
    lastCallSale = null;
    await _save();
  }

  /// Reset to Sheela's example month (assets/data/demo.json), on the phone and in Firestore.
  Future<void> loadDemo() async {
    final demo = await _demo();
    _read(demo);
    lastCallSale = null;
    _outbox = [];
    await _saveOutbox();
    await _save();
    if (!cloudConfigured) return;
    try {
      await cloud.resetTo(demo, collections);
      online = true;
    } catch (e) {
      online = false;
      debugPrint('reset in Firestore failed: $e');
    }
    if (!_disposed) notifyListeners();
  }

  String _newId(String col) => '${col.substring(0, 1)}${DateTime.now().microsecondsSinceEpoch}';

  Future<String> add(String col, Rec obj) async {
    final id = (obj['id'] as String?) ?? _newId(col);
    final row = {...obj, 'id': id};
    data[col] = [...this[col], row];
    if (col == 'sales' && _byCall(row)) lastCallSale = id;
    await _save();
    _queue({'op': 'set', 'col': col, 'id': id, 'row': row});
    return id;
  }

  Future<void> update(String col, String id, Rec obj) async {
    Rec? merged;
    data[col] = [
      for (final r in this[col])
        if (r['id'] == id) merged = {...r, ...obj, 'id': id} else r,
    ];
    await _save();
    if (merged != null) _queue({'op': 'set', 'col': col, 'id': id, 'row': merged});
  }

  Future<void> remove(String col, String id) async {
    data[col] = this[col].where((r) => r['id'] != id).toList();
    await _save();
    _queue({'op': 'delete', 'col': col, 'id': id});
  }

  /// Her name and place (users/demo1).
  Future<void> setUser(Rec changes) async {
    user = {...user, ...changes};
    await _save();
    _queue({'op': 'user', 'col': 'users', 'id': 'demo1', 'row': user});
  }

  /// A request on the buy-together board (bulk_requests).
  Future<String> addBulk(Rec obj) async {
    final id = _newId('bulk');
    final row = {...obj, 'id': id};
    bulk = [...bulk, row];
    await _save();
    _queue({'op': 'set', 'col': 'bulk_requests', 'id': id, 'row': row});
    return id;
  }

  static bool _byCall(Rec s) => s['via'] == 'call' || s['via'] == 'web-call';

  // ---- Firestore sync ----

  void _queue(Rec op) {
    if (!cloudConfigured) return;
    _outbox.add(op);
    unawaited(_saveOutbox().then((_) => _flush()));
  }

  Future<void> _saveOutbox() => _prefs.setString(_outboxKey, jsonEncode(_outbox));

  /// Sends waiting changes in order. Stops at the first failure and keeps the rest for later.
  /// Only one send runs at a time: two at once could each remove the same "sent" entry and drop a change.
  Future<void>? _flushing;
  Future<void> _flush() => _flushing ??= _send().whenComplete(() => _flushing = null);

  Future<void> _send() async {
    while (_outbox.isNotEmpty) {
      final op = _outbox.first;
      try {
        if (op['op'] == 'user') {
          await cloud.setUser(Map<String, dynamic>.from(op['row'] as Map));
        } else if (op['op'] == 'delete') {
          await cloud.delete(op['col'], op['id']);
        } else {
          await cloud.set(op['col'], op['id'], Map<String, dynamic>.from(op['row'] as Map));
        }
      } catch (e) {
        online = false;
        debugPrint('send to Firestore failed, will retry: $e');
        return;
      }
      _outbox.removeAt(0);
      await _saveOutbox();
    }
  }

  /// One Firestore check right now (tests, and a pull-to-refresh later). Waits for a check already running.
  Future<void> syncNow() => _tick();

  Future<void>? _ticking;
  Future<void> _tick() {
    if (!cloudConfigured || !_active || _disposed) return Future.value();
    return _ticking ??= _check().whenComplete(() => _ticking = null);
  }

  Future<void> _check() async {
    final wasOnline = online;
    try {
      await _flush();
      // Never let Firestore overwrite changes that haven't reached it yet.
      if (_outbox.isNotEmpty) {
        online = false;
        return;
      }
      if (_pulledAll) {
        await _pullToday();
      } else {
        await _pullAll();
      }
      online = true;
    } catch (e) {
      online = false;
      debugPrint('Firestore check failed: $e');
    } finally {
      if (online != wasOnline && !_disposed) notifyListeners();
    }
  }

  Future<void> _pullAll() async {
    final remoteUser = await cloud.getUser();
    if (remoteUser == null) {
      // Firestore was never filled: put this phone's copy there (like the first run of js/data.js).
      await cloud.resetTo(_snapshot(), collections);
      _pulledAll = true;
      return;
    }
    final lists = await Future.wait([for (final c in collections) cloud.list(c)]);
    final remoteBulk = await cloud.list('bulk_requests');
    final before = _ids(this['sales']);
    final next = {'user': remoteUser, for (var i = 0; i < collections.length; i++) collections[i]: lists[i], 'bulk_requests': remoteBulk};
    await _apply(next, before);
    _pulledAll = true;
  }

  Future<void> _pullToday() async {
    final day = today();
    final remote = await cloud.salesOn(day);
    final before = _ids(this['sales']);
    final sales = [...this['sales'].where((s) => s['date'] != day), ...remote];
    await _apply({..._snapshot(), 'sales': sales}, before);
  }

  static Set<Object?> _ids(List<Rec> rows) => {for (final r in rows) r['id']};

  Future<void> _apply(Map<String, dynamic> next, Set<Object?> salesBefore) async {
    // Same order every time, so comparing the JSON tells us if anything really changed.
    for (final c in [...collections, 'bulk_requests']) {
      final rows = [for (final r in (next[c] as List? ?? const [])) Map<String, dynamic>.from(r as Map)]
        ..sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
      next[c] = rows;
    }
    final current = _snapshot();
    for (final c in [...collections, 'bulk_requests']) {
      current[c] = [...(current[c] as List)]..sort((a, b) => '${(a as Map)['id']}'.compareTo('${(b as Map)['id']}'));
    }
    if (jsonEncode(next) == jsonEncode(current)) return;

    final fromCall = (next['sales'] as List).cast<Rec>().where((s) => !salesBefore.contains(s['id']) && _byCall(s) && s['date'] == today()).toList();
    _read(next);
    if (fromCall.isNotEmpty) {
      lastCallSale = fromCall.last['id'] as String?;
      callSales.value++;
    }
    await _save();
  }
}
