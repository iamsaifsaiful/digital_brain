import 'package:flutter/material.dart';

import '../core/format.dart';
import '../state/hisab.dart';
import 'kit.dart';

/// First run: owner's name and the agent's WhatsApp number.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.h});
  final Hisab h;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _owner = TextEditingController(text: 'সাইফুল');
  final _agent = TextEditingController(text: 'মনোয়ারা স্টোর (তন্তু ভাই)');
  final _wa = TextEditingController();
  final _comm = TextEditingController(text: '0');
  String? _err;
  bool _busy = false;

  Future<void> _save() async {
    final wa = en(_wa.text).replaceAll(RegExp(r'[^0-9+]'), '');
    if (_owner.text.trim().isEmpty || _agent.text.trim().isEmpty) {
      setState(() => _err = 'নাম দুটো লিখুন');
      return;
    }
    if (wa.replaceAll('+', '').length < 9) {
      setState(() => _err = 'এজেন্টের হোয়াটসঅ্যাপ নম্বর ঠিকমতো লিখুন');
      return;
    }
    setState(() {
      _err = null;
      _busy = true;
    });
    await widget.h.setup(owner: _owner.text, agentName: _agent.text, agentWhatsapp: wa, commission: parseNum(_comm.text) ?? 0);
  }

  @override
  Widget build(BuildContext context) => Screen(
        title: 'শুরু করা যাক',
        back: false,
        bottom: Pill(label: 'শুরু করুন', icon: Icons.arrow_forward_rounded, onTap: _busy ? null : _save),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: [
          const Note('এই তথ্য পরে সেটিংস থেকে বদলানো যাবে। এজেন্টের নম্বরে প্রতিটা লেনদেনের মেসেজ একই চ্যাটে যাবে।', icon: Icons.info_outline_rounded),
          const SizedBox(height: 16),
          Field(label: 'আপনার নাম', controller: _owner),
          const SizedBox(height: 14),
          Field(label: 'এজেন্টের নাম', controller: _agent),
          const SizedBox(height: 14),
          Field(label: 'এজেন্টের হোয়াটসঅ্যাপ নম্বর', controller: _wa, phone: true, hint: '01XXXXXXXXX'),
          const SizedBox(height: 14),
          Field(label: 'এজেন্টের কমিশন (প্রতি হাজার টাকায়, না থাকলে ০)', controller: _comm, number: true, suffix: '৳/হাজার'),
          if (_err != null) ...[const SizedBox(height: 14), Note(_err!, color: K.redTint, textColor: K.red)],
        ]),
      );
}
