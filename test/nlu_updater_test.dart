import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:digital_brain/nlu/updater.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('nlu'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<String> sha(List<int> b) async => (await Sha256().hash(b)).bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  test('a newer model: downloaded, checked, kept; the same again is not fetched; 204 = back to the built-in one', () async {
    final bytes = utf8.encode('pretend tflite');
    var gets = 0;
    final client = MockClient((r) async {
      gets++;
      return http.Response.bytes(bytes, 200);
    });
    final files = NluModelFiles(dir);
    final answer = {'version': 'm2', 'url': 'https://github.com/x/m2.tflite', 'sha256': await sha(bytes), 'thresholds': {'intents': ['task_add'], 'slot_tags': ['O'], 'temperature': 1.25}};
    expect(await updateNluModel(files, 200, answer, client: client), 'updated:m2');
    expect(files.present, isTrue);
    expect(files.model.readAsBytesSync(), bytes);
    expect(jsonDecode(files.config.readAsStringSync())['temperature'], 1.25);
    expect(await updateNluModel(files, 200, answer, client: client), 'same');
    expect(gets, 1);
    expect(await updateNluModel(files, 204, const {}, client: client), 'builtin');
    expect(files.present, isFalse);
  });

  test('a file that does not match its SHA-256 is never kept', () async {
    final client = MockClient((r) async => http.Response('something else', 200));
    final files = NluModelFiles(dir);
    final r = await updateNluModel(files, 200, {'version': 'm3', 'url': 'https://x/m3.tflite', 'sha256': 'a' * 64, 'thresholds': {'intents': []}}, client: client);
    expect(r, 'bad-hash');
    expect(files.present, isFalse);
  });

  test('only https, and a config must come with it', () async {
    final files = NluModelFiles(dir);
    expect(await updateNluModel(files, 200, {'version': 'm4', 'url': 'http://x/m.tflite', 'sha256': 'a' * 64, 'thresholds': {'intents': []}}), 'failed');
    expect(await updateNluModel(files, 200, {'version': 'm4', 'url': 'https://x/m.tflite', 'sha256': 'a' * 64, 'thresholds': {}}), 'failed');
  });

  test('mobile data: nothing downloaded until Wi-Fi; a model too big is refused', () async {
    final bytes = utf8.encode('pretend tflite');
    var gets = 0;
    final client = MockClient((r) async {
      gets++;
      return http.Response.bytes(bytes, 200);
    });
    final files = NluModelFiles(dir);
    final answer = {'version': 'm4', 'url': 'https://x/m4.tflite', 'sha256': await sha(bytes), 'size': bytes.length, 'thresholds': {'intents': ['task_add']}};
    expect(await updateNluModel(files, 200, answer, client: client, mayDownload: false), 'wait-wifi');
    expect(gets, 0);
    expect(files.present, isFalse);
    expect(await updateNluModel(files, 200, answer, client: client, mayDownload: true), 'updated:m4');
    expect(await updateNluModel(files, 200, {...answer, 'version': 'm5', 'size': nluMaxModelBytes + 1}, client: client), 'too-big');
    expect(files.current, 'm4');
  });
}
