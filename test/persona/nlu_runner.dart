// The real on-phone model for the persona walks: the same .tflite, run by a
// small Python server (LiteRT) over a socket, called synchronously.
import 'dart:convert';
import 'dart:io';

import 'package:digital_brain/nlu/reader.dart';
import 'package:digital_brain/nlu/wordpiece.dart';

const _dir = '/tmp/claude-0/-home-claude/4fd9a382-e0f3-5053-ab35-3e2ac049be70/scratchpad/nlu';

class SocketRunner implements NluRunner {
  int calls = 0;
  @override
  Future<NluOutput> run(List<int> ids, List<int> mask, List<int> types) async {
    calls++;
    final f = File('$_dir/req_$pid.json')..writeAsStringSync(jsonEncode({'ids': ids, 'mask': mask, 'types': types}));
    final r = Process.runSync('python3', ['$_dir/client.py', '$_dir/nlu.sock', f.path]);
    final j = jsonDecode(r.stdout as String) as Map<String, dynamic>;
    List<double> v(Object? x) => [for (final e in x as List) (e as num).toDouble()];
    return NluOutput(v(j['intent']), [for (final r in j['slots'] as List) v(r)], [for (final r in j['bound'] as List) v(r)]);
  }
}

NluReader realReader() {
  final cfg = jsonDecode(File('tool/nlu/models/2026.10.22-bert2/config.json').readAsStringSync()) as Map<String, dynamic>;
  final vocab = const LineSplitter().convert(File('assets/nlu/vocab.txt').readAsStringSync());
  return NluReader(NluConfig.fromJson(cfg), WordPiece(vocab), SocketRunner());
}
