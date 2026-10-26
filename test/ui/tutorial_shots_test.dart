// "কীভাবে ব্যবহার করবেন" video (owner, 26 Oct): each feature walked the way a
// user would, with every step's screen and the spot pressed. SHOTS=1
// --update-goldens writes test/ui/shots/tutorial/<flow>-<n>.png and
// test/ui/shots/tutorial/<flow>.json (gitignored).
import 'dart:convert';
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:digital_brain/ui/widgets.dart' show PrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_brain/state/family_state.dart' show FamilyLink;

import 'package:digital_brain/app.dart';
import 'package:digital_brain/screens/lock_screen.dart' show googleFirst;
import 'package:digital_brain/state/brain.dart' show BrainHealth;

import '../app_test.dart' show Rig, loadFonts, settle, start;
import 'home_final_shots_test.dart' show icons, sample;

final shots = Platform.environment['SHOTS'] == '1';

class Flow {
  Flow(this.t, this.name);
  final WidgetTester t;
  final String name;
  final steps = <Map<String, Object?>>[];

  /// The screen as it is now; [tap] is pressed after (its place is kept).
  Future<void> step(Finder? tap, {String? type, Finder? field, bool press = true, double below = 0}) async {
    Rect? r;
    if (tap != null) {
      await t.ensureVisible(tap.first);
      await settle(t);
      r = t.getRect(tap.first);
      if (below > 0) r = Rect.fromLTWH(12, r.top - 6, 366, r.height + below);
    }
    final n = steps.length;
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/tutorial/$name-$n.png'));
    steps.add({'n': n, if (r != null) (press ? 'tap' : 'look'): [r.left, r.top, r.width, r.height], if (type != null) 'type': type});
    if (tap != null && press) {
      await t.tap(tap.first);
      await settle(t);
    }
    if (type != null) {
      await t.enterText((field ?? find.byType(TextField).last).first, type);
      await settle(t);
    }
    if (shots) File('test/ui/shots/tutorial/$name.json').writeAsStringSync(jsonEncode(steps));
  }

  void dump() => debugPrint('TEXTS $name: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().where((s) => s.trim().isNotEmpty).toList().reversed.take(45).toList().reversed.join(' | ')}');
}

Future<Rig> rig0(WidgetTester t, {bool data = true}) async {
  if (shots) {
    await icons();
    debugDisableShadows = false;
  }
  final rig = await start(t);
  rig.nowAt = DateTime(2026, 10, 24, 10, 15);
  await rig.brain.setLook(Look.light);
  await rig.brain.setUserName('সাইফুল ইসলাম');
  if (data) rig.brain.data = sample(rig.nowAt);
  await settle(t);
  return rig;
}

