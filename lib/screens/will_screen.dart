// ওছিয়তনামা (owner, 24 Oct): the user's own will, written in নোট, with the
// day it was last changed. It is kept as one note (id [willNoteId]) so it
// is locked, backed up and — when chosen — goes to the heirs with the notes.
// Writing it is premium; one already written can always be read.
import 'package:flutter/material.dart';
import '../ui/secure.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../logic/pro.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/pro_gate.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const willNoteId = 'will';
const willCategory = 'ওছিয়তনামা';

Note? willOf(AppData d) => d.notes.where((n) => n.id == willNoteId).firstOrNull;

/// The card at the top of নোট.
class WillCard extends StatelessWidget {
  const WillCard({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final w = willOf(brain.data);
    return Panel(
      child: InkWell(
        key: const Key('will-open'),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WillScreen())),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: C.ochreTint, borderRadius: BorderRadius.circular(13)),
              child: Icon(Icons.history_edu_outlined, color: C.ochre, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(tr('ওছিয়তনামা'), style: body(15.5, weight: FontWeight.w600))),
                  if (!brain.has(ProFeature.will)) ...[const SizedBox(width: 6), const ProMark()],
                ]),
                Text(w == null ? tr('এখনো লেখা হয়নি — নিজের ওছিয়ত লিখে রাখুন') : trf('শেষ ওছিয়ত: {0}', [fullDate(w.updatedAt)]),
                    key: const Key('will-date'), style: body(12.5, color: C.muted)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: C.muted),
          ]),
        ),
      ),
    );
  }
}

class WillScreen extends StatefulWidget {
  const WillScreen({super.key});

  @override
  State<WillScreen> createState() => _WillScreenState();
}

class _WillScreenState extends State<WillScreen> {
  late final TextEditingController _text;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: willOf(BrainScope.read(context).data)?.body ?? '');
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String _sample(Brain brain) {
    final name = brain.userName.isEmpty ? tr('[আপনার নাম]') : brain.userName;
    return trf(
        'বিসমিল্লাহির রাহমানির রাহীম।\n\nআমি, {0}, সুস্থ মস্তিষ্কে, কারো চাপ ছাড়া এই ওছিয়ত করছি।\n\n১. আমার দেনা: …\n২. আমার পাওনা: …\n৩. আমার সম্পদের এক-তৃতীয়াংশের মধ্যে ওছিয়ত: …\n৪. জানাজা ও দাফন: …\n৫. পরিবারের জন্য কথা: …\n\nবাকি সম্পদ ইসলামি উত্তরাধিকার আইন অনুযায়ী ভাগ হবে।',
        [name]);
  }

  Future<void> _save(Brain brain) async {
    if (!await needPro(context, ProFeature.will) || !mounted) return;
    final body = _text.text.trim();
    if (body.isEmpty) {
      toast(context, tr('কিছু লেখা নেই'));
      return;
    }
    await brain.saveNote(Note(id: willNoteId, title: tr('ওছিয়তনামা'), body: body, category: willCategory, updatedAt: brain.services.now()));
    if (!mounted) return;
    setState(() => _changed = false);
    toast(context, trf('ওছিয়তনামা রাখা হলো — {0}', [fullDate(brain.services.now())]));
  }

  @override
  Widget build(BuildContext context) => SecureView(child: _secretBuild(context));

  Widget _secretBuild(BuildContext context) {
    final brain = BrainScope.of(context);
    final w = willOf(brain.data);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('ওছিয়তনামা')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              Text(
                w == null ? tr('এখনো লেখা হয়নি') : trf('শেষ ওছিয়ত: {0}', [fullDate(w.updatedAt)]),
                key: const Key('will-last'),
                style: body(14, weight: FontWeight.w600, color: w == null ? C.muted : C.green),
              ),
              const SizedBox(height: 4),
              Text(tr('এই ফোনে তালাবদ্ধ থাকে। ফ্যামিলিতে উত্তরাধিকারী রাখলে আর “নোট” দেখার অনুমতি দিলে তিনি পরে দেখতে পাবেন। বদলালে নতুন তারিখ দেখাবে।'),
                  style: body(12.5, color: C.muted, height: 1.45)),
              const SizedBox(height: 12),
              TextField(
                key: const Key('will-text'),
                controller: _text,
                minLines: 12,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                onChanged: (_) {
                  if (!_changed) setState(() => _changed = true);
                },
                decoration: InputDecoration(hintText: tr('আপনার ওছিয়ত এখানে লিখুন…'), alignLabelWithHint: true),
              ),
              if (_text.text.trim().isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('will-sample'),
                    onPressed: () => setState(() {
                      _text.text = _sample(brain);
                      _changed = true;
                    }),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: Text(tr('একটা নমুনা দিয়ে শুরু করুন')),
                  ),
                ),
              const SizedBox(height: 12),
              PrimaryButton(key: const Key('will-save'), label: w == null ? tr('রাখুন') : tr('বদলে রাখুন'), icon: Icons.check_rounded, onPressed: _changed || w == null ? () => _save(brain) : null),
              const SizedBox(height: 10),
              Text(tr('এটা আইনি দলিলের বদলে নয় — প্রয়োজনে আলেম বা আইনজীবীর পরামর্শ নিন।'), style: body(12, color: C.muted2, height: 1.4)),
            ]),
          ),
        ]),
      ),
    );
  }
}
