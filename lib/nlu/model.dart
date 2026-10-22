// Loads the on-phone model (downloaded from the server, lib/nlu/updater.dart;
// a development build may still carry one in assets/nlu/) and runs it off
// the UI thread.
// Any failure (no model, a phone the library does not support) leaves the
// model off; the app keeps working with its old reading.
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'reader.dart';
import 'updater.dart';
import 'wordpiece.dart';

class TfliteRunner implements NluRunner {
  TfliteRunner._(this._it, this._iso, this._order, this._maxT, this._outs);

  final Interpreter _it;
  final IsolateInterpreter _iso;
  final List<String> _order; // input names in the model's order
  final int _maxT;
  final List<List<int>> _outs; // output shapes

  /// A model downloaded from the server (lib/nlu/updater.dart) first; if it
  /// does not load, it is deleted. Then one in the assets, if a build has it.
  static Future<NluReader?> load() async {
    try {
      final files = NluModelFiles(await getApplicationSupportDirectory());
      if (files.present) {
        try {
          return await _open(jsonDecode(files.config.readAsStringSync()) as Map<String, dynamic>, Interpreter.fromFile(files.model, options: InterpreterOptions()..threads = 2));
        } catch (_) {
          files.clear();
        }
      }
    } catch (_) {}
    try {
      return await _open(jsonDecode(await rootBundle.loadString('assets/nlu/config.json')) as Map<String, dynamic>,
          await Interpreter.fromAsset('assets/nlu/model.tflite', options: InterpreterOptions()..threads = 2));
    } catch (_) {
      return null;
    }
  }

  static Future<NluReader> _open(Map<String, dynamic> configJson, Interpreter it) async {
    {
      final config = NluConfig.fromJson(configJson);
      final vocab = const LineSplitter().convert(await rootBundle.loadString('assets/nlu/vocab.txt'));
      final iso = await IsolateInterpreter.create(address: it.address);
      final order = [for (final t in it.getInputTensors()) t.name];
      final outs = [for (final t in it.getOutputTensors()) t.shape];
      return NluReader(config, WordPiece(vocab), TfliteRunner._(it, iso, order, config.maxT, outs));
    }
  }

  @override
  Future<NluOutput> run(List<int> ids, List<int> mask, List<int> types) async {
    final inputs = <Object>[
      for (final n in _order) [n.contains('type') ? types : n.contains('mask') ? mask : ids],
    ];
    final outputs = <int, Object>{};
    for (var i = 0; i < _outs.length; i++) {
      final s = _outs[i];
      outputs[i] = s.length == 2 ? [List<double>.filled(s[1], 0)] : [List.generate(s[1], (_) => List<double>.filled(s[2], 0))];
    }
    await _iso.runForMultipleInputs(inputs, outputs);
    List<double>? intent;
    List<List<double>>? slots, bound;
    for (var i = 0; i < _outs.length; i++) {
      final v = (outputs[i] as List).first;
      if (_outs[i].length == 2) {
        intent = (v as List).cast<double>();
      } else if (_outs[i][2] == 3) {
        bound = [for (final r in v as List) (r as List).cast<double>()];
      } else {
        slots = [for (final r in v as List) (r as List).cast<double>()];
      }
    }
    assert(_maxT == (slots?.length ?? _maxT));
    return NluOutput(intent!, slots!, bound!);
  }

  void close() {
    _iso.close();
    _it.close();
  }
}
