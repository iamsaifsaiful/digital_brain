/// আরও › ফোনে কথা বোঝার মডেল (owner, 2 Nov): why the app has its own small
/// model, how it reads what you say, how it learns a little more every round,
/// what the model now on this phone does better, and how you can help — in
/// that order. The numbers are the release gate's own measure (tool/nlu/gate.py
/// on the gold set, written sentences), never a guess.
library;

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'feedback_screen.dart' show FeedbackScreen;

/// What a released model does better than the one before it, measured by the
/// gate on the test set: (what, before %, after %). Add one entry per release.
const nluReleaseNotes = <String, List<(String, double, double)>>{
  // Round 11, 30 Oct 2026, against 2026.10.22-bert2 (nlu-results › gate.md).
  'r20261030-14': [
    ('সব মিলিয়ে ঠিক বোঝা', 76.1, 93.5),
    ('নতুন কাজ যোগ করা', 66.6, 97.0),
    ('রিমাইন্ডার দেখতে চাওয়া', 69.8, 100.0),
    ('কাউকে ফোন করতে বলা', 23.8, 92.4),
    ('আয়-ব্যয় লেখা', 72.9, 94.3),
    ('টাকার সব কথা', 83.5, 94.0),
    ('জন্মদিন-বিবাহবার্ষিকী', 89.0, 100.0),
    ('সমস্যা বা সাহায্য চাওয়া', 58.7, 73.0),
  ],
};

String _pct(double v) => '${bnDigits(v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1))}%';

