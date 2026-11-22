import 'package:flutter/material.dart';

import '../logic/lang.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'settings_parts.dart' show pickAccentColor;

/// আরও › থিম ও ভাষা (owner, 22 Nov: "চেহারা ও ভাষা" renamed, and the insides
/// redone: "একদম ভাল লাগে না"). Two designs to choose from:
/// 1 = picture tiles with a live sample on top, 2 = a short list, each row
/// opening its own sheet.
int lookDesign = 1;

class LookSettings extends StatelessWidget {
  const LookSettings({super.key});

  @override
  Widget build(BuildContext context) => lookDesign == 2 ? const _LookList() : const _LookTiles();
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

/// What the app looks like with these choices: a reminder card.
class _Sample extends StatelessWidget {
  const _Sample();

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('look-sample'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('এমন দেখাবে'), style: body(12, color: C.muted, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(11)),
                child: Icon(Icons.alarm_rounded, color: C.green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('মাকে ফোন করা'), style: body(15, weight: FontWeight.w600)),
                  Text(tr('আজ সন্ধ্যা ৭টা'), style: body(12.5, color: C.muted)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(20)),
                child: Text(tr('হয়ে গেছে'), style: body(12.5, weight: FontWeight.w600, color: C.onAccent)),
              ),
            ]),
          ),
        ]),
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
    return Wrap(spacing: 4, runSpacing: 4, children: [
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
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final d in darkSets)
        Semantics(
          selected: brain.darkKey == d.key,
          button: true,
          label: isEn ? d.nameEn : d.name,
          child: InkWell(
            key: Key('dark-${d.key}'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => brain.setDarkSet(d.key),
            child: Container(
              width: 84,
              padding: const EdgeInsets.fromLTRB(7, 7, 7, 6),
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
                Text(isEn ? d.nameEn : d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: d.muted2, height: 1.2)),
              ]),
            ),
          ),
        ),
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
      const _Sample(),
      const SizedBox(height: 14),
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

// ── Design 2: a short list, each row opening a sheet ──

class _LookList extends StatelessWidget {
  const _LookList();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final accent = accentFor(brain.accentKey);
    final night = darkSets.firstWhere((d) => d.key == brain.darkKey, orElse: () => darkSets.first);
    Widget icon(IconData i, Color fg, Color bg) => Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
          child: Icon(i, color: fg, size: 20),
        );
    Widget value(String text, {Widget? lead}) => Row(mainAxisSize: MainAxisSize.min, children: [
          if (lead != null) ...[lead, const SizedBox(width: 6)],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13.5, color: C.muted)),
          ),
          const SizedBox(width: 2),
          Icon(Icons.chevron_right_rounded, color: C.muted),
        ]);
    Widget dot(Color c) => Container(width: 16, height: 16, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: C.line)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Sample(),
      const SizedBox(height: 14),
      Panel(
        child: Rows(children: [
          ListRow(
            key: const Key('look-row-lang'),
            leading: icon(Icons.translate_rounded, C.blue, C.blueTint),
            title: tr('ভাষা') + (isEn ? '' : ' · Language'),
            trailing: value(brain.english ? 'English' : 'বাংলা'),
            onTap: () => _pick<bool>(context, tr('ভাষা'), [(false, 'বাংলা', 'অ'), (true, 'English', 'A')], brain.english, brain.setEnglish),
          ),
          ListRow(
            key: const Key('look-row-theme'),
            leading: icon(Icons.contrast_rounded, C.purple, C.purpleTint),
            title: tr('থিম'),
            trailing: value(lookName(brain.look)),
            onTap: () => _themeSheet(context),
          ),
          ListRow(
            key: const Key('look-row-accent'),
            leading: icon(Icons.palette_outlined, C.green, C.greenTint),
            title: tr('মূল রঙ'),
            trailing: value(isEn ? accent.nameEn : accent.name, lead: dot(accent.main)),
            onTap: () => _sheet(context, tr('মূল রঙ'), (_) => const _AccentDots()),
          ),
          if (brain.look != Look.light)
            ListRow(
              key: const Key('look-row-dark'),
              leading: icon(Icons.dark_mode_outlined, C.ochre, C.ochreTint),
              title: tr('অন্ধকারের রঙ'),
              trailing: value(isEn ? night.nameEn : night.name, lead: dot(night.ground)),
              onTap: () => _sheet(context, tr('অন্ধকারের রঙ'), (_) => const _DarkSets()),
            ),
          ListRow(
            key: const Key('look-row-size'),
            leading: icon(Icons.format_size_rounded, C.teal, C.tealTint),
            title: tr('লেখার আকার'),
            trailing: value(sizeName(brain.letterSize)),
            onTap: () => _pick<double>(context, tr('লেখার আকার'), [for (final s in _sizes) (s, sizeName(s), 'অ')], brain.letterSize, brain.setLetterSize, grow: true),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Panel(padding: const EdgeInsets.fromLTRB(14, 10, 8, 10), child: _easyRow(brain)),
    ]);
  }

  static Future<void> _sheet(BuildContext context, String title, WidgetBuilder child) => showAppSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: display(20, weight: 700)),
              const SizedBox(height: 14),
              ListenableBuilder(listenable: BrainScope.read(context), builder: (c, _) => child(c)),
            ]),
          ),
        ),
      );

  static Future<void> _pick<T>(BuildContext context, String title, List<(T, String, String)> items, T value, Future<void> Function(T) set, {bool grow = false}) => _sheet(context, title, (ctx) {
        return Panel(
          child: Rows(children: [
            for (final (i, (v, label, glyph)) in items.indexed)
              ListRow(
                key: Key('look-pick-$i'),
                leading: SizedBox(
                  width: 34,
                  child: Center(child: Text(glyph, textScaler: TextScaler.noScaling, style: body(grow ? 16 + i * 5.0 : 17, weight: FontWeight.w700, color: C.muted2))),
                ),
                title: label,
                trailing: v == value ? Icon(Icons.check_circle_rounded, color: C.green) : Icon(Icons.circle_outlined, color: C.line),
                onTap: () {
                  set(v);
                  Navigator.pop(ctx);
                },
              ),
          ]),
        );
      });

  static Future<void> _themeSheet(BuildContext context) => _sheet(context, tr('থিম'), (ctx) {
        final brain = BrainScope.of(ctx);
        return Panel(
          child: Rows(children: [
            for (final l in Look.values)
              ListRow(
                key: Key('look-pick-${l.name}'),
                leading: SizedBox(width: 56, child: _ThemeSwatch(l)),
                title: lookName(l),
                subtitle: lookNote(l),
                trailing: brain.look == l ? Icon(Icons.check_circle_rounded, color: C.green) : Icon(Icons.circle_outlined, color: C.line),
                onTap: () {
                  brain.setLook(l);
                  Navigator.pop(ctx);
                },
              ),
          ]),
        );
      });
}
