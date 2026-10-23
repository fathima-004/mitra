// Every screen opens on a small phone (360 px) in both languages without layout errors, and the main
// actions really save. Run: flutter test test/screens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/i18n.dart';
import 'package:mitra/logic/calc.dart';
import 'package:mitra/logic/parse.dart';
import 'package:mitra/main.dart';
import 'package:mitra/screens/add.dart';
import 'package:mitra/screens/login.dart';
import 'package:mitra/screens/more.dart';
import 'package:mitra/screens/products.dart';
import 'package:mitra/screens/profit.dart';
import 'package:mitra/screens/records.dart';
import 'package:mitra/strings.dart';
import 'package:mitra/ui/kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> show(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(360 * 3, 720 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: mitraTheme2(), home: page));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The real fonts, so text is measured as on a phone.
Future<void> loadFonts() async {
  const weights = ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'];
  for (final (family, file) in [('Malayalam', 'NotoSansMalayalam'), ('Jakarta', 'PlusJakartaSans'), ('Roboto', 'PlusJakartaSans')]) {
    final loader = FontLoader(family);
    for (final w in weights) {
      loader.addFont(rootBundle.load('assets/fonts/$file-$w.ttf'));
    }
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
  });

  for (final lang in ['ml', 'en']) {
    testWidgets('[$lang] every screen fits a small phone', (tester) async {
      L.lang.value = lang;
      for (final page in <Widget>[
        const LoginScreen(),
        const Shell(),
        const RecordsScreen(),
        const ProductsScreen(),
        const MoreScreen(),
        const AddIncomeScreen(),
        const AddExpenseScreen(),
        const ProfitScreen(),
        const ReportScreen(),
        const SavingsScreen(),
        const GstScreen(),
        const BulkScreen(),
        const BillsScreen(),
        const BusinessScreen(),
        const SupportScreen(),
        const HelpScreen(),
      ]) {
        await show(tester, page);
        expect(tester.takeException(), isNull, reason: '${page.runtimeType} in $lang');
      }
    });
  }

  testWidgets("add income saves a sale with today's date", (tester) async {
    L.lang.value = 'en';
    final before = repo['sales'].length;
    await show(tester, const AddIncomeScreen());
    await tester.tap(find.byIcon(Icons.add_rounded));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await settle(tester);
    expect(find.text('3'), findsOneWidget);
    expect(find.text(rupees(300)), findsOneWidget, reason: '3 biriyani at ₹100');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(repo['sales'].length, before + 1);
    expect(repo['sales'].last['qty'], 3);
    expect(repo['sales'].last['date'], today());
  });

  testWidgets('add expense saves a purchase with its category', (tester) async {
    L.lang.value = 'en';
    final before = repo['purchases'].length;
    await show(tester, const AddExpenseScreen(cat: 'gas'));
    await tester.enterText(find.byType(TextField).first, '900');
    await settle(tester);
    await tester.ensureVisible(find.text('Save'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(repo['purchases'].length, before + 1);
    expect(repo['purchases'].last['cat'], 'gas');
    expect(repo['purchases'].last['amount'], 900);
  });

  testWidgets('the GST calculator adds and removes GST', (tester) async {
    L.lang.value = 'en';
    await show(tester, const GstScreen());
    await tester.tap(find.text('18%'));
    await settle(tester);
    expect(find.text('₹1180.00'), findsOneWidget, reason: '1000 + 18%');
    await tester.tap(find.text('Find GST inside a price'));
    await settle(tester);
    expect(find.text('₹152.54'), findsOneWidget, reason: 'GST inside 1000 at 18%');
  });

  test('speech text is understood with word lists', () {
    final products = repo['products'];
    final a = understand('innu 12 biriyani poyi', products);
    expect(a.sure, isTrue);
    expect(a.sales, [
      {'product': 'p1', 'qty': 12}
    ]);
    final b = understand('ഇന്ന് 12 ബിരിയാണിയും 30 ചപ്പാത്തിയും വിറ്റു', products);
    expect(b.sales, [
      {'product': 'p1', 'qty': 12},
      {'product': 'p2', 'qty': 30}
    ]);
    final c = understand('200 രൂപയ്ക്ക് അരി വാങ്ങി', products);
    expect(c.expense?['cat'], 'ingredients');
    expect(c.expense?['amount'], 200);
    final d = understand('gas refill 900', products);
    expect(d.expense?['cat'], 'gas');
    expect(understand('kure biriyani', products).sure, isFalse);
  });

  testWidgets('switching language updates the More tab and pages opened on top', (tester) async {
    L.lang.value = 'ml';
    tester.view.physicalSize = const Size(360 * 3, 720 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    void redraw() => redrawAll();
    L.lang.addListener(redraw);
    addTearDown(() => L.lang.removeListener(redraw));
    await tester.pumpWidget(MaterialApp(theme: mitraTheme2(), home: const Shell(start: 4)));
    await settle(tester);
    expect(find.text('കൂടുതൽ'), findsWidgets);
    await tester.tap(find.text('ജിഎസ്ടി, നികുതി'));
    await settle(tester);
    L.lang.value = 'en';
    await settle(tester);
    expect(find.text('GST & tax'), findsOneWidget, reason: 'the open GST page');
    Navigator.of(tester.element(find.text('GST & tax'))).pop();
    await settle(tester);
    expect(find.text('Monthly report'), findsOneWidget, reason: 'the More tab underneath');
    expect(find.text('More'), findsWidgets);
    L.lang.value = 'ml';
  });

  testWidgets("home has the call me button under today's money", (tester) async {
    L.lang.value = 'en';
    await show(tester, const Shell());
    expect(find.text('Mitra, call me'), findsOneWidget);
    final money = tester.getTopLeft(find.text('Money received today')).dy;
    final call = tester.getTopLeft(find.text('Mitra, call me')).dy;
    final income = tester.getTopLeft(find.text('Add income')).dy;
    expect(call > money && call < income, isTrue);
  });

  testWidgets('schemes screen lists the checked schemes she can join now', (tester) async {
    L.lang.value = 'en';
    await show(tester, const SchemesScreen());
    expect(find.text('Schemes you can join now'), findsOneWidget);
    for (final t in ['PM Suraksha Bima Yojana (accident insurance)', 'Atal Pension Yojana (pension)', 'Udyam Registration (free business registration)']) {
      await tester.scrollUntilVisible(find.text(t), 200);
      expect(find.text(t), findsOneWidget);
    }
    expect(find.textContaining('No scheme news'), findsNothing);
    expect(find.textContaining('Auto rickshaw'), findsNothing);
  });

  testWidgets('the savings goal is called "Savings goal", not the demo name', (tester) async {
    L.lang.value = 'en';
    await show(tester, const SavingsScreen());
    expect(find.textContaining('Auto rickshaw'), findsNothing);
    L.lang.value = 'ml';
    await show(tester, const SavingsScreen());
    expect(find.text('ഓട്ടോ'), findsNothing);
    expect(find.text('സമ്പാദ്യ ലക്ഷ്യം'), findsWidgets);
  });
}
