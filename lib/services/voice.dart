import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Listening (speech to text) and speaking (text to speech), in Bengali.
abstract class Voice {
  /// Asks for the microphone the first time. False when speech is not
  /// available on this phone.
  Future<bool> init();

  /// Starts listening. [onWords] gets the words so far; [onDone] the final
  /// sentence (may be empty); [onError] a short Bengali message.
  Future<void> listen({
    required void Function(String words) onWords,
    required void Function(String words) onDone,
    required void Function(String message) onError,
    bool short = false,
  });

  /// Stops and keeps what was heard (onDone fires).
  Future<void> stop();

  /// Stops and throws away what was heard.
  Future<void> cancel();

  /// Starts speaking and returns at once.
  Future<void> speak(String text);

  /// Speaks and returns when the sentence is finished (used before
  /// listening for a spoken "হ্যাঁ" / "না").
  Future<void> speakAndWait(String text);
  Future<void> stopSpeaking();

  /// When true, [speak] stays silent (the "answer aloud" setting is off).
  bool muted = false;
}

/// How long the user must stay quiet before the app treats the sentence as
/// finished. Short answers (হ্যাঁ / না) need less.
const sentenceSilence = Duration(seconds: 2);
const answerSilence = Duration(milliseconds: 1200);

class DeviceVoice extends Voice {
  final _stt = SpeechToText();
  final _tts = FlutterTts();
  bool _ready = false;
  String? _locale;

  // One "turn" of listening can span several recogniser sessions: Android
  // ends a session at any short pause, so the app restarts it and joins the
  // words until the user has been quiet for [_silence].
  String _committed = '';
  String _current = '';
  bool _finished = true;
  bool _restarting = false;
  bool _short = false;
  Duration _silence = sentenceSilence;
  DateTime _turnStarted = DateTime.now();
  void Function(String)? _onWords;
  void Function(String)? _onDone;
  void Function(String)? _onError;
  Timer? _quiet;

  String get _words => '$_committed $_current'.trim();

