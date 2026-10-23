import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../logic/templates.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

export '../logic/templates.dart' show personaLabel;

/// "আপনি কে?": the kind of user, so lists, one-tap questions and the
/// money page start out arranged for them. Shown once after the PIN, and
/// from সেটিংস.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.fromSettings = false});
  final bool fromSettings;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? _picked;
  final _lists = <String>{};

  void _pick(String key) {
    setState(() {
      _picked = key;
      _lists
        ..clear()
        ..addAll(personaSetup(key).lists);
    });
  }

  Future<void> _done() async {
    final brain = BrainScope.read(context);
    final key = _picked ?? 'other';
    await brain.setPref('persona', key);
    if (!widget.fromSettings || brain.quickQuestions.toString() == Brain.defaultQuestions.toString()) {
      await brain.setQuickQuestions(personaSetup(key).questions);
    }
    for (final t in listTemplates) {
      if (_lists.contains(t.name) && !brain.data.tasks.any((x) => x.list == tr(t.name))) {
        await brain.addList(tr(t.name), [for (final i in t.items) tr(i)]);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          if (widget.fromSettings) TopBar(title: tr('আপনার পরিচয়')) else const SizedBox(height: 16),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: [
              if (!widget.fromSettings) ...[
                Text(tr('আপনি কী করেন?'), style: display(26, weight: 700)),
                const SizedBox(height: 6),
                Text(tr('বেছে নিলে তালিকা, এক চাপের প্রশ্ন আর হিসাবের পাতা আপনার মতো করে সাজানো থাকবে। পরে সেটিংস থেকে বদলানো যায়।'),
                    style: body(15, color: C.muted, height: 1.5)),
                const SizedBox(height: 16),
              ],
              for (final p in personas) ...[
                Material(
                  color: _picked == p.$1 ? C.greenTint : C.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _pick(p.$1),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _picked == p.$1 ? C.green : C.line, width: _picked == p.$1 ? 2 : 1),
                      ),
                      child: Row(children: [
                        Text(p.$2, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(tr(p.$3), style: body(16, weight: FontWeight.w600)),
                            Text(tr(p.$4), style: body(13, color: C.muted)),
                          ]),
                        ),
                        if (_picked == p.$1) Icon(Icons.check_circle_rounded, color: C.green),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (_picked != null) ...[
                const SizedBox(height: 8),
                SectionTitle(tr('তৈরি তালিকা যোগ করবেন?')),
                Panel(
                  child: Column(children: [
                    for (final t in listTemplates)
                      CheckboxListTile(
                        value: _lists.contains(t.name),
                        onChanged: (v) => setState(() => v == true ? _lists.add(t.name) : _lists.remove(t.name)),
                        title: Text('${t.icon} ${tr(t.name)}', style: body(15)),
                        subtitle: Text(trf('{0}টি জিনিস', [bnDigits(t.items.length)]), style: body(12.5, color: C.muted)),
                      ),
                  ]),
                ),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(children: [
              PrimaryButton(label: _picked == null ? tr('পরে করবো') : tr('শুরু করি'), onPressed: _done),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// তৈরি তালিকা: ready-made lists to add in one tap.
class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('তৈরি তালিকা')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              Text(tr('একটা বেছে নিলে তার সব জিনিস কাজের তালিকায় আলাদা নামে উঠে যাবে। টিক দিয়ে দিয়ে শেষ করুন, দরকারমতো বাদ দিন বা যোগ করুন।'),
                  style: body(14, color: C.muted, height: 1.5)),
              const SizedBox(height: 14),
              for (final t in listTemplates) ...[
                Panel(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(t.icon, style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(tr(t.name), style: body(17, weight: FontWeight.w600))),
                      _addButton(context, brain, t),
                    ]),
                    const SizedBox(height: 6),
                    Text(t.items.map(tr).join(' · '), style: body(13, color: C.muted, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                const SizedBox(height: 10),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _addButton(BuildContext context, Brain brain, ListTemplate t) {
    final have = brain.data.tasks.any((x) => x.list == tr(t.name) && !x.done);
    if (have) return Pill(tr('যোগ করা আছে'));
    return FilledButton(
      onPressed: () async {
        await brain.addList(tr(t.name), [for (final i in t.items) tr(i)]);
        if (context.mounted) toast(context, trf('‘{0}’ কাজের তালিকায় যোগ হলো', [tr(t.name)]));
      },
      style: FilledButton.styleFrom(backgroundColor: C.green, shape: const StadiumBorder()),
      child: Text(tr('যোগ করুন')),
    );
  }
}
