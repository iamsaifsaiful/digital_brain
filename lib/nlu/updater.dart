// A newer on-phone model from the server (brief step F.7): GET /nlu/model
// says which version this member gets (rollout share, SHA-256). The file is
// downloaded, checked against its SHA-256 and kept beside the app's data;
// the next start loads it. 204 = the built-in model again (a rollback). A
// downloaded model that fails to load is deleted and the built-in one used.
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

class NluModelFiles {
  NluModelFiles(this.dir);
  final Directory dir;

  File get model => File('${dir.path}/nlu/model.tflite');
  File get config => File('${dir.path}/nlu/config.json');
  File get version => File('${dir.path}/nlu/version.txt');

  bool get present => model.existsSync() && config.existsSync();

  String? get current => version.existsSync() ? version.readAsStringSync().trim() : null;

  void clear() {
    final d = Directory('${dir.path}/nlu');
    if (d.existsSync()) d.deleteSync(recursive: true);
  }
}

/// [answer]: the server's reply to GET /nlu/model (status and body). Returns
/// what happened, for the trace: 'same', `updated:VERSION`, 'builtin', 'bad-hash', 'failed'.
Future<String> updateNluModel(NluModelFiles files, int status, Map<String, dynamic> answer, {http.Client? client}) async {
  if (status == 204 || (status == 200 && answer['version'] == null)) {
    if (files.present) files.clear();
    return 'builtin';
  }
  if (status != 200) return 'failed';
  final ver = '${answer['version']}';
  if (files.current == ver && files.present) return 'same';
  final url = '${answer['url'] ?? ''}';
  final sha = '${answer['sha256'] ?? ''}'.toLowerCase();
  final cfg = answer['thresholds'];
  if (!url.startsWith('https://') || sha.length != 64 || cfg is! Map || cfg['intents'] == null) return 'failed';
  try {
    final c = client ?? http.Client();
    final r = await c.get(Uri.parse(url)).timeout(const Duration(minutes: 3));
    if (r.statusCode != 200) return 'failed';
    final got = (await Sha256().hash(r.bodyBytes)).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    if (got != sha) return 'bad-hash';
    final d = Directory('${files.dir.path}/nlu')..createSync(recursive: true);
    // Written aside first, then moved in, so a half-written file is never loaded.
    final tmp = File('${d.path}/model.tmp')..writeAsBytesSync(r.bodyBytes, flush: true);
    File('${d.path}/config.tmp').writeAsStringSync(jsonEncode(cfg), flush: true);
    tmp.renameSync(files.model.path);
    File('${d.path}/config.tmp').renameSync(files.config.path);
    files.version.writeAsStringSync(ver, flush: true);
    return 'updated:$ver';
  } catch (_) {
    return 'failed';
  }
}
