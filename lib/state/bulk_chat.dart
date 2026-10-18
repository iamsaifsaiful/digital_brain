// Lists the app has shown, kept as they were shown (the ids in order, what
// was asked, how many matched and how many were shown), and requests about
// several of their items at once: "এইগুলো সব মুছে দাও", "প্রথম দুটো কাল
// রাখো", "দ্বিতীয়টা ছাড়া সব শেষ". The targets are fixed from the list as
// shown before anything changes; a removal is asked once; the result says
// how many really changed. Three things are kept apart: the list just
// shown ([ResultSet]), the one item being talked about (focus), and the
// change waiting for a yes ([_BulkProposal]).
part of 'chat.dart';

/// A list as the user saw it.
class ResultSet {
  ResultSet({required this.domain, required this.label, required this.ids, required this.matching, required this.shown, required this.source, required this.at, required this.turn})
      : id = 'rs${at.microsecondsSinceEpoch}',
        used = at;
  final String id;

  /// 'tasks', 'reminders', 'notes', 'medicines', 'habits', 'health', 'money'.
  final String domain;

  /// What was asked, for saying back: "আজকের", "অফিসের".
  final String label;

  /// In the order shown.
  final List<String> ids;

  /// How many matched the question, and how many of them were on screen.
  final int matching;
  final int shown;

  /// The user's words that asked for it.
  final String source;
  final DateTime at;
  DateTime used;
  int turn;

  bool get complete => shown >= matching;
}

/// A change to several items waiting for its one yes.
class _BulkProposal {
  _BulkProposal(this.action, this.set, this.ids, this.opId);
  final BulkAction action;
  final ResultSet set;
  final List<String> ids;
  final String opId;
}

/// The last change to several items, for "ওগুলো ফেরত আনো".
class _BulkBatch {
  _BulkBatch(this.op, this.domain, this.ids, this.trashIds, this.at);
  final String op;
  final String domain;
  final List<String> ids;
  final List<String> trashIds;
  final DateTime at;
}

/// What each list can do with several items at once by voice.
const bulkOps = <String, Set<String>>{
  'tasks': {'delete', 'done', 'reopen', 'move', 'remind', 'reminder_off', 'urgent', 'show', 'reverse', 'restore'},
  'reminders': {'delete', 'reminder_off', 'show', 'reverse', 'restore'},
  'notes': {'delete', 'show', 'reverse', 'restore'},
  'medicines': {'reminder_off', 'show', 'reverse'},
  'habits': {'done', 'not_done', 'reminder_off', 'show', 'reverse'},
  'health': {'show', 'reverse', 'wrong', 'delete'},
  'money': {'report', 'show', 'reverse', 'delete'},
  // People's balances (ids are the people's account keys). "মুছে দাও" is
  // asked as a choice: settled (the history stays) or the records removed.
  'ledger': {'delete', 'settle', 'erase', 'show'},
};

/// "কাজ" → "কাজের", "রিমাইন্ডার" → "রিমাইন্ডারের", "নোট" → "নোটের",
/// "ওষুধ" → "ওষুধের"; a word ending in a vowel sign takes "র" ("মাপ" →).
String _possBn(String w) => RegExp(r'[\u09BE-\u09CC]$').hasMatch(w) ? '$wর' : '$wের';

const _domainBn = {'tasks': 'কাজ', 'reminders': 'রিমাইন্ডার', 'notes': 'নোট', 'medicines': 'ওষুধ', 'habits': 'অভ্যাস', 'health': 'মাপ', 'money': 'লেনদেন', 'ledger': 'হিসাব'};

extension _BulkChat on ChatController {
  /// A list was shown: kept as the one "এগুলো" means (several kept, newest last).
  void _rememberSet(String domain, String label, List<String> ids, {int? matching, int? shown, required String source}) {
    final s = ResultSet(domain: domain, label: label, ids: ids, matching: matching ?? ids.length, shown: shown ?? ids.length, source: source, at: _now, turn: _turn);
    _sets.removeWhere((x) => x.domain == domain);
    _sets.add(s);
    if (_sets.length > 6) _sets.removeAt(0);
  }

  /// Still meant by "এগুলো": shown or used within 30 minutes and the last
  /// 12 turns.
  bool _setFresh(ResultSet s) => _now.difference(s.used).inMinutes <= 30 && _turn - s.turn <= 12;

  /// The list [b] is about: the one of its kind if said, else the newest.
  /// Null when there is none (or none fresh).
  ResultSet? _setFor(BulkAction b) {
    final fresh = _sets.where(_setFresh).toList();
    if (b.domain.isNotEmpty) return fresh.where((s) => s.domain == b.domain).lastOrNull;
    // A bare "এগুলো": the list shown last — unless something else was said
    // or answered after it (then it is not known what "these" are).
    final last = fresh.lastOrNull;
    return last != null && last.turn >= _topicTurn ? last : null;
  }

  /// [sel] on [set] → ids, or the reason it cannot be told (said as is).
  (List<String>, String?) _resolve(Selection sel, ResultSet set, {List<String> lastPicked = const []}) {
    final items = set.ids;
    final n = items.length;
    String? bad(int i) => (i == -1 || (i >= 1 && i <= n)) ? null : trf('তালিকায় {0}টা আছে — {1} নম্বর নেই।', [bnDigits(n), bnDigits(i)]);
    int at(int i) => i == -1 ? n - 1 : i - 1;
    List<String> out;
    switch (sel.kind) {
      case SelKind.all || SelKind.global:
        out = [...items];
      case SelKind.indexes:
        for (final i in sel.indexes) {
          final e = bad(i);
          if (e != null) return (const [], e);
        }
        out = [for (final i in sel.indexes) items[at(i)]];
      case SelKind.first:
        if (sel.n > n) return (const [], trf('তালিকায় {0}টাই আছে — প্রথম {1}টা হয় না।', [bnDigits(n), bnDigits(sel.n)]));
        out = items.take(sel.n).toList();
      case SelKind.last:
        if (sel.n > n) return (const [], trf('তালিকায় {0}টাই আছে — শেষের {1}টা হয় না।', [bnDigits(n), bnDigits(sel.n)]));
        out = items.skip(n - sel.n).toList();
      case SelKind.range:
        final a = sel.from, b = sel.to;
        if (a > b) return (const [], trf('{0} থেকে {1} — উল্টো হয়ে গেল। আরেকবার বলুন।', [bnDigits(a), bnDigits(b)]));
        final e = bad(a) ?? bad(b);
        if (e != null) return (const [], e);
        out = items.sublist(a - 1, b);
      case SelKind.names:
        out = [];
        for (final terms in sel.names) {
          final hit = _namedIn(set, terms);
          if (hit.isEmpty) return (const [], trf('এই তালিকায় “{0}” নেই।', [terms.join(' ')]));
          if (hit.length > 1) return (const [], trf('“{0}” নামে {1}টা আছে — কোনটা, নম্বর দিয়ে বলুন।', [terms.join(' '), bnDigits(hit.length)]));
          out.add(hit.single);
        }
      case SelKind.filter:
        out = [for (final id in items) if (_passes(set.domain, id, sel.filter)) id];
      case SelKind.rest:
        if (lastPicked.isEmpty) return (const [], tr('কোনগুলো বাদে বাকিগুলো — আগে কোনটা বেছেছিলেন বুঝতে পারছি না। নম্বর দিয়ে বলুন।'));
        out = [for (final id in items) if (!lastPicked.contains(id)) id];
    }
    // "দ্বিতীয়টা ছাড়া", "ব্যাংকেরটা থাকবে".
    for (final i in sel.exceptIdx) {
      final e = bad(i);
      if (e != null) return (const [], e);
      out.remove(items[at(i)]);
    }
    for (final marked in sel.exceptNames) {
      final one = marked.isNotEmpty && marked.first == exceptOne;
      final terms = one ? marked.sublist(1) : marked;
      final hit = _namedIn(set, terms);
      if (hit.isEmpty) return (const [], trf('এই তালিকায় “{0}” নেই — কোনটা থাকবে, আরেকবার বলুন।', [terms.join(' ')]));
      // "ফোনেরটা থাকবে" with two by that name: which one, asked. "জন্মদিন
      // ছাড়া সব": every one by that name stays (keeping more is the safe side).
      if (one && hit.length > 1) return (const [], trf('“{0}” নামে {1}টা আছে — কোনটা থাকবে, নম্বর দিয়ে বলুন।', [terms.join(' '), bnDigits(hit.length)]));
      out.removeWhere(hit.contains);
    }
    return (out, null);
  }

