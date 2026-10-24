import 'package:flutter/material.dart';

import '../logic/me.dart' show bloodGroups;

import '../logic/bn.dart';
import '../logic/lang.dart';
import 'pro_screen.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// The user's round photo, or their initial (or a person icon) without one.
class UserPhoto extends StatelessWidget {
  const UserPhoto({super.key, this.size = 42, this.onDark = false});
  final double size;

  /// On the green home header: a light ring and white icon.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final photo = brain.photo;
    final name = brain.userName.trim();
    final Widget inner;
    if (photo != null) {
      inner = Image.memory(photo, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => const SizedBox());
    } else if (name.isNotEmpty) {
      inner = Center(
        child: Text(name.characters.first.toUpperCase(),
            style: display(size * 0.42, weight: 700, color: onDark ? Colors.white : C.greenDark)),
      );
    } else {
      inner = Icon(Icons.person_outline_rounded, color: onDark ? Colors.white : C.greenDark, size: size * 0.55);
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onDark ? Colors.white.withValues(alpha: 0.18) : C.greenTint,
        border: Border.all(color: onDark ? Colors.white.withValues(alpha: 0.55) : C.line, width: onDark ? 1.5 : 1),
      ),
      child: inner,
    );
  }
}

/// Camera, gallery or remove — for the profile photo.
Future<void> changePhoto(BuildContext context) async {
  final brain = BrainScope.read(context);
  final pick = await showAppSheet<int>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: Icon(Icons.photo_camera_outlined, color: C.green), title: Text(tr('ছবি তুলুন')), onTap: () => Navigator.pop(ctx, 0)),
        ListTile(leading: Icon(Icons.photo_library_outlined, color: C.green), title: Text(tr('গ্যালারি থেকে')), onTap: () => Navigator.pop(ctx, 1)),
        if (brain.photo != null)
          ListTile(leading: Icon(Icons.delete_outline_rounded, color: C.red), title: Text(tr('ছবি সরান')), onTap: () => Navigator.pop(ctx, 2)),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (pick == null) return;
  if (pick == 2) {
    await brain.setPhoto(null);
    return;
  }
  // A small square-ish photo is plenty for a profile picture.
  final f = await brain.services.files.pickPhoto(camera: pick == 0, side: 512);
  if (f == null) return;
  await brain.setPhoto(f.bytes);
  if (context.mounted) toast(context, tr('প্রোফাইলের ছবি রাখা হলো'));
}

/// Top of the settings page: photo, then name, place and blood group as
/// separate full-width rows, each big enough for a thumb (no mis-taps).
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.onName, required this.onPlace});
  final VoidCallback onName;
  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final blood = brain.data.emergency.blood;
    Widget row(Key key, IconData icon, Color color, String label, String value, VoidCallback onTap, {bool empty = false}) => Material(
          color: Colors.transparent,
          child: InkWell(
            key: key,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(label, style: body(12.5, color: C.muted)),
                      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15.5, weight: FontWeight.w600, color: empty ? C.green : C.ink)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.muted),
                ]),
              ),
            ),
          ),
        );
    return Panel(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Semantics(
              button: true,
              label: tr('প্রোফাইলের ছবি বদলান'),
              child: InkWell(
                key: const Key('profile-photo'),
                customBorder: const CircleBorder(),
                onTap: () => changePhoto(context),
                child: Stack(clipBehavior: Clip.none, children: [
                  const UserPhoto(size: 72),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: C.green, shape: BoxShape.circle, border: Border.all(color: C.surface, width: 2)),
                      child: const Icon(Icons.photo_camera_rounded, size: 15, color: Colors.white),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(brain.userName.isEmpty ? tr('আপনার নাম দিন') : brain.userName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: display(20, weight: 700, color: brain.userName.isEmpty ? C.muted : C.ink)),
                if (brain.signedIn) Text(brain.googleEmail, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, color: C.muted)),
                if (brain.gated) ...[const SizedBox(height: 6), const PlanBadge()],
              ]),
            ),
          ]),
        ),
        Divider(height: 1, color: C.line2),
        row(const Key('profile-name'), Icons.badge_outlined, C.green, tr('নাম'), brain.userName.isEmpty ? tr('নাম দিন') : brain.userName, onName, empty: brain.userName.isEmpty),
        Divider(height: 1, indent: 52, color: C.line2),
        row(const Key('profile-place'), Icons.place_outlined, C.blue, tr('জেলা/শহর'), brain.autoPlace ? trf('{0} · ফোনের লোকেশন অনুযায়ী', [tr(brain.district)]) : tr(brain.district), onPlace),
        Divider(height: 1, indent: 52, color: C.line2),
        row(const Key('profile-blood'), Icons.bloodtype_outlined, C.rose, tr('রক্তের গ্রুপ'), blood.isEmpty ? tr('রক্তের গ্রুপ দিন') : blood, () => pickBloodGroup(context),
            empty: blood.isEmpty),
      ]),
    );
  }
}

