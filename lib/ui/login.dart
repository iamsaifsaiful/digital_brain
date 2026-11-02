import 'package:flutter/material.dart';

import '../services/api.dart';
import '../state/hisab.dart';
import 'kit.dart';
import '../core/lang.dart';
import 'lock_screen.dart';

/// Sign in to the shop's server: admin or agent, the server decides.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.h});
  final Hisab h;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _login = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _err;

  Future<void> _go() async {
    if (_login.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _err = 'মোবাইল নম্বর (বা লগইন নাম) আর পাসওয়ার্ড দিন');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await widget.h.login(_login.text, _pass.text, device: 'Android');
    } on ApiDenied {
      setState(() => _err = 'লগইন হয়নি — নম্বর বা পাসওয়ার্ড ঠিক নেই, অথবা লগইন বন্ধ করা আছে');
    } on ApiOffline {
      setState(() => _err = 'ইন্টারনেট নেই বা সার্ভারে পৌঁছানো যাচ্ছে না');
    } catch (_) {
      setState(() => _err = 'লগইন হয়নি, একটু পরে আবার চেষ্টা করুন');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.h.s.api.configured;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(22, 30, 22, 24), children: [
          Align(alignment: Alignment.centerRight, child: LangButton(h: widget.h)),
          const Center(child: ExchangeAnim(width: 230)),
          const SizedBox(height: 14),
          Tx('রেমিট খাতা', textAlign: TextAlign.center, style: t(22, w: FontWeight.w700)),
          const SizedBox(height: 4),
          Tx('এডমিন বা এজেন্ট — নিজের লগইন দিয়ে ঢুকুন', textAlign: TextAlign.center, style: t(14, c: K.muted)),
          const SizedBox(height: 26),
          if (!ready) ...[
            const Note('এই অ্যাপটি সার্ভারের সাথে ঠিক করা নেই। সঠিক অ্যাপটি ইনস্টল করুন।', color: K.redTint, textColor: K.red, icon: Icons.error_outline_rounded),
            const SizedBox(height: 16),
          ],
          Field(label: 'মোবাইল নম্বর বা লগইন নাম', controller: _login, phone: false),
          const SizedBox(height: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(left: 6, bottom: 4), child: Tx('পাসওয়ার্ড', style: t(13, c: K.muted))),
            TextField(
              controller: _pass,
              obscureText: !_show,
              style: t(16),
              onSubmitted: (_) => _go(),
              decoration: InputDecoration(
                filled: true,
                fillColor: K.card,
                suffixIcon: IconButton(
                  tooltip: tr(_show ? 'লুকান' : 'দেখান'),
                  icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _show = !_show),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: K.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: K.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: K.blue, width: 2)),
              ),
            ),
          ]),
          if (_err != null) ...[const SizedBox(height: 14), Note(_err!, color: K.redTint, textColor: K.red)],
          const SizedBox(height: 22),
          Pill(label: _busy ? 'লগইন হচ্ছে…' : 'লগইন', icon: Icons.login_rounded, onTap: _busy || !ready ? null : _go),
          const SizedBox(height: 18),
          Tx('লগইন না থাকলে দোকানের মূল এডমিনের কাছে চান।', textAlign: TextAlign.center, style: t(13, c: K.muted)),
          const SizedBox(height: 26),
          MadeBy(h: widget.h),
        ]),
      ),
    );
  }
}
