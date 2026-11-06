import 'package:flutter/material.dart';

import '../logic/home_scene.dart';
import '../logic/lang.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// আরও › চেহারা ও ভাষা › হোমের ছবি (owner, 4 Nov): the member picks the
/// painting, or leaves it on অটো (the season by the Bangla calendar), and
/// turns the weather, the movements and the special days on or off.
class HomePictureScreen extends StatelessWidget {
  const HomePictureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final choice = brain.text('home_scene', defaultScene);
    final current = sceneFor(choice, now);

    Widget tile(String key) {
      final on = choice == key || (key == defaultScene && !sceneNames.containsKey(choice));
      final shown = key == 'auto' ? seasonOf(now) : key;
      return Semantics(
        selected: on,
        button: true,
        label: tr(sceneNames[key]!),
        child: InkWell(
          key: Key('scene-$key'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => brain.setPref('home_scene', key),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? C.green : C.border, width: on ? 2.5 : 1),
              color: C.surface,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Stack(fit: StackFit.expand, children: [
                  Image.asset(sceneAsset(shown, night: false), fit: BoxFit.cover, alignment: const Alignment(0, 0.7), cacheWidth: 360, excludeFromSemantics: true),
                  if (on) Positioned(right: 6, top: 6, child: Icon(Icons.check_circle_rounded, color: C.green, size: 22)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Text(tr(sceneNames[key]!), maxLines: 2, overflow: TextOverflow.ellipsis, style: body(12.5, weight: on ? FontWeight.w700 : FontWeight.w500, height: 1.3)),
              ),
            ]),
          ),
        ),
      );
    }

    Widget grid(List<String> keys) => GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.86,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [for (final k in keys) tile(k)],
        );

    Widget toggle(String key, IconData icon, String title, String sub) => Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(children: [
            Icon(icon, color: C.muted2, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: body(15)),
                Text(sub, style: body(12, color: C.muted)),
              ]),
            ),
            Switch(key: Key('scene-$key'), value: brain.text(key) != 'off', onChanged: (v) => brain.setPref(key, v ? 'on' : 'off')),
          ]),
        );

    Text head(String t) => Text(t, style: display(16, weight: 600));

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('হোমের ছবি')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
              Text(trf('এখন দেখাচ্ছে: {0}', [tr(sceneNames[current]!)]), style: body(13.5, color: C.muted)),
              const SizedBox(height: 12),
              grid(const ['auto', 'river']),
              const SizedBox(height: 18),
              head(tr('ঋতু')),
              const SizedBox(height: 8),
              grid(seasonKeys),
              const SizedBox(height: 18),
              head(tr('এলাকা')),
              const SizedBox(height: 8),
              grid(regionKeys),
              const SizedBox(height: 18),
              Panel(
                child: Column(children: [
                  toggle('scene_weather', Icons.umbrella_outlined, tr('আবহাওয়া ছবিতে'), tr('বৃষ্টি হলে ছবিতেও বৃষ্টি, কুয়াশা, ঝড়ে বিদ্যুৎ')),
                  Divider(height: 1, color: C.border),
                  toggle('scene_motion', Icons.waves_rounded, tr('ছবিতে নড়াচড়া'), tr('নৌকা চলবে, পানি ঝিকমিক, সন্ধ্যায় পাখি, রাতে জোনাকি')),
                  Divider(height: 1, color: C.border),
                  toggle('scene_special', Icons.celebration_outlined, tr('বিশেষ দিনের ছবি'), tr('পহেলা বৈশাখ, ২১ ফেব্রুয়ারি, ২৬ মার্চ, ১৬ ডিসেম্বর, ঈদ')),
                ]),
              ),
              const SizedBox(height: 10),
              Text(tr('রাতে চাঁদ আসল তিথি অনুযায়ী — নতুন চাঁদ থেকে পূর্ণিমা। ফোনে অ্যানিমেশন বন্ধ থাকলে ছবি স্থির থাকে।'), style: body(12.5, color: C.muted, height: 1.5)),
            ]),
          ),
        ]),
      ),
    );
  }
}
