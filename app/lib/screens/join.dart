// How a new woman joins Mitra (demo walkthrough, nothing is sent or saved as a new user):
// welcome → what you need → join in the app (phone + code, about you, what you sell, goal)
// or join by a phone call (recorded Malayalam sign-up call) → ready → how to log in next time.
import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';

enum JoinStep { welcome, phone, about, sell, goal, done, call }

const _districts = [
  ('തിരുവനന്തപുരം', 'Thiruvananthapuram'),
  ('കൊല്ലം', 'Kollam'),
  ('പത്തനംതിട്ട', 'Pathanamthitta'),
  ('ആലപ്പുഴ', 'Alappuzha'),
  ('കോട്ടയം', 'Kottayam'),
  ('ഇടുക്കി', 'Idukki'),
  ('എറണാകുളം', 'Ernakulam'),
  ('തൃശ്ശൂർ', 'Thrissur'),
  ('പാലക്കാട്', 'Palakkad'),
  ('മലപ്പുറം', 'Malappuram'),
  ('കോഴിക്കോട്', 'Kozhikode'),
  ('വയനാട്', 'Wayanad'),
  ('കണ്ണൂർ', 'Kannur'),
  ('കാസർഗോഡ്', 'Kasaragod'),
];

// EXAMPLE presets to tap instead of typing. Prices are only starting points; she edits them.
const _kinds = {
  'food': (
    'ഭക്ഷണം',
    'Food',
    [
      ('ബിരിയാണി', 'Biriyani', 100),
      ('ചപ്പാത്തി', 'Chapathi', 8),
      ('പൊറോട്ട', 'Parotta', 12),
      ('അച്ചാർ കുപ്പി', 'Pickle bottle', 120),
      ('ഊണ്', 'Meals', 70),
      ('അപ്പം', 'Appam', 10),
    ]
  ),
  'snacks': (
    'അച്ചാർ, പലഹാരം',
    'Pickles & snacks',
    [
      ('അച്ചാർ കുപ്പി', 'Pickle bottle', 120),
      ('ചിപ്സ് പാക്കറ്റ്', 'Chips packet', 60),
      ('ഉണ്ണിയപ്പം', 'Unniyappam (dozen)', 80),
      ('അവലോസ് പൊടി', 'Avalose podi', 90),
    ]
  ),
  'tailoring': (
    'തയ്യൽ',
    'Tailoring',
    [
      ('ബ്ലൗസ് തയ്യൽ', 'Blouse stitching', 350),
      ('ചുരിദാർ', 'Churidar', 450),
      ('ആൾട്ടറേഷൻ', 'Alteration', 100),
      ('സ്കൂൾ യൂണിഫോം', 'School uniform', 300),
    ]
  ),
};

