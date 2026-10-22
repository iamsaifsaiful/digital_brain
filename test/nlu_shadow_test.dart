import 'package:flutter_test/flutter_test.dart';
import 'package:digital_brain/nlu/reader.dart';
import 'package:digital_brain/nlu/shadow.dart';
import 'package:digital_brain/nlu/wordpiece.dart';

class _Reader extends NluReader {
  _Reader(this.answer) : super(NluConfig.fromJson(_cfg), WordPiece(['[PAD]', '[UNK]']), _NoRun());
  final List<NluPiece> answer;
  @override
  Future<List<NluPiece>> read(String text, String state, String kind) async => answer;
}

class _NoRun implements NluRunner {
  @override
  Future<NluOutput> run(List<int> ids, List<int> mask, List<int> types) => throw UnimplementedError();
}

const _cfg = {'intents': <String>[], 'slot_tags': <String>[], 'temperature': 1, 'thresholds': <String, Object>{}, 'maxt': 8, 'state_words': <String, String>{}, 'kind_words': <String, String>{}};

void main() {
  // Shadow reading is off under `flutter test` by default; these tests drive it directly.
  test('counts agreement with the old reading; acts on nothing', () async {
    final out = <String>[];
    final s = NluShadow(() async => _Reader([const NluPiece('task_add', 0.95, true, ['কাল'], {})]), count: out.add, force: true);
    s.listen(1, 'কাল ব্যাংকে যাব', 'idle', 'none');
    await s.oldReading(1, ['task_add']);
    s.listen(2, 'কাল ব্যাংকে যাব', 'idle', 'none');
    await s.oldReading(2, ['reminder_add']);
    s.listen(3, 'হ্যাঁ', 'confirm_save', 'none');
    s.listen(4, 'আবার', 'idle', 'none'); // turn 3 was taken by an early handler
    expect(out, ['nlu_same_sure', 'nlu_differ_sure', 'nlu_early']);
  });

  test('the server switch off: nothing is read', () async {
    final out = <String>[];
    var read = 0;
    final s = NluShadow(() async {
      read++;
      return null;
    }, count: out.add, enabled: () => false, force: true);
    s.listen(1, 'কাল', 'idle', 'none');
    await s.oldReading(1, ['task_add']);
    expect(read, 0);
    expect(out, isEmpty);
  });
}
