import 'package:flutter/material.dart';

import '../logic/lang.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'settings_parts.dart' show pickAccentColor;

/// আরও › থিম ও ভাষা (owner, 22 Nov: "চেহারা ও ভাষা" renamed, and the insides
/// redone: "একদম ভাল লাগে না"). Picture tiles with a live sample on top
/// (the owner's pick of two, 23 Nov). No sample card on top
/// (owner, 23 Nov: "ইউজার কিছুই করতে পারতেছে না") — the page itself changes at once.

class LookSettings extends StatelessWidget {
  const LookSettings({super.key});

  @override
  Widget build(BuildContext context) => const _LookTiles();
}

String lookName(Look l) => switch (l) {
      Look.sun => tr('সময়ের সাথে'),
      Look.system => tr('ফোনের মতো'),
      Look.light => tr('আলো'),
      Look.dark => tr('অন্ধকার'),
    };

String lookNote(Look l) => switch (l) {
      Look.sun => tr('দিনে আলো, সন্ধ্যার পর অন্ধকার'),
      Look.system => tr('ফোনের সেটিং যা বলে'),
      Look.light => tr('সবসময় আলো'),
      Look.dark => tr('সবসময় অন্ধকার'),
    };

String sizeName(double s) => s >= 1.3 ? tr('আরও বড়') : (s >= 1.15 ? tr('বড়') : tr('সাধারণ'));

const _sizes = [1.0, 1.15, 1.3];

/// A small picture of a theme: the ground, a card and two lines.
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch(this.look);
  final Look look;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final night = darkSets.firstWhere((d) => d.key == brain.darkKey, orElse: () => darkSets.first);
    const dayGround = Color(0xFFF1F4F2), dayCard = Colors.white, dayLine = Color(0xFFCFD8D4);
    Widget half(Color ground, Color card, Color line) => Container(
          color: ground,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
          child: Container(
            decoration: BoxDecoration(color: card, borderRadius: const BorderRadius.vertical(top: Radius.circular(5))),
            padding: const EdgeInsets.fromLTRB(5, 6, 5, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 4, width: 22, decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 4),
              Container(height: 3, decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 3),
              Container(height: 3, width: 26, decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(2))),
            ]),
          ),
        );
    final day = half(dayGround, dayCard, dayLine);
    final dark = half(night.ground, night.surface, night.line);
    final Widget face = switch (look) {
      Look.light => day,
      Look.dark => dark,
      _ => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: ClipRect(child: OverflowBox(alignment: Alignment.centerLeft, maxWidth: double.infinity, child: SizedBox(width: 64, child: day)))),
          Expanded(child: ClipRect(child: OverflowBox(alignment: Alignment.centerRight, maxWidth: double.infinity, child: SizedBox(width: 64, child: dark)))),
        ]),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 52,
        child: Stack(fit: StackFit.expand, children: [
          face,
          if (look == Look.sun || look == Look.system)
            Center(
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: dayLine)),
                child: Icon(look == Look.sun ? Icons.wb_twilight_rounded : Icons.smartphone_rounded, size: 13, color: const Color(0xFF3E524B)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// A tile that can be chosen: a soft border, the accent when chosen.
class _Choice extends StatelessWidget {
  const _Choice({super.key, required this.selected, required this.onTap, required this.child, this.padding = const EdgeInsets.all(8)});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? C.greenTint : C.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: selected ? C.green : C.line, width: selected ? 1.6 : 1)),
          child: InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      );
}

/// The accent circles and "নিজের রং".
class _AccentDots extends StatelessWidget {
  const _AccentDots();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final custom = brain.accentKey.startsWith('#');
    Widget dot({required bool on, Color? color, Gradient? gradient, IconData? icon, required String label, required VoidCallback onTap, Key? key}) => Semantics(
          selected: on,
          button: true,
          label: label,
          child: Tooltip(
            message: label,
            child: InkWell(
              key: key,
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? C.ink : Colors.transparent, width: 2)),
                child: Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color, gradient: gradient),
                  child: on || icon != null ? Icon(on ? Icons.check_rounded : icon, color: Colors.white, size: 20) : null,
                ),
              ),
            ),
          ),
        );
    // Spread edge to edge, like the dark colours below.
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      for (final a in accents) dot(key: Key('accent-${a.key}'), on: brain.accentKey == a.key, color: a.main, label: isEn ? a.nameEn : a.name, onTap: () => brain.setAccent(a.key)),
      dot(
        key: const Key('accent-custom'),
        on: custom,
        color: custom ? accentFor(brain.accentKey).main : null,
        gradient: custom ? null : const SweepGradient(colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red]),
        icon: Icons.add_rounded,
        label: tr('নিজের রং'),
        onTap: () => pickAccentColor(context),
      ),
    ]);
  }
}

