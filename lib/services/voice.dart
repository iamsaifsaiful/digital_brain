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

class DeviceVoice extends Voice {
  final _stt = SpeechToText();
  final _tts = FlutterTts();
  bool _ready = false;
  String? _locale;
  String _last = '';
  bool _finished = false;
  void Function(String)? _onDone;
  void Function(String)? _onError;
  Timer? _guard;

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

  void _handleError(SpeechRecognitionError e) {
    final msg = switch (e.errorMsg) {
      'error_no_match' || 'error_speech_timeout' => 'কিছু শুনতে পাইনি। আবার বলুন।',
      'error_network' || 'error_network_timeout' || 'error_server' => 'ইন্টারনেট সংযোগ লাগবে। লিখেও যোগ করতে পারেন।',
      'error_audio' || 'error_insufficient_permissions' => 'মাইক্রোফোন ব্যবহারের অনুমতি দিন।',
      'error_language_not_supported' || 'error_language_unavailable' => 'ফোনে বাংলা ভয়েস চালু নেই। Google অ্যাপের ভয়েস সেটিং থেকে বাংলা যোগ করুন।',
      _ => 'শুনতে সমস্যা হয়েছে। আবার চেষ্টা করুন।',
    };
    if (_last.trim().isNotEmpty) {
      _finish();
    } else {
      _finished = true;
      _guard?.cancel();
      _onError?.call(msg);
    }
  }

  void _handleStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      // The final result normally arrives first; if not, wait only a moment.
      _guard?.cancel();
      _guard = Timer(const Duration(milliseconds: 250), _finish);
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _guard?.cancel();
    _onDone?.call(_last.trim());
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
    _last = '';
    _finished = false;
    _onDone = onDone;
    _onError = onError;
    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult r) {
          _last = r.recognizedWords;
          onWords(_last);
          if (r.finalResult) _finish();
        },
        listenOptions: SpeechListenOptions(
          localeId: _locale,
          listenFor: Duration(seconds: short ? 8 : 40),
          // Stop about 1.6 s after the user stops talking (was 4 s).
          pauseFor: Duration(milliseconds: short ? 1300 : 1600),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );
    } catch (e) {
      debugPrint('listen failed: $e');
      _finished = true;
      onError('শুনতে সমস্যা হয়েছে। আবার চেষ্টা করুন।');
    }
  }

  /// "বলা শেষ": act on what was heard right away; the recogniser is stopped
  /// in the background.
  @override
  Future<void> stop() async {
    _guard?.cancel();
    if (_last.trim().isNotEmpty) {
      _finish();
    } else {
      _guard = Timer(const Duration(milliseconds: 400), _finish);
    }
    try {
      await _stt.stop();
    } catch (_) {}
  }

  @override
  Future<void> cancel() async {
    _finished = true;
    _guard?.cancel();
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
