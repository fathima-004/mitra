import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/repo.dart';
import 'i18n.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'screens/more.dart';
import 'screens/products.dart';
import 'screens/records.dart';
import 'screens/speak.dart';
import 'strings.dart';
import 'ui/kit.dart';

final repo = Repo();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([T.load(), L.load(), repo.init()]);
  await repo.ensureDemoToday();
  syncLanguage(repo);
  final prefs = await SharedPreferences.getInstance();
  final loggedIn = (prefs.getBool('loggedIn') ?? false) || (prefs.getBool('joined') ?? false);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  runApp(MitraApp(loggedIn: loggedIn));
}

class MitraApp extends StatefulWidget {
  final bool loggedIn;
  const MitraApp({super.key, required this.loggedIn});

  @override
  State<MitraApp> createState() => _MitraAppState();
}

class _MitraAppState extends State<MitraApp> {
  @override
  void initState() {
    super.initState();
    L.lang.addListener(redrawAll);
  }

  @override
  void dispose() {
    L.lang.removeListener(redrawAll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mitra',
        debugShowCheckedModeBanner: false,
        theme: mitraTheme2(),
        // On the web build, ?tab=1 opens a tab directly (screenshots, the projector).
        home: widget.loggedIn || Uri.base.queryParameters.containsKey('tab')
            ? Shell(start: int.tryParse(Uri.base.queryParameters['tab'] ?? '') ?? 0)
            : const LoginScreen(),
      );
}

/// After a language switch, redraw every widget on screen: the tabs kept alive in the background and any
/// page opened on top (GST, Savings ...). Text comes from tr(), which widgets don't "listen" to, so a
/// normal rebuild would skip screens that are const or already built. Nothing is reset: same page, same state.
void redrawAll() {
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(mark);
}

Future<void> logIn(BuildContext context) async {
  (await SharedPreferences.getInstance()).setBool('loggedIn', true);
  if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const Shell()), (_) => false);
  }
}

Future<void> logOut(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('loggedIn', false);
  await prefs.setBool('joined', false);
  if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }
}

/// Home, Records, Speak (the big mic), Products, More.
class Shell extends StatefulWidget {
  final int start;
  const Shell({super.key, this.start = 0});

  @override
  State<Shell> createState() => ShellState();

  static ShellState? of(BuildContext context) => context.findAncestorStateOfType<ShellState>();
}

class ShellState extends State<Shell> {
  late int tab = widget.start.clamp(0, 4);

  void go(int i) {
    if (i == 2) {
      openSpeak(context);
      return;
    }
    setState(() => tab = i);
  }

  // A sale saved by the phone call arrived from Firestore: say so, wherever she is in the app.
  void _onCallSale() {
    if (mounted) say(context, tr('added_by_call'), icon: Icons.call_rounded);
  }

  @override
  void initState() {
    super.initState();
    repo.callSales.addListener(_onCallSale);
  }

  @override
  void dispose() {
    repo.callSales.removeListener(_onCallSale);
    super.dispose();
  }

  static const _items = [
    ('nav_home', Icons.home_outlined, Icons.home_rounded),
    ('nav_records', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    ('nav_speak', Icons.mic_rounded, Icons.mic_rounded),
    ('nav_products', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
    ('nav_more', Icons.menu_rounded, Icons.menu_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    const pages = [HomeScreen(), RecordsScreen(), SizedBox(), ProductsScreen(), MoreScreen()];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: K.line))),
        child: SafeArea(
          child: SizedBox(
            height: 78,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < _items.length; i++) Expanded(child: _navItem(i)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i) {
    final (key, off, on) = _items[i];
    final selected = tab == i;
    if (i == 2) {
      return InkWell(
        onTap: () => go(2),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: K.green,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: K.green.withValues(alpha: .35), blurRadius: 14, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 2),
          Text(tr(key), maxLines: 1, style: ts(12, w: FontWeight.w700, c: K.green)),
          const SizedBox(height: 4),
        ]),
      );
    }
    final color = selected ? K.green : K.muted;
    return InkWell(
      onTap: () => go(i),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(selected ? on : off, color: color, size: 26),
        const SizedBox(height: 3),
        Text(tr(key), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, w: selected ? FontWeight.w800 : FontWeight.w600, c: color)),
      ]),
    );
  }
}
