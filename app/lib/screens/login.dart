// Log in, or one tap into the demo for the judges. Owner: Hiba.
// The demo account is Sheela's (assets/data/demo.json): phone 98765 43210, PIN 1234.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n.dart';
import '../main.dart';
import '../ui/kit.dart';
import 'join.dart';

const demoPhone = '9876543210';
const demoPin = '1234';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phone = TextEditingController();
  final pin = TextEditingController();
  String? error;

  void _login() {
    if (phone.text.replaceAll(' ', '') == demoPhone && pin.text == demoPin) {
      logIn(context);
    } else {
      setState(() => error = tr('wrong_login'));
    }
  }

  Widget _langChip(String code, String label) {
    final on = L.lang.value == code;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontFamily: code == 'ml' ? 'Malayalam' : 'Jakarta', fontWeight: FontWeight.w700)),
        selected: on,
        selectedColor: K.greenSoft,
        side: BorderSide(color: on ? K.green : K.line),
        onSelected: (_) => L.set(code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(22, 10, 22, 24), children: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [_langChip('ml', 'മലയാളം'), _langChip('en', 'English')]),
            const SizedBox(height: 26),
            Center(
              child: Container(
                width: 92,
                height: 92,
                decoration: const BoxDecoration(color: K.greenSoft, shape: BoxShape.circle),
                child: const Icon(Icons.eco_rounded, color: K.green, size: 52),
              ),
            ),
            const SizedBox(height: 14),
            Text(tr('app_name'), textAlign: TextAlign.center, style: ts(34, w: FontWeight.w800)),
            Text(tr('tagline'), textAlign: TextAlign.center, style: ts(16, w: FontWeight.w500, c: K.muted)),
            const SizedBox(height: 30),

            // One tap for the judges.
            Tint(
              color: K.greenSoft,
              onTap: () => logIn(context),
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                const Bubble(Icons.play_arrow_rounded, color: Colors.white, bg: K.green, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('demo_login'), style: ts(19, w: FontWeight.w800, c: K.greenDark)),
                    Text(tr('demo_login_sub'), style: ts(13.5, w: FontWeight.w500, c: K.muted)),
                  ]),
                ),
                const Icon(Icons.arrow_forward_rounded, color: K.green),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(children: [
                const Expanded(child: Divider(color: K.line)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(tr('or'), style: ts(14, c: K.muted))),
                const Expanded(child: Divider(color: K.line)),
              ]),
            ),

            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: money(20, w: FontWeight.w600),
              decoration: InputDecoration(
                labelText: tr('phone'),
                labelStyle: ts(15, c: K.muted),
                prefixText: '+91  ',
                counterText: '',
                prefixIcon: const Icon(Icons.phone_rounded),
              ),
              onChanged: (_) => setState(() => error = null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pin,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: money(20, w: FontWeight.w600),
              decoration: InputDecoration(labelText: tr('pin'), labelStyle: ts(15, c: K.muted), counterText: '', prefixIcon: const Icon(Icons.lock_rounded)),
              onChanged: (_) => setState(() => error = null),
              onSubmitted: (_) => _login(),
            ),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: ts(14, c: K.red))),
            const SizedBox(height: 16),
            BigBtn(tr('login'), icon: Icons.login_rounded, onTap: phone.text.length == 10 && pin.text.length == 4 ? _login : null),
            const SizedBox(height: 8),
            Text(tr('demo_hint'), textAlign: TextAlign.center, style: ts(13, w: FontWeight.w500, c: K.muted)),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinScreen())),
              child: Text(tr('new_here'), style: ts(16, w: FontWeight.w700, c: K.green)),
            ),
          ]),
        ),
      );
}