  /// Items of [set] named by [terms] (by the words of their title).
  List<String> _namedIn(ResultSet set, List<String> terms) {
    final d = brain.data;
    switch (set.domain) {
      case 'tasks':
        // Every item the words fit (two "ফোন করা" are both found, then asked).
        final pool = [for (final id in set.ids) ..._maybe(id)];
        return [for (final t in pool) if (taskScore(t, terms) > 0) t.id];
      default:
        String title(String id) => switch (set.domain) {
              'reminders' => d.reminders.where((x) => x.id == id).firstOrNull?.title ?? '',
              'notes' => d.notes.where((x) => x.id == id).map((x) => '${x.title} ${x.body}').firstOrNull ?? '',
              'medicines' => d.medicines.where((x) => x.id == id).firstOrNull?.name ?? '',
              'habits' => d.habits.where((x) => x.id == id).firstOrNull?.name ?? '',
              _ => '',
            };
        bool hits(String title) {
          final ws = words(normalize(title));
          return terms.every((t) => ws.any((w) => wordsMatch(t, w)));
        }
        return [for (final id in set.ids) if (hits(title(id))) id];
    }
  }

  bool _passes(String domain, String id, String filter) {
    if (domain != 'tasks') return false;
    final t = _taskById(id);
    if (t == null) return false;
    return switch (filter) {
      'urgent' => t.urgent,
      'overdue' => t.lateAt(_now) || t.windowPassed(_now),
      'undated' => t.due == null,
      'open' => !t.done,
      'done' => t.done,
      _ => false,
    };
  }

  /// Handles "এগুলো সব …" when a list was shown (or the whole list was
  /// named). False when [t] is not about several items of a list.
  Future<bool> _bulk(String t, List<String> out) async {
    // "৩০ অক্টোবর এবং ৩১ ডিসেম্বরের রিমাইন্ডার বাদ দাও": those days' items,
    // as one group — asked once.
    final dated = datedBulk(tidySpeech(t), _now);
    if (dated != null) {
      final d = brain.data;
      bool on(DateTime x) => dated.days.contains(DateTime(x.year, x.month, x.day));
      final ids = dated.domain == 'reminders'
          ? [for (final r in d.reminders) if ((!dated.alarms || r.alarm) && on(r.nextDate(_now))) r.id]
          : [for (final x in d.tasks) if (!x.done && x.due != null && on(x.due!)) x.id];
      final label = trf('{0}-এর', [dated.days.map((x) => '${bnDigits(x.day)} ${monthName(x.month)}').join(tr(' ও '))]);
      if (ids.isEmpty) {
        _say(out, trf('{0} কোনো {1} নেই — কিছু বদলাইনি।', [label, _domainBn[dated.domain] ?? '']));
        return true;
      }
      _rememberSet(dated.domain, label, ids, source: t);
      await _bulkStart(BulkAction(t, selection: const Selection(SelKind.all), op: dated.op, domain: dated.domain), _sets.last, ids, out);
      _onList = true;
      return true;
    }
    var cmds = bulkCommands(tidySpeech(t), _now);
    if (cmds == null || cmds.isEmpty) {
      // One place in a list that is not the to-do list ("দ্বিতীয়টা ভুল"
      // after a health list): the same resolver. To-dos keep their own.
      final one = singleIndexCommand(tidySpeech(t), _now);
      final newest = _sets.where(_setFresh).lastOrNull;
      if (one == null || newest == null || newest.domain == 'tasks' || (one.domain.isNotEmpty && one.domain != newest.domain)) return false;
      cmds = [one];
    }
    return _bulkWith(cmds, t, out);
  }

