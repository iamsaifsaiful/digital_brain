// A newer on-phone model from the server (brief step F.7): GET /nlu/model
// says which version this member gets (rollout share, SHA-256). The file is
// downloaded, checked against its SHA-256 and kept beside the app's data;
// the reader is opened again with it. 204 = no model for this member (the
// app carries none since 2.42.0 — the model was 14 MB of the APK). Downloaded
// only on Wi-Fi (an unmetered network), never on mobile data. A model that
// fails to load is deleted; the app keeps working with its rules.
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

/// The largest model a phone downloads (the first one is ~14 MB).
const nluMaxModelBytes = 40 * 1024 * 1024;

/// [answer]: the server's reply to GET /nlu/model (status and body). Returns
/// what happened, for the trace: 'same', `updated:VERSION`, 'builtin',
/// 'wait-wifi' (a download is due but [mayDownload] is false — on mobile
/// data), 'too-big', 'bad-hash', 'failed'.
Future<String> updateNluModel(NluModelFiles files, int status, Map<String, dynamic> answer, {http.Client? client, bool mayDownload = true}) async {
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
  final size = answer['size'] is num ? (answer['size'] as num).toInt() : 0;
  if (size > nluMaxModelBytes) return 'too-big';
  if (!mayDownload) return 'wait-wifi';
  try {
    final c = client ?? http.Client();
    final r = await c.get(Uri.parse(url)).timeout(const Duration(minutes: 3));
    if (r.statusCode != 200) return 'failed';
    if (r.bodyBytes.length > nluMaxModelBytes) return 'too-big';
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
