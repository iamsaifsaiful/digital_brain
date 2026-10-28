import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// রক্তের গ্রুপ দিলে (owner, 28 Oct): a mobile number and the last donation
/// day — or "মনে নেই" — must come with it; all three are kept on our server
/// so we can help in an emergency. False when the member did not finish.
Future<bool> askBloodDetails(BuildContext context, String group) async {
  final ok = await showAppSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _BloodDetails(group: group));
  return ok == true;
}

class _BloodDetails extends StatefulWidget {
  const _BloodDetails({required this.group});
  final String group;

  @override
  State<_BloodDetails> createState() => _BloodDetailsState();
}

class _BloodDetailsState extends State<_BloodDetails> {
  late final Brain brain = BrainScope.read(context);
  late final _phone = TextEditingController(text: brain.text('blood_phone'));
  late DateTime? _last = DateTime.tryParse(brain.text('blood_last'));
  late bool _unknown = _last == null && brain.flag('blood_last_unknown');
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final digits = asciiDigits(_phone.text.trim()).replaceAll(RegExp(r'[^0-9]'), '');
    final local = digits.startsWith('880') ? '0${digits.substring(3)}' : digits;
    if (!RegExp(r'^01[3-9]\d{8}$').hasMatch(local)) return setState(() => _error = tr('মোবাইল নম্বর দিন — ১১ অঙ্কের, যেমন ০১৭১২৩৪৫৬৭৮'));
    if (_last == null && !_unknown) return setState(() => _error = tr('শেষ কবে রক্ত দিয়েছেন — তারিখ দিন, অথবা “মনে নেই” বেছে নিন'));
    setState(() {
      _busy = true;
      _error = null;
    });
    await brain.setBloodDetails(phone: local, last: _last, unknown: _unknown);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final now = brain.services.now();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(trf('রক্তের গ্রুপ {0}', [widget.group]), style: display(20, weight: 700)),
            const SizedBox(height: 6),
            Text(tr('রক্তের গ্রুপ, মোবাইল নম্বর আর শেষ রক্তদানের তারিখ আমাদের সার্ভারে থাকবে — যেন বিপদে আমরা আপনাকে বা আপনার জন্য রক্ত খুঁজে সাহায্য করতে পারি। গ্রুপ মুছে দিলে সার্ভার থেকেও মুছে যায়।'),
                style: body(13, color: C.muted, height: 1.5)),
            const SizedBox(height: 14),
            TextField(
              key: const Key('blood-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: tr('মোবাইল নম্বর *'), hintText: '01712345678'),
            ),
            const SizedBox(height: 12),
            Text(tr('শেষ কবে রক্ত দিয়েছেন? *'), style: body(13, weight: FontWeight.w600, color: C.muted2)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                key: const Key('blood-last-pick'),
                label: Text(_last == null ? tr('তারিখ দিন') : fullDate(_last!)),
                selected: _last != null,
                onSelected: (_) async {
                  final d = await showDatePicker(context: context, initialDate: _last ?? now, firstDate: DateTime(now.year - 30), lastDate: now);
                  if (d != null) {
                    setState(() {
                      _last = d;
                      _unknown = false;
                    });
                  }
                },
              ),
              ChoiceChip(
                key: const Key('blood-last-unknown'),
                label: Text(tr('মনে নেই / কখনো দিইনি')),
                selected: _unknown,
                onSelected: (v) => setState(() {
                  _unknown = v;
                  if (v) _last = null;
                }),
              ),
            ]),
            if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: body(14, color: C.red))],
            const SizedBox(height: 16),
            PrimaryButton(key: const Key('blood-save'), label: tr('রাখুন'), onPressed: _busy ? null : _save),
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('বাতিল'))),
          ]),
        ),
      ),
    );
  }
}