  /// [cmds] (from the rules or the AI — the same shape) on the list meant.
  Future<bool> _bulkWith(List<BulkAction> cmds, String t, List<String> out) async {
    final first = cmds.first;
    // "সব দিনের সব কাজ মুছে দাও": the whole list of its kind, said so.
    if (first.selection.kind == SelKind.global) {
      final dom = first.domain.isEmpty ? 'tasks' : first.domain;
      if (dom != 'tasks') return false;
      final open = [for (final x in brain.data.tasks) if (!x.done) x.id];
      _rememberSet('tasks', tr('সব দিনের'), open, source: t);
    }
    // "আমার সব রিমাইন্ডার বাদ দিয়ে দাও" with no reminders on screen: the
    // sentence names the whole list of its kind — that list, asked once.
    if (first.selection.kind == SelKind.all && const {'reminders', 'notes', 'ledger', 'money'}.contains(first.domain) && first.op != 'show' &&
        !_sets.any((s) => s.domain == first.domain && _setFresh(s)) && _thas2(t, r'(?:(?:^|\s)সব|সকল|সমস্ত|যতগুলো|সবগুলো|সবকটা|গুলো|গুলা)')) {
      final owedToMe = !_thas2(t, r'(?:দেনা|ঋণ|ধার\s+নি)');
      // "আমার সকল আয় বাদ দাও": the আয়-ব্যয় records of that kind (people's
      // ধার-দেনা has its own words and its own question).
      final income = _thas2(t, r'(?:আয়|ইনকাম|income)'), expense = _thas2(t, r'(?:খরচ|ব্যয়|expense)');
      final cashKind = income == expense ? null : (income ? CashKind.income : CashKind.expense);
      final all = switch (first.domain) {
        'reminders' => [for (final r in brain.data.reminders) r.id],
        'notes' => [for (final n in brain.data.notes) n.id],
        'money' => [for (final e in brain.data.cash) if (cashKind == null || e.kind == cashKind) e.id],
        _ => [for (final p in balances(brain.data.ledger)) if (owedToMe ? p.balance > 0 : p.balance < 0) p.key],
      };
      final noun = first.domain == 'money' ? (cashKind == CashKind.income ? tr('আয়') : cashKind == CashKind.expense ? tr('খরচ') : tr('আয়-ব্যয়')) : _domainBn[first.domain] ?? '';
      if (all.isEmpty) {
        _say(out, trf('কোনো {0} রাখা নেই — কিছু বদলাইনি।', [noun]));
        return true;
      }
      _rememberSet(first.domain, first.domain == 'money' ? noun : tr('সব'), all, source: t);
    }
    final set = _setFor(first);
    // "আম্মার শেষ তিনটা মাপ দেখাও": a new question, not about the list
    // shown — only "এর মধ্যে জরুরিগুলো দেখাও"-like narrowing stays here.
    if (first.op == 'show' && (set == null || !const {SelKind.filter, SelKind.all, SelKind.rest}.contains(first.selection.kind) || (first.domain.isNotEmpty && first.domain != set.domain))) return false;
    if (set == null && first.op == 'reverse') return false;
    if (set == null) {
      // A group with nothing shown to point at: only a plain list request
      // goes on to the other rules ("সব কাজ মুছে দাও" asks there).
      // "আজকের যতগুলো কাজ আছে সবগুলো বাদ দাও" names its own scope: the
      // rules for that. Only a bare "এগুলো" with nothing shown is asked.
      if (_thas2(t, r'(?:কাজ|তালিকা|লিস্ট|নোট|রিমাইন্ডার|ওষুধ|অভ্যাস)') || !_thas2(t, r'(?:এইগুলো|এগুলো|এগুলা|এইগুলা|ওগুলো|ওইগুলো|ওগুলা|এসব|ওসব|এই\s+গুলো|সেগুলো|বাকিগুলো|সবগুলো|সবগুলা|সব\s+গুলো|সব\s+গুলা|সবকটা|সবকয়টা)')) return false;
      final stale = _sets.where((s) => first.domain.isEmpty || s.domain == first.domain).lastOrNull;
      // Still fresh, but something else was said after it: which list is
      // meant is not known — asked, with the way to bring it back.
      if (stale != null && _setFresh(stale)) {
        _say(out, trf('“এগুলো” বলতে কোন তালিকা বোঝাচ্ছেন? মাঝে অন্য কথা হয়েছে — আগের তালিকাটা আবার দেখতে বলুন, যেমন “{0}”, তারপর বলুন।', [stale.source]));
        return true;
      }
      _say(out, stale != null ? trf('আগের {0}তালিকাটা অনেক আগের — এখন কোনগুলো বলছেন বুঝতে আবার দেখে নিই? যেমন বলুন “{1}”।', [stale.label.isEmpty ? '' : '${stale.label} ', stale.source]) : tr('কোন তালিকার কথা বলছেন? আগে তালিকাটা দেখতে বলুন — যেমন “আজকের কাজ দাও”, তারপর “এগুলো সব …”।'));
      return true;
    }
    // "সব রিমাইন্ডার দেখাও" while to-dos were shown: a new question, not about this list.
    if (first.op == 'show' && first.selection.kind == SelKind.all) return false;
    final ops = bulkOps[set.domain] ?? const {};
    for (final c in cmds) {
      if (!ops.contains(c.op)) {
        _say(out, trf('{0} তালিকায় একসাথে এ কাজটা কথায় করা যায় না — {1}টা {2} যেমন ছিল আছে।', [_possBn(_domainBn[set.domain] ?? set.domain), bnDigits(set.ids.length), _domainBn[set.domain] ?? '']));
        return true;
      }
    }
    set.used = _now;
    set.turn = _turn;
    _onList = true;
    var picked = _lastPicked;
    for (final c in cmds) {
      final (ids, why) = _resolve(c.selection, set, lastPicked: picked);
      if (why != null) {
        _say(out, why);
        return true;
      }
      picked = ids;
      await _bulkStart(c, set, ids, out);
      if (wait == ChatWait.bulk) return true;
    }
    return true;
  }

  bool _thas2(String t, String p) => RegExp(fold(p)).hasMatch(fold(t));

  /// One change about [ids] of [set]: carried out, asked once (removing), or
  /// the scope asked when the list was not all on screen.
  Future<void> _bulkStart(BulkAction c, ResultSet set, List<String> ids, List<String> out) async {
    final live = [for (final id in ids) if (_exists(set.domain, id)) id];
    if (live.isEmpty && c.op != 'restore') {
      _say(out, ids.isEmpty ? tr('এই তালিকায় এমন কিছু নেই — কিছু বদলাইনি।') : tr('তালিকার এগুলো আর নেই — কিছু বদলাইনি।'));
      return;
    }
    // Shown only in part (more matched than were on screen): which, asked.
    if (!set.complete && c.selection.kind == SelKind.all && c.op != 'show') {
      final shownIds = set.ids.take(set.shown).toList();
      _clarifyOptions = [
        (trf('দেখানো {0}টা', [bnDigits(shownIds.length)]), BulkAction(c.transcript, selection: Selection(SelKind.first, n: shownIds.length), op: c.op, domain: set.domain, due: c.due, time: c.time, day: c.day)),
        (trf('পাওয়া সব {0}টা', [bnDigits(set.matching)]), BulkAction(c.transcript, selection: const Selection(SelKind.all), op: c.op, domain: set.domain, due: c.due, time: c.time, day: c.day)),
      ];
      _clarifySet = set;
      _ask(out, trf('দেখানো {0}টা, নাকি পাওয়া সব {1}টা?', [bnDigits(shownIds.length), bnDigits(set.matching)]), ChatWait.clarify, choices: [for (final o in _clarifyOptions) ChatChoice(o.$1, o.$1)]);
      return;
    }
    if (c.op == 'remind' && c.time == null) {
      // "এই দুটি কাজের রিমাইন্ডার দাও": the time is asked, and the answer
      // ("দুপুর ১২ টায়") sets them — each on its own day.
      if (set.domain == 'tasks') {
        _batchTasks = (live, '', _turn);
        _batchPart = null;
        _ask(out, trf('{0}টা কাজের রিমাইন্ডার — প্রতিটা নিজের দিনে, কয়টায় মনে করাব? যেমন “দুপুর ১২টায়”।', [bnDigits(live.length)]), ChatWait.batchTime);
        return;
      }
      _say(out, tr('কয়টায় মনে করাব? সময়সহ বলুন — যেমন “এগুলোর রিমাইন্ডার সকাল ১০টায় দাও”।'));
      return;
    }
    if (c.op == 'remind' && c.ampmOpen) {
      final h = c.time! ~/ 60, m = c.time! % 60;
      final r = ampmReadings(DateTime(_now.year, _now.month, _now.day, h, m), _now);
      _clarifyOptions = [for (final x in r) (bnTime(x.hour, x.minute), BulkAction(c.transcript, selection: c.selection, op: 'remind', domain: set.domain, time: x.hour * 60 + x.minute, due: c.due))];
      _clarifySet = set;
      _ask(out, trf('{0}, নাকি {1}?', [bnTime(r[0].hour, r[0].minute), bnTime(r[1].hour, r[1].minute)]), ChatWait.clarify, choices: [for (final o in _clarifyOptions) ChatChoice(o.$1, o.$1)]);
      return;
    }
    _lastPicked = live;
    if (set.domain == 'ledger' && c.op == 'delete') {
      // Money: "বাদ দাও" may mean "paid back" or "remove the records" —
      // the one question is which, with who and how much.
      final people = [for (final p in balances(brain.data.ledger)) if (live.contains(p.key)) p];
      final sum = people.fold<int>(0, (a, p) => a + p.balance.abs());
      _clarifyOptions = [
        (tr('শোধ হয়ে গেছে ধরে নাও (হিসাব থাকবে)'), BulkAction(c.transcript, selection: c.selection, op: 'settle', domain: 'ledger')),
        (tr('পুরো হিসাব মুছে দাও'), BulkAction(c.transcript, selection: c.selection, op: 'erase', domain: 'ledger')),
      ];
      _clarifySet = set;
      _ask(out, trf('{0} জনের মোট {1} টাকার হিসাব — কী করব? সব শোধ হয়ে গেছে ধরে নেব, নাকি হিসাবগুলোই মুছে দেব?', [bnDigits(people.length), bnNumber(sum)]), ChatWait.clarify,
          facts: _bulkWhat(set, live), choices: [for (final o in _clarifyOptions) ChatChoice(o.$1, o.$1), ChatChoice(tr('থাক'), 'থাক')]);
      return;
    }
    if (c.op == 'delete') {
      // Removing several: asked once, with what and how many.
      _pendingBulk = _BulkProposal(c, set, live, 'op${_now.microsecondsSinceEpoch}');
      final what = _bulkWhat(set, live);
      final cashSum = set.domain == 'money' ? brain.data.cash.where((e) => live.contains(e.id)).fold<int>(0, (a, e) => a + e.amount) : 0;
      final q = set.domain == 'money'
          ? trf('{0}-এর {1}টা এন্ট্রি, মোট {2} টাকা — সব মুছে দেব? (মুছে ফেলা পাতায় ফেরত আনা যাবে)', [set.label, bnDigits(live.length), bnNumber(cashSum)])
          : set.label == tr('সব') && live.length == set.ids.length
          ? trf('আপনার সব {0}টা {1} মুছে দেব?', [bnDigits(live.length), _domainBn[set.domain] ?? ''])
          : trf('{0} এই {1}টা {2} মুছে দেব?', [set.label.isEmpty ? '' : set.label, bnDigits(live.length), _domainBn[set.domain] ?? '']).trim();
      _ask(out, q, ChatWait.bulk,
          choices: [ChatChoice(tr('হ্যাঁ, মুছে দাও'), 'হ্যাঁ'), ChatChoice(tr('না'), 'না')], facts: what);
      return;
    }
    await _bulkRun(c, set, live, out);
  }

