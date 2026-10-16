import 'dart:async';

import 'package:flutter/foundation.dart';

import 'speech_join.dart';
import 'trace.dart';
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

  /// Gets the recogniser ready in the background (only when the microphone
  /// is already allowed — never asks), so the first tap listens at once.
  Future<void> warmUp() async {}

  /// Starts listening. [onWords] gets the words so far; [onDone] the final
  /// sentence (may be empty); [onError] a short Bengali message.
  ///
  /// [say]: spoken while already listening (e.g. "আমি শুনছি", or the answer
  /// itself). If the user starts talking over it, the app stops speaking
  /// and hears everything; its own voice is not taken as the user's words.
  /// [onSaid] fires when the app stops speaking (finished or interrupted).
  Future<void> listen({
    required void Function(String words) onWords,
    required void Function(String words) onDone,
    required void Function(String message) onError,
    bool short = false,
    String? say,
    void Function()? onSaid,
    void Function()? onReady,
  });

  /// Speak over the microphone: the user may interrupt a long answer by
  /// talking. Off by default — the microphone opens after the app finishes
  /// speaking, so it can never hear itself.
  bool bargeIn = false;

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

  /// The last sentence heard, and the recogniser's other guesses for it
  /// (best first). When the first guess makes no sense, the app tries these.
  String lastHeard = '';
  List<String> lastAlternatives = const [];

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
const sentenceSilence = Duration(milliseconds: 2600);
const answerSilence = Duration(milliseconds: 1100);

/// A sentence that sounds finished needs only a short quiet.
const finishedSilence = Duration(milliseconds: 1300);

/// Last words of a finished sentence: a request, a statement, a question.
const _finishedEndings = [
  'দাও', 'দিও', 'দিয়ো', 'দেন', 'দিন', 'করো', 'করেন', 'করুন', 'রাখো', 'রাখেন', 'রাখুন', 'যাও', 'খোলো', 'দেখাও', 'বলো', 'বলেন', 'বলুন', 'শোনাও', 'থামো', 'পাঠাও',
  'আছে', 'আছেন', 'হবে', 'লাগবে', 'দিবে', 'দেবে', 'হলো', 'হল', 'হয়েছে', 'গেছে', 'নেই', 'ছি', 'ছে', 'লাম', 'লেন', 'বো', 'বেন',
  'কত', 'কী', 'কি', 'কবে', 'কখন', 'কোথায়', 'কেন', 'কেমন', 'ধন্যবাদ', 'চাই',
];

final _finishedEnds = [for (final e in _finishedEndings) echoToken(e)];

/// Words after which the speaker is surely going on.
final _open = {for (final w in const ['আর', 'এবং', 'কিন্তু', 'যে', 'তারপর', 'মানে', 'আবার', 'তো', 'বা', 'অথবা', 'and', 'but']) echoToken(w)};

class DeviceVoice extends Voice {
  final _stt = SpeechToText();
  final _tts = FlutterTts();
  bool _ready = false;
  Future<bool>? _initing;
  Future<void>? _ttsSetup;
  String? _locale;

  // One "turn" of listening can span several recogniser sessions: Android
  // ends a session at any short pause, so the app restarts it and joins the
  // words until the user has been quiet for [_silence].
  final _join = SpeechJoin();
  bool _finished = true;
  bool _restarting = false;
  bool _short = false;
  int _retries = 0;

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

  /// The recogniser really started listening (not only asked to).
  void Function()? _onReady;
  Timer? _quiet;

  /// What the app is saying while it listens (its words, to tell its own
  /// voice from the user's), and whether it is still speaking.
  List<String> _echo = const [];
  bool _talking = false;

  /// When the answer spoken while listening ended: the recogniser often
  /// reports the speaker's last words a moment later.
  DateTime _talkEndedAt = DateTime(2000);
  void Function()? _onSaid;

  String get _heard => _join.text;

  /// Other guesses for the whole sentence so far (see [Voice.lastAlternatives]).
  List<String> _alts = const [];

  /// The partial text kept when a session ended before its final result;
  /// that session's final text, arriving later, replaces it (never added twice).

  /// The words on screen are a partial guess; the recogniser has not given
  /// its final (more accurate) text for them yet.
  bool _partial = false;

  /// The quiet time is over and the recogniser was asked for its final
  /// text: the turn ends when it comes (or after a short wait).
  bool _finalizing = false;

  /// When the app itself last cancelled a recogniser session: an error that
  /// session reports late must not end the next turn.
  DateTime _cancelledAt = DateTime(2000);

