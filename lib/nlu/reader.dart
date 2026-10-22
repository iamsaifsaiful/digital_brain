// Reads a message with the on-phone model, the same way the training code
// does (tool/nlu/train/common.py read()): rule split of lines and numbered
// items, the model's boundary tags split a line, each piece gets an intent
// and its fact spans. Only reading — nothing here acts.
import 'dart:math' as math;

import 'normalize.dart';
import 'wordpiece.dart';

/// What the model gives for one input.
class NluOutput {
  const NluOutput(this.intentLogits, this.slotLogits, this.boundLogits);
  final List<double> intentLogits;
  final List<List<double>> slotLogits; // per piece position
  final List<List<double>> boundLogits;
}

/// Runs the model on encoded input (ids, mask, types of length maxT).
abstract class NluRunner {
  Future<NluOutput> run(List<int> ids, List<int> mask, List<int> types);
}

class NluPiece {
  const NluPiece(this.intent, this.conf, this.sure, this.words, this.slots);
  final String intent;
  final double conf;

  /// Conf at or above this intent's threshold (set on dev data).
  final bool sure;
  final List<String> words;

  /// slot name → the words marked (the value comes from lib/nlu/values.dart).
  final Map<String, String> slots;
}

class NluConfig {
  NluConfig.fromJson(Map<String, dynamic> j)
      : intents = (j['intents'] as List).cast<String>(),
        slotTags = (j['slot_tags'] as List).cast<String>(),
        temperature = (j['temperature'] as num).toDouble(),
        thresholds = {for (final e in (j['thresholds'] as Map<String, dynamic>).entries) e.key: (e.value as num).toDouble()},
        maxT = j['maxt'] as int,
        stateWords = (j['state_words'] as Map<String, dynamic>).cast<String, String>(),
        kindWords = (j['kind_words'] as Map<String, dynamic>).cast<String, String>();

  final List<String> intents;
  final List<String> slotTags;
  final double temperature;
  final Map<String, double> thresholds;
  final int maxT;
  final Map<String, String> stateWords;
  final Map<String, String> kindWords;
}

class NluReader {
  NluReader(this.config, this.wp, this.runner);

  final NluConfig config;
  final WordPiece wp;
  final NluRunner runner;

  /// ids, mask, types and each word's first piece position (-1 if cut).
  (List<int>, List<int>, List<int>, List<int>) encode(String state, String kind, List<String> words) {
    final maxT = config.maxT;
    final ctx = '${config.stateWords[state] ?? config.stateWords['idle']} ${config.kindWords[kind] ?? config.kindWords['none']}';
    final ids = [wp.idOf('[CLS]'), ...wp.ids(ctx), wp.idOf('[SEP]')];
    final types = List<int>.filled(ids.length, 0, growable: true);
    final first = <int>[];
    for (final w in words) {
      var p = wp.ids(w);
      if (p.isEmpty) p = [wp.idOf('[UNK]')];
      if (ids.length + p.length >= maxT) {
        first.add(-1);
        continue;
      }
      first.add(ids.length);
      ids.addAll(p);
      types.addAll(List.filled(p.length, 1));
    }
    ids.add(wp.idOf('[SEP]'));
    types.add(1);
    final mask = List<int>.filled(ids.length, 1, growable: true);
    while (ids.length < maxT) {
      ids.add(0);
      types.add(0);
      mask.add(0);
    }
    return (ids, mask, types, first);
  }

  static int _argmax(List<double> v) {
    var k = 0;
    for (var i = 1; i < v.length; i++) {
      if (v[i] > v[k]) k = i;
    }
    return k;
  }

  Future<(List<String>, List<String>)> _tag(String state, String kind, List<String> words) async {
    final (ids, mask, types, first) = encode(state, kind, words);
    final out = await runner.run(ids, mask, types);
    final tags = <String>[];
    final bound = <String>[];
    for (final pos in first) {
      tags.add(pos < 0 ? 'O' : config.slotTags[_argmax(out.slotLogits[pos])]);
      bound.add(pos < 0 ? 'I' : const ['O', 'B', 'I'][_argmax(out.boundLogits[pos])]);
    }
    for (var i = 0; i < tags.length; i++) {
      final t = tags[i];
      if (t.startsWith('I-') && (i == 0 || tags[i - 1] == 'O' || tags[i - 1].substring(2) != t.substring(2))) tags[i] = 'B-${t.substring(2)}';
    }
    return (tags, bound);
  }

  Future<(String, double)> _intent(String state, String kind, List<String> words) async {
    final (ids, mask, types, _) = encode(state, kind, words);
    final z = (await runner.run(ids, mask, types)).intentLogits.map((x) => x / config.temperature).toList();
    final m = z.reduce(math.max);
    final e = z.map((x) => math.exp(x - m)).toList();
    final s = e.reduce((a, b) => a + b);
    final k = _argmax(e);
    return (config.intents[k], e[k] / s);
  }

  static Map<String, String> spans(List<String> words, List<String> tags) {
    final slots = <String, String>{};
    String? cur;
    var buf = <String>[];
    void close() {
      if (cur != null) slots.putIfAbsent(cur!, () => buf.join(' '));
      cur = null;
      buf = [];
    }

    for (var i = 0; i < words.length; i++) {
      final t = tags[i];
      if (cur != null && !(t.startsWith('I-') && t.substring(2) == cur)) close();
      if (t.startsWith('B-')) {
        cur = t.substring(2);
        buf = [words[i]];
      } else if (t.startsWith('I-') && cur != null) {
        buf.add(words[i]);
      }
    }
    close();
    return slots;
  }

  /// state: a docs/nlu-spec.md state name; kind: none | tasks | reminders.
  Future<List<NluPiece>> read(String text, String state, String kind) async {
    var parts = nluSplitLines(text);
    if (parts.length > 1) {
      final (k, p) = parts.first;
      final t = p.trimRight();
      if (k == 'line' && (t.endsWith(':') || t.endsWith('-') || t.endsWith('ঃ'))) parts = [('head', p), ...parts.skip(1)];
    }
    final out = <NluPiece>[];
    for (final (k, p) in parts) {
      final ws = nluWords(p);
      if (ws.isEmpty || k == 'head') continue;
      final (tags, bound) = await _tag(state, kind, ws);
      final cuts = [0, for (var i = 2; i <= ws.length - 2; i++) if (bound[i] == 'B') i, ws.length];
      for (var c = 0; c + 1 < cuts.length; c++) {
        final w = ws.sublist(cuts[c], cuts[c + 1]);
        final (intent, conf) = await _intent(state, kind, w);
        out.add(NluPiece(intent, conf, conf >= (config.thresholds[intent] ?? 0.99), w, spans(w, tags.sublist(cuts[c], cuts[c + 1]))));
      }
    }
    return out;
  }
}
