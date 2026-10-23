// Persona walkthroughs (not part of the suite): drives the app like a user,
// logs what was said and answered, and saves screenshots.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digital_brain/nlu/shadow.dart' show nluLoaderForTests;

import '../app_test.dart' show Rig, settle, start, tell;
import 'nlu_runner.dart';

/// MODEL=1: the walks read with the real on-phone model ("on" mode).
final withModel = Platform.environment['MODEL'] == '1';

class Walk {
  Walk(this.t, this.rig, this.id, this.who);
  final WidgetTester t;
  final Rig rig;
  final String id;
  final String who;
  final log = StringBuffer();
  int _n = 0;

  static Future<Walk> begin(WidgetTester t, String id, String who) async {
    if (withModel) nluLoaderForTests = () async => realReader();
    final rig = await start(t);
    if (withModel) rig.brain.nluMode = 'on';
    final w = Walk(t, rig, id, who);
    w.log.writeln('=== $id · $who${withModel ? ' (ফোনের মডেল চালু)' : ''}');
    return w;
  }

  Future<void> openMic() async {
    final mic = find.byTooltip('বলুন');
    if (mic.evaluate().isNotEmpty) {
      await t.tap(mic.first);
      await settle(t);
    }
  }

  int _phone() => rig.brain.answerSources.values.fold(0, (a, m) => a + (m['nlu_phone'] ?? 0));

  Future<void> say(String s) async {
    final n0 = rig.voice.spoken.length;
    final p0 = _phone();
    try {
      await tell(t, rig, s);
      await settle(t);
    } catch (e) {
      log.writeln('» $s\n  !! $e');
      return;
    }
    final said = rig.voice.spoken.skip(n0).join(' ⏎ ');
    final src = _phone() > p0 ? '   [ফোনের মডেলের উত্তর]' : '';
    log.writeln('» $s\n  ← ${said.isEmpty ? '(চুপ)' : said}$src');
  }

  Future<void> tap(Finder f, String what) async {
    if (f.evaluate().isEmpty) {
      log.writeln('# পাওয়া গেল না: $what');
      return;
    }
    try {
      await t.ensureVisible(f.first);
      await settle(t);
      await t.tap(f.first);
      await settle(t);
      log.writeln('# চাপ: $what');
    } catch (e) {
      log.writeln('# চাপা গেল না: $what ($e)');
    }
  }

  Future<void> back() async {
    final nav = find.byType(Navigator);
    if (nav.evaluate().isEmpty) return;
    await t.binding.handlePopRoute();
    await settle(t);
  }

  Future<void> shot(String name) async {
    _n++;
    await expectLater(find.byType(MaterialApp).first, matchesGoldenFile('out/$id-$_n-$name.png'));
    log.writeln('# ছবি: $id-$_n-$name.png');
  }

  void note(String s) => log.writeln('# $s');

  Future<void> done() async {
    final d = rig.brain.data;
    log.writeln('# শেষে: কাজ ${d.tasks.length}, রিমাইন্ডার ${d.reminders.length}, আয়-ব্যয় ${d.cash.length}, লেনদেন ${d.ledger.length}, নোট ${d.notes.length}, নম্বর ${d.contacts.length}');
    for (final r in d.reminders) {
      log.writeln('   ⏰ ${r.title} · ${r.date.toIso8601String().substring(0, 10)} ${r.hour}:${r.minute.toString().padLeft(2, '0')} · ${r.repeat.name}');
    }
    for (final c in d.cash) {
      log.writeln('   ৳ ${c.kind.name} ${c.amount} · ${c.category} · ${c.note}${c.projectId == null ? '' : ' · প্রজেক্ট'}');
    }
    for (final l in d.ledger) {
      log.writeln('   ↔ ${l.kind.name} ${l.amount} · ${l.person}');
    }
    for (final x in d.tasks) {
      log.writeln('   ☐ ${x.title} · ${x.list} · ${x.due?.toIso8601String().substring(0, 10) ?? ''}');
    }
    Directory('test/persona/out').createSync(recursive: true);
    File('test/persona/out/$id.txt').writeAsStringSync(log.toString());
  }
}
