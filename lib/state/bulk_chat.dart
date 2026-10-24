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
    // "শুধু পাওনাগুলো দাও, দেনা বাদ": a list to see — "বাদ" leaves a side
    // out of the answer, it removes nothing.
    if (oneSideAsked(t) != null) return false;
    // "ওষুধ খাইনি, … টিক সরাও; রিমাইন্ডার বন্ধ কোরো না": a dose, not a list.
    if (RegExp(fold(r'(?:ওষুধ|ঔষধ|ট্যাবলেট|ডোজ)')).hasMatch(fold(t)) && RegExp(fold(r'(?:টিক|খাইনি|খাই\s+নি|খেয়েছি)')).hasMatch(fold(t))) return false;
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
    // "২০২৭ সালের রিমাইন্ডার গুলো বাদ দাও", "নভেম্বরের গুলো মুছে দাও" (a
    // reminder list shown): every one in that stretch of time — asked once.
    if (await _periodBulk(t, out)) return true;
    var cmds = bulkCommands(tidySpeech(t), _now);
    // "৪নং থেকে ৮নং মুছে দাও। ৯নং এ রিমাইন্ডার যুক্ত কর": the first sentence
    // on the list, the rest heard after it.
    if (cmds == null) {
      final parts = [for (final x in t.split(RegExp(r'\s*[।!]\s*'))) if (x.trim().isNotEmpty) x.trim()];
      if (parts.length > 1) {
        final first = bulkCommands(tidySpeech(parts.first), _now);
        if (first != null && first.isNotEmpty) {
          cmds = first;
          t = parts.first;
          _bulkRest = parts.skip(1).join('। ');
        }
      }
    }
    if (cmds == null || cmds.isEmpty) {
      // One place in a list that is not the to-do list ("দ্বিতীয়টা ভুল"
      // after a health list): the same resolver. To-dos keep their own.
      final one = singleIndexCommand(tidySpeech(t), _now);
      final newest = _sets.where(_setFresh).lastOrNull;
      // To-dos keep their own rules, except removing one ("৮নং টা বাদ দাও"),
      // which the to-do rules hear as a general "মুছে দাও".
      if (one == null || newest == null || (newest.domain == 'tasks' && one.op != 'delete') || (one.domain.isNotEmpty && one.domain != newest.domain)) return false;
      cmds = [one];
    }
    return _bulkWith(cmds, t, out);
  }

  /// The day a reminder is on for a stretch of time: its own date, or the
  /// next time a repeating one rings.
  DateTime? _dayOf(String domain, String id) {
    final d = brain.data;
    if (domain == 'reminders') {
      final r = d.reminders.where((x) => x.id == id).firstOrNull;
      if (r == null) return null;
      final on = r.repeat == Repeat.none ? r.date : r.nextDate(_now);
      return DateTime(on.year, on.month, on.day);
    }
    final x = d.tasks.where((x) => x.id == id).firstOrNull;
    return x?.due == null ? null : dayOnly(x!.due!);
  }

  List<String> _inPeriod(String domain, Iterable<String> ids, DateTime from, DateTime to) => [
        for (final id in ids)
          if (_dayOf(domain, id) case final day? when !day.isBefore(from) && !day.isAfter(to)) id
      ];

  Future<bool> _periodBulk(String t, List<String> out) async {
    final period = periodSaid(tidySpeech(t), _now);
    if (period == null) return false;
    final op = bulkOpOf(tidySpeech(t));
    if (!const {'delete', 'reminder_off', 'done'}.contains(op)) return false;
    final f = fold(normalize(t));
    var domain = RegExp(fold(r'(?:রিমাইন্ডার|এলার্ম|অ্যালার্ম|reminder|alarm)')).hasMatch(f)
        ? 'reminders'
        : (RegExp(fold(r'(?:কাজ|টাস্ক|টুডু|task)')).hasMatch(f) ? 'tasks' : '');
    final shown = _sets.where(_setFresh).lastOrNull;
    if (domain.isEmpty && shown != null && (shown.domain == 'reminders' || shown.domain == 'tasks')) domain = shown.domain;
    if (domain.isEmpty) return false;
    await _periodRemove(domain, op, period, t, out);
    return true;
  }

  /// [op] on every [domain] item in [period], asked once.
  Future<void> _periodRemove(String domain, String op, ({DateTime from, DateTime to, String label}) period, String t, List<String> out) async {
    final d = brain.data;
    final pool = domain == 'reminders' ? [for (final r in d.reminders) r.id] : [for (final x in d.tasks) if (!x.done) x.id];
    final ids = _inPeriod(domain, pool, period.from, period.to);
    final label = period.label;
    if (ids.isEmpty) {
      _say(out, trf('{0} কোনো {1} নেই — কিছু বদলাইনি।', [label, _domainBn[domain] ?? '']));
      return;
    }
    _rememberSet(domain, label, ids, source: t);
    await _bulkStart(BulkAction(t, selection: const Selection(SelKind.all), op: op, domain: domain), _sets.last, ids, out);
    _onList = true;
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
    // Every part resolved first, against the list as shown — a removal
    // never changes which item another part's number means.
    final plan = <(BulkAction, List<String>)>[];
    final failed = <String>[];
    for (final c in cmds) {
      final (ids, why) = _resolve(c.selection, set, lastPicked: picked);
      if (why != null) {
        if (cmds.length == 1) {
          _say(out, why);
          return true;
        }
        failed.add(why);
        continue;
      }
      picked = ids;
      plan.add((c, ids));
    }
    // Removals last (each asked once), so the rest are done and said first.
    plan.sort((a, b) => (a.$1.op == 'delete' ? 1 : 0).compareTo(b.$1.op == 'delete' ? 1 : 0));
    if (failed.isNotEmpty) _say(out, '${failed.join(' ')} ${tr('ওই অংশে কিছু বদলাইনি।')}');
    await _runPlan(plan, set, out);
    return true;
  }

  /// Runs [plan] in order; a part that asks something (a removal to
  /// confirm, a time) keeps the rest waiting until it is answered.
  Future<void> _runPlan(List<(BulkAction, List<String>)> plan, ResultSet set, List<String> out) async {
    for (var i = 0; i < plan.length; i++) {
      await _bulkStart(plan[i].$1, set, plan[i].$2, out);
      if (wait != ChatWait.none) {
        _planRest = (plan.sublist(i + 1), set);
        return;
      }
    }
    _planRest = null;
  }

  /// After an answer: the parts of the same request still to do.
  Future<void> _continuePlan(List<String> out) async {
    final rest = _planRest;
    _planRest = null;
    if (rest == null || rest.$1.isEmpty || wait != ChatWait.none) return;
    await _runPlan(rest.$1, rest.$2, out);
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
      _pendingBulk = _BulkProposal(c, set, live, 'op${_now.microsecondsSinceEpoch}-$_turn');
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
    // "শুধু ২০২৭ সালের", "না, শুধু নভেম্বরের": the same removal, narrowed to
    // that stretch of time — asked again, nothing removed yet.
    final per = periodSaid(tidySpeech(t), _now);
    if (per != null && (p.set.domain == 'reminders' || p.set.domain == 'tasks') && !RegExp(fold(r'(?:দেখাও|দেখান|বলো|বলুন|দাও\s*$)')).hasMatch(fold(normalize(t)))) {
      final ids = _inPeriod(p.set.domain, p.ids, per.from, per.to);
      if (ids.isEmpty) {
        _say(out, trf('{0} কোনো {1} এই তালিকায় নেই — কিছু মুছিনি।', [per.label, _domainBn[p.set.domain] ?? '']));
        return true;
      }
      _pendingBulk = null;
      wait = ChatWait.none;
      _rememberSet(p.set.domain, per.label, ids, source: t);
      await _bulkStart(BulkAction(t, selection: const Selection(SelKind.all), op: p.action.op, domain: p.set.domain), _sets.last, ids, out);
      return true;
    }
    // A new selection said with a "no": the proposal is replaced, not added to.
    final rest = tidySpeech(t.replaceFirst(RegExp(fold(r'^\s*(?:না|নাহ|উহু)[,\s]+')), ''));
    var again = bulkCommands(rest, _now);
    // "না, শেষের দুটো": only which ones — the same removal.
    final onlySel = selectionIn(' ${fold(rest).replaceAll(RegExp(r'[।!?]'), ' ')} ');
    if ((again == null || again.isEmpty) && onlySel != null && onlySel.kind != SelKind.all) again = [BulkAction(t, selection: onlySel, op: 'delete', domain: p.set.domain)];
    if (again != null && again.isNotEmpty) {
      final s = again.first.selection;
      final narrowing = s.kind == SelKind.all && s.hasExcept && again.first.op == 'show';
      // "তালিকা দাও" while a removal waits: to see — never a removal of
      // everything waiting. The question is set aside, nothing removed.
      if (again.first.op == 'show' && !narrowing && s.kind == SelKind.all) {
        _pendingBulk = null;
        wait = ChatWait.none;
        choices = const [];
        messages.add(ChatMessage.app(tr('মোছার প্রশ্নটা বাদ দিলাম — কিছু মোছা হয়নি।'), info: true));
        return false;
      }
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
      await _continuePlan(out);
      return true;
    }
    _say(out, tr('ঠিক আছে, কিছু মুছিনি।'));
    await _continuePlan(out);
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
        // What is left of the list that was shown, said with it.
        final leftIds = [for (final id in set.ids) if (_taskById(id) case final x? when !x.done) id];
        final left = leftIds.length;
        // The list shown is now what is left, in the same order: "৩নং" next
        // means the third of these — shown with the answer.
        final shownLeft = [for (final id in _shownTasks) if (_taskById(id) case final x? when !x.done) id];
        if (_shownTasks.isNotEmpty) {
          _shownTasks = shownLeft;
          _shownAt = _now;
        }
        final numbered = _shownTasks.isNotEmpty ? shownLeft : leftIds;
        _say(out, _outcome(trf('{0}টা {1} মুছে দিয়েছি', [bnDigits(ok - series), noun]), ok, ids.length, failed, skipped) + (series > 0 ? trf(' {0}টা নিয়মিত কাজের শুধু এবারেরটা বাদ দিয়েছি — পুরো সিরিজ আছে।', [bnDigits(series)]) : '') + (left > 0 ? trf(' তালিকার বাকি {0}টা আছে।', [bnDigits(left)]) : ''),
            facts: left > 0 && numbered.length <= 10 ? [for (final (i, id) in numbered.indexed) '${bnDigits(i + 1)}. ${taskLine(_taskById(id)!, _now)}'] : const [],
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
        (DateTime, TaskSpan)? movedTo;
        await each((id) async {
          final t = _taskById(id)!;
          if (t.repeat != null) {
            repeating++;
            return false;
          }
          // "এগুলো জুন মাসে" with no year: each in its own year's June
          // ("২০৪১ সালের মে" → জুন ২০৪১), never pulled to this year.
          var due = c.due!;
          if (c.span == TaskSpan.month && !c.yearSaid && t.due != null && t.due!.year > due.year) {
            due = DateTime(t.due!.year, due.month);
          }
          // Already on that day (a retry): not changed again.
          if (t.due != null && t.span == c.span && dayOnly(t.due!) == due) return false;
          await brain.saveTask(t.copyWith(due: due, span: c.span));
          movedTo = (due, c.span);
          // Its reminder goes with it — no alarm left on the old day.
          final rid = t.reminderId;
          final r = rid == null ? null : d.reminders.where((x) => x.id == rid).firstOrNull;
          if (r != null && r.repeat == Repeat.none && c.span == TaskSpan.day) await brain.saveReminder(r.copyWith(date: c.due));
          return true;
        });
        _say(
            out,
            _outcome(trf('{0}টা {1} {2} রেখেছি', [bnDigits(ok), noun, c.span == TaskSpan.month ? trf('{0} {1}-এর যেকোনো সময়', [bnMonths[(movedTo?.$1 ?? c.due!).month - 1], bnDigits((movedTo?.$1 ?? c.due!).year)]) : sayWhen(c.due!, _now, withTime: false)]), ok, ids.length - repeating, failed, skipped) +
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
                (brain.scheduleFailed ? tr(' তবে ফোনে সেট করা যায়নি — এখনো বাজবে না।') : (on ? '' : tr(' তবে ফোনে অ্যাপের নোটিফিকেশন বন্ধ — এখন বাজবে না।'))),
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

  /// "মে মাসে যুক্ত কর", "কাজ গুলো মে মাসে রাখো" right after a list of
  /// to-dos was kept: those to-dos, moved to that month (of their own year)
  /// or day — never a note or a new account named "মে".
  Future<bool> _batchWhenFor(String t, List<String> out) async {
    final b = _batchTasks;
    if (b == null || b.$3 < _turn - 3) return false;
    final f = ' ${fold(normalize(tidySpeech(t))).replaceAll(RegExp(r'[।,!?]'), ' ')} ';
    if (!RegExp(fold(r'(?:যুক্ত|যোগ|রাখ|সরা|নিয়ে\s+যা|দাও|দিন|করো|কর\s|লিখ|বসাও)')).hasMatch(f)) return false;
    final tasks = [for (final id in b.$1) ..._maybe(id)].where((x) => !x.done).toList();
    if (tasks.isEmpty) return false;
    final months = bnMonths.map(fold).toList();
    final mo = RegExp('(?<=\\s)(${months.join('|')})(?:\\s+${fold('মাস')}\\S*|${fold('ের')}|${fold('এর')}|${fold('ে')}|${fold('তে')})?(?=\\s)').firstMatch(f);
    DateTime? due;
    var span = TaskSpan.day;
    final hasDayNum = RegExp(r'(?<=\s)[0-9০-৯]{1,2}(?:\s|$)').hasMatch(f);
    final yearSaid = RegExp(r'[0-9০-৯]{4}').firstMatch(f);
    if (mo != null && !hasDayNum) {
      final mi = months.indexOf(mo[1]!) + 1;
      // The to-dos' own year ("২০৪১ সালের" kept before), unless one is said.
      final own = tasks.first.due?.year;
      var y = yearSaid != null ? int.parse(asciiDigits(yearSaid[0]!)) : (own != null && own > _now.year ? own : _now.year);
      if (yearSaid == null && own == null && mi < _now.month) y++;
      due = DateTime(y, mi, 1);
      span = TaskSpan.month;
    } else {
      final w = parseWhen(tidySpeech(t), _now);
      if (w == null || !w.hasDay) return false;
      due = dayOnly(w.day);
    }
    // Only the when, the verb and words for "these to-dos".
    final rest = f
        .replaceAll(mo == null ? RegExp(r'^$') : RegExp(RegExp.escape(mo[0]!)), ' ')
        .replaceAll(RegExp(fold(r'(?<=\s)(?:কাজ\s*(?:গুলো|গুলা|গুলি)?|এগুলো|এগুলা|ওগুলো|সব|সবগুলো|এই|ওই|তালিকা\S*|লিস্ট\S*|যুক্ত|যোগ|কর|করো|করে|দাও|দিন|রাখো|রাখ|রেখে|সরাও|সরিয়ে|লিখো|লিখে|বসাও|মধ্যে|মাসে|মাসের|সালের|সালে|তে|এ|এর)(?=\s)')), ' ')
        .replaceAll(RegExp(r'[0-9০-৯]+'), ' ')
        .trim();
    if (rest.isNotEmpty && mo != null) return false;
    if (mo == null && withoutWhen(rest).trim().isNotEmpty) return false;
    final snap = brain.snapshot();
    for (final x in tasks) {
      await brain.saveTask(x.copyWith(due: due, span: span));
    }
    final when = span == TaskSpan.month ? (due.year == _now.year ? trf('{0} মাসে', [monthName(due.month)]) : trf('{0} {1}-এ', [monthName(due.month), bnDigits(due.year)])) : sayWhen(due, _now, withTime: false);
    _say(out, trf('ঠিক আছে, {0}টা কাজ {1} রাখলাম।', [bnDigits(tasks.length), when]), facts: [for (final x in tasks) x.title], links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
    _offerUndo(snap);
    return true;
  }

  /// A separate account (অন্যান্য হিসাব) by name: "শিক্ষার্থীদের বেতনের
  /// হিসাব রাখো নাই?" (none yet: offered), "শিক্ষার্থীদের বেতনের জন্যে একটি
  /// হিসাব বিভাগ দরকার" (opened), "অন্যান্য হিসাবে তা খুলো" (the one just
  /// asked about). Never the পাওনা-দেনা total.
  Future<bool> _accountTalk(String t, List<String> out) async {
    final f = fold(normalize(tidySpeech(t))).replaceAll(RegExp(r'[?？।!,]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    String clean(String x) {
      var ws = x.trim().split(' ').where((w) => w.isNotEmpty).toList();
      ws = ws.where((w) => !RegExp(fold(r'^(?:আমার|আমাদের|এই|ওই|একটি|একটা|একটা|আলাদা|নতুন|নামে|নামের|নামক|নামেই)$')).hasMatch(w)).toList();
      if (ws.isEmpty) return '';
      final last = ws.last;
      if (!RegExp(fold(r'দের$')).hasMatch(last)) ws[ws.length - 1] = last.replaceFirst(RegExp(fold(r'(?:ের|এর)$')), '');
      return ws.join(' ');
    }
    bool ok(String name) {
      if (name.isEmpty || name.length < 3) return false;
      // "অন্যান্য হিসাব খোলো": the page itself, never an account named অন্যান্য.
      if (RegExp(fold(r'^(?:অন্যান্য|অন্য|আলাদা|নতুন|সব|এই|ওই|আমার|হিসাব|হিসেব)(?:\s+(?:অন্যান্য|হিসাব|হিসেব))*$')).hasMatch(name)) return false;
      // Not a person in the লেনদেন book, nor the book's own words.
      if (RegExp(fold(r'(?:^|\s)(?:পাওনা|দেনা|লেনদেন|আয়|ব্যয়|খরচ|মাসের|আজকের|কালকের|সব|মোট|ব্যাংক|বিকাশ|নগদ)(?:\s|$)')).hasMatch(name)) return false;
      return !brain.data.ledger.any((e) => fold(normalize(e.person)) == name);
    }
    final fresh = _accountWanted != null && _now.difference(_accountWanted!.$2).inMinutes <= 15;
    // "অন্যান্য হিসাবে তা খুলো", "আলাদা হিসাব খুলে দাও" — the one just asked about.
    final openIt = RegExp(fold(r'^(?:(?:অন্যান্য|আলাদা)\s+হিস(?:া|ে)ব(?:ে|ের)?\s+)?(?:(?:তা|এটা|ওটা|সেটা|সেটি|এটি)\s+)?(?:খুলো|খোলো|খুলে\s+দাও|খুলে\s+দিন|খুলুন|খুলে\s+দেও|খুলে\s+রাখো|খোল)$')).firstMatch(f);
    if (openIt != null && fresh && RegExp(fold(r'(?:অন্যান্য|আলাদা|তা|এটা|ওটা|সেটা)')).hasMatch(f)) {
      await _openAccount(_accountWanted!.$1, out);
      return true;
    }
    // "<X>-এর জন্যে একটি হিসাব বিভাগ দরকার / খুলে দাও".
    final need = RegExp(fold(r'^(.+?)\s+(?:এর\s+)?(?:জন্যে|জন্য|জন্যও)\s+(?:একটি\s+|একটা\s+|আলাদা\s+|নতুন\s+)*(?:হিসাব|হিসেব|অ্যাকাউন্ট)(?:\s+(?:বিভাগ|খাতা|পাতা))?\s+(?:দরকার|লাগবে|চাই|খোলো|খুলো|খুলে\s+দাও|খুলুন|বানাও|করো|করে\s+দাও)$')).firstMatch(f);
    if (need != null) {
      final name = clean(need[1]!.replaceFirst(RegExp(fold(r'(?:ের|এর)$')), ''));
      if (!ok(name)) return false;
      final known = projectByName(brain.data, name) ?? projectMeant(brain.data, name);
      if (known != null) {
        _say(out, trf('‘{0}’ নামে হিসাব আগেই খোলা আছে — অন্যান্য হিসাবে পাবেন।', [known.name]), links: [ChatLink(LinkKind.page, tr('অন্যান্য হিসাব'), page: 'projects')]);
        return true;
      }
      await _openAccount(name, out);
      return true;
    }
    // "অন্যান্য হিসাবে শিক্ষার্থীদের বেতনের একটা হিসাব খোলো": that account.
    final make = RegExp(fold(r'^(?:(?:অন্যান্য|আলাদা)\s+হিস(?:া|ে)ব(?:ে|ের\s+(?:মধ্যে|ভেতরে|ভিতরে))?\s+)?(.+?)\s+(?:(?:একটি|একটা|নতুন|আলাদা)\s+)*(?:হিসাব|হিসেব|অ্যাকাউন্ট|খাতা)\s+(?:খোলো|খুলো|খুলে\s+দাও|খুলে\s+দিন|খুলুন|খোল|বানাও|বানিয়ে\s+দাও|তৈরি\s+করো|তৈরি\s+করে\s+দাও|চালু\s+করো)$')).firstMatch(f);
    if (make != null) {
      final name = clean(make[1]!);
      if (ok(name) && name.split(' ').length <= 4) {
        final known = projectByName(brain.data, name) ?? projectMeant(brain.data, name);
        if (known != null) {
          _say(out, trf('‘{0}’ নামে হিসাব আগেই খোলা আছে — অন্যান্য হিসাবে পাবেন।', [known.name]), links: [ChatLink(LinkKind.page, tr('অন্যান্য হিসাব'), page: 'projects')]);
          return true;
        }
        await _openAccount(name, out);
        return true;
      }
    }
    // "<X>-এর হিসাব রাখো নাই?" — none yet: offered; one there: shown.
    final ask = RegExp(fold(r'^(.+?)\s+(?:হিসাব|হিসেব)(?:টা|টি)?\s+(?:রাখো\s*(?:নাই|নেই|নি|না)|রাখোনি|রাখোনাই|রাখোনেই|রাখ\s*(?:নাই|নেই)|রাখছ\s*না|নাই|নেই|আছে\s*(?:কি|কিনা)?|কোথায়|কই)$')).firstMatch(f);
    if (ask != null) {
      final name = clean(ask[1]!);
      if (!ok(name) || name.split(' ').length > 4) return false;
      // A খাত ("বাজারের হিসাব আছে?") or a person is not an account.
      if ([...knownCategories(brain.data, CashKind.expense), ...knownCategories(brain.data, CashKind.income)].map((c) => fold(normalize(c))).contains(name)) return false;
      final known = projectByName(brain.data, name) ?? projectMeant(brain.data, name);
      if (known != null) return false; // the account's own answer (its entries) comes from the usual rules
      _accountWanted = (name, _now);
      _ask(out, trf('‘{0}’ নামে আলাদা কোনো হিসাব এখনো নেই। অন্যান্য হিসাবে ‘{0}’ খুলে দিই?', [name]), ChatWait.newAccount, choices: [ChatChoice(tr('হ্যাঁ, খুলে দাও'), 'হ্যাঁ'), ChatChoice(tr('না'), 'না')]);
      return true;
    }
    return false;
  }

  /// "বাজার কি ৫০০০?": a doubt about an amount — checked against what is
  /// written today under that খাত (or its words), never a search of phone
  /// numbers.
  bool _amountDoubt(String t, List<String> out) {
    final f = fold(normalize(t)).replaceAll(RegExp(r'[?？।!]'), ' ').trim();
    final m = RegExp(fold(r'^(\S+(?:\s+\S+)?)\s+(?:কি|কী)\s+([০-৯0-9][০-৯0-9,]*)\s*(?:টাকা)?(?:\s+(?:ছিল|হয়েছে|হয়েছে|লিখেছ|লিখলা|রাখলা|রাখছ))?$')).firstMatch(f);
    if (m == null) return false;
    final word = m[1]!.replaceFirst(RegExp(fold(r'(?:ে|এ|ের|এর)$')), '');
    final said = int.tryParse(asciiDigits(m[2]!).replaceAll(',', ''));
    if (said == null || word.length < 2) return false;
    final today = dayOnly(_now);
    final hits = [
      for (final e in brain.data.cash)
        if (!e.date.isBefore(today.subtract(const Duration(days: 1))) && (fold(normalize(e.category)).startsWith(word) || fold(normalize(e.note)).contains(word))) e
    ];
    if (hits.isEmpty) {
      _say(out, trf('“{0}” খাতে আজ কোনো খরচ লেখা নেই। রাখতে চাইলে বলুন, যেমন “{0} {1} টাকা খরচ”।', [m[1]!, bnNumber(said)]));
      return true;
    }
    final e = hits.last;
    _say(out, e.amount == said
        ? trf('হ্যাঁ, {0} — {1} টাকা লেখা আছে ({2})।', [e.category, bnNumber(e.amount), shortDate(e.date)])
        : trf('না — {0} লেখা আছে {1} টাকা ({2}), {3} নয়। ভুল হলে বলুন “{0} {3} টাকা হবে”।', [e.category, bnNumber(e.amount), shortDate(e.date), bnNumber(said)]),
        links: [ChatLink(LinkKind.cash, tr('আয়-ব্যয় দেখুন'))]);
    return true;
  }

  Future<void> _openAccount(String name, List<String> out) async {
    _accountWanted = null;
    final known = projectByName(brain.data, name);
    if (known != null) {
      _say(out, trf('‘{0}’ নামে হিসাব আগেই খোলা আছে।', [known.name]), links: [ChatLink(LinkKind.page, tr('অন্যান্য হিসাব'), page: 'projects')]);
      return;
    }
    if (!brain.canAddProject) {
      _say(out, tr('নতুন অন্যান্য হিসাব খোলা প্রিমিয়াম সুবিধা — প্রিমিয়াম চালু করলে খুলে দিতে পারব।'), links: [ChatLink(LinkKind.page, tr('প্রিমিয়াম ভার্সন'), page: 'pro')]);
      return;
    }
    final snap = brain.snapshot();
    await brain.projectNamed(name);
    _actions++;
    _say(out, trf('খুলে দিলাম — অন্যান্য হিসাবে ‘{0}’। এখন বলুন, যেমন “মাহি ২০০০ টাকা দিয়েছে, {0} হিসাবে”।', [name]), links: [ChatLink(LinkKind.page, tr('অন্যান্য হিসাব'), page: 'projects')]);
    _offerUndo(snap);
  }

  /// "২০৪১ সালের প্রতিটি কাজের রিমাইন্ডার দাও, সকাল ১১ টায়": a reminder
  /// for each of those to-dos at that time on its own day (a to-do for a
  /// whole month or year: its first day, said so).
  Future<bool> _eachTaskReminder(String t, List<String> out) async {
    final f = ' ${fold(normalize(tidySpeech(t))).replaceAll(RegExp(r'[।,!?]'), ' ')} ';
    if (!RegExp(fold(r'(?<=\s)(?:প্রতিটি|প্রতিটা|প্রত্যেকটি|প্রত্যেকটা|প্রত্যেক|সব|সবগুলো|সকল)\s+কাজ(?:ের|ে|গুলোর|গুলোতে)?\s+(?:রিমাইন্ডার|এলার্ম|অ্যালার্ম|মনে)')).hasMatch(f)) return false;
    final w = parseWhen(tidySpeech(t), _now);
    if (w == null || !w.hasTime) return false;
    final open = [for (final x in brain.data.tasks) if (!x.done) x];
    final year = RegExp(r'([0-9০-৯]{4})\s*' + fold('সাল')).firstMatch(f);
    final months = bnMonths.map(fold).toList();
    final mo = RegExp('(?<=\\s)(${months.join('|')})(?=\\s|${fold('ের')}|${fold('মাস')})').firstMatch(f);
    List<Task> pick;
    if (year != null || mo != null) {
      final y = year == null ? null : int.parse(asciiDigits(year[1]!));
      final m = mo == null ? null : months.indexOf(mo[1]!) + 1;
      pick = [for (final x in open) if (x.due != null && (y == null || x.due!.year == y) && (m == null || x.due!.month == m)) x];
    } else if (w.hasDay) {
      pick = [for (final x in open) if (x.due != null && x.span == TaskSpan.day && dayOnly(x.due!) == dayOnly(w.day)) x];
    } else {
      final b = _batchTasks;
      final set = _sets.where((x) => x.domain == 'tasks' && _setFresh(x)).lastOrNull;
      final ids = b != null && b.$3 >= _turn - 3 ? b.$1 : (set?.ids ?? const <String>[]);
      pick = [for (final id in ids) ..._maybe(id)].where((x) => !x.done).toList();
    }
    if (pick.isEmpty) {
      _say(out, tr('কোন কাজগুলোর কথা বলছেন, খুঁজে পেলাম না — যেমন বলুন “কালকের প্রতিটি কাজের রিমাইন্ডার দাও, সকাল ৯টায়”।'));
      return true;
    }
    // A month or a year with no day: the day is asked, never its first day taken.
    final spans = [for (final x in pick) if (x.due != null && x.span != TaskSpan.day) x];
    if (spans.isNotEmpty && spans.length == pick.length && spans.every((x) => x.span == TaskSpan.month && dayOnly(x.due!) == dayOnly(spans.first.due!))) {
      _spanRemind = ([for (final x in spans) x.id], w.at.hour * 60 + w.at.minute, dayOnly(spans.first.due!));
      final m = spans.first.due!;
      _ask(out, trf('এই {0}টা কাজ {1} {2}-এর, নির্দিষ্ট দিন নেই। {1} মাসের কত তারিখে {3}-এ মনে করাব?', [bnDigits(spans.length), monthName(m.month), bnDigits(m.year), bnTime(w.at.hour, w.at.minute)]), ChatWait.taskDate);
      return true;
    }
    final snap = brain.snapshot();
    final kept = <String>[];
    var past = 0, firstDay = false;
    for (final x in pick) {
      final d = x.due ?? dayOnly(_now);
      if (x.span != TaskSpan.day) firstDay = true;
      final at = DateTime(d.year, d.month, d.day, w.at.hour, w.at.minute);
      if (!at.isAfter(_now)) {
        past++;
        continue;
      }
      final r = Reminder(title: x.title, date: dayOnly(at), hour: at.hour, minute: at.minute, daysBefore: 0);
      await brain.saveReminder(r);
      await brain.saveTask(x.copyWith(reminderId: r.id));
      kept.add('${x.title} — ${sayWhen(at, _now)}');
    }
    final time = bnTime(w.at.hour, w.at.minute);
    final note = [
      if (firstDay) tr('যেগুলোর নির্দিষ্ট দিন নেই, সেগুলো মাস/বছরের প্রথম দিনে রাখলাম।'),
      if (past > 0) trf('{0}টার সময় পেরিয়ে গেছে, ওগুলোতে দিইনি।', [bnDigits(past)]),
      if (brain.scheduleFailed) tr('তবে ফোনে সেট করা যায়নি — এখনো বাজবে না।'),
    ].join(' ');
    _say(out, '${trf('ঠিক আছে, {0}টা কাজের রিমাইন্ডার {1}-এ রাখলাম।', [bnDigits(kept.length), time])}${note.isEmpty ? '' : ' $note'}', facts: kept, links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন'))]);
    _offerUndo(snap);
    return true;
  }

  /// A reminder for each of [ids] at [minutes] after midnight on [day].
  Future<void> _remindTasksOn(List<String> ids, int minutes, DateTime day, List<String> out) async {
    final at = DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
    if (!at.isAfter(_now)) {
      _say(out, trf('{0} তো পার হয়ে গেছে — কিছু রাখিনি।', [sayWhen(at, _now)]));
      return;
    }
    final snap = brain.snapshot();
    final kept = <String>[];
    for (final id in ids) {
      final x = _taskById(id);
      if (x == null || x.done) continue;
      final r = Reminder(title: x.title, date: dayOnly(at), hour: at.hour, minute: at.minute, daysBefore: 0);
      await brain.saveReminder(r);
      await brain.saveTask(x.copyWith(reminderId: r.id));
      kept.add(x.title);
    }
    _say(out, '${trf('ঠিক আছে, {0}টা কাজের রিমাইন্ডার {1}-এ রাখলাম।', [bnDigits(kept.length), sayWhen(at, _now)])}${brain.scheduleFailed ? ' ${tr('তবে ফোনে সেট করা যায়নি — এখনো বাজবে না।')}' : ''}',
        facts: kept, links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন'))]);
    _offerUndo(snap);
  }

  Future<bool> _batchTimeAnswer(String t, List<String> out) async {
    final part = _batchPart;
    final own = parseWhen(t, _now);
    if (own == null || !own.hasTime) {
      if (_looksNew(t)) {
        wait = ChatWait.none;
        _batchPart = null;
        _planRest = null;
        return false;
      }
      _say(out, tr('সময়টা ধরতে পারিনি। যেমন বলুন “১টায়” বা “দুপুর ১টায়”।'));
      return true;
    }
    final w = part != null && !saysDayPart(t) ? parseWhen('$part $t', _now) : own;
    wait = ChatWait.none;
    _batchPart = null;
    await _batchRemindAt(w!.at.hour * 60 + w.at.minute, out);
    // "৮নং বাদ দাও এবং ৭নং এ রিমাইন্ডার দাও": the removal waited for the time.
    await _continuePlan(out);
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
