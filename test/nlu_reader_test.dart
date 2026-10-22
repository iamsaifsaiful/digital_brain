import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:digital_brain/nlu/reader.dart';
import 'package:digital_brain/nlu/wordpiece.dart';

/// Stands in for the model: intent and tags from simple word checks, so the
/// reading around the model (split, boundaries, spans, thresholds) is tested.
class FakeRunner implements NluRunner {
  FakeRunner(this.config, this.wp);
  final NluConfig config;
  final WordPiece wp;

  @override
  Future<NluOutput> run(List<int> ids, List<int> mask, List<int> types) async {
    final n = config.maxT;
    final bayar = wp.ids('বাজার').first;
    final ar = wp.ids('আর').first;
    final kal = wp.ids('কাল').first;
    final intent = List<double>.filled(config.intents.length, 0);
    intent[config.intents.indexOf(ids.contains(bayar) ? 'cash_add' : 'task_add')] = 10;
    List<double> one(int k, int m) => List.generate(m, (i) => i == k ? 5.0 : 0.0);
    final slots = <List<double>>[];
    final bound = <List<double>>[];
    var afterAr = false;
    for (var i = 0; i < n; i++) {
      final isWord = types[i] == 1 && mask[i] == 1 && ids[i] != wp.idOf('[SEP]');
      slots.add(one(isWord && ids[i] == kal ? config.slotTags.indexOf('B-date') : 0, config.slotTags.length));
      bound.add(one(isWord ? (afterAr ? 1 : 2) : 0, 3));
      afterAr = isWord && ids[i] == ar;
    }
    return NluOutput(intent, slots, bound);
  }
}

void main() {
  final cfgFile = File('tool/nlu/models/2026.10.22-bert2/config.json');
  test('reading around the model: lines, boundaries, spans, sure', () async {
    final config = NluConfig.fromJson(jsonDecode(cfgFile.readAsStringSync()) as Map<String, dynamic>);
    final wp = WordPiece(File('assets/nlu/vocab.txt').readAsLinesSync());
    final r = NluReader(config, wp, FakeRunner(config, wp));
    final pieces = await r.read('কাল ব্যাংকে যাব আর বাজার ৫০০ টাকা', 'idle', 'none');
    expect(pieces.map((p) => p.intent), ['task_add', 'cash_add']);
    expect(pieces.first.slots['date'], 'কাল');
    expect(pieces.first.sure, isTrue);
    final list = await r.read('আজকের কাজ:\n১. দুধ কেনা ২. কাল ব্যাংকে যাওয়া', 'idle', 'none');
    expect(list.length, 2); // the heading is not a request of its own
    final (ids, mask, types, first) = r.encode('confirm_delete', 'tasks', ['হ্যাঁ']);
    expect(ids.length, config.maxT);
    expect(types[first.single], 1);
    expect(mask.where((m) => m == 1).length, first.single + wp.ids('হ্যাঁ').length + 1);
  }, skip: cfgFile.existsSync() ? false : 'no model in assets/nlu');
}