/// The user's blood group (kept on the emergency card; the assistant answers
/// "আমার ব্লাড গ্রুপ কী?" from it).
Future<void> pickBloodGroup(BuildContext context) async {
  final brain = BrainScope.read(context);
  final current = brain.data.emergency.blood;
  final picked = await showAppSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('আপনার রক্তের গ্রুপ'), style: display(20, weight: 700)),
          const SizedBox(height: 4),
          Text(tr('জরুরি কার্ডে থাকবে; রক্তদাতা হলে মিলিয়ে দেখা যাবে।'), style: body(13.5, color: C.muted)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final g in [...bloodGroups, ''])
              ChoiceChip(label: Text(g.isEmpty ? tr('জানি না') : g, style: body(16, weight: FontWeight.w600)), selected: current == g, onSelected: (_) => Navigator.pop(ctx, g)),
          ]),
        ]),
      ),
    ),
  );
  if (picked != null && picked != current) await brain.saveEmergency(brain.data.emergency.copyWith(blood: picked));
}

/// সেটিংস › চেহারা ও ভাষা: language, light/dark, accent colour, letter size, easy mode.
class LookSection extends StatelessWidget {
  const LookSection({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    Widget label(String t, [String? sub]) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: body(15, weight: FontWeight.w500)),
            if (sub != null) Text(sub, style: body(12.5, color: C.muted)),
          ]),
        );
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        label(tr('ভাষা') + (isEn ? '' : ' · Language')),
        SegTabs<bool>(
          items: const [(false, 'বাংলা'), (true, 'English')],
          value: brain.english,
          onChanged: (v) => brain.setEnglish(v),
        ),
        const SizedBox(height: 18),
        label(tr('থিম')),
        SegTabs<Look>(
          items: [(Look.system, tr('ফোনের মতো')), (Look.light, tr('আলো')), (Look.dark, tr('অন্ধকার'))],
          value: brain.look,
          onChanged: (v) => brain.setLook(v),
        ),
        const SizedBox(height: 18),
        label(tr('মূল রঙ')),
        Wrap(spacing: 12, runSpacing: 10, children: [
          for (final a in accents)
            Tooltip(
              message: isEn ? a.nameEn : a.name,
              child: Semantics(
                selected: brain.accentKey == a.key,
                button: true,
                label: isEn ? a.nameEn : a.name,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => brain.setAccent(a.key),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: a.main,
                      shape: BoxShape.circle,
                      border: Border.all(color: brain.accentKey == a.key ? C.ink : Colors.transparent, width: 2.5),
                    ),
                    child: brain.accentKey == a.key ? const Icon(Icons.check_rounded, color: Colors.white, size: 22) : null,
                  ),
                ),
              ),
            ),
          // Any colour the user likes.
          Tooltip(
            message: tr('নিজের রং'),
            child: Semantics(
              selected: brain.accentKey.startsWith('#'),
              button: true,
              label: tr('নিজের রং'),
              child: InkWell(
                key: const Key('accent-custom'),
                customBorder: const CircleBorder(),
                onTap: () => pickAccentColor(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: brain.accentKey.startsWith('#') ? accentFor(brain.accentKey).main : null,
                    gradient: brain.accentKey.startsWith('#')
                        ? null
                        : const SweepGradient(colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red]),
                    border: Border.all(color: brain.accentKey.startsWith('#') ? C.ink : Colors.transparent, width: 2.5),
                  ),
                  child: Icon(brain.accentKey.startsWith('#') ? Icons.check_rounded : Icons.add_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        label(tr('লেখার আকার')),
        SegTabs<double>(
          items: [(1.0, tr('সাধারণ')), (1.15, tr('বড়')), (1.3, tr('আরও বড়'))],
          value: brain.letterSize,
          onChanged: (v) => brain.setLetterSize(v),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('সহজ মোড'), style: body(15, weight: FontWeight.w500)),
              Text(tr('বড় লেখা, হোমে ৪টা বড় বোতাম, উত্তর কণ্ঠে শোনাবে — বয়স্কদের জন্য সুবিধা'), style: body(12.5, color: C.muted)),
            ]),
          ),
          Switch(value: brain.easyMode, onChanged: (v) => brain.setEasyMode(v)),
        ]),
      ]),
    );
  }
}

