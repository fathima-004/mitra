// Speak to add: "ഇന്ന് 12 ബിരിയാണി വിറ്റു" → 12 Biriyani → Save. Owner: Hiba.
// The phone turns speech into text (Android speech recognition, ml-IN). logic/parse.dart finds products,
// numbers and amounts with word lists. Nothing is saved until she taps Save (CLAUDE.md: numbers are confirmed).
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../i18n.dart';
import '../logic/calc.dart';
import '../logic/parse.dart';
import '../logic/spend.dart';
import '../main.dart';
import '../strings.dart' show rupees;
import '../ui/kit.dart';
import '../widgets/art.dart';
import 'add.dart';

void openSpeak(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SpeakScreen()));

class SpeakScreen extends StatefulWidget {
  const SpeakScreen({super.key});
  @override
  State<SpeakScreen> createState() => _SpeakScreenState();
}

class _SpeakScreenState extends State<SpeakScreen> with SingleTickerProviderStateMixin {
  final stt = SpeechToText();
  late final pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  final typed = TextEditingController();
  bool ready = false, listening = false, typing = false;
  String heard = '';
  Heard? result;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      ready = await stt.initialize(
        onStatus: (s) {
          if (!mounted) return;
          final on = s == 'listening';
          setState(() => listening = on);
          on ? pulse.repeat() : pulse.stop();
        },
        onError: (_) {
          if (mounted) setState(() => listening = false);
          pulse.stop();
        },
      );
    } catch (_) {
      ready = false;
    }
    if (!mounted) return;
    setState(() => typing = !ready);
    if (ready) _listen();
  }

  Future<void> _listen() async {
    setState(() {
      heard = '';
      result = null;
    });
    final locales = await stt.locales();
    String? want(String id) => locales.any((l) => l.localeId.toLowerCase() == id.toLowerCase()) ? id : null;
    final locale = (L.ml ? want('ml_IN') ?? want('ml-IN') : want('en_IN') ?? want('en-IN')) ?? want('ml_IN');
    await stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: locale,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (r) {
        setState(() => heard = r.recognizedWords);
        if (r.finalResult) _understand(r.recognizedWords);
      },
    );
  }

  void _understand(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      heard = text;
      result = understand(text, repo['products'], repo['words']);
    });
  }

  Future<void> _saveSales(List<Rec> items) async {
    final t = TimeOfDay.now();
    final time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    for (final i in items) {
      await repo.add('sales', {'date': today(), 'time': time, 'product': i['product'], 'qty': i['qty'], 'via': 'app'});
    }
    if (!mounted) return;
    say(context, tr('saved'));
    Navigator.pop(context);
  }

  Future<void> _saveExpense(Rec e) async {
    final t = TimeOfDay.now();
    await repo.add('purchases', {
      'date': today(),
      'time': '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
      'cat': e['cat'],
      'item': e['item'],
      'item_ml': e['item_ml'],
      'qty': 1,
      'unit': '',
      'amount': e['amount'],
      'gst': 0,
    });
    if (!mounted) return;
    say(context, tr('saved'));
    Navigator.pop(context);
  }

  @override
  void dispose() {
    stt.cancel();
    pulse.dispose();
    super.dispose();
  }

  Widget _mic() => GestureDetector(
        onTap: ready ? (listening ? stt.stop : _listen) : null,
        child: AnimatedBuilder(
          animation: pulse,
          builder: (_, child) => Stack(alignment: Alignment.center, children: [
            for (final shift in [0.0, .5])
              Opacity(
                opacity: listening ? (1 - ((pulse.value + shift) % 1)) * .5 : 0,
                child: Container(
                  width: 130 + 70 * ((pulse.value + shift) % 1),
                  height: 130 + 70 * ((pulse.value + shift) % 1),
                  decoration: const BoxDecoration(color: K.greenSoft, shape: BoxShape.circle),
                ),
              ),
            child!,
          ]),
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: ready ? K.green : K.muted,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: K.green.withValues(alpha: .3), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Icon(listening ? Icons.mic_rounded : Icons.mic_none_rounded, color: Colors.white, size: 64),
          ),
        ),
      );

  Widget _confirm(Heard r) {
    if (r.sales.isNotEmpty) {
      final products = {for (final p in repo['products']) p['id']: p};
      final total = r.sales.fold<num>(0, (s, i) => s + (i['qty'] as int) * ((products[i['product']]?['price'] as num?) ?? 0));
      return Tint(
        color: K.greenSoft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('is_this_right'), style: ts(17, w: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final i in r.sales)
            RowItem(
              leading: FoodArt(products[i['product']], size: 42),
              title: '${i['qty']} ${pick(products[i['product']], 'name')}',
              trailing: Text(rupees((i['qty'] as int) * ((products[i['product']]?['price'] as num?) ?? 0)), style: money(16, c: K.green)),
              // Change the number before saving: open the normal form with it filled in.
              onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => AddIncomeScreen(product: i['product'] as String, qty: i['qty'] as int))),
            ),
          const Divider(color: K.line),
          Row(children: [
            Expanded(child: Text(tr('total_amount'), style: ts(15, w: FontWeight.w700))),
            Text(rupees(total), style: money(22, c: K.greenDark)),
          ]),
          const SizedBox(height: 12),
          BigBtn(tr('save'), icon: Icons.check_circle_rounded, onTap: () => _saveSales(r.sales)),
        ]),
      );
    }
    final e = r.expense!;
    final c = catBy('${e['cat']}');
    return Tint(
      color: K.redSoft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('is_this_right'), style: ts(17, w: FontWeight.w800)),
        RowItem(
          leading: Bubble(c.icon, color: c.color, bg: Colors.white),
          title: L.ml ? '${e['item_ml']}' : '${e['item']}',
          sub: tr('cat_${e['cat']}'),
          trailing: Text(rupees(e['amount'] as num), style: money(20, c: K.red)),
          onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => AddExpenseScreen(cat: '${e['cat']}', amount: e['amount'] as int, item: '${e['item']}', itemMl: '${e['item_ml']}'))),
        ),
        const SizedBox(height: 8),
        BigBtn(tr('save'), icon: Icons.check_circle_rounded, color: K.red, onTap: () => _saveExpense(e)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Page2(
      title: tr('speak_to_add'),
      tint: Colors.white,
      children: [
        const SizedBox(height: 20),
        Center(child: SizedBox(width: 210, height: 210, child: Center(child: _mic()))),
        const SizedBox(height: 10),
        Text(listening ? tr('listening') : (ready ? tr('tap_to_speak') : tr('no_mic')),
            textAlign: TextAlign.center, style: ts(22, w: FontWeight.w800)),
        Text(tr('speak_hint'), textAlign: TextAlign.center, style: ts(14.5, w: FontWeight.w500, c: K.muted)),
        if (heard.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('"$heard"', textAlign: TextAlign.center, style: ts(18, w: FontWeight.w600, c: K.ink)),
        ],
        const SizedBox(height: 18),
        if (r != null && !r.empty)
          _confirm(r)
        else if (r != null) ...[
          Text(tr('didnt_catch'), textAlign: TextAlign.center, style: ts(15, c: K.red)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: BigBtn(tr('add_income'), color: K.green, onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AddIncomeScreen())))),
            const SizedBox(width: 10),
            Expanded(child: BigBtn(tr('add_expense'), color: K.red, onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AddExpenseScreen())))),
          ]),
        ] else
          Tint(
            color: const Color(0xFFF3F5F3),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('examples'), style: ts(15.5, w: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final k in ['eg1', 'eg2', 'eg3', 'eg4'])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    const Icon(Icons.circle, size: 7, color: K.green),
                    const SizedBox(width: 10),
                    Expanded(child: Text(tr(k), style: ts(15, w: FontWeight.w500))),
                  ]),
                ),
            ]),
          ),
        const SizedBox(height: 14),
        if (!typing)
          TextButton.icon(
            onPressed: () => setState(() => typing = true),
            icon: const Icon(Icons.keyboard_rounded, color: K.muted),
            label: Text(tr('type_instead'), style: ts(15, c: K.muted)),
          )
        else
          TextField(
            controller: typed,
            style: ts(17),
            textInputAction: TextInputAction.done,
            onSubmitted: _understand,
            decoration: InputDecoration(
              hintText: tr('eg1'),
              hintStyle: ts(15, c: K.muted),
              suffixIcon: IconButton(icon: const Icon(Icons.send_rounded, color: K.green), onPressed: () => _understand(typed.text)),
            ),
          ),
      ],
    );
  }
}