  bool _exists(String domain, String id) {
    final d = brain.data;
    return switch (domain) {
      'tasks' => d.tasks.any((x) => x.id == id),
      'reminders' => d.reminders.any((x) => x.id == id),
      'notes' => d.notes.any((x) => x.id == id),
      'medicines' => d.medicines.any((x) => x.id == id),
      'habits' => d.habits.any((x) => x.id == id),
      'health' => d.health.any((x) => x.id == id),
      'money' => d.ledger.any((x) => x.id == id) || d.cash.any((x) => x.id == id),
      'ledger' => balances(d.ledger).any((p) => p.key == id && !p.settled),
      _ => false,
    };
  }

  List<String> _bulkWhat(ResultSet set, List<String> ids) {
    final d = brain.data;
    return [
      for (final id in ids)
        switch (set.domain) {
          'tasks' => _maybe(id).map((t) => taskLine(t, _now)).firstOrNull ?? '',
          'reminders' => d.reminders.where((x) => x.id == id).map((r) => '${r.title} — ${sayWhen(r.nextDate(_now), _now, withTime: false)} ${bnTime(r.hour, r.minute)}').firstOrNull ?? '',
          'notes' => d.notes.where((x) => x.id == id).map((n) => n.title.isEmpty ? n.body : n.title).firstOrNull ?? '',
          'medicines' => d.medicines.where((x) => x.id == id).map((m) => m.name).firstOrNull ?? '',
          'habits' => d.habits.where((x) => x.id == id).map((h) => h.name).firstOrNull ?? '',
          'ledger' => balances(d.ledger).where((p) => p.key == id).map((p) => owesText(p.name, p.balance)).firstOrNull ?? '',
          'money' => d.cash.where((x) => x.id == id).map((e) => '${e.kind == CashKind.income ? tr('আয়') : tr('খরচ')}: ${e.category} — ${bnNumber(e.amount)} ${tr('টাকা')} (${shortDate(e.date)})').firstOrNull ??
              d.ledger.where((x) => x.id == id).map((e) => '${e.person} — ${bnNumber(e.amount)} ${tr('টাকা')}').firstOrNull ??
              '',
          _ => id,
        },
    ];
  }

