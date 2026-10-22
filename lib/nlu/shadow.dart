// Shadow mode (brief step F.10): the on-phone model reads every message next
// to the old rules but never acts. Only counts are kept — whether the two
// readings agree, and whether the model was sure — under the "nlu_*" names of
// the shadow counts (no words leave the phone).
import 'dart:io' show Platform;

import '../services/trace.dart';
import 'reader.dart';

/// On unless a build turns it off (--dart-define=NLU_SHADOW=false); off in tests.
final nluShadowOn = const bool.fromEnvironment('NLU_SHADOW', defaultValue: true) && !Platform.environment.containsKey('FLUTTER_TEST');

class NluShadow {
  NluShadow(this._load);

  final Future<NluReader?> Function() _load;

  /// Today's counts (kept in memory; sent with the server switch, step G).
  final Map<String, int> counts = {};
  void _count(String key) => counts[key] = (counts[key] ?? 0) + 1;
  Future<NluReader?>? _reader;
  final Map<int, Future<List<NluPiece>?>> _readings = {};

  /// A message arrived (turn, the words as heard, the app's state in spec names).
  void listen(int turn, String text, String state, String kind) {
    if (!nluShadowOn) return;
    // Turns the old rules settled before their usual reading (a pending
    // answer, a list change…) are counted apart.
    for (final k in _readings.keys.where((k) => k < turn).toList()) {
      _readings.remove(k);
      _count('nlu_early');
    }
    _reader ??= _load();
    _readings[turn] = _reader!.then((r) async {
      if (r == null) return null;
      try {
        return await r.read(text, state, kind);
      } catch (e) {
        Trace.log('nlu', 'shadow read failed', {'error': e.toString()});
        return null;
      }
    });
  }

  /// What the old rules understood for that turn (spec intent names).
  Future<void> oldReading(int turn, List<String> intents) async {
    final f = _readings.remove(turn);
    if (f == null) return;
    final pieces = await f;
    if (pieces == null) {
      _count('nlu_off');
      return;
    }
    final mine = {for (final p in pieces) p.intent};
    final sure = pieces.isNotEmpty && pieces.every((p) => p.sure);
    final same = mine.length == intents.toSet().length && mine.containsAll(intents);
    final key = same ? (sure ? 'nlu_same_sure' : 'nlu_same') : (sure ? 'nlu_differ_sure' : 'nlu_differ');
    _count(key);
    Trace.log('nlu', 'shadow', {'old': intents.join(','), 'model': [for (final p in pieces) '${p.intent}:${p.conf.toStringAsFixed(2)}'].join(','), 'result': key});
  }
}
