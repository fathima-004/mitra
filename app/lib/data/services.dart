// Things the app asks the internet for. Owner: Hiba.
// - Government updates: the official PIB (Press Information Bureau) English RSS feed, filtered to
//   scheme news that suits a small home business. Anything about loans is dropped.
//   The last good result is kept on the phone, so the screen still works offline.
// - "Mitra, call me": the call-me Netlify function rings the demo phone.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../config.dart';

const pibFeed = 'https://www.pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3&reg=3';

class News {
  final String title, link;
  final bool relevant;
  const News(this.title, this.link, this.relevant);
  Map<String, dynamic> toJson() => {'title': title, 'link': link, 'relevant': relevant};
  static News fromJson(Map<String, dynamic> j) => News('${j['title']}', '${j['link']}', j['relevant'] == true);
}

final _schemeWords = RegExp(
    r'scheme|yojana|mission|women|woman|mahila|self[- ]help|\bshg|kudumbashree|msme|micro|entrepreneur|startup|artisan|'
    r'vendor|food processing|skill|livelihood|rural|nari|lakhpati|didi|subsid|grant|training|gst|tax|fssai|udyam|handloom|cooperative',
    caseSensitive: false);
final _loanWords = RegExp(r'loan|credit|lend|lender|nbfc|mudra|svanidhi|guarantee|interest rate|borrow|microfinance|debt', caseSensitive: false);

class NewsResult {
  final List<News> items;
  final DateTime? fetched;
  final bool fromCache;
  const NewsResult(this.items, this.fetched, this.fromCache);
}

List<News> parseFeed(String body) {
  final doc = XmlDocument.parse(body.trim().replaceFirst('﻿', ''));
  return [
    for (final item in doc.findAllElements('item'))
      (() {
        final title = item.getElement('title')?.innerText.trim() ?? '';
        final link = item.getElement('link')?.innerText.trim() ?? '';
        return News(title, link, _schemeWords.hasMatch(title));
      })(),
  ].where((n) => n.title.isNotEmpty && n.link.startsWith('https://') && !_loanWords.hasMatch(n.title)).toList();
}

Future<NewsResult> governmentNews() async {
  final prefs = await SharedPreferences.getInstance();
  try {
    final res = await http.get(Uri.parse(pibFeed), headers: {'User-Agent': 'Mitra/1.0'}).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception(res.statusCode);
    final items = parseFeed(utf8.decode(res.bodyBytes));
    final now = DateTime.now();
    await prefs.setString('news', jsonEncode({'at': now.toIso8601String(), 'items': items.map((n) => n.toJson()).toList()}));
    return NewsResult(items, now, false);
  } catch (_) {
    final raw = prefs.getString('news');
    if (raw == null) return const NewsResult([], null, true);
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return NewsResult([for (final x in j['items'] as List) News.fromJson(Map<String, dynamic>.from(x))], DateTime.tryParse('${j['at']}'), true);
  }
}

/// Rings the demo phone. True when the call was started.
Future<bool> callMe() async {
  if (siteUrl.isEmpty) return false;
  try {
    final res = await http.post(Uri.parse('$siteUrl/.netlify/functions/call-me')).timeout(const Duration(seconds: 8));
    return res.statusCode < 300;
  } catch (_) {
    return false;
  }
}