/// The dark look's colours, as small cards.
class _DarkSets extends StatelessWidget {
  const _DarkSets();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    // Owner, 23 Nov: three to a row, edge to edge (no gap on the right).
    const perRow = 3;
    Widget card(DarkSet d) => Semantics(
          selected: brain.darkKey == d.key,
          button: true,
          label: isEn ? d.nameEn : d.name,
          child: InkWell(
            key: Key('dark-${d.key}'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => brain.setDarkSet(d.key),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
              decoration: BoxDecoration(
                color: d.ground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: brain.darkKey == d.key ? C.green : d.line, width: brain.darkKey == d.key ? 2 : 1),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Container(height: 14, decoration: BoxDecoration(color: d.surface, borderRadius: BorderRadius.circular(5), border: Border.all(color: d.line)))),
                  if (brain.darkKey == d.key) ...[const SizedBox(width: 4), Icon(Icons.check_circle_rounded, size: 14, color: C.green)],
                ]),
                const SizedBox(height: 5),
                Text(isEn ? d.nameEn : d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: d.muted2, height: 1.2)),
              ]),
            ),
          ),
        );
    return Column(children: [
      for (var r = 0; r < darkSets.length; r += perRow) ...[
        if (r > 0) const SizedBox(height: 8),
        Row(children: [
          for (var i = r; i < r + perRow; i++) ...[
            if (i > r) const SizedBox(width: 8),
            Expanded(child: i < darkSets.length ? card(darkSets[i]) : const SizedBox.shrink()),
          ],
        ]),
      ],
    ]);
  }
}

Widget _easyRow(Brain brain) => Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('সহজ মোড'), style: body(15, weight: FontWeight.w500)),
          Text(tr('বড় লেখা, হোমে ৪টি বড় বোতাম, উত্তর কণ্ঠে শোনাবে — বয়স্কদের জন্য সুবিধা'), style: body(12.5, color: C.muted, height: 1.35)),
        ]),
      ),
      const SizedBox(width: 8),
      Switch(key: const Key('look-easy'), value: brain.easyMode, onChanged: (v) => brain.setEasyMode(v)),
    ]);

// ── Design 1: tiles ──

class _LookTiles extends StatelessWidget {
  const _LookTiles();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    Widget head(String t, [String? sub]) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text(t, style: body(14, weight: FontWeight.w600, color: C.muted2))),
            if (sub != null) Text(sub, style: body(12, color: C.muted)),
          ]),
        );
    final darkMatters = brain.look != Look.light;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Panel(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          head(tr('ভাষা') + (isEn ? '' : ' · Language')),
          Row(children: [
            for (final (en, glyph, name) in [(false, 'অ', 'বাংলা'), (true, 'A', 'English')]) ...[
              if (en) const SizedBox(width: 10),
              Expanded(
                child: _Choice(
                  key: Key('look-lang-${en ? 'en' : 'bn'}'),
                  selected: brain.english == en,
                  onTap: () => brain.setEnglish(en),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: brain.english == en ? C.green : C.surface2, borderRadius: BorderRadius.circular(10)),
                      child: Text(glyph, style: body(17, weight: FontWeight.w700, height: 1.1, color: brain.english == en ? C.onAccent : C.muted2)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(name, style: body(15, weight: FontWeight.w600))),
                  ]),
                ),
              ),
            ],
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          head(tr('থিম'), lookNote(brain.look)),
          Row(children: [
            for (final (i, l) in Look.values.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _Choice(
                  key: Key('look-theme-${l.name}'),
                  selected: brain.look == l,
                  onTap: () => brain.setLook(l),
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 7),
                  child: Column(children: [
                    _ThemeSwatch(l),
                    const SizedBox(height: 6),
                    FittedBox(fit: BoxFit.scaleDown, child: Text(lookName(l), maxLines: 1, style: body(12, weight: brain.look == l ? FontWeight.w600 : FontWeight.w400))),
                  ]),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 18),
          head(tr('মূল রঙ')),
          const _AccentDots(),
          if (darkMatters) ...[
            const SizedBox(height: 16),
            head(tr('অন্ধকারের রঙ'), tr('অন্ধকার থিমে পেছনের রঙ')),
            const _DarkSets(),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          head(tr('লেখার আকার')),
          Row(children: [
            for (final (i, s) in _sizes.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _Choice(
                  key: Key('look-size-$i'),
                  selected: brain.letterSize == s,
                  onTap: () => brain.setLetterSize(s),
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                  child: Column(children: [
                    SizedBox(
                      height: 30,
                      child: Center(
                        child: Text('অ', textScaler: TextScaler.noScaling, style: body(16 + i * 5.0, weight: FontWeight.w600, height: 1.1, color: brain.letterSize == s ? C.green : C.ink)),
                      ),
                    ),
                    Text(sizeName(s), style: body(12, weight: brain.letterSize == s ? FontWeight.w600 : FontWeight.w400)),
                  ]),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          Divider(height: 1, color: C.line),
          const SizedBox(height: 8),
          _easyRow(brain),
        ]),
      ),
    ]);
  }
}
