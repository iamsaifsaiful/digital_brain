import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../logic/lang.dart';

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

  /// Name of the Bengali voice the user picked (null: choose the best).
  String? preferredVoice;

  /// Bengali voices installed on the phone, best first.
  Future<List<VoiceOption>> voices();

  /// Switches to [v] (null: back to the automatic choice).
  Future<void> useVoice(VoiceOption? v);
}

class VoiceOption {
  const VoiceOption({required this.name, required this.locale, required this.online});
  final String name;
  final String locale;

  /// Google's higher-quality voices that stream from the internet.
  final bool online;
}

/// How long the user must stay quiet before the app treats the sentence as
/// finished. Short answers (হ্যাঁ / না) need less.
/// The user may pause to think mid-sentence: only a longer quiet ends it.
const sentenceSilence = Duration(milliseconds: 3200);
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
  bool _retried = false;

  /// Which listening turn is current. A restart scheduled by an older turn
  /// (or by a session that was cancelled) must not start a second session.
  int _turn = 0;

  /// When the app last finished speaking: the microphone waits a moment so
  /// it does not hear the end of the app's own voice.
  DateTime _spokeAt = DateTime(2000);

  /// The recogniser listed a Bengali language (null: it could not say —
  /// Android 13+ lists only the offline languages).
  bool? banglaListed;
  String get localeInUse => _locale ?? '';
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
        // On Android 13+ the plugin asks only for the *offline* languages, and
        // on some phones that call never answers: never wait more than 3 s.
        var locales = <LocaleName>[];
        try {
          locales = await _stt.locales().timeout(const Duration(seconds: 3));
        } catch (_) {}
        banglaListed = locales.isEmpty ? null : locales.any((l) => l.localeId.toLowerCase().startsWith('bn'));
        String? pick(String id) {
          for (final l in locales) {
            if (l.localeId.toLowerCase().replaceAll('-', '_') == id) return l.localeId;
          }
          return null;
        }
        _locale = pick('bn_bd') ?? pick('bn_in') ?? pick('bn');
        _locale ??= locales.where((l) => l.localeId.toLowerCase().startsWith('bn')).map((l) => l.localeId).firstOrNull;
        // Not listed (common: the online recogniser supports Bengali but
        // only offline languages are listed): ask for Bangladesh Bengali.
        _locale ??= 'bn-BD';
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
      // 0.5 is Android's normal speed in flutter_tts (it doubles the value).
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      final list = await voices();
      VoiceOption? pick;
      for (final v in list) {
        if (v.name == preferredVoice) pick = v;
      }
      pick ??= list.firstOrNull;
      if (pick != null) await _apply(pick);
    } catch (e) {
      debugPrint('TTS setup failed: $e');
    }
  }

  @override
  Future<List<VoiceOption>> voices() async {
    try {
      final raw = await _tts.getVoices;
      final out = <VoiceOption>[];
      for (final v in (raw as List? ?? const [])) {
        if (v is! Map) continue;
        final name = '${v['name'] ?? ''}';
        final locale = '${v['locale'] ?? ''}';
        if (!locale.toLowerCase().startsWith('bn') && !name.toLowerCase().startsWith('bn')) continue;
        final online = name.contains('network') || '${v['network_required']}' == '1' || '${v['network_required']}' == 'true';
        out.add(VoiceOption(name: name, locale: locale, online: online));
      }
      // Bangladesh first, then the natural-sounding online voices.
      int rank(VoiceOption v) => (v.locale.toLowerCase().contains('bd') ? 0 : 2) + (v.online ? 0 : 1);
      out.sort((a, b) => rank(a).compareTo(rank(b)));
      return out;
    } catch (e) {
      debugPrint('voices failed: $e');
      return const [];
    }
  }

  Future<void> _apply(VoiceOption v) async {
    try {
      await _tts.setVoice({'name': v.name, 'locale': v.locale});
    } catch (e) {
      debugPrint('setVoice failed: $e');
    }
  }

  @override
  Future<void> useVoice(VoiceOption? v) async {
    preferredVoice = v?.name;
    if (v != null) {
      await _apply(v);
    } else {
      final list = await voices();
      if (list.isNotEmpty) await _apply(list.first);
    }
  }

  /// (Re)starts the quiet timer: the turn ends when it fires.
  void _armQuietTimer() {
    _quiet?.cancel();
    _quiet = Timer(_silence, _finish);
  }

  void _handleError(SpeechRecognitionError e) {
    if (_finished) return;
    final code = e.errorMsg;
    if (_words.isNotEmpty) {
      // A pause after some words (no_match / speech_timeout on a restarted
      // session, or a dropped connection): keep what was heard and let the
      // quiet timer end the turn.
      _quiet ??= Timer(_silence, _finish);
      return;
    }
    // Nothing said yet: silence is not a failure, the turn just ends empty
    // (the chat listens again).
    if (code == 'error_no_match' || code == 'error_speech_timeout') {
      _finish();
      return;
    }
    // A busy recogniser (often the previous session still closing) gets one
    // more try for this turn.
    if ((code == 'error_busy' || code == 'error_client') && !_retried) {
      _retried = true;
      final turn = _turn;
      Future<void>.delayed(const Duration(milliseconds: 600), () async {
        if (_finished || turn != _turn) return;
        try {
          await _stt.cancel();
        } catch (_) {}
        if (!_finished && turn == _turn) await _startSession(turn);
      });
      return;
    }
    _finished = true;
    _quiet?.cancel();
    _onError?.call(voiceErrorMessage(code));
  }

  /// A session ended. If the user said something and the quiet time has not
  /// passed yet, listen again so a continued sentence is not lost.
  void _handleStatus(String status) {
    if (_finished) return;
    if (status == 'done' || status == 'doneNoResult' || status == 'notListening') {
      if (_current.isNotEmpty) {
        _committed = _words;
        _current = '';
      }
      if (_words.isNotEmpty && !_restarting && DateTime.now().difference(_turnStarted).inSeconds < 60) {
        _restarting = true;
        final turn = _turn;
        Future<void>.delayed(const Duration(milliseconds: 120), () async {
          if (turn != _turn) return;
          _restarting = false;
          if (!_finished) await _startSession(turn);
        });
      } else if (_words.isEmpty && !_restarting) {
        // Some phones end a silent session without any error: end the turn
        // (empty) so the app never waits forever.
        _quiet?.cancel();
        _quiet = Timer(const Duration(milliseconds: 1500), _finish);
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

  Future<void> _startSession(int turn) async {
    if (turn != _turn || _finished) return;
    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult r) {
          // Words from an older turn (a late callback) are never mixed in.
          if (_finished || turn != _turn) return;
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
      if (turn != _turn) return;
      if (_words.isNotEmpty) {
        _quiet ??= Timer(_silence, _finish);
      } else if (!_finished) {
        _finished = true;
        _onError?.call(voiceErrorMessage('$e'.contains('permission') ? 'error_permission' : 'error_unknown'));
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
    final turn = ++_turn;
    if (!await init()) {
      var permitted = true;
      try {
        permitted = await _stt.hasPermission;
      } catch (_) {}
      onError(voiceErrorMessage(permitted ? 'unavailable' : 'error_permission'));
      return;
    }
    await stopSpeaking();
    // Let the app's own voice fade before the microphone opens.
    final sinceSpoke = DateTime.now().difference(_spokeAt);
    if (sinceSpoke < const Duration(milliseconds: 350)) await Future<void>.delayed(const Duration(milliseconds: 350) - sinceSpoke);
    if (turn != _turn) return; // a newer listen() or cancel() came meanwhile
    _quiet?.cancel();
    _quiet = null;
    // A session left over from before (the recogniser was not released)
    // would make the new one fail silently.
    if (_stt.isListening) {
      try {
        await _stt.cancel();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    _retried = false;
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
    await _startSession(turn);
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
    _turn++;
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
      await _useTtsLanguage(_mostlyLatin(text));
      // Some speech engines never report "done": do not wait forever, or
      // the conversation would stop listening.
      final limit = Duration(milliseconds: (4000 + text.length * 110).clamp(4000, 90000));
      await _tts.speak(forSpeech(text)).timeout(limit, onTimeout: () => null);
    } catch (e) {
      debugPrint('speak failed: $e');
    } finally {
      _spokeAt = DateTime.now();
    }
  }

  bool _ttsEnglish = false;

  /// English replies (English mode) are read with an English voice; Bangla with the Bangla one.
  Future<void> _useTtsLanguage(bool english) async {
    if (english == _ttsEnglish) return;
    _ttsEnglish = english;
    if (english) {
      for (final l in ['en-IN', 'en-US', 'en-GB']) {
        final ok = await _tts.isLanguageAvailable(l);
        if (ok == true || ok == 1) {
          await _tts.setLanguage(l);
          return;
        }
      }
    } else {
      await _setupTts();
    }
  }

  @override
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// More Latin letters than Bengali ones: an English reply.
bool _mostlyLatin(String text) {
  var latin = 0, bangla = 0;
  for (final r in text.runes) {
    if ((r >= 65 && r <= 90) || (r >= 97 && r <= 122)) {
      latin++;
    } else if (r >= 0x0980 && r <= 0x09FF) {
      bangla++;
    }
  }
  return latin > bangla * 2 && latin > 3;
}

/// A short Bengali message for a recogniser error code (the codes the
/// speech_to_text plugin sends on Android).
String voiceErrorMessage(String code) => switch (code) {
      'error_no_match' || 'error_speech_timeout' => tr('কিছু শুনতে পাইনি। আবার বলুন — মাইকের কাছে, একটু জোরে।'),
      'error_network' || 'error_network_timeout' || 'error_server' || 'error_server_disconnected' =>
        tr('বাংলা শুনে বুঝতে ইন্টারনেট লাগে, সংযোগ পাওয়া যাচ্ছে না। নিচে লিখেও দিতে পারেন।'),
      'error_too_many_requests' => tr('এই মুহূর্তে ফোনের ভয়েস সেবা ব্যস্ত। একটু পরে আবার চেষ্টা করুন।'),
      'error_permission' =>
        tr('মাইক্রোফোনের অনুমতি দেওয়া নেই। ফোনের Settings → Apps → My Assistant → Permissions থেকে Microphone চালু করুন।'),
      'error_audio_error' => tr('মাইক্রোফোন চালু করা গেল না — অন্য কোনো অ্যাপ (কল, রেকর্ডার) মাইক ব্যবহার করছে কি না দেখুন।'),
      'error_busy' || 'error_client' => tr('ফোনের ভয়েস সেবা আগের কাজ শেষ করছে। মাইক আবার চাপুন।'),
      'error_language_not_supported' || 'error_language_unavailable' =>
        tr('এই ফোনের ভয়েস সেবায় বাংলা চালু নেই। Google অ্যাপ → Settings → Voice → Languages থেকে “বাংলা (বাংলাদেশ)” যোগ করুন।'),
      'unavailable' => tr('এই ফোনে কথা শুনে লেখার সেবা (Google ভয়েস) পাওয়া যায়নি। Google অ্যাপ চালু/হালনাগাদ করুন, অথবা লিখে দিন।'),
      _ => tr('শুনতে সমস্যা হয়েছে। আবার চেষ্টা করুন, অথবা লিখে দিন।'),
    };

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
  Future<List<VoiceOption>> voices() async => const [];

  @override
  Future<void> useVoice(VoiceOption? v) async {
    preferredVoice = v?.name;
  }

  @override
  Future<void> stopSpeaking() async {}
}

/// Future "I will" verbs written without ও-কার ("দেব", "করব") are read by
/// the speech engine as other words ("দেব" = god). Spoken with ও-কার they
/// sound right: দেবো, করবো. List bullets are not read out.
const _futureVerbs = [
  'দেব', 'নেব', 'করব', 'রাখব', 'পাব', 'বলব', 'যাব', 'আনব', 'খুলব', 'শুনব', 'দেখব', 'পাঠাব', 'লিখব', 'জানাব', 'করাব',
  'বাজাব', 'খাব', 'থাকব', 'ধরব', 'ফেলব', 'চাইব', 'তুলব', 'বসাব', 'মেলাব', 'খুঁজব', 'বোঝাব', 'চালাব', 'ঘুমাব', 'উঠব', 'ফিরব', 'দিব', 'নিব',
];
final _futureRe = RegExp('(?<=^|[\\s,।!?;:“”"(])(${_futureVerbs.join('|')})(?=\$|[\\s,।!?;:“”")—-])');

String forSpeech(String text) =>
    text.replaceAll('•', '').replaceAllMapped(_futureRe, (m) => '${m[1]}ো');