/// সেটিংস › মূল রঙ › নিজের রং: any hue, lighter or deeper, seen before saving.
Future<void> pickAccentColor(BuildContext context) async {
  final brain = BrainScope.read(context);
  final start = HSLColor.fromColor(accentFor(brain.accentKey).main);
  var hue = start.hue;
  var shade = start.lightness.clamp(0.22, 0.45);
  final picked = await showAppSheet<Color>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final color = customAccent(HSLColor.fromAHSL(1, hue, 0.75, shade).toColor()).main;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr('নিজের রং বেছে নিন'), style: display(20, weight: 700)),
              const SizedBox(height: 14),
              Container(
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
                child: Text(tr('এমন দেখাবে'), style: body(17, weight: FontWeight.w600, color: Colors.white)),
              ),
              const SizedBox(height: 16),
              Text(tr('রং'), style: body(14, color: C.muted)),
              Container(
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: LinearGradient(colors: [for (var h = 0; h <= 360; h += 30) HSLColor.fromAHSL(1, h.toDouble(), 0.75, 0.42).toColor()]),
                ),
              ),
              Slider(key: const Key('hue'), value: hue, min: 0, max: 360, activeColor: color, onChanged: (v) => setSheet(() => hue = v)),
              Text(tr('হালকা – গাঢ়'), style: body(14, color: C.muted)),
              Slider(key: const Key('shade'), value: 0.67 - shade, min: 0.22, max: 0.45, activeColor: color, onChanged: (v) => setSheet(() => shade = 0.67 - v)),
              const SizedBox(height: 8),
              PrimaryButton(label: tr('এই রং রাখুন'), icon: Icons.check_rounded, color: color, onPressed: () => Navigator.pop(ctx, color)),
            ]),
          ),
        );
      },
    ),
  );
  if (picked != null) await brain.setAccent(colorKey(picked));
}

/// ফ্রি / প্রো / ট্রায়াল on the profile; a tap shows what Pro gives.
class PlanBadge extends StatelessWidget {
  const PlanBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final pro = brain.pro;
    final trial = pro && brain.proKind == 'trial';
    final until = brain.proUntil;
    final label = !pro
        ? tr('ফ্রি')
        : trial
            ? tr('ট্রায়াল')
            : tr('প্রিমিয়াম');
    final sub = pro && until != null ? trf('{0} পর্যন্ত', [shortDate(until)]) : (pro ? '' : tr('প্রিমিয়াম নিন'));
    final fg = pro ? C.ochre : C.muted;
    final bg = pro ? C.ochreTint : C.chip;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: BorderSide(color: fg.withValues(alpha: 0.35))),
        child: InkWell(
          key: const Key('plan-badge'),
          customBorder: const StadiumBorder(),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(pro ? Icons.workspace_premium_rounded : Icons.person_outline_rounded, size: 16, color: fg),
              const SizedBox(width: 5),
              Text(label, style: body(13, weight: FontWeight.w700, color: fg)),
              if (sub.isNotEmpty) Text(' · $sub', style: body(12.5, color: fg)),
            ]),
          ),
        ),
      ),
    );
  }
}