class NluModelScreen extends StatelessWidget {
  const NluModelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final ver = brain.nluModelVersion;
    final notes = nluReleaseNotes[ver];
    final state = switch (brain.nluModelState) {
      'ready' => trf('এই ফোনে চলছে · সংস্করণ {0}', [ver]),
      'wait-wifi' => tr('Wi-Fi পেলে নিজে নামবে (প্রায় ১৪ MB) — মোবাইল ডেটায় নয়'),
      'builtin' => tr('এখনো চালু হয়নি — অ্যাপ নিজের নিয়মে বুঝছে'),
      _ => tr('নামানো যায়নি — পরে আবার চেষ্টা হবে'),
    };
    Widget head(String n, String t) => Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 8),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(9)),
              child: Text(n, style: body(14, weight: FontWeight.w700, color: C.onAccent, height: 1)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(t, style: body(17, weight: FontWeight.w700))),
          ]),
        );
    Widget para(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: body(14.5, height: 1.6)));
    Widget step(String n, String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 26, child: Text(n, style: body(14.5, weight: FontWeight.w700, color: C.green))),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: body(14.5, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(text, style: body(13.5, color: C.muted, height: 1.55)),
              ]),
            ),
          ]),
        );
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('কথা বোঝার মডেল')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
              Panel(
                key: const Key('nlu-state'),
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.psychology_outlined, color: C.green, size: 26),
                  const SizedBox(width: 12),
                  Expanded(child: Text(state, style: body(14.5, weight: FontWeight.w600, height: 1.45))),
                ]),
              ),

              head('১', tr('কেন নিজের মডেল')),
              para(tr('আমরা চাই My Assistant সবাই বিনা মূল্যে ব্যবহার করতে পারুক। আপনার প্রতিটা কথা বড় ক্লাউড AI দিয়ে বোঝাতে হলে প্রতিবার খরচ হয় — সেই খরচ শেষে ব্যবহারকারীকেই দিতে হতো।')),
              para(tr('তাই আমরা নিজেরা একটা ছোট মডেল বানাচ্ছি, যা আপনার ফোনের ভেতরেই চলে। এতে কোনো খরচ নেই, ইন্টারনেট ছাড়াও কাজ করে, আর আপনার কথা ফোনের বাইরে যায় না।')),

              head('২', tr('এটা কীভাবে বোঝে')),
              para(tr('আপনি যা বলেন বা লেখেন, তা একসাথে দুজন পড়ে — অ্যাপের নিজের নিয়ম আর এই মডেল। দুজন একমত হলে সেটাই করা হয়।')),
              para(tr('একমত না হলে, দরকার হলে আমাদের সার্ভার থেকে তৃতীয় একটা মত নেওয়া হয় — নাম সরিয়ে। তিনজনের দুজন যা বলে, সেটাই। পাসওয়ার্ড, মোবাইল নম্বর, কোড বা স্বাস্থ্য-ওষুধের কথা থাকলে কখনো বাইরে যায় না — ফোনেই সিদ্ধান্ত হয়।')),

              head('৩', tr('দিনে দিনে কীভাবে শিখছে')),
              step('১.', tr('নমুনা'), tr('যেসব কথায় নিয়ম আর মডেল একমত হয়নি, তার কিছু নাম সরিয়ে সার্ভারে আসে। পাসওয়ার্ড, মোবাইল নম্বর, কোড, স্বাস্থ্য বা ওষুধের কথা কখনো না; ১৮০ দিন পর নিজে মুছে যায়।')),
              step('২.', tr('সঠিক অর্থ'), tr('প্রতিটা বাক্যের সঠিক অর্থ আমরা মিলিয়ে লিখি — কোনটা কাজ, কোনটা রিমাইন্ডার, কোনটা টাকার হিসাব।')),
              step('৩.', tr('নতুন করে শেখানো'), tr('এসব আর হাজার হাজার বাক্য দিয়ে নতুন মডেল শেখানো হয়।')),
              step('৪.', tr('কড়া পরীক্ষা'), tr('প্রায় ৭ হাজার বাক্যের আলাদা পরীক্ষায় — যে বাক্য শেখানোয় কখনো দেওয়া হয় না। কোনো ধরনের কথায় আগের চেয়ে স্পষ্ট খারাপ করলে নতুন মডেল বাতিল।')),
              step('৫.', tr('অল্প অল্প করে চালু'), tr('পরীক্ষায় পাস করলে আগে কিছু ফোনে, ঠিক থাকলে সবার ফোনে — Wi-Fi পেলে নিজে নামে। সমস্যা হলে আগের মডেলে ফেরা যায়।')),

              head('৪', tr('এই মডেলে কী উন্নতি হয়েছে')),
              if (notes == null)
                para(brain.nluModelState == 'ready' ? trf('সংস্করণ {0}-এর হিসাব এখনো এখানে যোগ হয়নি।', [ver]) : tr('মডেল নামলে এখানে দেখাবে, আগের সংস্করণের চেয়ে কোথায় কতটা ভালো।'))
              else ...[
                para(tr('আগের সংস্করণের সাথে তুলনা — একই পরীক্ষায়, কতটা ঠিক বুঝেছে:')),
                Panel(
                  key: const Key('nlu-notes'),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(children: [
                    for (final (i, (what, a, b)) in notes.indexed) ...[
                      if (i > 0) Divider(height: 1, color: C.line2),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          Expanded(child: Text(tr(what), style: body(14, weight: i == 0 ? FontWeight.w700 : FontWeight.w500))),
                          Text(_pct(a), style: body(13.5, color: C.muted)),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward_rounded, size: 16, color: C.muted)),
                          Text(_pct(b), style: body(14.5, weight: FontWeight.w700, color: C.green)),
                        ]),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 8),
                Text(tr('লেখা বাক্যের পরীক্ষায় মাপা। মুখে বললে ফোনের মাইক কতটা ঠিক শোনে, তার ওপরও নির্ভর করে।'), style: body(12.5, color: C.muted, height: 1.5)),
              ],

              head('৫', tr('আপনি কীভাবে সাহায্য করবেন')),
              Panel(
                padding: EdgeInsets.zero,
                child: Rows(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                    child: Row(children: [
                      Icon(Icons.school_outlined, color: C.muted2, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr('কথা বোঝা আরও ভালো করতে সাহায্য করুন'), style: body(15)),
                          Text(tr('কিছু বার্তা নাম সরিয়ে সার্ভারে যায় — পাসওয়ার্ড, মোবাইল নম্বর, কোড বা স্বাস্থ্যের কথা কখনো না; ১৮০ দিন পর নিজে মুছে যায়'), style: body(12, color: C.muted)),
                        ]),
                      ),
                      Switch(key: const Key('nlu-samples'), value: brain.nluSamplesOn, onChanged: (v) => brain.setNluSamplesOn(v)),
                    ]),
                  ),
                  ListRow(
                    leading: Icon(Icons.forum_outlined, color: C.muted2, size: 22),
                    title: tr('ভুল বুঝলে আমাদের জানান'),
                    subtitle: tr('কী বলেছিলেন আর কী হলো — লিখে দিন'),
                    trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FeedbackScreen())),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// আরও › "আমার পাঠানো বার্তা সার্ভার থেকে মুছে দিন" (owner, 2 Nov): first what
