// Every screen opens on a small phone without layout errors, and the setup forms save real rows.
// Run: flutter test
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/main.dart';
import 'package:mitra/screens/more.dart';
import 'package:mitra/screens/setup.dart';
import 'package:mitra/strings.dart';
import 'package:mitra/theme.dart';
import 'package:mitra/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> show(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(360 * 3, 720 * 3); // a small Android phone
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: mitraTheme(), home: page));
  await settle(tester);
}

// The call button pulses forever, so wait a fixed time instead of "until nothing moves".
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The real fonts, so text is measured as on a phone (the default test font draws every letter as a wide box).
Future<void> loadFonts() async {
  const families = {
    'Malayalam': ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'],
    'Jakarta': ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'],
  };
  for (final f in families.entries) {
    final loader = FontLoader(f.key);
    for (final w in f.value) {
      final file = f.key == 'Malayalam' ? 'NotoSansMalayalam-$w.ttf' : 'PlusJakartaSans-$w.ttf';
      loader.addFont(rootBundle.load('assets/fonts/$file'));
    }
    await loader.load();
  }
  // Material widgets that don't name a font family use Roboto: give them Jakarta.
  final roboto = FontLoader('Roboto')..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'));
  await roboto.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await T.load();
    await loadFonts();
    await repo.init();
  });

  testWidgets('the app with its five tabs', (tester) async {
    await show(tester, const Shell());
    expect(find.byType(Shell), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      tester.state<ShellState>(find.byType(Shell)).go(i);
      await tester.pump(const Duration(seconds: 2));
    }
  });

  testWidgets('setup: products, bills, purchases', (tester) async {
    await show(tester, const SetupScreen());
    expect(find.text('Biriyani'), findsWidgets);
    await tester.tap(find.text(T.ml('tab_bills')));
    await settle(tester);
    await tester.tap(find.text(T.ml('tab_purchases')));
    await settle(tester);
  });

  testWidgets('setup: adding a product saves it', (tester) async {
    await show(tester, const SetupScreen());
    final before = repo['products'].length;
    await tester.ensureVisible(find.text('${T.ml('add')}  ${T.en('add')}', findRichText: true));
    await tester.pump();
    await tester.tap(find.text('${T.ml('add')}  ${T.en('add')}', findRichText: true));
    await settle(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'ഇഡ്ഡലി');
    await tester.enterText(fields.at(1), 'Idli');
    await tester.enterText(fields.at(2), '10');
    await tester.tap(find.text('${T.ml('save')}  ${T.en('save')}', findRichText: true));
    await settle(tester);
    expect(repo['products'].length, before + 1);
    expect(repo['products'].last['price'], 10);
    expect(find.text('Idli'), findsOneWidget, reason: 'the new product must show in the list straight away');
  });

  testWidgets('setup: adding a bill saves it for this month', (tester) async {
    await show(tester, const SetupScreen());
    await tester.tap(find.text(T.ml('tab_bills')));
    await settle(tester);
    final before = repo['bills'].length;
    await tester.ensureVisible(find.text('${T.ml('add')}  ${T.en('add')}', findRichText: true));
    await tester.pump();
    await tester.tap(find.text('${T.ml('add')}  ${T.en('add')}', findRichText: true));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), '500');
    await tester.tap(find.text('${T.ml('save')}  ${T.en('save')}', findRichText: true));
    await settle(tester);
    expect(repo['bills'].length, before + 1);
    expect(repo['bills'].last['type'], 'gas');
    expect(repo['bills'].last['amount'], 500);
    expect(find.text('₹500'), findsOneWidget, reason: 'the new bill must show in the list straight away');
  });

  testWidgets('schemes and support say "being checked" until checked content exists', (tester) async {
    await show(tester, const SchemesScreen());
    expect(find.textContaining('being checked'), findsOneWidget);
    await show(tester, const SupportScreen());
    expect(find.textContaining('being checked'), findsOneWidget);
  });

  testWidgets('buy together shows the groups and lets her join one', (tester) async {
    await show(tester, const BulkScreen());
    expect(find.textContaining('women buying together'), findsWidgets);
    final before = repo.bulk.length;
    final join = find.text('${T.ml('add')}  ${T.en('add')}', findRichText: true);
    if (join.evaluate().isNotEmpty) {
      await tester.ensureVisible(join.first);
      await tester.pump();
      await tester.tap(join.first);
      await settle(tester);
      await tester.enterText(find.byType(TextField), '20');
      await tester.tap(find.byType(FilledButton));
      await settle(tester);
      expect(repo.bulk.length, before + 1);
    }
  });

  testWidgets('a long button label wraps instead of being cut off', (tester) async {
    await show(tester, const Scaffold(body: Padding(padding: EdgeInsets.all(16), child: BigButton('call_see'))));
    final text = tester.renderObject<RenderParagraph>(find.byType(RichText).first);
    expect(text.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });
}
