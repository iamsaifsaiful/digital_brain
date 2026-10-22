// Shadow mode (brief step F.10): the on-phone model reads every message next
// to the old rules but never acts. Only counts are kept — whether the two
// readings agree, and whether the model was sure — under the "nlu_*" names of
// the shadow counts (no words leave the phone).
import 'dart:io' show Platform;

import '../services/trace.dart';
import 'normalize.dart';
import 'reader.dart';

/// On unless a build turns it off (--dart-define=NLU_SHADOW=false); off in tests.
final nluShadowOn = const bool.fromEnvironment('NLU_SHADOW', defaultValue: true) && !Platform.environment.containsKey('FLUTTER_TEST');

class NluShadow {
  NluShadow(this._load, {void Function(String key)? count, bool Function()? enabled, this.force = false, this.onCompare})
      : _countOut = count,
        _enabled = enabled;

  /// After each comparison: (the words, the state, the model's pieces, the
  /// rules' intents, whether they agreed). Used for learning samples.
  final void Function(String text, String state, List<NluPiece> pieces, List<String> old, bool same)? onCompare;
  final Map<int, (String, String, String)> _said = {};

  /// Runs even under `flutter test` (for the shadow's own tests).
  final bool force;

  final Future<NluReader?> Function() _load;
  final void Function(String key)? _countOut;

  /// The server's switch (GET /nlu/config): off stops the shadow reading.
  final bool Function()? _enabled;

  /// This session's counts; each also goes to the daily answer-source counts
  /// (sent to the server once a day, numbers only).
  final Map<String, int> counts = {};
  void _count(String key) {
    counts[key] = (counts[key] ?? 0) + 1;
    _countOut?.call(key);
  }
  Future<NluReader?>? _reader;

  /// A new model was downloaded (or removed): the next message opens it.
  void reload() => _reader = null;
  final Map<int, Future<List<NluPiece>?>> _readings = {};

  /// A message arrived (turn, the words as heard, the app's state in spec names).
  void listen(int turn, String text, String state, String kind) {
    if (!(nluShadowOn || force) || !(_enabled?.call() ?? true)) return;
    // Turns the old rules settled before their usual reading (a pending
    // answer, a list change…) are counted apart.
    for (final k in _readings.keys.where((k) => k < turn).toList()) {
      _readings.remove(k);
      _said.remove(k);
      _count('nlu_early');
    }
    _said[turn] = (text, state, kind);
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

  /// The model's reading of that turn ("on" mode), with its state and list
  /// kind — only when [text] is the same words it read (a message joined with
  /// the one before, or changed, is not the reading the model made).
  (Future<List<NluPiece>?>, String, String)? readingFor(int turn, String text) {
    final f = _readings[turn], said = _said[turn];
    if (f == null || said == null || nluNormalize(said.$1) != nluNormalize(text)) return null;
    return (f, said.$2, said.$3);
  }

  /// What the old rules understood for that turn (spec intent names).
  Future<void> oldReading(int turn, List<String> intents) async {
    final f = _readings.remove(turn);
    final said = _said.remove(turn);
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
    if (said != null) onCompare?.call(said.$1, said.$2, pieces, intents, same);
    Trace.log('nlu', 'shadow', {'old': intents.join(','), 'model': [for (final p in pieces) '${p.intent}:${p.conf.toStringAsFixed(2)}'].join(','), 'result': key});
  }
}
