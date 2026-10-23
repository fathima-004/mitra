// Renders the main screens to PNG for a visual check (not part of the normal test run: the file name
// doesn't end in _test). Run: flutter test test/render_shots.dart --update-goldens
// Pictures land in app/build/shots/.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/i18n.dart';
import 'package:mitra/main.dart';
import 'package:mitra/screens/add.dart';
import 'package:mitra/screens/login.dart';
import 'package:mitra/screens/more.dart';
import 'package:mitra/screens/profit.dart';
import 'package:mitra/screens/records.dart';
import 'package:mitra/screens/products.dart';
import 'package:mitra/strings.dart';
import 'package:mitra/ui/kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loadFonts() async {
  const weights = ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'];
  for (final (family, file) in [('Malayalam', 'NotoSansMalayalam'), ('Jakarta', 'PlusJakartaSans'), ('Roboto', 'PlusJakartaSans')]) {
    final loader = FontLoader(family);
    for (final w in weights) {
      loader.addFont(rootBundle.load('assets/fonts/$file-$w.ttf'));
    }
    await loader.load();
  }
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final icons = File('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await T.load();
    await loadFonts();
    await repo.init();
    await repo.ensureDemoToday();
  });

  final pages = <String, Widget Function()>{
    'login': () => const LoginScreen(),
    'home': () => const Shell(),
    'income': () => const AddIncomeScreen(),
    'expense': () => const AddExpenseScreen(cat: 'ingredients', amount: 200),
    'records': () => const RecordsScreen(),
    'profit': () => const ProfitScreen(),
    'report': () => const ReportScreen(),
    'products': () => const ProductsScreen(),
    'more': () => const MoreScreen(),
    'gst': () => const GstScreen(),
    'savings': () => const SavingsScreen(),
    'bulk': () => const BulkScreen(),
    'help': () => const HelpScreen(),
    'schemes': () => const SchemesScreen(),
  };

  for (final lang in ['ml', 'en']) {
    for (final e in pages.entries) {
      testWidgets('$lang ${e.key}', (tester) async {
        L.lang.value = lang;
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(RepaintBoundary(child: MaterialApp(theme: mitraTheme2(), debugShowCheckedModeBanner: false, home: e.value())));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('../build/shots/${lang}_${e.key}.png'));
      });
    }
  }

  test('rupees helper is loaded', () => expect(rupees(1000), '₹1,000'));
}
