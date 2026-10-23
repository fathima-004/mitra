import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/repo.dart';
import 'screens/call.dart';
import 'screens/daily.dart';
import 'screens/home.dart';
import 'screens/join.dart';
import 'screens/money.dart';
import 'screens/profit.dart';
import 'strings.dart';
import 'theme.dart';

final repo = Repo();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([T.load(), repo.init()]);
  final joined = (await SharedPreferences.getInstance()).getBool('joined') ?? false;
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  runApp(MitraApp(joined: joined));
}

class MitraApp extends StatelessWidget {
  final bool joined;
  const MitraApp({super.key, required this.joined});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mitra',
        debugShowCheckedModeBanner: false,
        theme: mitraTheme(),
        // On the web build, ?tab=3 opens a tab directly (handy for screenshots and the projector).
        home: joined || Uri.base.queryParameters.containsKey('tab')
            ? Shell(start: int.tryParse(Uri.base.queryParameters['tab'] ?? '') ?? 0)
            : const JoinScreen(),
      );
}

/// The five tabs with a raised round call button in the middle.
class Shell extends StatefulWidget {
  final int start;
  const Shell({super.key, this.start = 0});

  @override
  State<Shell> createState() => ShellState();

  static ShellState? of(BuildContext context) => context.findAncestorStateOfType<ShellState>();
}

class ShellState extends State<Shell> {
  late int tab = widget.start;
  void go(int i) => setState(() => tab = i);

  static const _items = [
    ('nav_home', Icons.home_outlined, Icons.home_rounded),
    ('nav_daily', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    ('nav_call', Icons.call_rounded, Icons.call_rounded),
    ('nav_profit', Icons.trending_up_rounded, Icons.trending_up_rounded),
    ('nav_money', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    const pages = [HomeScreen(), DailyScreen(), CallScreen(), ProfitScreen(), MoneyScreen()];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: C.card.withValues(alpha: .96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: C.line),
            boxShadow: const [BoxShadow(color: Color(0x4017231F), blurRadius: 30, offset: Offset(0, 12), spreadRadius: -10)],
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < _items.length; i++) Expanded(child: _navItem(i)),
          ]),
        ),
      ),
    );
  }

  Widget _navItem(int i) {
    final (key, off, on) = _items[i];
    final selected = tab == i;
    if (i == 2) {
      return GestureDetector(
        onTap: () => go(i),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Transform.translate(
            offset: const Offset(0, -22),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [C.brand, C.brandDeep], begin: Alignment.topLeft, end: Alignment.bottomRight),
                border: Border.all(color: C.bg, width: 5),
                boxShadow: const [BoxShadow(color: Color(0x99062F29), blurRadius: 20, offset: Offset(0, 10), spreadRadius: -6)],
              ),
              child: const Icon(Icons.call_rounded, color: Colors.white, size: 26),
            ),
          ),
          Transform.translate(
              offset: const Offset(0, -18),
              child: Text(T.ml(key), style: const TextStyle(fontFamily: 'Malayalam', fontSize: 11.5, fontWeight: FontWeight.w700, color: C.brand))),
        ]),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => go(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: selected ? C.brandSoft : Colors.transparent, borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(selected ? on : off, color: selected ? C.brand : C.muted, size: 22),
          const SizedBox(height: 2),
          Text(T.ml(key),
              style: TextStyle(fontFamily: 'Malayalam', fontSize: 11.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? C.brand : C.muted)),
        ]),
      ),
    );
  }
}