  @override
  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(onError: _handleError, onStatus: _handleStatus);
      if (_ready) {
        final locales = await _stt.locales();
        String? pick(String id) {
          for (final l in locales) {
            if (l.localeId.toLowerCase().replaceAll('-', '_') == id) return l.localeId;
          }
          return null;
        }
        _locale = pick('bn_bd') ?? pick('bn_in') ?? pick('bn');
        _locale ??= locales.where((l) => l.localeId.toLowerCase().startsWith('bn')).map((l) => l.localeId).firstOrNull;
        _locale ??= 'bn_BD';
      }
      await _setupTts();
    } catch (e) {
      debugPrint('Speech unavailable: $e');
      _ready = false;
    }
    return _ready;
  }

  Future<void> _setupTts() async {
    try {
      for (final l in ['bn-BD', 'bn-IN', 'bn']) {
        final ok = await _tts.isLanguageAvailable(l);
        if (ok == true || ok == 1) {
          await _tts.setLanguage(l);
          break;
        }
      }
      await _tts.setSpeechRate(0.45);
      await _tts.awaitSpeakCompletion(true);
    } catch (e) {
      debugPrint('TTS setup failed: $e');
    }
  }

  /// (Re)starts the quiet timer: the turn ends when it fires.
  void _armQuietTimer() {
    _quiet?.cancel();
    _quiet = Timer(_silence, _finish);
  }

  void _handleError(SpeechRecognitionError e) {
    if (_finished) return;
    if (_words.isNotEmpty) {
      // A pause after some words (error_no_match / speech_timeout on a
      // restarted session): just let the quiet timer decide.
      _quiet ??= Timer(_silence, _finish);
      return;
    }
    final msg = switch (e.errorMsg) {
      'error_no_match' || 'error_speech_timeout' => 'কিছু শুনতে পাইনি। আবার বলুন।',
      'error_network' || 'error_network_timeout' || 'error_server' => 'ইন্টারনেট সংযোগ লাগবে। লিখেও যোগ করতে পারেন।',
      'error_audio' || 'error_insufficient_permissions' => 'মাইক্রোফোন ব্যবহারের অনুমতি দিন।',
      'error_language_not_supported' || 'error_language_unavailable' => 'ফোনে বাংলা ভয়েস চালু নেই। Google অ্যাপের ভয়েস সেটিং থেকে বাংলা যোগ করুন।',
      _ => 'শুনতে সমস্যা হয়েছে। আবার চেষ্টা করুন।',
    };
    _finished = true;
    _quiet?.cancel();
    _onError?.call(msg);
  }

  /// A session ended. If the user said something and the quiet time has not
  /// passed yet, listen again so a continued sentence is not lost.
  void _handleStatus(String status) {
    if (_finished) return;
    if (status == 'done' || status == 'notListening') {
      if (_current.isNotEmpty) {
        _committed = _words;
        _current = '';
      }
      if (_words.isNotEmpty && !_restarting && DateTime.now().difference(_turnStarted).inSeconds < 60) {
        _restarting = true;
        Future<void>.delayed(const Duration(milliseconds: 120), () async {
          _restarting = false;
          if (!_finished) await _startSession();
        });
      }
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _quiet?.cancel();
    _quiet = null;
    final words = _words;
    unawaited(_stt.cancel().then((_) {}, onError: (_) {}));
    _onDone?.call(words);
  }

  Future<void> _startSession() async {
    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult r) {
          if (_finished) return;
          final changed = r.recognizedWords != _current;
          _current = r.recognizedWords;
          if (changed && _words.isNotEmpty) {
            _onWords?.call(_words);
            _armQuietTimer(); // new words: wait the full quiet time again
          }
          if (r.finalResult) {
            _committed = _words;
            _current = '';
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: _locale,
          listenFor: Duration(seconds: _short ? 10 : 60),
          // Our own quiet timer ends the turn; this is only a safety net.
          pauseFor: Duration(seconds: _short ? 4 : 8),
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e) {
      debugPrint('listen failed: $e');
      if (_words.isNotEmpty) {
        _quiet ??= Timer(_silence, _finish);
      } else if (!_finished) {
        _finished = true;
        _onError?.call('শুনতে সমস্যা হয়েছে। আবার চেষ্টা করুন।');
      }
    }
  }

  @override
  Future<void> listen({
    required void Function(String words) onWords,
    required void Function(String words) onDone,
    required void Function(String message) onError,
    bool short = false,
  }) async {
    if (!await init()) {
      onError('এই ফোনে ভয়েস চালু করা যায়নি। লিখে যোগ করুন।');
      return;
    }
    await stopSpeaking();
    _quiet?.cancel();
    _quiet = null;
    _committed = '';
    _current = '';
    _finished = false;
    _restarting = false;
    _short = short;
    _silence = short ? answerSilence : sentenceSilence;
    _turnStarted = DateTime.now();
    _onWords = onWords;
    _onDone = onDone;
    _onError = onError;
    await _startSession();
  }

  /// "বলা শেষ": act on what was heard right away.
  @override
  Future<void> stop() async {
    if (_words.isNotEmpty) {
      _finish();
    } else {
      _quiet?.cancel();
      _quiet = Timer(const Duration(milliseconds: 600), _finish);
      try {
        await _stt.stop();
      } catch (_) {}
    }
  }

  @override
  Future<void> cancel() async {
    _finished = true;
    _quiet?.cancel();
    _quiet = null;
    try {
      await _stt.cancel();
    } catch (_) {}
  }

  @override
  Future<void> speak(String text) async {
    if (muted) return;
    unawaited(speakAndWait(text));
  }

  @override
  Future<void> speakAndWait(String text) async {
    if (muted) return;
    try {
      await init();
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('speak failed: $e');
    }
  }

  @override
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// For tests: say() feeds a sentence as if it was heard.
class FakeVoice extends Voice {
  final spoken = <String>[];
  void Function(String)? _onWords;
  void Function(String)? _onDone;
  bool available = true;

  @override
  Future<bool> init() async => available;

  @override
  Future<void> listen({
    required void Function(String words) onWords,
    required void Function(String words) onDone,
    required void Function(String message) onError,
    bool short = false,
  }) async {
    if (!available) {
      onError('ভয়েস নেই');
      return;
    }
    _onWords = onWords;
    _onDone = onDone;
  }

  void say(String words) {
    _onWords?.call(words);
    _onDone?.call(words);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> speak(String text) async {
    if (!muted) spoken.add(text);
  }

  @override
  Future<void> speakAndWait(String text) => speak(text);

  @override
  Future<void> stopSpeaking() async {}
}
