// Firestore sync against an in-memory fake of the Firestore REST API.
// Run: flutter test --dart-define=FIREBASE_PROJECT=test
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mitra/config.dart';
import 'package:mitra/data/repo.dart';
import 'package:mitra/i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';

const root = 'projects/test/databases/(default)/documents';

/// Documents by full name ("projects/.../documents/users/demo1/sales/s1") → Firestore fields.
class FakeFirestore {
  final docs = <String, Map<String, dynamic>>{};
  bool down = false;
  int writes = 0;

  Map<String, dynamic> _docJson(String name) => {'name': name, 'fields': docs[name]};

  Future<http.Response> handle(http.Request req) async {
    return _handle(req);
  }

  static http.Response _res(String body, int status) =>
      http.Response.bytes(utf8.encode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

  Future<http.Response> _handle(http.Request req) async {
    if (down) throw http.ClientException('no network');
    final path = Uri.decodeFull(req.url.path).replaceFirst('/v1/', '');
    if (req.method == 'POST' && path.endsWith(':commit')) {
      for (final w in (jsonDecode(req.body)['writes'] as List)) {
        if (w['delete'] != null) docs.remove(w['delete']);
        if (w['update'] != null) docs[w['update']['name']] = Map<String, dynamic>.from(w['update']['fields']);
        writes++;
      }
      return _res('{}', 200);
    }
    if (req.method == 'POST' && path.endsWith(':runQuery')) {
      final q = jsonDecode(req.body)['structuredQuery'];
      final col = q['from'][0]['collectionId'];
      final want = q['where']['fieldFilter']['value']['stringValue'];
      final prefix = '${path.replaceFirst(':runQuery', '')}/$col/';
      final hits =
          docs.keys.where((n) => n.startsWith(prefix) && !n.substring(prefix.length).contains('/')).where((n) => docs[n]!['date']?['stringValue'] == want);
      return _res(
          jsonEncode([
            for (final n in hits) {'document': _docJson(n)}
          ]),
          200);
    }
    if (req.method == 'PATCH') {
      final fields = Map<String, dynamic>.from(jsonDecode(req.body)['fields']);
      final mask = req.url.queryParametersAll['updateMask.fieldPaths'];
      // With an update mask only those fields change, like real Firestore.
      docs[path] = mask == null
          ? fields
          : {
              ...?docs[path],
              for (final k in mask)
                if (fields.containsKey(k)) k: fields[k]
            };
      writes++;
      return _res(jsonEncode(_docJson(path)), 200);
    }
    if (req.method == 'DELETE') {
      docs.remove(path);
      writes++;
      return _res('{}', 200);
    }
    if (req.method == 'GET') {
      if (docs.containsKey(path)) return _res(jsonEncode(_docJson(path)), 200);
      final prefix = '$path/';
      final kids = docs.keys.where((n) => n.startsWith(prefix) && !n.substring(prefix.length).contains('/')).toList();
      final depth = path.split('/').length - root.split('/').length;
      if (depth.isEven) return _res('{"error":"not found"}', 404); // a document path
      return _res(
          jsonEncode({
            'documents': [for (final n in kids) _docJson(n)]
          }),
          200);
    }
    return _res('unexpected', 500);
  }

  /// What the phone call does: one sale saved in Firestore with via:"call".
  void callSale(String id, String date, String product, int qty) {
    docs['$root/users/demo1/sales/$id'] = {
      'id': {'stringValue': id},
      'date': {'stringValue': date},
      'product': {'stringValue': product},
      'qty': {'integerValue': '$qty'},
      'via': {'stringValue': 'call'},
    };
  }

  int count(String col) => docs.keys.where((n) => n.startsWith('$root/users/demo1/$col/')).length;
}

String todayIso() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('runs with the Firestore project set', () => expect(cloudConfigured, isTrue, reason: 'run with --dart-define=FIREBASE_PROJECT=test'));

  test('first run fills an empty Firestore with the demo month', () async {
    final fs = FakeFirestore();
    await http.runWithClient(() async {
      final repo = Repo();
      await repo.init();
      await repo.syncNow();
      expect(fs.docs.containsKey('$root/users/demo1'), isTrue);
      expect(fs.count('sales'), repo['sales'].length);
      expect(fs.count('products'), 4);
      expect(repo.online, isTrue);
      repo.dispose();
    }, () => MockClient(fs.handle));
  });

  test('a sale saved by the phone call shows up in the app and is announced', () async {
    final fs = FakeFirestore();
    await http.runWithClient(() async {
      final repo = Repo();
      await repo.init();
      await repo.syncNow(); // seeds
      await repo.syncNow(); // full pull
      final before = repo['sales'].length;
      var announced = 0;
      repo.callSales.addListener(() => announced++);

      fs.callSale('call1', todayIso(), 'p1', 12);
      await repo.syncNow();

      expect(repo['sales'].length, before + 1);
      expect(repo['sales'].any((s) => s['id'] == 'call1' && s['qty'] == 12 && s['via'] == 'call'), isTrue);
      expect(announced, 1);

      await repo.syncNow(); // nothing new: no second announcement
      expect(announced, 1);
      repo.dispose();
    }, () => MockClient(fs.handle));
  });

