import 'package:flutter/material.dart';

import '../logic/suggest.dart';
import '../logic/lang.dart';
import '../logic/parser.dart';
import '../logic/search.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import 'home_shell.dart';
import 'search_screen.dart';

/// The one box at the bottom of every main page, where the thumb reaches:
/// type to find (matches show right above as you type), send to save or
/// ask, or tap the big mic and speak. On Home the one-tap questions sit
/// just above it.
class AssistantBar extends StatefulWidget {
  const AssistantBar({super.key, this.questions = false});

  /// Show the one-tap questions (Home).
  final bool questions;

  @override
  State<AssistantBar> createState() => _AssistantBarState();
}

class _AssistantBarState extends State<AssistantBar> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _text.clear();
    _focus.unfocus();
    openChatWith(context, t);
  }

  void _openSearch(String q) {
    _focus.unfocus();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchScreen(initial: q)));
  }

  /// A few of the user's own things matching what is typed so far.
  List<(IconData, String, String)> _matches(Brain brain, String q) {
    final terms = searchTerms(normalize(q));
    final use = terms.isEmpty ? [normalize(q)] : terms;
    final out = <(IconData, String, String)>[];
    for (final h in searchAll(brain.data, use).take(4)) {
      switch (h) {
        case ContactHit(:final contact):
          out.add((Icons.person_outline_rounded, contact.name, tr('যোগাযোগ')));
        case PersonHit(:final person):
          out.add((Icons.payments_outlined, person, tr('হিসাব')));
        case ReminderHit(:final reminder):
          out.add((Icons.notifications_none_rounded, reminder.title, tr('রিমাইন্ডার')));
        case NoteHit(:final note):
          out.add((Icons.sticky_note_2_outlined, note.title, tr('নোট')));
        case VaultHit(:final item):
          out.add((Icons.lock_outline_rounded, item.name, tr('পাসওয়ার্ড')));
        case DocHit(:final doc):
          out.add((Icons.folder_copy_outlined, doc.title, tr('ডকুমেন্ট')));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final q = _text.text.trim();
    final typing = q.isNotEmpty;
    final matches = typing ? _matches(brain, q) : const <(IconData, String, String)>[];
    final hints = typing ? suggestPrompts(q, brain.data, max: 3) : const <String>[];

    Widget chip(String label, VoidCallback onTap, {IconData? icon}) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: C.greenTint,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[Icon(icon, size: 16, color: C.greenDark), const SizedBox(width: 5)],
                  Text(label, style: body(13.5, weight: FontWeight.w500, color: C.greenDark, height: 1.2)),
                ]),
              ),
            ),
          ),
        );

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // While typing: what matches, and "ask the assistant".
      // Keys keep the box itself in place when the panel appears above it;
      // without them the text field was rebuilt and the keyboard closed
      // after the first letter.
      if (typing && _focus.hasFocus)
        Container(
          key: const ValueKey('matches'),
          constraints: const BoxConstraints(maxHeight: 260),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: C.dark ? 0.35 : 0.08), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Material(
            color: C.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: C.line)),
            clipBehavior: Clip.antiAlias,
            child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
            for (final (icon, title, kind) in matches)
              ListTile(
                dense: true,
                leading: Icon(icon, color: C.muted2, size: 21),
                title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w500)),
                trailing: Text(kind, style: body(12, color: C.muted)),
                onTap: () => _openSearch(q),
              ),
            ListTile(
              dense: true,
              leading: Icon(Icons.auto_awesome_rounded, color: C.green, size: 21),
              title: Text(trf('সহকারীকে বলুন: “{0}”', [q]), maxLines: 2, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w600, color: C.greenDark)),
              onTap: _send,
            ),
            if (matches.isNotEmpty)
              ListTile(
                dense: true,
                leading: Icon(Icons.search_rounded, color: C.muted2, size: 21),
                title: Text(tr('সব মিল দেখুন'), style: body(14, color: C.muted2)),
                onTap: () => _openSearch(q),
              ),
            // What can be done with the typed words: a tap puts the sentence in the box.
            for (final h in hints)
              ListTile(
                key: ValueKey('suggest:$h'),
                dense: true,
                leading: Icon(Icons.lightbulb_outline_rounded, color: C.ochre, size: 21),
                title: Text(h.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, style: body(15)),
                trailing: Icon(Icons.north_west_rounded, color: C.muted, size: 18),
                onTap: () {
                  _text.text = h;
                  _text.selection = TextSelection.collapsed(offset: h.length);
                  setState(() {});
                },
              ),
          ]),
          ),
        ),
      Container(
        key: const ValueKey('box'),
        decoration: BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.border))),
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // The one-tap questions: once the box is touched (approved design keeps the bar quiet).
          if (widget.questions && !typing && _focus.hasFocus) ...[
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                children: [
                  chip(tr('আগের কথা'), () => openAssistant(context), icon: Icons.forum_outlined),
                  for (final x in brain.quickQuestions) chip(x, () => openChatWith(context, x)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(children: [
              Expanded(
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  decoration: BoxDecoration(
                    color: C.ground,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: _focus.hasFocus ? C.green : C.border, width: _focus.hasFocus ? 1.5 : 1),
                  ),
                  child: Row(children: [
                    Icon(Icons.keyboard_outlined, color: C.muted, size: 20),
                    const SizedBox(width: 9),
                    Expanded(
                      child: TextField(
                        controller: _text,
                        focusNode: _focus,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        style: body(14),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: tr('বলুন বা লিখুন — “রবিনকে ৫০০ দিলাম”'),
                          hintStyle: body(13.5, color: C.muted),
                        ),
                      ),
                    ),
                    if (typing)
                      IconButton(
                        tooltip: tr('মুছুন'),
                        visualDensity: VisualDensity.compact,
                        onPressed: _text.clear,
                        icon: Icon(Icons.close_rounded, color: C.muted, size: 20),
                      )
                    else if (_focus.hasFocus)
                      // The earlier conversations, once the box is touched.
                      IconButton(
                        key: const Key('home-past-chats'),
                        tooltip: tr('আগের কথাগুলো'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => openPastChats(context),
                        icon: Icon(Icons.history_rounded, color: C.muted, size: 21),
                      ),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              // The mic; once something is typed it becomes "send".
              Tooltip(
                message: typing ? tr('পাঠান') : tr('বলুন'),
                child: Semantics(
                  button: true,
                  label: typing ? tr('পাঠান') : tr('বলুন'),
                  excludeSemantics: true,
                  child: Material(
                    color: C.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(17),
                      onTap: typing ? _send : () => openVoice(context),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: Icon(typing ? Icons.arrow_upward_rounded : Icons.mic_none_rounded, color: C.onAccent, size: 26),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }
}
