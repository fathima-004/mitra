// The phone call: "Mitra, call me" rings her phone through Hiba's call-me function (PLAN.md §5),
// and this screen shows what she can press or say on the call.
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/common.dart';


class CallMeCard extends StatefulWidget {
  const CallMeCard({super.key});
  @override
  State<CallMeCard> createState() => _CallMeCardState();
}

class _CallMeCardState extends State<CallMeCard> with SingleTickerProviderStateMixin {
  late final _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  bool busy = false;

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  Future<void> _call() async {
    setState(() => busy = true);
    try {
      if (siteUrl.isEmpty) throw Exception('no site');
      final res = await http.post(Uri.parse('$siteUrl/.netlify/functions/call-me')).timeout(const Duration(seconds: 8));
      if (res.statusCode >= 300) throw Exception(res.statusCode);
      if (mounted) toast(context, 'call_started', icon: Icons.call_rounded);
    } catch (_) {
      if (mounted) toast(context, 'call_unavailable', icon: Icons.call_rounded);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MCard(
      onTap: busy ? null : _call,
      color: C.goldSoft,
      border: Border.all(color: const Color(0x66C9971F)),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        SizedBox(
          width: 64,
          height: 64,
          child: AnimatedBuilder(
            animation: _ring,
            builder: (_, __) => Stack(alignment: Alignment.center, children: [
              for (final shift in [0.0, .5])
                Opacity(
                  opacity: (1 - ((_ring.value + shift) % 1)).clamp(0, 1) * .5,
                  child: Container(
                    width: 48 + 24 * ((_ring.value + shift) % 1),
                    height: 48 + 24 * ((_ring.value + shift) % 1),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.brand, width: 2)),
                  ),
                ),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [C.brand, C.brandDeep])),
                child: busy
                    ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.call_rounded, color: Colors.white),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Bi.k(busy ? 'calling' : 'call_me', size: 17, weight: FontWeight.w800),
            const SizedBox(height: 2),
            Text(T.ml('call_me_hint'), style: const TextStyle(fontFamily: 'Malayalam', fontSize: 12.5, color: C.muted)),
          ]),
        ),
        const Icon(Icons.arrow_forward_rounded, color: C.brand),
      ]),
    );
  }
}

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  static const _menu = [
    ('1', 'call_key1'),
    ('2', 'call_key2'),
    ('3', 'call_key3'),
    ('4', 'call_key4'),
    ('9', 'call_key9'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 120), children: [
        const TopBar('call_title'),
        const SizedBox(height: 16),
        const CallMeCard(),
        const SizedBox(height: 14),
        MCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Bi.k('call_menu_title', size: 16, weight: FontWeight.w700),
            Rows([
              for (final (key, label) in _menu)
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: C.brandDeep, borderRadius: BorderRadius.circular(12)),
                    child: Text(key, style: numStyle(20, color: C.goldLight)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Bi.k(label, size: 15)),
                ]),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        HeroCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Bi.k('call_try', size: 15, color: Colors.white, enColor: Colors.white70, weight: FontWeight.w700),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: C.goldLight, borderRadius: BorderRadius.circular(16)),
              child: const Text('"ഇന്ന് 12 ബിരിയാണി പോയി"\n"innu 12 biriyani poyi"',
                  style: TextStyle(fontFamily: 'Malayalam', fontWeight: FontWeight.w700, color: C.brandDeep, fontSize: 16, height: 1.5)),
            ),
            const SizedBox(height: 10),
            Bi.k('call_try_sub', size: 13, color: Colors.white, enColor: Colors.white70, weight: FontWeight.w500),
          ]),
        ),
      ]),
    );
  }
}