  test('sales added in the app reach Firestore; offline ones wait and are sent later', () async {
    final fs = FakeFirestore();
    await http.runWithClient(() async {
      final repo = Repo();
      await repo.init();
      await repo.syncNow();
      await repo.syncNow();
      final start = fs.count('sales');

      await repo.add('sales', {'date': todayIso(), 'product': 'p2', 'qty': 30, 'via': 'app'});
      await repo.syncNow();
      expect(fs.count('sales'), start + 1);

      fs.down = true;
      await repo.add('sales', {'date': todayIso(), 'product': 'p3', 'qty': 5, 'via': 'app'});
      await repo.add('sales', {'date': todayIso(), 'product': 'p4', 'qty': 2, 'via': 'app'});
      await repo.syncNow();
      expect(repo.online, isFalse);
      expect(fs.count('sales'), start + 1);
      // Offline rows stay on the phone, even though Firestore doesn't have them yet.
      expect(repo['sales'].where((s) => s['date'] == todayIso() && (s['product'] == 'p3' || s['product'] == 'p4')).length, 2);

      fs.down = false;
      await repo.syncNow();
      expect(fs.count('sales'), start + 3);
      expect(repo['sales'].where((s) => s['date'] == todayIso() && (s['product'] == 'p3' || s['product'] == 'p4')).length, 2);
      expect(repo.online, isTrue);

      // Undo in the app deletes it in Firestore too.
      final id = repo['sales'].firstWhere((s) => s['product'] == 'p4')['id'] as String;
      await repo.remove('sales', id);
      await repo.syncNow();
      expect(fs.count('sales'), start + 2);
      repo.dispose();
    }, () => MockClient(fs.handle));
  });

  test('reset demo resets Firestore too', () async {
    final fs = FakeFirestore();
    await http.runWithClient(() async {
      final repo = Repo();
      await repo.init();
      await repo.syncNow();
      fs.callSale('call9', todayIso(), 'p1', 3);
      await repo.syncNow();
      await repo.loadDemo();
      await repo.syncNow(); // the demo's sales for today follow the reset
      expect(fs.docs.containsKey('$root/users/demo1/sales/call9'), isFalse);
      expect(fs.count('sales'), repo['sales'].length);
      repo.dispose();
    }, () => MockClient(fs.handle));
  });

  test('a change made on the phone call (not a sale) shows up after the next check', () async {
    final fs = FakeFirestore();
    await http.runWithClient(() async {
      final repo = Repo();
      await repo.init();
      await repo.syncNow(); // seeds
      await repo.syncNow(); // full pull
      // The call saves an expense and stamps users/demo1.changedAt.
      fs.docs['$root/users/demo1/purchases/callx1'] = {
        'id': {'stringValue': 'callx1'},
        'date': {'stringValue': todayIso()},
        'item': {'stringValue': 'Gas'},
        'cat': {'stringValue': 'gas'},
        'amount': {'integerValue': '900'},
        'via': {'stringValue': 'call'},
      };
      fs.docs['$root/users/demo1']!['changedAt'] = {'stringValue': '2026-10-24T10:00:00Z'};
      await repo.syncNow();
      expect(repo['purchases'].any((p) => p['id'] == 'callx1' && p['amount'] == 900), isTrue);
      repo.dispose();
    }, () => MockClient(fs.handle));
  });

  test('many saves in the same instant all keep their own row', () async {
    SharedPreferences.setMockInitialValues({});
    final fs = FakeFirestore();
    await http.runWithClient(() async {
      final repo = Repo();
      await repo.init();
      final before = repo['sales'].length;
      await Future.wait([
        for (var i = 0; i < 20; i++) repo.add('sales', {'date': todayIso(), 'product': 'p1', 'qty': 1, 'via': 'app'})
      ]);
      expect(repo['sales'].length, before + 20);
      expect(repo['sales'].map((s) => s['id']).toSet().length, repo['sales'].length);
      repo.dispose();
    }, () => MockClient(fs.handle));
  });

  test('the language is shared with the phone call both ways', () async {
    SharedPreferences.setMockInitialValues({});
    final fs = FakeFirestore();
    await http.runWithClient(() async {
      final repo = Repo();
      await repo.init();
      L.lang.value = 'ml';
      syncLanguage(repo);
      await repo.syncNow(); // seeds
      await repo.syncNow();

      // App → call: switching in the app saves users/demo1.lang.
      await L.set('en');
      await repo.syncNow();
      expect(fs.docs['$root/users/demo1']?['lang']?['stringValue'], 'en');
      expect(fs.docs['$root/users/demo1']?['name']?['stringValue'], 'Sheela', reason: 'other fields must stay');

      // Call → app: pressing 8 on the call saves "ml" and stamps changedAt; the app follows.
      fs.docs['$root/users/demo1']!['lang'] = {'stringValue': 'ml'};
      fs.docs['$root/users/demo1']!['changedAt'] = {'stringValue': '2026-10-24T11:00:00Z'};
      await repo.syncNow();
      expect(L.lang.value, 'ml');
      repo.dispose();
    }, () => MockClient(fs.handle));
  });
}
