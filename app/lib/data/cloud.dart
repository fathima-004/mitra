// Firestore over its REST API (no Firebase SDK, no google-services.json, no extra Gradle plugins).
// Owner: Hiba. Same paths and shapes as PLAN.md §5 and js/data.js: users/demo1/{col}/{id}, bulk_requests/{id}.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../logic/calc.dart';

const user = 'demo1';
const _timeout = Duration(seconds: 6);

String get _root => 'projects/$firebaseProject/databases/(default)/documents';
String get _base => 'https://firestore.googleapis.com/v1/$_root';

Uri _uri(String path, [Map<String, String> q = const {}]) =>
    Uri.parse('$_base$path').replace(queryParameters: {if (firebaseApiKey.isNotEmpty) 'key': firebaseApiKey, ...q});

String _colPath(String col) => col == 'bulk_requests' ? '/bulk_requests' : '/users/$user/$col';

// ---- Firestore value encoding ----
Map<String, dynamic> _enc(Object? v) {
  if (v == null) return {'nullValue': null};
  if (v is bool) return {'booleanValue': v};
  if (v is int) return {'integerValue': '$v'};
  if (v is num) return {'doubleValue': v};
  if (v is String) return {'stringValue': v};
  if (v is List) return {'arrayValue': {'values': [for (final x in v) _enc(x)]}};
  if (v is Map) return {'mapValue': {'fields': _fields(Map<String, dynamic>.from(v))}};
  return {'stringValue': '$v'};
}

Map<String, dynamic> _fields(Rec row) => {for (final e in row.entries) e.key: _enc(e.value)};

Object? _dec(Map<String, dynamic> v) {
  if (v.containsKey('stringValue')) return v['stringValue'];
  if (v.containsKey('integerValue')) return int.parse('${v['integerValue']}');
  if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
  if (v.containsKey('booleanValue')) return v['booleanValue'];
  if (v.containsKey('timestampValue')) return v['timestampValue'];
  if (v.containsKey('arrayValue')) return [for (final x in (v['arrayValue']['values'] as List? ?? const [])) _dec(Map<String, dynamic>.from(x))];
  if (v.containsKey('mapValue')) return _row(Map<String, dynamic>.from(v['mapValue']['fields'] ?? {}));
  return null;
}

Rec _row(Map<String, dynamic> fields) => {for (final e in fields.entries) e.key: _dec(Map<String, dynamic>.from(e.value))};

Rec _doc(Map<String, dynamic> d) => {..._row(Map<String, dynamic>.from(d['fields'] ?? {})), 'id': (d['name'] as String).split('/').last};

void _check(http.Response r) {
  if (r.statusCode >= 300) throw CloudError(r.statusCode, r.body.length > 200 ? r.body.substring(0, 200) : r.body);
}

class CloudError implements Exception {
  final int status;
  final String body;
  CloudError(this.status, this.body);
  @override
  String toString() => 'Firestore $status: $body';
}

// ---- Reads ----
Future<Rec?> getUser() async {
  final r = await http.get(_uri('/users/$user')).timeout(_timeout);
  if (r.statusCode == 404) return null;
  _check(r);
  final d = _doc(jsonDecode(utf8.decode(r.bodyBytes)))..remove('id');
  return d;
}

Future<List<Rec>> list(String col) async {
  final out = <Rec>[];
  String? token;
  do {
    final r = await http.get(_uri(_colPath(col), {'pageSize': '300', if (token != null) 'pageToken': token})).timeout(_timeout);
    _check(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    for (final d in (j['documents'] as List? ?? const [])) {
      out.add(_doc(Map<String, dynamic>.from(d)));
    }
    token = j['nextPageToken'] as String?;
  } while (token != null);
  return out;
}

/// Today's sales only: a cheap query to run every few seconds (Firestore counts one read per document).
Future<List<Rec>> salesOn(String date) async {
  final r = await http
      .post(_uri('/users/$user:runQuery'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'structuredQuery': {
              'from': [{'collectionId': 'sales'}],
              'where': {
                'fieldFilter': {'field': {'fieldPath': 'date'}, 'op': 'EQUAL', 'value': {'stringValue': date}},
              },
            },
          }))
      .timeout(_timeout);
  _check(r);
  return [
    for (final x in jsonDecode(utf8.decode(r.bodyBytes)) as List)
      if ((x as Map)['document'] != null) _doc(Map<String, dynamic>.from(x['document'])),
  ];
}

// ---- Writes ----
Future<void> set(String col, String id, Rec row) async {
  final r = await http
      .patch(_uri('${_colPath(col)}/$id'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'fields': _fields(row)}))
      .timeout(_timeout);
  _check(r);
}

Future<void> delete(String col, String id) async {
  final r = await http.delete(_uri('${_colPath(col)}/$id')).timeout(_timeout);
  if (r.statusCode != 404) _check(r);
}

/// Replaces demo1 and the bulk board with [demo] (data/demo.json), like loadDemo() in js/data.js.
Future<void> resetTo(Map<String, dynamic> demo, List<String> collections) async {
  final writes = <Map<String, dynamic>>[];
  for (final c in [...collections, 'bulk_requests']) {
    for (final d in await list(c)) {
      writes.add({'delete': '$_root${_colPath(c)}/${d['id']}'});
    }
  }
  writes.add({'update': {'name': '$_root/users/$user', 'fields': _fields(Map<String, dynamic>.from(demo['user'] ?? {}))}});
  for (final c in [...collections, 'bulk_requests']) {
    for (final row in (demo[c] as List? ?? const [])) {
      final r = Map<String, dynamic>.from(row as Map);
      writes.add({'update': {'name': '$_root${_colPath(c)}/${r['id']}', 'fields': _fields(r)}});
    }
  }
  // Firestore takes up to 500 writes per commit.
  for (var i = 0; i < writes.length; i += 400) {
    final r = await http
        .post(Uri.parse('https://firestore.googleapis.com/v1/$_root:commit')
                .replace(queryParameters: {if (firebaseApiKey.isNotEmpty) 'key': firebaseApiKey}),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'writes': writes.sublist(i, i + 400 > writes.length ? writes.length : i + 400)}))
        .timeout(const Duration(seconds: 20));
    _check(r);
  }
}