  /// The answer to "…মুছে দেব?": yes runs it once; no or "থাক" drops it;
  /// "না, শেষের দুটো" / "না, ওষুধেরটা থাকবে" changes what is meant and asks again.
  Future<bool> _bulkAnswer(String t, List<String> out) async {
    _onList = true;
    final fixId = _healthFix;
    if (fixId != null) {
      _healthFix = null;
      wait = ChatWait.none;
      final h = brain.data.health.where((x) => x.id == fixId).firstOrNull;
      if (h == null) return true;
      if (RegExp(fold(r'(?:মুছে|মুছো|ডিলিট|বাদ)')).hasMatch(fold(t))) {
        final snap = brain.snapshot();
        await brain.deleteHealth(h.id);
        _say(out, tr('মাপটা মুছে দিয়েছি।'));
        _offerUndo(snap);
        return true;
      }
      final nums = RegExp(r'\d+(?:\.\d+)?').allMatches(asciiDigits(spokenNumbers(t))).map((m) => double.parse(m[0]!)).toList();
      if (nums.isEmpty || (h.kind == HealthKind.bp && nums.length < 2)) {
        _say(out, tr('মানটা ধরতে পারিনি — কিছু বদলাইনি।'));
        return true;
      }
      final snap = brain.snapshot();
      final fixed = HealthLog(id: h.id, member: h.member, kind: h.kind, at: h.at, a: nums[0], b: h.kind == HealthKind.bp ? nums[1] : h.b, c: h.c, tag: h.tag, note: h.note);
      await brain.saveHealth(fixed);
      _actions++;
      _say(out, trf('ঠিক করেছি — {0}: {1}। নতুন কোনো মাপ যোগ করিনি।', [sayWhen(h.at, _now), readingText(fixed)]));
      _offerUndo(snap);
      return true;
    }
    final p = _pendingBulk;
    if (p == null) return false;
    final f = ' ${fold(t).replaceAll(RegExp(r'[।,!?]'), ' ')} ';
    // A new selection said with a "no": the proposal is replaced, not added to.
    final rest = tidySpeech(t.replaceFirst(RegExp(fold(r'^\s*(?:না|নাহ|উহু)[,\s]+')), ''));
    var again = bulkCommands(rest, _now);
    // "না, শেষের দুটো": only which ones — the same removal.
    final onlySel = selectionIn(' ${fold(rest).replaceAll(RegExp(r'[।!?]'), ' ')} ');
    if ((again == null || again.isEmpty) && onlySel != null && onlySel.kind != SelKind.all) again = [BulkAction(t, selection: onlySel, op: 'delete', domain: p.set.domain)];
    if (again != null && again.isNotEmpty) {
      final s = again.first.selection;
      final narrowing = s.kind == SelKind.all && s.hasExcept && again.first.op == 'show';
      if (narrowing || again.first.op == 'delete' || again.first.op == 'show') {
        final sel = narrowing ? null : s;
        final List<String> ids;
        if (sel == null) {
          final (keep, why) = _resolve(Selection(SelKind.all, exceptIdx: s.exceptIdx, exceptNames: s.exceptNames), ResultSet(domain: p.set.domain, label: p.set.label, ids: p.ids, matching: p.ids.length, shown: p.ids.length, source: p.set.source, at: _now, turn: _turn));
          if (why != null) {
            _say(out, why);
            return true;
          }
          ids = keep;
        } else {
          final (x, why) = _resolve(sel, p.set);
          if (why != null) {
            _say(out, why);
            return true;
          }
          ids = x;
        }
        _pendingBulk = null;
        wait = ChatWait.none;
        await _bulkStart(BulkAction(t, selection: sel ?? const Selection(SelKind.all), op: 'delete', domain: p.set.domain), p.set, ids, out);
        return true;
      }
    }
    // "না, ওষুধেরটা থাকবে": one left out of what was asked.
    final keep = RegExp(fold(r'(?:^|\s)(\S+?)(?:ের|এর|র)?(?:টা|টি)\s+(?:থাকবে|থাকুক|থাক|রাখো)')).firstMatch(f);
    if (keep != null) {
      final terms = searchTerms(normalize(keep[1]!));
      final set = ResultSet(domain: p.set.domain, label: p.set.label, ids: p.ids, matching: p.ids.length, shown: p.ids.length, source: p.set.source, at: _now, turn: _turn);
      final hit = _namedIn(set, terms);
      if (hit.isNotEmpty) {
        _pendingBulk = null;
        wait = ChatWait.none;
        await _bulkStart(p.action, p.set, [for (final id in p.ids) if (!hit.contains(id)) id], out);
        return true;
      }
    }
    final yn = yesNo(t);
    // Something new said instead of an answer ("ফাউন্ডেশনের কাছে আমি ৬৪ হাজার
    // টাকা পাবো"): nothing removed, and that is heard on its own.
    if (yn == null && _looksNew(t)) return false;
    wait = ChatWait.none;
    choices = const [];
    _pendingBulk = null;
    if (yn == true || RegExp(fold(r'^\s*(?:ঠিক\s+আছে|ওকে|ok|okay|দাও|মুছে\s+দাও|করো)\b')).hasMatch(fold(t).toLowerCase())) {
      if (_doneOps.contains(p.opId)) return true;
      _doneOps.add(p.opId);
      await _bulkRun(p.action, p.set, p.ids, out);
      return true;
    }
    _say(out, tr('ঠিক আছে, কিছু মুছিনি।'));
    return true;
  }