void main() {

  Finder field(String label) => find.byWidgetPredicate((w) => w is TextField && (w.decoration?.labelText == label || w.decoration?.hintText == label));
  Finder tool(String label) => find.descendant(of: find.byKey(const Key('home-tools')), matching: find.text(label));


  testWidgets('tutorial: start', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await loadFonts();
    if (shots) {
      await icons();
      debugDisableShadows = false;
    }
    googleFirst = true;
    final rig = Rig();
    await t.pumpWidget(DigitalBrainApp(brain: rig.brain));
    await rig.brain.load();
    await settle(t);
    final f = Flow(t, 'start');
    await f.step(find.byKey(const Key('welcome-google')), press: false);
    await f.step(find.byKey(const Key('welcome-later')));
    await f.step(find.text('১').last);
    for (final d in ['২', '৩', '৪']) {
      await t.tap(find.text(d).last);
      await t.pump(const Duration(milliseconds: 30));
    }
    await settle(t);
    await f.step(find.text('১').last);
    for (final d in ['২', '৩', '৪']) {
      await t.tap(find.text(d).last);
      await t.pump(const Duration(milliseconds: 30));
    }
    await settle(t);
    rig.nowAt = DateTime(2026, 10, 24, 10, 15);
    await rig.brain.setUserName('সাইফুল ইসলাম');
    await settle(t);
    await f.step(null);
    googleFirst = false;
    debugDisableShadows = true;
  });

  testWidgets('tutorial: home', (t) async {
    await rig0(t);
    final f = Flow(t, 'home');
    await f.step(find.text('সুপ্রভাত, সাইফুল'), press: false, below: 150);
    await f.step(find.text('আজকের কাজ'), press: false, below: 250);
    await f.step(find.text('টাকার হিসাব'), press: false, below: 230);
    await f.step(find.text('সামনের ছুটি'), press: false, below: 140);
    await f.step(find.byKey(const Key('home-tools')), press: false);
    await f.step(find.byTooltip('বলুন'), press: false);
    await f.step(find.text('সংরক্ষণ').last, press: false);
    debugDisableShadows = true;
  });

  testWidgets('tutorial: more', (t) async {
    await rig0(t);
    final f = Flow(t, 'more');
    await f.step(find.text('আরও').last);
    for (final x in ['রক্তের গ্রুপ', 'কী কী করা যায়', 'রিমাইন্ডার ঠিকমতো বাজবে তো?', 'বড় লেখা, হোমে ৪টা বড় বোতাম, উত্তর কণ্ঠে শোনাবে — বয়স্কদের জন্য সুবিধা', 'Google অ্যাকাউন্ট ও ব্যাকআপ', 'PIN বদলান', 'রিমাইন্ডারের রিংটোন']) {
      await f.step(find.text(x), press: false, below: 40);
    }
    debugDisableShadows = true;
  });

  testWidgets('tutorial: voice', (t) async {
    final rig = await rig0(t);
    final f = Flow(t, 'voice');
    await f.step(find.byTooltip('বলুন'));
    await f.step(null);
    rig.voice.say('কাল সকাল দশটায় ডাক্তারের কাছে যেতে হবে');
    await settle(t, 20);
    await f.step(null);
    debugDisableShadows = true;
  });

  testWidgets('tutorial: reminder', (t) async {
    await rig0(t);
    final f = Flow(t, 'reminder');
    await f.step(find.text('যোগ করুন'));
    final title = field('যেমন: ক্লায়েন্টকে কোটেশন পাঠানো');
    await f.step(title, type: 'ডাক্তারের কাছে যাওয়া', field: title);
    await f.step(find.byKey(const Key('add-remind')));
    await f.step(find.text('কাল').last);
    await f.step(find.text('সকাল ১১টা'));
    await f.step(find.text('রাখুন').last);
    await f.step(null);
    debugDisableShadows = true;
  });

  testWidgets('tutorial: cash', (t) async {
    await rig0(t);
    final f = Flow(t, 'cash');
    await f.step(find.text('হিসাব').last);
    await f.step(find.widgetWithText(PrimaryButton, 'খরচ'));
    final amount = find.byType(TextField).first;
    await f.step(amount, type: '৫০০', field: amount);
    await f.step(find.text('বাজার').first);
    await f.step(find.text('রাখুন').last);
    await f.step(null);
    debugDisableShadows = true;
  });

  testWidgets('tutorial: ledger', (t) async {
    await rig0(t);
    final f = Flow(t, 'ledger');
    await f.step(find.text('হিসাব').last);
    await f.step(find.text('ধার-দেনা').first);
    await f.step(find.text('নতুন লেনদেন'));
    await f.step(find.text('ধার দিলাম'));
    final who = field('কাকে');
    await f.step(who, type: 'রবিন', field: who);
    final amount = field('পরিমাণ (৳)');
    await f.step(amount, type: '৫০০০', field: amount);
    await f.step(find.text('সেভ করুন'));
    await f.step(null);
    f.dump();
    debugDisableShadows = true;
  });

  testWidgets('tutorial: docs', (t) async {
    await rig0(t);
    final f = Flow(t, 'docs');
    await f.step(tool('ডকুমেন্টস'));
    await f.step(find.text('ছবি তুলুন'), press: false);
    await f.step(find.text('জাতীয় পরিচয়পত্র'), press: false);
    debugDisableShadows = true;
  });

  testWidgets('tutorial: vault', (t) async {
    await rig0(t);
    final f = Flow(t, 'vault');
    await f.step(tool('পাসওয়ার্ড'));
    await f.step(find.text('পাসওয়ার্ড যোগ করুন'));
    await f.step(find.text('Facebook').first);
    final user = field('ইউজারনেম');
    await f.step(user, type: 'saiful.islam', field: user);
    final pass = field('পাসওয়ার্ড');
    await f.step(pass, type: 'Amar#Pass2026', field: pass);
    await f.step(find.text('সেভ করুন'));
    await f.step(null);
    debugDisableShadows = true;
  });

  testWidgets('tutorial: meds', (t) async {
    final rig = await rig0(t);
    await rig.brain.saveMember(FamilyMember(id: 'amma', name: 'আম্মা'));
    final f = Flow(t, 'meds');
    await f.step(tool('ওষুধ'));
    await f.step(find.text('ওষুধ যোগ'));
    final name = field('যেমন: নাপা, সেকলো');
    await f.step(name, type: 'অ্যামলোডিপিন', field: name);
    await f.step(find.byKey(const Key('med-who-amma')));
    await f.step(find.byKey(const Key('med-per-3')));
    await f.step(find.text('রাখুন').last);
    await f.step(null);
    debugDisableShadows = true;
  });

  testWidgets('tutorial: emergency', (t) async {
    await rig0(t);
    final f = Flow(t, 'emergency');
    await f.step(find.text('সংরক্ষণ').last);
    await f.step(find.text('জরুরি কার্ড'));
    await f.step(find.text('এখনই বানাই'));
    final name = field('নাম');
    await f.step(name, type: 'সাইফুল ইসলাম', field: name);
    await f.step(find.text('B+'));
    await f.step(find.text('রাখুন').last);
    await f.step(null);
    debugDisableShadows = true;
  });

  testWidgets('tutorial: zakat', (t) async {
    await rig0(t);
    final f = Flow(t, 'zakat');
    await f.step(tool('যাকাত'));
    await f.step(find.textContaining('যাকাতযোগ্য সম্পদ'), press: false);
    debugDisableShadows = true;
  });

  testWidgets('tutorial: backup', (t) async {
    await rig0(t);
    final f = Flow(t, 'backup');
    await f.step(find.text('ব্যাকআপ নিন — ফোন হারালেও সব ফিরে পাবেন'));
    await f.step(find.text('Google দিয়ে লগইন'), press: false);
    await f.step(find.text('ফাইল থেকে ফিরিয়ে আনুন'), press: false);
    debugDisableShadows = true;
  });

  testWidgets('tutorial: family', (t) async {
    final rig = await rig0(t);
    rig.brain.googleEmail = 'saiful@gmail.com';
    rig.brain.family.links = [
      FamilyLink.fromJson({'id': 9, 'status': 'active', 'name': 'আম্মা', 'email': 'amma@gmail.com', 'i_call': 'আম্মা', 'they_call': 'ছেলে', 'i_allow': ['task', 'reminder', 'medicine'], 'they_allow': ['task', 'reminder', 'medicine', 'location']}),
      FamilyLink.fromJson({'id': 10, 'status': 'active', 'name': 'রাফি', 'email': 'rafi@gmail.com', 'i_call': 'ছেলে', 'they_call': 'আব্বা', 'i_allow': ['task'], 'they_allow': ['task', 'reminder'], 'they_are_my_heir': true}),
    ];
    await settle(t);
    final f = Flow(t, 'family');
    await f.step(tool('ফ্যামিলি'));
    await f.step(find.text('আমার ফ্যামিলি'), press: false, below: 150);
    await f.step(find.byKey(const Key('family-add')));
    await f.step(find.byKey(const Key('family-email')), type: 'amma@gmail.com', field: find.byKey(const Key('family-email')));
    await f.step(find.byKey(const Key('family-relation')), type: 'আম্মা', field: find.byKey(const Key('family-relation')));
    await f.step(find.text('তিনি আমার জন্য যা করতে পারবেন'), press: false, below: 220);
    Navigator.of(t.element(find.byKey(const Key('family-email')))).pop();
    await settle(t);
    await f.step(find.byKey(const Key('family-9')));
    await f.step(find.byKey(const Key('family-do-task')), press: false, below: 200);
    await f.step(find.text('আমার উত্তরাধিকারী'), press: false, below: 50);
    debugDisableShadows = true;
  });
}