/// the learning samples are, what never goes and why we take them; then one
/// button that deletes what was sent and stops sending (it can be turned on
/// again from the model's page).
class NluSamplesScreen extends StatefulWidget {
  const NluSamplesScreen({super.key});

  @override
  State<NluSamplesScreen> createState() => _NluSamplesScreenState();
}

class _NluSamplesScreenState extends State<NluSamplesScreen> {
  bool _busy = false;

  Future<void> _delete() async {
    final brain = BrainScope.read(context);
    final ok = await confirmDialog(context,
        title: tr('পাঠানো বার্তা মুছে দেবেন?'),
        text: tr('সার্ভারে আপনার পাঠানো সব বার্তা মুছে যাবে, আর এখন থেকে পাঠানো বন্ধ থাকবে। চাইলে পরে “ফোনে কথা বোঝার মডেল” পাতা থেকে আবার চালু করতে পারবেন।'),
        yes: tr('মুছে দিন'),
        danger: true);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final why = await brain.deleteMyNluSamples();
    if (why == null) await brain.setNluSamplesOn(false);
    if (!mounted) return;
    setState(() => _busy = false);
    toast(context, why ?? tr('মুছে দেওয়া হয়েছে — আর পাঠানো হবে না'));
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    Widget sec(String title, List<String> lines) => Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: body(16, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 8, right: 10), child: Container(width: 6, height: 6, decoration: BoxDecoration(color: C.green, shape: BoxShape.circle))),
                  Expanded(child: Text(l, style: body(14.5, height: 1.55))),
                ]),
              ),
          ]),
        );
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('আমার পাঠানো বার্তা')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
              Text(brain.nluSamplesOn ? tr('এখন পাঠানো চালু আছে।') : tr('এখন পাঠানো বন্ধ আছে।'), style: body(14.5, weight: FontWeight.w600, color: brain.nluSamplesOn ? C.green : C.muted)),
              sec(tr('কী নিই'), [
                tr('যেসব কথায় অ্যাপের নিয়ম আর ফোনের মডেল একমত হয়নি, তার কিছু বাক্য — আর একমত হওয়া কথার প্রতি দশটার একটা।'),
                tr('বাক্যের নামগুলো ফোনেই সরিয়ে “<নাম১>” বসানো হয়।'),
                tr('সাথে যায়: অ্যাপ আর মডেলের সংস্করণ, অ্যাপ তখন কী জানতে চাইছিল, আর কে কী বুঝেছিল।'),
              ]),
              sec(tr('কী কখনো নিই না'), [
                tr('পাসওয়ার্ড, PIN, OTP বা কোনো লম্বা কোড'),
                tr('মোবাইল নম্বর'),
                tr('স্বাস্থ্য, ওষুধ, ভল্ট বা কন্টাক্টের কথা'),
                tr('আপনার নাম বা ইমেইল — নমুনার সাথে শুধু একটা গোপন সংকেত থাকে, যাতে আপনি চাইলে আপনারগুলো মুছে দেওয়া যায়'),
              ]),
              sec(tr('কেন নিই'), [
                tr('অ্যাপ সবার জন্য বিনা মূল্যে রাখতে আমরা ফোনের ভেতরে চলা নিজের মডেল বানাচ্ছি। মানুষ আসলে যেভাবে বলে, সেই বাক্য দিয়েই মডেল সবচেয়ে ভালো শেখে।'),
                tr('এই বাক্য শুধু মডেল শেখানো আর পরীক্ষার কাজে লাগে — বিক্রি হয় না, বিজ্ঞাপনে যায় না।'),
              ]),
              sec(tr('কতদিন থাকে'), [tr('১৮০ দিন পর নিজে মুছে যায়। তার আগেই মুছতে চাইলে নিচে চাপুন।')]),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('nlu-samples-delete'),
                onPressed: _busy ? null : _delete,
                style: FilledButton.styleFrom(backgroundColor: C.red, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                icon: _busy ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: C.onAccent)) : const Icon(Icons.delete_sweep_outlined, color: Colors.white),
                label: Text(tr('মুছে দিন'), style: body(16, weight: FontWeight.w600, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              Text(tr('মুছলে সার্ভারের সব বার্তা যাবে আর পাঠানো বন্ধ হবে।'), textAlign: TextAlign.center, style: body(12.5, color: C.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}