  /// What the user said: the heard words without the app's own voice.
  String get _words => _clean(_heard);
  String _clean(String heard) => _echo.isEmpty ? heard : _withoutEcho(heard);

  String _withoutEcho(String heard) {
    final raw = heard.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final toks = [for (final w in raw) echoToken(w)];
    // The longest start of what was heard that is a piece of the app's own
    // sentence, word for word (the microphone hearing the speaker).
    var run = 0;
    for (var len = toks.length; len >= 1; len--) {
      if (_isPieceOfEcho(toks.sublist(0, len))) {
        run = len;
        break;
      }
    }
    final rest = toks.sublist(run);
    // The microphone hearing the speaker, a little garbled ("…টাকা পাবেন"
    // heard as "টাকা পাই"): a few words, each the app's own word or sharing
    // its start, heard while it spoke or just after — not the user.
    if ((_talking || DateTime.now().difference(_talkEndedAt) < const Duration(milliseconds: 2500)) && toks.length <= 4 && toks.every(_nearEcho)) return '';
    if (_talking) {
      // While it speaks, only clear talk from the user counts (two words
      // that are not the app's, or a stop word); the rest is its own voice.
      final echo = _echo.toSet();
      final fresh = rest.where((t) => !echo.contains(t)).length;
      final stop = rest.any(_stopTokens.contains);
      if (!stop && fresh < 2) return '';
    }
    if (run == toks.length) {
      // All of it is the app's sentence: echo if two words or more; a single
      // word ("হ্যাঁ", "কাল") after it finished speaking is the user's.
      return run >= 2 ? '' : heard;
    }
    return run >= 2 ? raw.sublist(run).join(' ') : heard;
  }

  bool _nearEcho(String t) {
    if (_echo.contains(t)) return true;
    final head = t.runes.take(2).toList();
    if (head.length < 2) return false;
    return _echo.any((e) => e.runes.length >= 3 && e.runes.take(2).toList().join(',') == head.join(','));
  }

