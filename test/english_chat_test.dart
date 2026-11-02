// Global version (owner, 2 Nov: "প্রতিটি শব্দ সে ভাষায় হবে"): in English,
// the app's replies to the 500 everyday sentences have no Bengali — only the
// member's own words, in quotes, stay as said.
import 'dart:convert';
import 'dart:io';

import 'package:digital_brain/logic/lang.dart';
import 'package:digital_brain/logic/region.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig;

void main() {
  tearDown(() {
    isEn = false;
    setRegion(country: 'BD', currency: 'BDT');
  });

  test('500 sentences: English replies, Bengali only inside quotes', () async {
    final bn = RegExp('[ঀ-৿]+');
    final leaks = <String>[];
    for (final l in File('tool/nlu/gold/intent500.jsonl').readAsLinesSync()) {
      final text = '${(jsonDecode(l) as Map)['text'] ?? ''}';
      if (text.isEmpty) continue;
      final rig = Rig();
      await rig.brain.load();
      await rig.brain.setEnglish(true);
      isEn = true;
      final reply = await ChatController(rig.brain).hear(text);
      final bare = reply.replaceAll(RegExp(r'“[^”]*”|‘[^’]*’'), '');
      if (bn.hasMatch(bare)) leaks.add('$text => $reply');
    }
    expect(leaks, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 8)));

  test("the country's English: US spelling and names; 'city' abroad; Bangladesh as written", () {
    isEn = true;
    setRegion(country: 'BD');
    expect(localEnglish('Your district/city · e.g. “Rahim”'), 'Your district/city · e.g. “Rahim”');
    setRegion(country: 'US');
    expect(localEnglish('Pick a colour · e.g. “Rahim” · Call Mum'), 'Pick a color · e.g. “Mike” · Call Mom');
    expect(localEnglish('Your district/city'), 'Your city');
    setRegion(country: 'GB');
    expect(localEnglish('Pick a colour · e.g. “Rahim”'), 'Pick a colour · e.g. “James”');
    setRegion(country: 'SA');
    expect(localEnglish('e.g. “Rahim”, “Karim”'), 'e.g. “Ahmed”, “Omar”');
    expect(tr('যা খুঁজবেন লিখুন — যেমন “রহিম”, “গাড়ির কাগজ”। নিচে সাথে সাথে মিলে যাওয়া জিনিস দেখাবে। কিছু রাখতে বা জিজ্ঞেস করতে লিখে পাঠান (➤) — যেমন “রহিমকে ৫০০ টাকা দিলাম”।'), contains('Ahmed'));
    expect(trf('{0}: no tasks.', ['এই মাসে']), 'This month: no tasks.', reason: 'an app word put in is English too');
  });
}
