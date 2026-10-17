import 'trace.dart';

/// One listening turn's words, put together from several recogniser
/// sessions. Android ends a session at any short pause; the app opens a new
/// one and the words are joined here:
///
/// * words already final ([committed]) are never replaced or cleared by a
///   later session, a restart or a partial result;
/// * a partial result only changes the current piece ([current]);
/// * a final result is committed once — the same final sent again by the
///   same session is ignored, while the same words said again in a later
///   session are kept (the user really said them twice);
/// * results from an older session (a late callback) are ignored, except the
///   final text of a session that ended early, which replaces the partial
///   text kept for it (corrected, never doubled).
class SpeechJoin {
  String committed = '';
  String current = '';

  int _session = 0;
  int get session => _session;

  /// The partial text kept when a session ended before its final result,
  /// and which session it came from.
  String _kept = '';
  int _keptSession = -1;

  /// The last final text of each session (to drop a repeated final).
  final Map<int, String> _finals = {};

  /// What was committed before each session's first final: some phones send
  /// several finals in one session, each holding all the words so far
  /// ("তুমি", "তুমি ২০২৭", "তুমি ২০২৭ সালের"); the later one replaces the
  /// earlier instead of being added after it.
  final Map<int, String> _before = {};

  String get text => '$committed $current'.trim();

  void reset() {
    committed = '';
    current = '';
    _kept = '';
    _keptSession = -1;
    _finals.clear();
    _before.clear();
  }

  /// A new recogniser session in the same turn; returns its id.
  int newSession() {
    _session++;
    Trace.log('voice', 'session', {'session': _session, 'kept': text});
    return _session;
  }

  /// A result from session [sid]. [clean] removes the app's own voice.
  /// True when the words on screen changed.
  bool result(int sid, String words, {required bool isFinal, required String Function(String) clean}) {
    Trace.log('voice', isFinal ? 'final' : 'partial', {'session': sid, 'words': words, 'committed': committed, 'current': current});
    // The final text of a session that ended early: it takes the place of
    // the partial text kept for it.
    if (isFinal && sid == _keptSession && _kept.isNotEmpty && committed.trimRight().endsWith(_kept)) {
      final base = committed.trimRight();
      committed = '${base.substring(0, base.length - _kept.length)} $words'.trim();
      _finals[sid] = words;
      _kept = '';
      _keptSession = -1;
      return true;
    }
    if (sid != _session) {
      Trace.log('voice', 'stale result ignored', {'session': sid, 'current session': _session});
      return false;
    }
    // Some phones send the same final twice.
    if (isFinal && current.isEmpty && _finals[sid] == words) {
      Trace.log('voice', 'repeated final ignored', {'session': sid});
      return false;
    }
    if (words.trim().isNotEmpty) {
      _kept = '';
      _keptSession = -1;
    }
    final changed = words != current;
    current = words;
    if (isFinal) {
      final prev = _finals[sid];
      final w = words.trim();
      if (prev != null && prev.trim().isNotEmpty && (w.startsWith(prev.trim()) || prev.trim().startsWith(w))) {
        // The same session's words again, grown (or the same): replace.
        Trace.log('voice', 'cumulative final replaces the last', {'session': sid});
        final longer = w.length >= prev.trim().length ? w : prev.trim();
        committed = clean('${_before[sid] ?? ''} $longer'.trim());
      } else {
        _before.putIfAbsent(sid, () => committed);
        if (prev != null) _before[sid] = committed; // a new sentence in the same session
        committed = clean(text);
      }
      current = '';
      _finals[sid] = words;
    }
    return changed;
  }

  /// The session ended (maybe before its final): keep what it heard.
  void sessionEnded(String Function(String) clean) {
    if (current.isEmpty) return;
    _kept = current.trim();
    _keptSession = _session;
    committed = clean(text);
    current = '';
    Trace.log('voice', 'session ended, kept', {'session': _session, 'committed': committed});
  }

  /// Asked to finish: whatever is current becomes final.
  void commitCurrent(String Function(String) clean) {
    if (current.isEmpty) return;
    committed = clean(text);
    current = '';
  }
}