const _goals = [
  ('auto', 'ഓട്ടോ', 'Auto rickshaw', 40000),
  ('sewing', 'തയ്യൽ മെഷീൻ', 'Sewing machine', 12000),
  ('school', 'കുട്ടികളുടെ പഠനം', "Children's studies", 25000),
  ('house', 'വീട് നന്നാക്കൽ', 'House repair', 50000),
];

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});
  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  JoinStep step = JoinStep.welcome;
  final scroll = ScrollController();

  // App path
  final phone = TextEditingController(), name = TextEditingController(), goalAmount = TextEditingController();
  String code = '', district = 'Kozhikode', lang = 'ml', kind = 'food';
  bool codeSent = false;
  final picked = <String, ({String ml, String en, int price})>{};
  ({String key, String ml, String en})? goal;

  // Call path
  bool byCall = false;
  Map<String, dynamic>? call;
  final shown = <Map<String, dynamic>>[];
  int playing = 0, secs = 0;
  String? talking;
  bool callEnded = false;
  Timer? timer;
  final player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/data/join_call.json').then((s) => call = jsonDecode(s));
  }

  @override
  void dispose() {
    timer?.cancel();
    player.dispose();
    super.dispose();
  }

  void go(JoinStep s) {
    if (step == JoinStep.call) _stopCall();
    setState(() => step = s);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void back() => go(switch (step) {
        JoinStep.call => JoinStep.welcome,
        JoinStep.done => byCall ? JoinStep.call : JoinStep.goal,
        _ => JoinStep.values[step.index - 1],
      });

  Future<void> _finish() async {
    (await SharedPreferences.getInstance()).setBool('joined', true);
    if (mounted) await logIn(context);
  }

  // ---------- Join by call: replay with the recorded voice clips ----------
  void _stopCall() {
    playing++;
    timer?.cancel();
    player.stop();
    talking = null;
  }

  Future<void> _playClip(String id, int fallbackMs) async {
    final done = Completer<void>();
    final sub = player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await player.play(AssetSource('audio/join/$id.mp3'));
      await done.future.timeout(const Duration(seconds: 12), onTimeout: () {});
    } catch (_) {
      await Future.delayed(Duration(milliseconds: fallbackMs));
    } finally {
      await sub.cancel();
    }
  }

  Future<void> _runCall({bool fast = false}) async {
    if (call == null) return;
    _stopCall();
    final run = ++playing;
    setState(() {
      shown.clear();
      secs = 0;
      callEnded = false;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => secs++));
    for (final line in (call!['lines'] as List).cast<Map<String, dynamic>>()) {
      if (run != playing || !mounted) return;
      setState(() => shown.add(line));
      _scrollDown();
      if (fast) continue;
      if (line['id'] != null) {
        setState(() => talking = line['id']);
        await _playClip(line['id'], 900 + (line['ml'] as String).length * 40);
        if (run != playing) return;
        setState(() => talking = null);
        await Future.delayed(const Duration(milliseconds: 250));
      } else {
        await Future.delayed(Duration(milliseconds: line['who'] == 'key' ? 700 : 1400));
      }
    }
    if (run != playing || !mounted) return;
    timer?.cancel();
    setState(() => callEnded = true);
    _scrollDown();
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      });

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final appSteps = JoinStep.done.index + 1;
    return Scaffold(
      body: SafeArea(
        child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
          if (step != JoinStep.call && !(step == JoinStep.done && byCall))
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < appSteps; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 28,
                  height: 6,
                  decoration: BoxDecoration(color: i <= step.index ? C.gold : C.line, borderRadius: BorderRadius.circular(99)),
                ),
            ]),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, a) =>
                FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(a), child: child)),
            child: KeyedSubtree(key: ValueKey(step), child: _body()),
          ),
          if (step != JoinStep.welcome && step != JoinStep.done)
            Center(
              child: TextButton.icon(
                onPressed: back,
                icon: const Icon(Icons.arrow_back_rounded, size: 16, color: C.muted),
                label: Text('${T.ml('back')} · ${T.en('back')}', style: const TextStyle(color: C.muted)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _body() => switch (step) {
        JoinStep.welcome => _welcome(),
        JoinStep.phone => _phone(),
        JoinStep.about => _about(),
        JoinStep.sell => _sell(),
        JoinStep.goal => _goal(),
        JoinStep.done => _done(),
        JoinStep.call => _call(),
      };

  Widget _gap([double h = 14]) => SizedBox(height: h);

  Widget _title(String key) => Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 14), child: Bi.k(key, size: 24, weight: FontWeight.w800));

  Widget _welcome() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        HeroCard(
          child: Column(children: [
            const SizedBox(height: 6),
            const Text('മിത്ര', style: TextStyle(fontFamily: 'Malayalam', fontSize: 42, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
            const Text('MITRA', style: TextStyle(letterSpacing: 5, color: C.goldLight, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Bi.k('join_tag', size: 17, color: Colors.white, enColor: Colors.white70, align: TextAlign.center),
            const SizedBox(height: 18),
            const Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.end, spacing: 6, children: [
              FoodArt({'name_en': 'Biriyani'}, size: 64),
              FoodArt({'name_en': 'Chapathi'}, size: 64),
              FoodArt({'name_en': 'Pickle'}, size: 64),
              AutoArt(width: 110),
            ]),
          ]),
        ),
        _gap(),
        MCard(
          child: Rows([
            _benefit(Icons.call_rounded, C.brandSoft, C.brand, 'join_b1'),
            _benefit(Icons.trending_up_rounded, C.goldSoft, const Color(0xFF9A6F0E), 'join_b2'),
            _benefit(Icons.favorite_border_rounded, C.roseSoft, C.rose, 'join_b3'),
          ]),
        ),
        _gap(),
        MCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Bi.k('join_need', size: 16, weight: FontWeight.w700),
            const SizedBox(height: 10),
            for (final k in ['need_phone', 'need_name', 'need_sell'])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(color: C.greenSoft, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, size: 16, color: C.green),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Bi.k(k, size: 15)),
                ]),
              ),
            const Divider(color: C.line),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in ['need_no_email', 'need_no_password', 'need_no_docs', 'need_no_bank'])
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: C.redSoft, borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.close_rounded, size: 14, color: C.red),
                    const SizedBox(width: 4),
                    Text('${T.ml(k)} ', style: const TextStyle(fontFamily: 'Malayalam', color: C.red, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    Text(T.en(k), style: const TextStyle(color: C.red, fontSize: 11)),
                  ]),
                ),
            ]),
          ]),
        ),
        _gap(18),
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 10), child: Bi.k('join_how_join', size: 16, weight: FontWeight.w700)),
        _path(Icons.smartphone_rounded, 'path_app', false, () {
          byCall = false;
          go(JoinStep.phone);
        }),
        _gap(10),
        _path(Icons.call_rounded, 'path_call', true, () {
          byCall = true;
          shown.clear();
          callEnded = false;
          go(JoinStep.call);
        }),
        _gap(),
        _loginCard(withHelp: true),
      ]);

  Widget _benefit(IconData ic, Color bg, Color fg, String key) =>
      Row(children: [Badge2(ic, bg: bg, fg: fg), const SizedBox(width: 12), Expanded(child: Bi.k(key, size: 15))]);

  Widget _path(IconData ic, String key, bool gold, VoidCallback onTap) => MCard(
        onTap: onTap,
        color: gold ? C.goldSoft : C.card,
        border: Border.all(color: gold ? C.gold : C.brand, width: 1.5),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Badge2(ic, bg: gold ? Colors.white : C.brandSoft, fg: gold ? const Color(0xFF9A6F0E) : C.brand, size: 46),
          const SizedBox(width: 14),
          Expanded(child: Bi.k(key, size: 16, weight: FontWeight.w700)),
          const Icon(Icons.arrow_forward_rounded, color: C.brand),
        ]),
      );

  Widget _loginCard({bool withHelp = false}) => MCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Bi.k('login_title', size: 16, weight: FontWeight.w700),
          Rows([
            Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [const Badge2(Icons.smartphone_rounded, size: 40), const SizedBox(width: 12), Expanded(child: Bi.k('login_app', size: 14.5))]),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Badge2(Icons.dialpad_rounded, bg: C.goldSoft, fg: Color(0xFF9A6F0E), size: 40),
              const SizedBox(width: 12),
              Expanded(child: Bi.k('login_call', size: 14.5))
            ]),
            if (withHelp)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Badge2(Icons.support_agent_rounded, bg: C.roseSoft, fg: C.rose, size: 40),
                const SizedBox(width: 12),
                Expanded(child: Bi.k('login_help', size: 14.5))
              ]),
          ]),
        ]),
      );

  // 2. Phone number + demo code
  Widget _phone() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title('join_phone'),
        MCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Bi.k('join_phone_label', size: 14),
            const SizedBox(height: 8),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: numStyle(20, weight: FontWeight.w600),
              decoration: const InputDecoration(prefixText: '+91  ', counterText: '', hintText: '98765 43210'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (!codeSent)
              BigButton('join_send', onPressed: phone.text.length == 10 ? _sendCode : null)
            else ...[
              Bi.k('join_code', size: 14),
              const SizedBox(height: 8),
              Row(children: [
                for (var i = 0; i < 4; i++)
                  Container(
                    width: 58,
                    height: 62,
                    margin: const EdgeInsets.only(right: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: i < code.length ? C.brand : C.line, width: 1.5)),
                    child: Text(i < code.length ? code[i] : '', style: numStyle(28)),
                  ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.auto_awesome_rounded, size: 16, color: C.goldText),
                const SizedBox(width: 6),
                Expanded(child: Text(T.en('join_demo_code'), style: const TextStyle(color: C.goldText, fontSize: 13))),
              ]),
              const SizedBox(height: 12),
              BigButton('join_verify', onPressed: code.length == 4 ? () => go(JoinStep.about) : null),
            ],
          ]),
        ),
      ]);

  void _sendCode() {
    setState(() {
      codeSent = true;
      code = '';
    });
    // Demo: the code "arrives" and fills itself in, like SMS autofill on Android
    for (var i = 0; i < 4; i++) {
      Future.delayed(Duration(milliseconds: 700 + i * 220), () {
        if (mounted) setState(() => code = '1234'.substring(0, i + 1));
      });
    }
  }

  // 3. About her
  Widget _about() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title('join_about'),
        MCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Bi.k('join_name', size: 14),
            const SizedBox(height: 8),
            TextField(controller: name, decoration: const InputDecoration(hintText: 'ഷീല / Sheela'), onChanged: (_) => setState(() {})),
            const SizedBox(height: 14),
            Bi.k('join_district', size: 14),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: district,
              isExpanded: true,
              items: [
                for (final (m, e) in _districts)
                  DropdownMenuItem(value: e, child: Text('$m · $e', style: const TextStyle(fontFamily: 'Jakarta', fontFamilyFallback: fonts)))
              ],
              onChanged: (v) => setState(() => district = v ?? district),
            ),
            const SizedBox(height: 14),
            Bi.k('join_lang', size: 14),
            const SizedBox(height: 8),
            Row(children: [
              for (final (v, label) in [('ml', 'മലയാളം'), ('en', 'English')])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: v == 'ml' ? 8 : 0),
                    child: _choice(label, '', lang == v, () => setState(() => lang = v)),
                  ),
                ),
            ]),
          ]),
        ),
        _gap(),
        BigButton('join_next', onPressed: name.text.trim().isEmpty ? null : () => go(JoinStep.sell)),
      ]);

  Widget _choice(String ml, String en, bool on, VoidCallback onTap) => Material(
        color: on ? C.brandSoft : C.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.all(8),
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? C.brand : C.line, width: 1.5)),
            child: Bi(ml, en, size: 15, weight: FontWeight.w700, color: on ? C.brand : C.ink, align: TextAlign.center),
          ),
        ),
      );

  // 4. What she sells
  Widget _sell() {
    final (_, _, items) = _kinds[kind]!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title('join_sell'),
      Row(children: [
        for (final MapEntry(key: k, value: (m, e, _)) in _kinds.entries)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: k == 'tailoring' ? 0 : 8),
              child: _choice(
                  m,
                  e,
                  kind == k,
                  () => setState(() {
                        kind = k;
                        picked.clear();
                      })),
            ),
          ),
      ]),
      _gap(10),
      Bi.k('join_pick', size: 13.5, weight: FontWeight.w500),
      _gap(10),
      GridView.count(
        padding: EdgeInsets.zero, // no extra safe-area gap inside the page list
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.25,
        children: [
          for (final (m, e, price) in items) _pick(m, e, price),
        ],
      ),
      _gap(),
      BigButton('join_next', onPressed: picked.isEmpty ? null : () => go(JoinStep.goal)),
    ]);
  }

  Widget _pick(String m, String e, int price) {
    final on = picked.containsKey(e);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: on ? C.brand : C.line, width: 1.5),
        boxShadow: on ? const [BoxShadow(color: C.brandSoft, spreadRadius: 3)] : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => on ? picked.remove(e) : picked[e] = (ml: m, en: e, price: price)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              kind == 'tailoring'
                  ? const Badge2(Icons.content_cut_rounded, bg: C.plumSoft, fg: C.plum, size: 44)
                  : FoodArt({'name_en': e, 'name_ml': m}, size: 44),
              const SizedBox(width: 8),
              Expanded(child: Bi(m, e, size: 14, weight: FontWeight.w700)),
              AnimatedScale(
                scale: on ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: const CircleAvatar(radius: 11, backgroundColor: C.brand, child: Icon(Icons.check_rounded, size: 14, color: Colors.white)),
              ),
            ]),
            const Spacer(),
            if (on)
              SizedBox(
                height: 40,
                child: TextFormField(
                  initialValue: '${picked[e]!.price}',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: numStyle(15, weight: FontWeight.w700),
                  decoration: const InputDecoration(prefixText: '₹ ', contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                  onChanged: (v) => picked[e] = (ml: m, en: e, price: int.tryParse(v) ?? 0),
                ),
              )
            else
              Text(rupees(price), style: const TextStyle(color: C.muted, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  // 5. What she's saving for
  Widget _goal() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title('join_goal'),
        GridView.count(
          padding: EdgeInsets.zero, // no extra safe-area gap inside the page list
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.1,
          children: [
            for (final (k, m, e, target) in _goals)
              Material(
                color: goal?.key == k ? C.goldSoft : C.card,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() {
                    goal = (key: k, ml: m, en: e);
                    goalAmount.text = '$target';
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: goal?.key == k ? C.gold : C.line, width: 1.5)),
                    child: Bi(m, e, size: 15, weight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
        if (goal != null) ...[
          _gap(),
          MCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (goal!.key == 'auto') const Center(child: AutoArt(pct: 0, width: 130)),
              Bi.k('join_goal_fill', size: 13.5, weight: FontWeight.w500, align: TextAlign.center),
              const SizedBox(height: 12),
              Bi.k('join_goal_amount', size: 14),
              const SizedBox(height: 8),
              TextField(
                controller: goalAmount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: numStyle(18, weight: FontWeight.w700),
                decoration: const InputDecoration(prefixText: '₹ '),
              ),
            ]),
          ),
        ],
        _gap(),
        BigButton('join_next', onPressed: () => go(JoinStep.done)),
        TextButton(
          onPressed: () {
            setState(() => goal = null);
            go(JoinStep.done);
          },
          child: Text('${T.ml('join_skip')} · ${T.en('join_skip')}', style: const TextStyle(color: C.muted)),
        ),
      ]);

  // 6. Ready
  Widget _done() {
    final r = call?['result'] as Map<String, dynamic>?;
    final want = byCall ? '${r?['district']}' : district;
    final d = _districts.firstWhere((x) => x.$2 == want, orElse: () => _districts[10]);
    final who = byCall ? (r?['name'] ?? '') : (name.text.trim().isEmpty ? 'Sheela' : name.text.trim());
    final items = byCall
        ? [for (final p in (r?['products'] as List? ?? const [])) (ml: p['ml'] as String, en: p['en'] as String, price: p['price'] as int)]
        : picked.values.toList();
    Widget row(IconData ic, String a, String b) => Row(children: [Badge2(ic, size: 40), const SizedBox(width: 12), Expanded(child: Bi(a, b, size: 15))]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      HeroCard(
        child: Column(children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: .4, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, s, child) => Transform.scale(scale: s, child: child),
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [C.goldLight, C.gold])),
              child: const Icon(Icons.check_rounded, size: 40, color: C.brandDeep),
            ),
          ),
          const SizedBox(height: 12),
          Bi('${T.ml('join_welcome')}, $who!', '${T.en('join_welcome')}, $who!',
              size: 24, weight: FontWeight.w800, color: Colors.white, enColor: Colors.white70, align: TextAlign.center),
          const SizedBox(height: 8),
          Bi.k('join_ready', size: 16, color: Colors.white, enColor: Colors.white70, align: TextAlign.center),
        ]),
      ),
      _gap(),
      MCard(
        child: Rows([
          row(Icons.call_rounded, byCall ? '${r?['phone']}' : '+91 ${phone.text}', byCall ? '${T.en('joined_by_call')} · PIN ••••' : T.en('joined_by_app')),
          row(Icons.location_on_outlined, d.$1, d.$2),
          row(Icons.inventory_2_outlined, items.map((p) => p.ml).join(', '), items.map((p) => '${p.en} ${rupees(p.price)}').join(' · ')),
          if (!byCall && goal != null) row(Icons.account_balance_wallet_outlined, '${goal!.ml} · ${rupees(num.tryParse(goalAmount.text) ?? 0)}', goal!.en),
        ]),
      ),
      _gap(),
      MCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Bi.k('join_how', size: 16, weight: FontWeight.w700),
          Rows([
            for (final (i, k) in ['join_how1', 'join_how2', 'join_how3'].indexed)
              Row(children: [
                CircleAvatar(
                    radius: 14,
                    backgroundColor: i == 0 ? C.gold : C.bg2,
                    child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w800, color: i == 0 ? Colors.white : C.muted))),
                const SizedBox(width: 12),
                Expanded(child: Bi.k(k, size: 15)),
              ]),
          ]),
        ]),
      ),
      _gap(),
      _loginCard(),
      _gap(),
      BigButton('join_open', onPressed: _finish),
      const SizedBox(height: 8),
      Text(T.en('join_demo_end'), textAlign: TextAlign.center, style: const TextStyle(color: C.muted, fontSize: 13)),
    ]);
  }

  // 7. Join by a phone call
  Widget _call() {
    final time = '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
    final state = callEnded ? 'call_ended' : (shown.isEmpty ? 'call_ready' : 'call_live');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 14), child: Bi(T.ml('path_call'), T.en('call_sub'), size: 22, weight: FontWeight.w800)),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0B3F37), C.brandDeep], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(28),
          border: const Border(bottom: BorderSide(color: C.gold, width: 6)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [C.goldLight, C.gold])),
              child: const Icon(Icons.call_rounded, color: C.brandDeep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('മിത്ര · Mitra', style: TextStyle(fontFamily: 'Malayalam', color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                Text('${T.ml(state)} · ${T.en(state)}', style: const TextStyle(fontFamily: 'Jakarta', fontFamilyFallback: fonts, color: C.mint, fontSize: 12)),
              ]),
            ),
            Text(time, style: numStyle(15, color: Colors.white70, weight: FontWeight.w700)),
          ]),
          const Divider(color: Color(0x1FFFFFFF), height: 24),
          for (final line in shown) _bubble(line),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Icon(Icons.phone_in_talk_rounded, size: 56, color: Colors.white.withValues(alpha: .25)),
            ),
          const SizedBox(height: 8),
          if (shown.isEmpty) BigButton('call_play', gold: true, icon: Icons.volume_up_rounded, onPressed: () => _runCall()),
          if (!callEnded)
            TextButton(
              onPressed: () => _runCall(fast: true),
              child: Text('${T.ml('call_skip')} · ${T.en('call_skip')}', style: const TextStyle(color: Colors.white70)),
            ),
        ]),
      ),
      if (callEnded) ...[
        _gap(),
        BigButton('call_see', onPressed: () => go(JoinStep.done)),
      ],
    ]);
  }

  Widget _bubble(Map<String, dynamic> line) {
    final who = line['who'] as String;
    final isTalking = line['id'] != null && line['id'] == talking;
    Widget text(Color c, Color e) => Bi(line['ml'] ?? '', line['en'] ?? '', size: 14.5, color: c, enColor: e, weight: FontWeight.w600);
    final (align, child) = switch (who) {
      'key' => (
          Alignment.centerRight,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: C.goldLight.withValues(alpha: .7), width: 1.5)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.dialpad_rounded, size: 16, color: C.goldLight),
              const SizedBox(width: 6),
              Text('${line['v']}', style: numStyle(18, color: C.goldLight)),
            ]),
          )
        ),
      'sys' => (
          Alignment.center,
          Bi(line['ml'], line['en'], size: 12.5, color: Colors.white70, enColor: Colors.white54, weight: FontWeight.w500, align: TextAlign.center)
        ),
      'sms' => (
          Alignment.center,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration:
                BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: const Border(left: BorderSide(color: C.gold, width: 4))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: C.goldText)),
              text(C.ink, C.muted),
            ]),
          )
        ),
      'her' => (
          Alignment.centerRight,
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: C.goldLight,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4)),
              border: isTalking ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: text(C.brandDeep, const Color(0xA6062F29)),
          )
        ),
      _ => (
          Alignment.centerLeft,
          Container(
            constraints: const BoxConstraints(maxWidth: 290),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4)),
              border: isTalking ? Border.all(color: C.mint, width: 2) : null,
            ),
            child: text(Colors.white, Colors.white70),
          )
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: align,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 300),
          builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: c)),
          child: child,
        ),
      ),
    );
  }
}