  bool _isPieceOfEcho(List<String> piece) {
    if (piece.isEmpty || piece.length > _echo.length) return false;
    for (var i = 0; i + piece.length <= _echo.length; i++) {
      var ok = true;
      for (var j = 0; j < piece.length; j++) {
        if (_echo[i + j] != piece[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  }

  /// The app was talked over: stop speaking and listen.
  void _bargeIn() {
    if (!_talking) return;
    _talking = false;
    unawaited(stopSpeaking());
    _turnStarted = DateTime.now();
    _onSaid?.call();
  }

  @override
  Future<void> warmUp() async {
    if (_ready) return;
    try {
      if (await _stt.hasPermission) await init();
    } catch (_) {}
  }

  @override
  Future<bool> init() {
    if (_ready) return Future.value(true);
    // A warm-up and a tap at the same moment share one start.
    return _initing ??= _init().whenComplete(() => _initing = null);
  }

  Future<bool> _init() async {
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
      // The voice is set up alongside: listening must not wait for it.
      _ttsSetup ??= _setupTts();
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
    _quiet = Timer(_quietFor(_words), _settle);
  }

  /// The user went quiet. If the last words are only a partial guess, ask
  /// the recogniser to finish and use its final text (partial guesses are
  /// less accurate); never wait more than a moment for it.
  void _settle() {
    if (_finished) return;
    if (!_partial || _finalizing) return _finish();
    _finalizing = true;
    _quiet?.cancel();
    _quiet = Timer(const Duration(milliseconds: 900), _finish);
    unawaited(_stt.stop().then((_) {}, onError: (_) {}));
  }

  /// How long to wait after the last word: short when the sentence sounds
  /// finished ("…মনে করিয়ে দিও", "…কত?"), longer when it does not ("…আর",
  /// "রহিমকে ৫০০ টাকা") so a pause to think does not cut it.
  Duration _quietFor(String words) {
    if (_short) return answerSilence;
    final w = words.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (w.isEmpty) return _silence;
    final last = echoToken(w.last);
    if (_open.contains(last)) return sentenceSilence;
    if (w.length >= 3 && _finishedEnds.any(last.endsWith)) return finishedSilence;
    return _silence;
  }

  void _handleError(SpeechRecognitionError e) {
    if (_finished) return;
    final code = e.errorMsg;
    // The session the app itself just cancelled complaining late: not this turn's error.
    if ((code == 'error_client' || code == 'error_busy' || code == 'error_recognizer_busy') && DateTime.now().difference(_cancelledAt) < const Duration(milliseconds: 700)) return;
    if (_finalizing) return _finish();
    if (_words.isNotEmpty) {
      // A pause after some words (no_match / speech_timeout on a restarted
      // session, or a dropped connection): keep what was heard and let the
      // quiet timer end the turn.
      _quiet ??= Timer(_silence, _finish);
      return;
    }
    // Nothing heard yet. The recogniser often gives up within a second of
    // opening (the user had not started yet, or the first session after the
    // app opens) — that is why a sentence sometimes had to be said twice.
    // Keep listening quietly for the first seconds of the turn.
    if (code == 'error_no_match' || code == 'error_speech_timeout') {
      if (_inGrace) {
        _restart(const Duration(milliseconds: 150));
      } else {
        _finish();
      }
      return;
    }
    // A busy recogniser (often the previous session still closing) gets a
    // couple more tries for this turn.
    if ((code == 'error_busy' || code == 'error_client' || code == 'error_recognizer_busy') && _retries < 3) {
      _retries++;
      _restart(Duration(milliseconds: 300 * _retries), cancelFirst: true);
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
    if (status == 'listening') {
      final r = _onReady;
      _onReady = null;
      r?.call();
    }
    // Asked to finish: the session ending is expected; keep what was heard.
    if (_finalizing) {
      if (status == 'done' || status == 'doneNoResult' || status == 'notListening') {
        _join.commitCurrent(_clean);
        _quiet?.cancel();
        _quiet = Timer(const Duration(milliseconds: 250), _finish);
      }
      return;
    }
    if (status == 'done' || status == 'doneNoResult' || status == 'notListening') {
      _join.sessionEnded(_clean);
      if (_words.isNotEmpty && !_restarting && DateTime.now().difference(_turnStarted).inSeconds < 60) {
        _restarting = true;
        final turn = _turn;
        Future<void>.delayed(const Duration(milliseconds: 120), () async {
          if (turn != _turn) return;
          _restarting = false;
          if (!_finished) await _startSession(turn);
        });
      } else if (_words.isEmpty && !_restarting) {
        if (_inGrace) {
          // Ended before the user spoke: open again (see [_inGrace]).
          _restart(const Duration(milliseconds: 150));
        } else {
          // Some phones end a silent session without any error: end the
          // turn (empty) so the app never waits forever.
          _quiet?.cancel();
          _quiet = Timer(const Duration(milliseconds: 1500), _finish);
        }
      }
    }
  }

  /// The first seconds of a turn, when an empty session is restarted
  /// instead of ending the turn.
  bool get _inGrace => _words.isEmpty && (_talking || DateTime.now().difference(_turnStarted) < (_short ? const Duration(seconds: 6) : const Duration(seconds: 9)));

  /// Opens a new session for the same turn after [delay] (once at a time).
  void _restart(Duration delay, {bool cancelFirst = false}) {
    if (_restarting) return;
    _restarting = true;
    final turn = _turn;
    Future<void>.delayed(delay, () async {
      if (turn != _turn) return;
      if (cancelFirst) {
        try {
          await _stt.cancel();
        } catch (_) {}
      }
      _restarting = false;
      if (!_finished && turn == _turn) await _startSession(turn);
    });
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _quiet?.cancel();
    _quiet = null;
    final words = _words;
    Trace.log('voice', 'turn done', {'turn': _turn, 'sessions': _join.session, 'words': words});
    _cancelledAt = DateTime.now();
    lastHeard = words;
    lastAlternatives = _echo.isEmpty ? [for (final a in _alts) if (a != words) a] : const [];
    unawaited(_stt.cancel().then((_) {}, onError: (_) {}));
    _onDone?.call(words);
  }

  Future<void> _startSession(int turn) async {
    if (turn != _turn || _finished) return;
    final sid = _join.newSession();
    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult r) {
          // Words from an older turn (a late callback) are never mixed in.
          if (_finished || turn != _turn) return;
          final changed = _join.result(sid, r.recognizedWords, isFinal: r.finalResult, clean: _clean);
          // The recogniser's other guesses for this part of the sentence.
          final alts = [for (final a in r.alternates.skip(1)) if (a.recognizedWords.trim().isNotEmpty && a.recognizedWords != r.recognizedWords) a.recognizedWords];
          if (alts.isNotEmpty || r.finalResult) _alts = [for (final a in alts.take(4)) '${_join.committed} $a'.trim()];
          if (changed && _words.isNotEmpty) {
            _bargeIn();
            _onWords?.call(_words);
            _armQuietTimer(); // new words: wait the full quiet time again
          }
          _partial = !r.finalResult;
          if (r.finalResult) {
            // The final text the turn was waiting for.
            if (_finalizing) _finish();
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
    String? say,
    void Function()? onSaid,
    void Function()? onReady,
  }) async {
    final turn = ++_turn;
    Trace.log('voice', 'listen', {'turn': turn, 'short': short});
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
    // A short prompt ("আমি শুনছি") is said first and the microphone opens
    // right after, so the app never hears its own voice. Only a longer
    // answer is spoken while listening (the user may talk over it).
    if (say != null && say.trim().isNotEmpty && !muted && (!bargeIn || say.trim().split(RegExp(r'\s+')).length <= 4)) {
      await speakAndWait(say);
      // Let the last sound fade before the microphone opens.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (turn != _turn) return;
      onSaid?.call();
      say = null;
      onSaid = null;
      _spokeAt = DateTime.now();
    }
    _quiet?.cancel();
    _quiet = null;
    // A session left over from before (the recogniser was not released)
    // would make the new one fail silently.
    if (_stt.isListening) {
      _cancelledAt = DateTime.now();
      try {
        await _stt.cancel();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    _retries = 0;
    _join.reset();
    _alts = const [];
    _partial = false;
    _finalizing = false;
    _finished = false;
    _restarting = false;
    _short = short;
    _silence = short ? answerSilence : sentenceSilence;
    _turnStarted = DateTime.now();
    _onWords = onWords;
    _onDone = onDone;
    _onError = onError;
    _onReady = onReady;
    final talk = say;
    final speaking = talk != null && talk.trim().isNotEmpty && !muted;
    _echo = speaking ? [for (final w in forSpeech(talk).split(RegExp(r'\s+'))) if (w.isNotEmpty) echoToken(w)] : const [];
    _talking = speaking;
    _onSaid = onSaid;
    await _startSession(turn);
    // Started without an error: listening now (some phones never report the status).
    if (turn == _turn && !_finished) {
      final r = _onReady;
      _onReady = null;
      r?.call();
    }
    if (!speaking) {
      onSaid?.call();
      return;
    }
    unawaited(() async {
      try {
        await _tts.stop();
        await _useTtsLanguage(_mostlyLatin(talk));
        final limit = Duration(milliseconds: (4000 + talk.length * 110).clamp(4000, 90000));
        await _tts.speak(forSpeech(talk)).timeout(limit, onTimeout: () => null);
      } catch (e) {
        debugPrint('speak failed: $e');
      }
      if (turn != _turn || !_talking) return;
      // Finished speaking: from now on the user has the full quiet time.
      _talking = false;
      _talkEndedAt = DateTime.now();
      // Only the app's own voice was heard: forget it, so it is not joined to what the user says next.
      if (_words.isEmpty) _join.committed = '';
      _turnStarted = DateTime.now();
      _onSaid?.call();
    }());
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
    if (_talking) {
      _talking = false;
      unawaited(stopSpeaking());
    }
    _finished = true;
    _quiet?.cancel();
    _quiet = null;
    _cancelledAt = DateTime.now();
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
      await _ttsSetup;
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
    String? say,
    void Function()? onSaid,
    void Function()? onReady,
  }) async {
    if (say != null && say.trim().isNotEmpty && !muted) spoken.add(say);
    onSaid?.call();
    onReady?.call();
    if (!available) {
      onError('ভয়েস নেই');
      return;
    }
    _onWords = onWords;
    _onDone = onDone;
  }

  void say(String words, {List<String> alternatives = const []}) {
    lastHeard = words;
    lastAlternatives = alternatives;
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

/// A word compared loosely (digits, punctuation and spelling variants
/// aside), to tell the app's own voice from the user's.
String echoToken(String w) {
  const bnDigits = '০১২৩৪৫৬৭৮৯';
  var t = w.toLowerCase();
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(bnDigits[i], '$i');
  }
  return t
      .replaceAll('য়', 'য়')
      .replaceAll('ড়', 'ড়')
      .replaceAll(RegExp('[​-‍﻿]'), '')
      .replaceAll(RegExp(r'[।?!,.;:"“”‘’()\[\]—–\-]'), '');
}

/// Said over the app's voice, these stop it even alone.
final _stopTokens = {
  for (final w in const ['থামো', 'থাম', 'থামেন', 'চুপ', 'স্টপ', 'stop', 'বন্ধ', 'হ্যাঁ', 'হ্যা', 'না', 'জি', 'ঠিক', 'আচ্ছা', 'ok', 'okay']) echoToken(w),
};