  /// Carries out [c] on [ids], each once; says how many really changed.
  Future<void> _bulkRun(BulkAction c, ResultSet set, List<String> ids, List<String> out) async {
    final snap = brain.snapshot();
    final trashBefore = {for (final x in brain.data.trash) x.id};
    var ok = 0;
    final failed = <String>[];
    final skipped = <String>[];
    final d = brain.data;
    Future<void> each(Future<bool> Function(String) f) async {
      for (final id in ids) {
        if (!_exists(set.domain, id)) {
          skipped.add(id);
          continue;
        }
        try {
          if (await f(id)) ok++;
        } catch (_) {
          failed.add(id);
        }
      }
    }

    final noun = _domainBn[set.domain] ?? '';
    switch ((set.domain, c.op)) {
      case ('tasks', 'delete'):
        var series = 0;
        await each((id) async {
          final t = _taskById(id)!;
          // A repeating to-do on today's list: this time skipped, never the series.
          if (t.repeat != null) {
            await brain.skipTaskOnce(t);
            series++;
            return true;
          }
          await brain.deleteTask(id);
          return true;
        });
        _say(out, _outcome(trf('{0}টা {1} মুছে দিয়েছি', [bnDigits(ok - series), noun]), ok, ids.length, failed, skipped) + (series > 0 ? trf(' {0}টা নিয়মিত কাজের শুধু এবারেরটা বাদ দিয়েছি — পুরো সিরিজ আছে।', [bnDigits(series)]) : ''),
            links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
      case ('tasks', 'done' || 'reopen'):
        final done = c.op == 'done';
        await each((id) async {
          final t = _taskById(id)!;
          if (t.done == done && t.repeat == null) return false;
          await brain.setTaskDone(t, done);
          return true;
        });
        _say(out, _outcome(done ? trf('{0}টা {1} শেষ হিসেবে টিক দিয়েছি', [bnDigits(ok), noun]) : trf('{0}টা {1} আবার বাকি রেখেছি', [bnDigits(ok), noun]), ok, ids.length, failed, skipped),
            links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
      case ('tasks', 'move'):
        var repeating = 0;
        await each((id) async {
          final t = _taskById(id)!;
          if (t.repeat != null) {
            repeating++;
            return false;
          }
          // Already on that day (a retry): not changed again.
          if (t.due != null && t.span == TaskSpan.day && dayOnly(t.due!) == c.due) return false;
          await brain.saveTask(t.copyWith(due: c.due));
          // Its reminder goes with it — no alarm left on the old day.
          final rid = t.reminderId;
          final r = rid == null ? null : d.reminders.where((x) => x.id == rid).firstOrNull;
          if (r != null && r.repeat == Repeat.none) await brain.saveReminder(r.copyWith(date: c.due));
          return true;
        });
        _say(
            out,
            _outcome(trf('{0}টা {1} {2} রেখেছি', [bnDigits(ok), noun, sayWhen(c.due!, _now, withTime: false)]), ok, ids.length - repeating, failed, skipped) +
                (repeating > 0 ? trf(' {0}টা নিয়মিত কাজ আগের নিয়মেই থাকল।', [bnDigits(repeating)]) : ''),
            links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
      case ('tasks', 'remind'):
        var limited = 0;
        await each((id) async {
          final t = _taskById(id)!;
          final day = c.due ?? (t.due != null && t.span == TaskSpan.day ? dayOnly(t.due!) : dayOnly(_now));
          var at = DateTime(day.year, day.month, day.day, c.time! ~/ 60, c.time! % 60);
          if (!at.isAfter(_now)) at = at.add(const Duration(days: 1));
          final rid = t.reminderId;
          final old = rid == null ? null : brain.data.reminders.where((x) => x.id == rid).firstOrNull;
          if (old == null && !brain.canAddReminder) {
            limited++;
            return false;
          }
          if (old != null) {
            await brain.saveReminder(old.copyWith(date: dayOnly(at), hour: at.hour, minute: at.minute, enabled: true));
          } else {
            final r = Reminder(title: t.title, date: dayOnly(at), hour: at.hour, minute: at.minute);
            await brain.saveReminder(r);
            await brain.saveTask(_taskById(id)!.copyWith(reminderId: r.id));
          }
          return true;
        });
        final on = (await brain.services.notifier.health()).notificationsOn;
        _say(
            out,
            _outcome(trf('{0}টা {1} রিমাইন্ডার {2}-এ দিয়েছি', [bnDigits(ok), _possBn(noun), bnTime(c.time! ~/ 60, c.time! % 60)]), ok, ids.length, failed, skipped) +
                (limited > 0 ? trf(' {0}টার রিমাইন্ডার চালু হয়নি — ফ্রিতে একসাথে {1}টা রাখা যায়।', [bnDigits(limited), bnDigits(freeReminders)]) : '') +
                (on ? '' : tr(' তবে ফোনে অ্যাপের নোটিফিকেশন বন্ধ — এখন বাজবে না।')),
            links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন'))]);
      case ('tasks', 'reminder_off'):
        await each((id) async {
          final t = _taskById(id)!;
          final r = t.reminderId == null ? null : d.reminders.where((x) => x.id == t.reminderId && x.enabled).firstOrNull;
          if (r == null) return false;
          await brain.saveReminder(r.copyWith(enabled: false));
          return true;
        });
        _say(out, ok == 0 ? tr('এগুলোর কোনোটার চালু রিমাইন্ডার ছিল না। কাজগুলো আছে।') : trf('{0}টা কাজের রিমাইন্ডার বন্ধ করেছি; কাজগুলো তালিকায় আছে।', [bnDigits(ok)]));
      case ('tasks', 'urgent'):
        await each((id) async {
          final t = _taskById(id)!;
          if (t.urgent) return false;
          await brain.saveTask(t.copyWith(urgent: true));
          return true;
        });
        _say(out, trf('{0}টা কাজ জরুরি করেছি।', [bnDigits(ok)]));
      case ('reminders', 'delete'):
        await each((id) async {
          await brain.deleteReminder(id);
          return true;
        });
        _say(out, _outcome(trf('{0}টা রিমাইন্ডার মুছে দিয়েছি', [bnDigits(ok)]), ok, ids.length, failed, skipped), links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন'))]);
      case ('reminders', 'reminder_off'):
        await each((id) async {
          final r = d.reminders.firstWhere((x) => x.id == id);
          if (!r.enabled) return false;
          await brain.saveReminder(r.copyWith(enabled: false));
          return true;
        });
        _say(out, trf('{0}টা রিমাইন্ডার বন্ধ করেছি — মুছিনি।', [bnDigits(ok)]), links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন'))]);
      case ('notes', 'delete'):
        await each((id) async {
          await brain.deleteNote(id);
          return true;
        });
        _say(out, _outcome(trf('{0}টা নোট মুছে দিয়েছি', [bnDigits(ok)]), ok, ids.length, failed, skipped), links: [ChatLink(LinkKind.notes, tr('নোট দেখুন'))]);
      case ('medicines', 'reminder_off'):
        await each((id) async {
          final m = d.medicines.firstWhere((x) => x.id == id);
          var any = false;
          for (final rid in m.reminderIds) {
            final r = d.reminders.where((x) => x.id == rid && x.enabled).firstOrNull;
            if (r == null) continue;
            await brain.saveReminder(r.copyWith(enabled: false));
            any = true;
          }
          return any;
        });
        _say(out, ok == 0 ? tr('এগুলোর কোনো চালু রিমাইন্ডার ছিল না। ওষুধগুলো তালিকায় আছে।') : trf('{0}টা ওষুধের রিমাইন্ডার বন্ধ করেছি; ওষুধগুলো তালিকায় আছে।', [bnDigits(ok)]), links: [ChatLink(LinkKind.page, tr('ওষুধ'), page: 'medicines')]);
      case ('habits', 'done' || 'not_done'):
        final day = c.day ?? dayOnly(_now);
        final want = c.op == 'done';
        await each((id) async {
          final h = brain.data.habits.firstWhere((x) => x.id == id);
          if (h.doneOn(day) == want) return false;
          await brain.toggleHabit(h, day);
          return true;
        });
        _say(out, want ? trf('{0}টা অভ্যাসে {1}-এর টিক দিয়েছি।', [bnDigits(ok), sayWhen(day, _now, withTime: false)]) : trf('{0}টার টিক তুলেছি; বাকিগুলো টিক ছাড়াই ছিল।', [bnDigits(ok)]),
            links: [ChatLink(LinkKind.page, tr('অভ্যাস'), page: 'habits')]);
      case ('habits', 'reminder_off'):
        await each((id) async {
          final h = brain.data.habits.firstWhere((x) => x.id == id);
          if (h.reminderId == null) return false;
          await brain.setHabitReminder(h, null);
          return true;
        });
        _say(out, trf('{0}টা অভ্যাসের রিমাইন্ডার বন্ধ করেছি; অভ্যাসগুলো আছে।', [bnDigits(ok)]));
      case ('ledger', 'settle'):
        // One "ফেরত পেলাম"/"শোধ করলাম" per person for exactly what is left.
        await each((key) async {
          final p = balances(d.ledger).firstWhere((x) => x.key == key);
          if (p.settled) return false;
          await brain.saveEntry(LedgerEntry(person: p.name, kind: p.balance > 0 ? LedgerKind.received : LedgerKind.repaid, amount: p.balance.abs(), date: _now, note: tr('একসাথে শোধ')), guessPhone: false);
          return true;
        });
        _say(out, _outcome(trf('{0} জনের হিসাব শোধ হিসেবে মিলিয়ে দিয়েছি — আগের লেনদেনগুলো আছে', [bnDigits(ok)]), ok, ids.length, failed, skipped), links: [ChatLink(LinkKind.page, tr('লেনদেন'), page: 'ledger')]);
      case ('ledger', 'erase'):
        await each((key) async {
          final keys = accountKeys(d.ledger);
          final mine = [for (final e in d.ledger) if (keys[e.id] == key) e.id];
          for (final id in mine) {
            await brain.deleteEntry(id);
          }
          return mine.isNotEmpty;
        });
        _say(out, _outcome(trf('{0} জনের সব লেনদেন মুছে দিয়েছি', [bnDigits(ok)]), ok, ids.length, failed, skipped), links: [ChatLink(LinkKind.page, tr('লেনদেন'), page: 'ledger')]);
      case ('money', 'delete'):
        // Only আয়-ব্যয় records; a person's ধার-দেনা is never removed from here.
        await each((id) async {
          if (!d.cash.any((x) => x.id == id)) return false;
          await brain.deleteCash(id);
          return true;
        });
        _say(out, _outcome(trf('{0}টা {1}-এর এন্ট্রি মুছে দিয়েছি', [bnDigits(ok), set.label]), ok, ids.length, failed, skipped), links: [ChatLink(LinkKind.cash, tr('আয়-ব্যয় দেখুন'))]);
      case ('money', 'report'):
        // Read-only: the PDF page with this list's span; nothing changes.
        _say(out, trf('এই {0}টা লেনদেনের PDF বানাতে PDF পাতা খুলছি — সেখানে সময়সীমা বেছে নিয়ে ডাউনলোড বা শেয়ার করুন।', [bnDigits(ids.length)]), links: [ChatLink(LinkKind.page, tr('PDF'), page: 'pdf')]);
        return;
      case ('health', 'wrong'):
        // "দ্বিতীয়টা ভুল": that reading, of that person — the right value is
        // asked; nothing new is measured or written until it is said.
        final h = d.health.where((x) => x.id == ids.first).firstOrNull;
        if (h == null) return;
        _healthFix = h.id;
        _ask(out, trf('{0} — {1}। ঠিক মানটা কত? বলুন যেমন “১২০/৮০”, বা “মুছে দাও”।', [sayWhen(h.at, _now), readingText(h)]), ChatWait.bulk);
        return;
      case ('health', 'delete'):
        await each((id) async {
          final h = d.health.firstWhere((x) => x.id == id);
          await brain.deleteHealth(h.id);
          return true;
        });
        _say(out, _outcome(trf('{0}টা মাপ মুছে দিয়েছি', [bnDigits(ok)]), ok, ids.length, failed, skipped));
      case (_, 'show' || 'reverse'):
        final ordered = c.op == 'reverse' ? ids.reversed.toList() : ids;
        final narrowed = ResultSet(domain: set.domain, label: set.label, ids: ordered, matching: ordered.length, shown: ordered.length, source: c.transcript, at: _now, turn: _turn);
        _sets.remove(set);
        _sets.add(narrowed);
        if (set.domain == 'tasks') {
          _shownTasks = ordered;
          _shownAt = _now;
        }
        _say(out, ordered.isEmpty ? tr('এর মধ্যে এমন কিছু নেই।') : trf('{0}টা:', [bnDigits(ordered.length)]), facts: _bulkWhat(set, ordered));
        return;
      case (_, 'restore'):
        await _bulkRestore(out);
        return;
      default:
        _say(out, tr('এ কাজটা এই তালিকায় একসাথে কথায় করা যায় না — কিছু বদলাইনি।'));
        return;
    }
    if (ok > 0) {
      _actions++;
      _offerUndo(snap);
      final newTrash = [for (final x in brain.data.trash) if (!trashBefore.contains(x.id)) x.id];
      _lastBatch = _BulkBatch(c.op, set.domain, ids, newTrash, _now);
      Trace.log('done', 'bulk', {'op': c.op, 'domain': set.domain, 'asked': ids.length, 'changed': ok, 'failed': failed.length, 'gone before': skipped.length});
    }
    // The same group stays the one meant ("ওগুলোর রিমাইন্ডার সকাল দশটায় দাও").
    if (c.op != 'delete') {
      set.used = _now;
      set.turn = _turn;
      final kept = ResultSet(domain: set.domain, label: set.label, ids: [for (final id in ids) if (_exists(set.domain, id)) id], matching: ids.length, shown: ids.length, source: c.transcript, at: _now, turn: _turn);
      _sets.remove(set);
      _sets.add(kept);
      if (set.domain == 'tasks') {
        _shownTasks = kept.ids;
        _shownAt = _now;
      }
    }
  }

  /// "৪টা মুছে দিয়েছি; ১টা করা যায়নি" — only what is true.
  String _outcome(String did, int ok, int asked, List<String> failed, List<String> skipped) {
    final bits = <String>[did];
    if (failed.isNotEmpty) bits.add(trf('{0}টা করা যায়নি', [bnDigits(failed.length)]));
    if (skipped.isNotEmpty) bits.add(trf('{0}টা আগেই তালিকা থেকে সরে গিয়েছিল', [bnDigits(skipped.length)]));
    if (ok == 0 && failed.isEmpty && skipped.isEmpty) return tr('এগুলোয় বদলানোর কিছু ছিল না — যেমন ছিল আছে।');
    return '${bits.join('; ')}।';
  }

  /// "ওগুলো ফেরত আনো" after removing several: that batch, from মুছে ফেলা.
  Future<void> _bulkRestore(List<String> out) async {
    final b = _lastBatch;
    if (b == null || b.trashIds.isEmpty || _now.difference(b.at).inHours > 24) {
      _say(out, tr('একসাথে মোছা কিছু মনে নেই। মুছে ফেলা পাতা থেকে বেছে ফেরত আনতে পারেন।'), links: [ChatLink(LinkKind.page, tr('মুছে ফেলা'), page: 'settings')]);
      return;
    }
    var n = 0;
    for (final id in b.trashIds) {
      final item = brain.data.trash.where((x) => x.id == id).firstOrNull;
      if (item == null) continue;
      await brain.restoreTrash(item);
      n++;
    }
    _lastBatch = null;
    _actions++;
    _say(out, n == b.trashIds.length ? trf('{0}টাই ফেরত এনেছি।', [bnDigits(n)]) : trf('{0}টা ফেরত এনেছি; {1}টা আর মুছে ফেলা-তে ছিল না।', [bnDigits(n), bnDigits(b.trashIds.length - n)]));
  }

  /// A reminder answer listed some: those are "এগুলো".
  /// "কোনটা মুছবো?" answered "সব" / "দুটোই": every one listed, as one group
  /// with one confirmation — when they are of one kind. Different kinds
  /// (a to-do and a reminder of the same name) are not removed together.
  Future<bool> _whichAll(List<String> out) async {
    final c = _current;
    final kinds = {for (final x in _targets) x.kind};
    const doms = {ItemKind.task: 'tasks', ItemKind.reminder: 'reminders', ItemKind.note: 'notes'};
    final dom = kinds.length == 1 ? doms[kinds.single] : null;
    final op = c is ManageItem ? (c.action == 'delete' ? 'delete' : (c.action == 'stop' ? 'reminder_off' : null)) : null;
    if (c is! ManageItem || dom == null || op == null || !(bulkOps[dom]?.contains(op) ?? false)) {
      _say(out, kinds.length > 1
          ? trf('এখানে আলাদা ধরনের জিনিস আছে ({0}) — একসাথে করছি না। কোনটা, নম্বর বলুন — যেমন “১”।', [kinds.map((k) => tr(k.bn)).join(', ')])
          : tr('একসাথে সবগুলো এভাবে করা যায় না — কোনটা, নম্বর বলুন, যেমন “১”।'));
      return true;
    }
    final ids = [for (final x in _targets) x.id];
    wait = ChatWait.none;
    choices = const [];
    _targets = const [];
    _rememberSet(dom, '', ids, source: c.transcript);
    await _bulkStart(BulkAction(c.transcript, selection: const Selection(SelKind.all), op: op, domain: dom), _sets.last, ids, out);
    return true;
  }

  /// "আমার পাওনা টাকা কত?" / "কার কাছে দেনা?": the people named in the answer.
  void _rememberLedger(LedgerQuery q) {
    final all = balances(brain.data.ledger);
    final people = switch (q.ask) {
      LedgerAsk.receivable => [for (final p in all) if (p.balance > 0) p],
      LedgerAsk.payable => [for (final p in all) if (p.balance < 0) p],
      LedgerAsk.all => [for (final p in all) if (!p.settled) p],
      _ => const <PersonBalance>[],
    };
    if (people.isEmpty) return;
    _rememberSet('ledger', q.ask == LedgerAsk.receivable ? tr('পাওনার') : (q.ask == LedgerAsk.payable ? tr('দেনার') : ''), [for (final p in people) p.key], source: q.transcript);
  }

  void _rememberReminders(ReminderQuery q) {
    // The very list the answer showed (same reading), shown in part when
    // more were upcoming than fit.
    final v = reminderView(brain.data, q, _now);
    if (v.shown.isEmpty) return;
    final upcoming = v.kind == 'all' || v.kind == 'miss';
    // The whole pool is kept (shown first) so "পাওয়া সব" can reach past the page.
    _rememberSet('reminders', v.kind == 'day' ? '${sayWhen(v.day!, _now, withTime: false)}-এর' : (upcoming ? tr('সামনের') : ''), [for (final r in v.pool) r.id],
        matching: v.matching, shown: v.shown.length, source: q.transcript);
  }

  /// "কী কী ওষুধ চলছে?", "অভ্যাসগুলো কেমন চলছে?": the whole list shown.
  void _rememberTopic(ProfileQuery q) {
    final topic = infoTopic(normalize(q.transcript));
    final d = brain.data;
    if (topic == 'medicines' && d.medicines.isNotEmpty) _rememberSet('medicines', '', [for (final m in d.medicines) m.id], source: q.transcript);
    if (topic == 'habits' && d.habits.isNotEmpty) _rememberSet('habits', '', [for (final h in d.habits) h.id], source: q.transcript);
  }

  void _rememberMoney(MoneyListQuery q) {
    final r = moneyRecords(brain.data, q);
    final ids = [...r.ledger.map((e) => e.id), ...r.cash.map((e) => e.id)];
    if (ids.isNotEmpty) _rememberSet('money', q.label, ids, source: q.transcript);
  }

  /// One-tap next steps under the conversation, from what was just shown or
  /// kept — every one a sentence the rules understand (see followups_test).
  /// Empty when nothing fits (the user's own questions are shown then).
  List<String> get _followUps {
    if (wait != ChatWait.none) return const [];
    final set = _sets.where(_setFresh).lastOrNull;
    // Only a list shown or acted on in this very turn: anything said after
    // it makes its steps stale.
    final current = set != null && set.turn == _turn ? set : null;
    if (current != null && current.ids.isNotEmpty) {
      final many = current.ids.length > 1;
      return switch (current.domain) {
        'tasks' => [if (many) 'প্রথমটা হয়ে গেছে' else 'এটা হয়ে গেছে', if (many) 'এগুলো সব কাল রাখো', if (many) 'জরুরিগুলো দেখাও', 'এগুলো সব মুছে দাও'],
        'reminders' => [if (many) 'প্রথমটা বন্ধ করো', 'এগুলো সব বন্ধ করো', 'এগুলো সব মুছে দাও', 'কালকের রিমাইন্ডার দেখাও'],
        'ledger' => ['আমি কাকে কত দেব?', 'আমার মোট পাওনা কত?', 'সব শোধ হয়ে গেছে'],
        'notes' => ['এগুলো সব মুছে দাও'],
        'medicines' => ['এগুলোর রিমাইন্ডার বন্ধ করো'],
        'habits' => ['সবগুলো আজ করেছি'],
        _ => const <String>[],
      };
    }
    final last = _lastSave;
    if (last != null && _savedTurn == _turn && _now.difference(last.$3).inMinutes < 10) {
      return switch (last.$1) {
        ReminderAdd(:final alarm) => [alarm ? 'আমার কোন এলার্ম আছে?' : 'আমার সব রিমাইন্ডার দেখাও', 'আজকের কাজের লিস্ট দাও'],
        TaskAdd() => ['আজকের কাজের লিস্ট দাও', 'কালকের কাজ দাও'],
        LedgerAdd() || LedgerSet() => ['আমার মোট পাওনা কত?', 'আমি কাকে কত দেব?'],
        CashAdd() => ['এই মাসে কত খরচ হলো?', 'আমার আয়-ব্যয়ের হিসাব দাও'],
        SpecialAdd() => ['কার কার জন্মদিন সামনে?'],
        _ => const <String>[],
      };
    }
    return const [];
  }

  static const _parts = ['ভোরে', 'সকালে', 'দুপুরে', 'বিকেলে', 'বিকালে', 'সন্ধ্যায়', 'সন্ধ্যায়', 'রাতে', 'ভোর', 'সকাল', 'দুপুর', 'বিকেল', 'বিকাল', 'সন্ধ্যা', 'রাত'];

  Future<bool> _batchTimeFor(String t, List<String> out) async {
    final b = _batchTasks;
    if (b == null || b.$3 != _turn - 1) return false;
    final f = normalize(tidySpeech(t));
    final ws = words(f);
    final part = ws.where((w) => _parts.map(normalize).contains(w)).firstOrNull;
    final w = parseWhen(tidySpeech(t), _now);
    final clock = w != null && w.hasTime && saysClock(tidySpeech(t));
    if (part == null && !clock) return false;
    // Only time words and the to-dos' own title words ("দুপুরে দাওয়াত",
    // "রাত ৮টায় মনে করিও"): anything else is a new request.
    final title = words(normalize(b.$2));
    const filler = ['মনে', 'করিও', 'করিয়ে', 'করিয়ে', 'দিও', 'দাও', 'আছে', 'হবে', 'টা', 'টায়', 'টায়', 'ই', 'দুই', 'দিনই', 'দিনেই'];
    final other = [
      for (final x in ws)
        if (!_parts.map(normalize).contains(x) && !title.contains(x) && !filler.map(normalize).contains(x) && !RegExp(r'^[0-9০-৯]').hasMatch(x) && !RegExp(fold(r'টা(?:য়|য়)?$')).hasMatch(fold(x))) x
    ];
    if (other.isNotEmpty) return false;
    if (clock && !hourOpen(tidySpeech(t), w.at.hour)) {
      await _batchRemindAt(w.at.hour * 60 + w.at.minute, out);
      return true;
    }
    _batchPart = part;
    final days = [for (final id in b.$1) if (_taskById(id)?.due != null) sayWhen(_taskById(id)!.due!, _now, withTime: false)];
    _ask(out, trf('“{0}” — {1}, {2} কয়টায় মনে করাব?', [b.$2.isEmpty ? tr('কাজগুলো') : b.$2, nameList(days, unit: 'দিন'), part == null ? '' : tr(part)]), ChatWait.batchTime);
    return true;
  }

  Future<bool> _batchTimeAnswer(String t, List<String> out) async {
    final part = _batchPart;
    final own = parseWhen(t, _now);
    if (own == null || !own.hasTime) {
      if (_looksNew(t)) {
        wait = ChatWait.none;
        _batchPart = null;
        return false;
      }
      _say(out, tr('সময়টা ধরতে পারিনি। যেমন বলুন “১টায়” বা “দুপুর ১টায়”।'));
      return true;
    }
    final w = part != null && !saysDayPart(t) ? parseWhen('$part $t', _now) : own;
    wait = ChatWait.none;
    _batchPart = null;
    await _batchRemindAt(w!.at.hour * 60 + w.at.minute, out);
    return true;
  }

  Future<void> _batchRemindAt(int minutes, List<String> out) async {
    final b = _batchTasks!;
    _batchTasks = null;
    final set = _sets.where((s) => s.domain == 'tasks').lastOrNull;
    if (set == null) return;
    await _bulkStart(BulkAction('', selection: const Selection(SelKind.all), op: 'remind', domain: 'tasks', time: minutes), set, b.$1, out);
  }
}
