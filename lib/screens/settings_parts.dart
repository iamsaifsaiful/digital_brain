import 'package:flutter/material.dart';

import '../logic/me.dart' show bloodGroups;

import '../logic/lang.dart';
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
  final pick = await showModalBottomSheet<int>(
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

/// Top of the settings page: photo, name and place.
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.onName, required this.onPlace});
  final VoidCallback onName;
  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Semantics(
          button: true,
          label: tr('প্রোফাইলের ছবি বদলান'),
          child: InkWell(
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
            InkWell(
              onTap: onName,
              child: Row(children: [
                Flexible(
                  child: Text(brain.userName.isEmpty ? tr('আপনার নাম দিন') : brain.userName,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: display(20, weight: 700, color: brain.userName.isEmpty ? C.muted : C.ink)),
                ),
                const SizedBox(width: 6),
                Icon(Icons.edit_outlined, size: 16, color: C.muted),
              ]),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: onPlace,
              child: Row(children: [
                Icon(Icons.place_outlined, size: 16, color: C.muted),
                const SizedBox(width: 4),
                Text(tr(brain.district), style: body(14, color: C.muted)),
              ]),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => pickBloodGroup(context),
              child: Row(children: [
                Icon(Icons.bloodtype_outlined, size: 16, color: C.rose),
                const SizedBox(width: 4),
                Text(brain.data.emergency.blood.isEmpty ? tr('রক্তের গ্রুপ দিন') : trf('রক্তের গ্রুপ {0}', [brain.data.emergency.blood]),
                    style: body(14, color: brain.data.emergency.blood.isEmpty ? C.green : C.muted, weight: brain.data.emergency.blood.isEmpty ? FontWeight.w600 : FontWeight.w400)),
              ]),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => changePhoto(context),
              child: Text(brain.photo == null ? tr('ছবি যোগ করুন') : tr('ছবি বদলান'), style: body(13.5, weight: FontWeight.w600, color: C.green)),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// The user's blood group (kept on the emergency card; the assistant answers
/// "আমার ব্লাড গ্রুপ কী?" from it).
Future<void> pickBloodGroup(BuildContext context) async {
  final brain = BrainScope.read(context);
  final current = brain.data.emergency.blood;
  final picked = await showModalBottomSheet<String>(
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
