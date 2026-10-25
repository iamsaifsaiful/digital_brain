// The to-do list in conversation: which to-do "ওটা", "দ্বিতীয়টা" or "বিলের
// কাজটা" means, asking only when two fit, and doing the change at once —
// added, ticked, moved, reminded — with "ফিরিয়ে নিন" to take it back.
// Only removing asks first (once).
part of 'chat.dart';

extension _TodoChat on ChatController {
  bool get _focusTaskFresh => _focusTaskAt != null && _now.difference(_focusTaskAt!).inMinutes <= 30;

  void _focusTask(Task t) {
    _focusTaskId = t.id;
    _focusTaskAt = _now;
  }

  Task? _taskById(String id) => brain.data.tasks.where((t) => t.id == id).firstOrNull;
  Iterable<Task> _maybe(String id) => brain.data.tasks.where((t) => t.id == id);

  /// The to-dos [r] can mean (more than one: ask which).
  List<Task> _refTasks(TaskRef r, {bool done = false}) {
    final all = brain.data.tasks;
    final pool = done ? all : all.where((t) => !t.done).toList();
    if (r.ids.isNotEmpty) return [for (final id in r.ids) ..._maybe(id)];
    if (r.index != null) {
      // The place in the list as it was shown (its ids, in that order) —
      // never a list sorted again now. No fresh list: nothing is guessed.
      if (!_shownFresh || _shownTasks.isEmpty) return const [];
      final ids = _shownTasks;
      final i = r.index! < 0 ? ids.length - 1 : r.index! - 1;
      if (i < 0 || i >= ids.length) return const [];
      return _maybe(ids[i]).where((t) => done || !t.done).toList();
    }
    if (r.terms.isNotEmpty) {
      final hit = tdMatch(pool, r.terms, open: !done);
      if (hit.isNotEmpty) {
        // The one being talked about wins a tie.
        final focus = _focusTaskFresh ? hit.where((t) => t.id == _focusTaskId).toList() : const <Task>[];
        return focus.isNotEmpty ? focus : hit;
      }
      // Words that name no to-do are never taken as "the one just talked
      // about" — another to-do must not be changed by mistake.
      return done ? tdMatch(all, r.terms, open: false) : const <Task>[];
    }
    if (r.it) {
      final f = _focusTaskFresh && _focusTaskId != null ? _taskById(_focusTaskId!) : null;
      if (f != null) return [f];
      final shown = _shownFresh ? [for (final id in _shownTasks) ..._maybe(id)] : const <Task>[];
      if (shown.length == 1) return shown;
    }
    return const [];
  }

  /// One to-do for [c], or null after asking which one (or saying none).
  Task? _oneTask(Command c, TaskRef r, List<String> out, {bool done = false}) {
    final found = _refTasks(r, done: done);
    if (found.length == 1) {
      _lastPicked = [found.single.id];
      return found.single;
    }
    if (found.isEmpty) {
      if (r.terms.isNotEmpty) {
        _say(out, trf('“{0}” — এমন কোনো কাজ তালিকায় পেলাম না।', [r.terms.join(' ')]), links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
        return null;
      }
      final open = openTasksOf(brain.data, _now);
      if (open.isEmpty) {
        _say(out, tr('কাজের তালিকায় এখন কোনো কাজ নেই।'));
        return null;
      }
      _todoWaiting = c;
      _todoChoices = open.take(6).toList();
      // "কাল রাখো" with no to-do being talked about: which one is asked.
      final q = c is TaskEdit && c.due != null ? trf('কোন কাজটি {0} রাখব?', [sayWhen(c.due!, _now, withTime: false)]) : tr('আপনি কোন কাজটির কথা বলছেন?');
      _ask(out, q, ChatWait.whichTask, choices: [for (final t in _todoChoices) ChatChoice(t.title, t.title)]);
      return null;
    }
    _todoWaiting = c;
    _todoChoices = found.take(6).toList();
    final q = found.length == 2 ? trf('“{0}”, নাকি “{1}”?', [found[0].title, found[1].title]) : trf('কোনটা? — {0}', [nameList([for (final t in _todoChoices) t.title], unit: 'টা')]);
    _ask(out, q, ChatWait.whichTask, choices: [for (final t in _todoChoices) ChatChoice(t.title, t.title)]);
    return null;
  }

  /// The same request, now about [t] (after "কোনটা?").
  Command _withTask(Command c, Task t) {
    final r = TaskRef(ids: [t.id]);
    return switch (c) {
      TaskDone() => TaskDone(c.transcript, terms: const [], ref: r, done: c.done, partial: c.partial),
      TaskEdit() => TaskEdit(c.transcript,
          ref: r,
          title: c.title,
          due: c.due,
          span: c.span,
          clearDue: c.clearDue,
          shiftDays: c.shiftDays,
          urgent: c.urgent,
          note: c.note,
          remindAt: c.remindAt,
          remindHour: c.remindHour,
          remindMinute: c.remindMinute,
          remindNeedsTime: c.remindNeedsTime,
          remindAmPm: c.remindAmPm,
          stopReminder: c.stopReminder,
          skipOnce: c.skipOnce,
          delete: c.delete,
          keep: c.keep,
          say: c.say,
          weekday: c.weekday,
          newTitle: c.newTitle,
          dayOfMonth: c.dayOfMonth),
      _ => c,
    };
  }

  /// "আগামীকাল", "আগামী সপ্তাহে", "ডিসেম্বর মাসে", "প্রতি শুক্রবার", "তারিখ ছাড়া".
  String _whenOf(Task t) {
    final r = t.repeat;
    if (r != null) {
      return switch (r.kind) {
        'daily' => tr('প্রতিদিন'),
        'weekly' => trf('প্রতি {0}', [nameList([for (final d in r.weekdays) dayName(d)], unit: 'দিন')]),
        'monthly' => trf('প্রতি মাসের {0} তারিখে', [bnDigits(r.monthDay)]),
        _ => trf('{0} দিন পরপর', [bnDigits(r.every)]),
      };
    }
    if (t.due == null) return tr('তারিখ ছাড়া');
    final line = taskLine(t.copyWith(urgent: false), _now);
    final m = RegExp(r'\((.*)\)$').firstMatch(line);
    return m?[1] ?? '';
  }

  // ───────────────────────── Adding ─────────────────────────

  /// Kept at once: "“ব্যাংকে যাওয়া” কাজটি কাল (শনিবার) রেখেছি।"
  Future<void> _saveTaskAdd(TaskAdd c, List<String> out, {required bool quiet}) async {
    final deadline = c.by ?? (c.deadline ? c.due : null);
    // "ফ্যানটা ঠিক করাতে হবে" with no day: the home-fix list, told on days off.
    final fix = c.due == null && c.repeat == null && (isHomeFix(c.title) || isHomeFix(c.transcript));
    // "বাথরুমের কলটা নষ্ট হয়ে গেছে, ঠিক করানো" → "বাথরুমের কলটা ঠিক করানো".
    final title = fix ? c.title.replaceAll(RegExp(r'\s+(?:নষ্ট|ভেঙে|ভেঙ্গে)\s+(?:হয়ে|হয়ে)\s+(?:গেছে|গিয়েছে|গিয়েছে|আছে)\s*,?'), '').replaceAll(RegExp(r'\s+'), ' ').trim() : c.title;
    final t = Task(title: title, due: c.due, span: c.span, repeat: c.repeat, urgent: c.urgent, note: c.condition ?? '', deadline: deadline, createdAt: _now, list: fix ? homeFixList : '');
    await brain.saveTask(t);
    _focusTask(t);
    // "আজ বাজারে যাবো রাত ৯টায়": a clear clock time said with it rings
    // then (a reminder linked to the to-do). A bare hour is left alone.
    final ringAt = await _timeSaidWith(c, t);
    if (quiet) {
      _batchTaskTitles.add(c.title);
      return;
    }
    final when = _whenOf(t);
    final String text;
    if (c.repeat != null) {
      text = trf('{0} “{1}” — নিয়মিত কাজ হিসেবে রেখেছি। প্রথমবার {2}।', [when, c.title, sayWhen(t.due!, _now, withTime: false)]);
    } else if (c.deadline && c.due != null) {
      text = trf('“{0}” — {1}-এর মধ্যে করার কাজ হিসেবে রেখেছি।', [c.title, sayWhen(c.due!, _now, withTime: false)]);
    } else if (fix) {
      text = brain.flag('n_fix', true)
          ? trf('“{0}” ঘরের মেরামতের তালিকায় রাখলাম — ছুটির দিন সকালে মনে করিয়ে দেব।', [title])
          : trf('“{0}” ঘরের মেরামতের তালিকায় রাখলাম।', [title]);
    } else if (c.due == null) {
      text = c.condition != null || RegExp(fold(r'(?:একদিন|সময়\s+করে|সুযোগ)')).hasMatch(fold(c.transcript))
          ? trf('“{0}” কাজটি তারিখ ছাড়া কাজের তালিকায় রেখেছি।', [c.title])
          : trf('“{0}” কাজটি কাজের তালিকায় রেখেছি।', [c.title]);
    } else if (c.by != null) {
      text = trf('“{0}” কাজটি {1} কাজের তালিকায় রেখেছি; শেষ সময় {2}।', [c.title, when, sayWhen(c.by!, _now, withTime: false)]);
    } else {
      text = trf('“{0}” কাজটি {1} কাজের তালিকায় রেখেছি।', [c.title, when]);
    }
    final ring = ringAt == null ? '' : trf(' {0}-এ মনে করিয়ে দেব।', [bnTime(ringAt.hour, ringAt.minute)]);
    final cond = c.condition == null ? '' : trf(' “{0}” — এটা কখন হবে, অ্যাপ নিজে জানতে পারে না; হলে বলবেন, বা একটা সময় বললে মনে করিয়ে দেব।', [c.condition]);
    _say(out, text + ring + cond, links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
    _history.add(AiTurn.app('[কাজের তালিকায় রাখা হলো: ${c.title}]'));
  }

  /// The clock time said with a new to-do of one day, as a reminder linked
  /// to it — only when the time is clear (a part of the day or 24-hour
  /// form) and still ahead; null otherwise (nothing is set).
  Future<DateTime?> _timeSaidWith(TaskAdd c, Task t) async {
    if (c.repeat != null || c.span != TaskSpan.day || !brain.canAddReminder) return null;
    final w = parseWhen(c.transcript, _now);
    // A clock said ("রাত ৯টায়"), not only a part of the day ("কাল সকালে").
    if (w == null || !w.hasTime || !saysClock(c.transcript) || hourOpen(c.transcript, w.at.hour)) return null;
    final day = t.due ?? dayOnly(_now);
    final at = DateTime(day.year, day.month, day.day, w.at.hour, w.at.minute);
    if (!at.isAfter(_now)) return null;
    final r = Reminder(title: t.title, date: dayOnly(at), hour: at.hour, minute: at.minute, daysBefore: 0);
    await brain.saveReminder(r);
    await brain.saveTask(t.copyWith(reminderId: r.id));
    return at;
  }

  /// The same to-do, open, already on the list.
  Task? _sameTask(TaskAdd c) {
    if (c.repeat != null || c.condition != null) return null;
    final n = normalize(c.title);
    return brain.data.tasks.where((t) => !t.done && normalize(t.title) == n && (c.due == null || t.due == null || dayOnly(t.due!) == dayOnly(c.due!))).firstOrNull;
  }

  // ───────────────────────── Changing ─────────────────────────

  Future<void> _todo(Command c, List<String> out) async {
    final snap = brain.snapshot();
    var changed = false;
    switch (c) {
      case TaskRestore():
        final gone = brain.data.trash.where((x) => x.kind == 'tasks').lastOrNull;
        if (gone == null) {
          _say(out, tr('মুছে ফেলা কোনো কাজ ফেরত আনার মতো নেই।'));
          return;
        }
        await brain.restoreTrash(gone);
        _say(out, trf('“{0}” ফেরত এনেছি — কাজের তালিকায় আছে।', [gone.title]), links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
        changed = true;
      case TaskDone():
        changed = await _taskDoneTodo(c, out);
      case TaskEdit():
        changed = await _taskEdit(c, out);
      case ReminderSnooze():
        changed = await _snooze(c, out);
      default:
        return;
    }
    if (changed) {
      _actions++;
      _offerUndo(snap);
    }
  }

  Future<bool> _taskDoneTodo(TaskDone c, List<String> out) async {
    if (c.all) {
      // [TaskDone.partial] on "all" = the whole list was chosen.
      if (!c.allToday && c.partial) return _allDone(c, out, today: false);
      if (!c.allToday) {
        _clarifyOptions = [
          (tr('আজকের কাজগুলো'), TaskDone(c.transcript, terms: const [], all: true, allToday: true)),
          (tr('তালিকার সব কাজ'), TaskDone(c.transcript, terms: const [], all: true, allToday: false, done: true, partial: true)),
        ];
        _ask(out, tr('আজকের কাজগুলো, নাকি তালিকার সব কাজ?'), ChatWait.clarify, choices: [for (final o in _clarifyOptions) ChatChoice(o.$1, o.$1)]);
        return false;
      }
      return _allDone(c, out, today: true);
    }
    final ref = c.ref ?? TaskRef(terms: c.terms);
    final t = _oneTask(c, ref, out, done: !c.done);
    if (t == null) return false;
    _focusTask(t);
    final links = [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))];
    if (c.partial) {
      _say(out, trf('আংশিক অগ্রগতি আলাদা করে রাখার ব্যবস্থা এখনো নেই — “{0}” বাকি হিসেবেই রইল। পুরো হলে বলবেন।', [t.title]), links: links);
      return false;
    }
    if (!c.done) {
      if (t.done) {
        await brain.setTaskDone(t, false);
        _say(out, trf('“{0}” কাজটি আবার অসমাপ্ত করেছি।', [t.title]), links: links);
        return true;
      }
      _say(out, trf('ঠিক আছে, “{0}” কাজটি বাকি আছে।', [t.title]), links: links);
      return false;
    }
    if (t.done) {
      _say(out, trf('“{0}” আগেই শেষ হিসেবে টিক দেওয়া আছে।', [t.title]), links: links);
      return false;
    }
    await brain.setTaskDone(t, true);
    final now = _taskById(t.id);
    if (t.repeat != null && now?.due != null) {
      _say(out, trf('“{0}” — এবারেরটা সম্পন্ন করেছি। আবার {1}।', [t.title, sayWhen(now!.due!, _now, withTime: false)]), links: links);
    } else {
      final left = brain.data.tasks.where((x) => !x.done).length;
      _say(out, trf('“{0}” কাজটি সম্পন্ন করেছি।{1}', [t.title, left > 0 ? trf(' আর {0}টা কাজ বাকি।', [bnDigits(left)]) : tr(' সব কাজ শেষ!')]), links: links);
    }
    _history.add(AiTurn.app('[কাজ শেষ হিসেবে টিক দেওয়া হলো]'));
    return true;
  }

  Future<bool> _allDone(TaskDone c, List<String> out, {required bool today}) async {
    final tasks = today ? [for (final i in planItemsOn(brain.data, _now, _now)) if (i.task != null) i.task!] : openTasksOf(brain.data, _now);
    if (tasks.isEmpty) {
      _say(out, today ? tr('আজকের জন্য কোনো বাকি কাজ নেই।') : tr('কাজের তালিকায় কোনো বাকি কাজ নেই।'));
      return false;
    }
    for (final t in tasks) {
      await brain.setTaskDone(t, true);
    }
    _say(out, trf('{0} {1}টা কাজ শেষ হিসেবে টিক দিলাম — {2}।', [today ? tr('আজকের') : tr('তালিকার'), bnDigits(tasks.length), nameList([for (final t in tasks) t.title], unit: 'টা')]),
        links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
    return true;
  }

  Future<bool> _taskEdit(TaskEdit c, List<String> out) async {
    final links = [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))];
    // Only something to say ("কয়েক দিন বন্ধ রাখো" → how many days?).
    if (c.say != null && !c.remindNeedsTime) {
      if (!c.ref.isEmpty) {
        final f = _refTasks(c.ref);
        if (f.length == 1) _focusTask(f.single);
      }
      _say(out, tr(c.say!));
      return false;
    }
    // "…কাজটা কাল রাখো" and it is not on the list: kept as a new one.
    if (c.newTitle != null && _refTasks(c.ref).isEmpty) {
      _current = TaskAdd(c.transcript, title: c.newTitle!, due: c.due, span: c.span ?? TaskSpan.day);
      await _saveTaskAdd(_current as TaskAdd, out, quiet: false);
      _current = null;
      return true;
    }
    final t = _oneTask(c, c.ref, out);
    if (t == null) return false;
    _focusTask(t);
    if (c.keep) {
      _say(out, trf('ঠিক আছে, “{0}” কাজটি রেখেছি — কিছু মুছিনি।', [t.title]), links: links);
      return false;
    }
    if (c.delete) {
      _current = TasksClear(c.transcript, ids: [t.id]);
      _ask(out, trf('“{0}” কাজটি মুছে দেব?', [t.title]), ChatWait.yesNo, choices: ChatController._yesNoChoices);
      return false;
    }
    if (c.skipOnce) {
      if (t.repeat == null || t.due == null) {
        _say(out, trf('“{0}” নিয়মিত কাজ নয়। চাইলে অন্য দিনে সরাতে বলুন, বা মুছে দিতে বলুন।', [t.title]));
        return false;
      }
      final skipped = t.due!;
      await brain.skipTaskOnce(t);
      final next = _taskById(t.id)!.due!;
      // Its one-time reminder follows to the next time, never left on the skipped day.
      final rid = t.reminderId;
      final rem = rid == null ? null : brain.data.reminders.where((x) => x.id == rid && x.enabled && x.repeat == Repeat.none).firstOrNull;
      if (rem != null) await brain.saveReminder(rem.copyWith(date: dayOnly(next)));
      _say(out, trf('{0} বাদ দিয়েছি; পরেরবার {1}।', [sayWhen(skipped, _now, withTime: false), sayWhen(next, _now, withTime: false)]), links: links);
      return true;
    }
    if (c.stopReminder) {
      final rid = t.reminderId;
      final r = rid == null ? null : brain.data.reminders.where((x) => x.id == rid).firstOrNull;
      if (r == null || !r.enabled) {
        _say(out, trf('“{0}”-এর কোনো রিমাইন্ডার চালু নেই। কাজটি তালিকায় আছে।', [t.title]), links: links);
        return false;
      }
      await brain.switchOffReminder(r.id);
      _say(out, trf('রিমাইন্ডার বন্ধ করেছি; “{0}” কাজটি তালিকায় আছে।', [t.title]), links: links);
      return true;
    }
    if (c.remindNeedsTime || c.remindAt != null || c.remindHour != null) return _taskRemind(c, t, out);

    var n = t;
    final said = <String>[];
    if (c.title != null) {
      n = n.copyWith(title: c.title);
      // The old name said too: a number or a near name picked the right one.
      said.add(trf('“{0}”-এর নাম বদলে “{1}” করেছি', [t.title, c.title]));
    }
    if (c.weekday != null) {
      final base = t.span == TaskSpan.week && t.due != null ? t.due! : null;
      final day = base != null ? base.add(Duration(days: (c.weekday! - DateTime.saturday) % 7)) : (c.due ?? _nextWeekday(c.weekday!));
      n = n.copyWith(due: day, span: TaskSpan.day);
      said.add(trf('{0} রেখেছি', [sayWhen(day, _now, withTime: false)]));
    } else if (c.dayOfMonth != null && t.span == TaskSpan.month && t.due != null) {
      final last = DateTime(t.due!.year, t.due!.month + 1, 0).day;
      final day = DateTime(t.due!.year, t.due!.month, c.dayOfMonth! > last ? last : c.dayOfMonth!);
      n = n.copyWith(due: day, span: TaskSpan.day);
      said.add(trf('{0} রেখেছি', [sayWhen(day, _now, withTime: false)]));
    } else if (c.due != null) {
      n = n.copyWith(due: c.due, span: c.span ?? TaskSpan.day);
      said.add(trf('{0} রেখেছি', [_whenOf(n)]));
    }
    if (c.clearDue) {
      n = n.copyWith(clearDue: true);
      said.add(trf('তারিখ সরিয়েছি; “{0}” কাজটি তালিকায় আছে', [t.title]));
    }
    if (c.shiftDays != 0) {
      if (t.due == null) {
        _say(out, trf('“{0}”-এর কোনো তারিখ রাখা নেই — কবে রাখব বলুন।', [t.title]));
        return false;
      }
      final day = dayOnly(t.due!).add(Duration(days: c.shiftDays));
      n = n.copyWith(due: day, span: t.span);
      said.add(trf('নতুন তারিখ {0}', [sayWhen(day, _now, withTime: false)]));
    }
    if (c.urgent != null) {
      n = n.copyWith(urgent: c.urgent);
      said.add(c.urgent! ? tr('জরুরি হিসেবে রেখেছি') : tr('সাধারণ অগ্রাধিকার দিয়েছি'));
    }
    if (c.note != null && c.note!.isNotEmpty) {
      n = n.copyWith(note: t.note.isEmpty ? c.note : '${t.note}; ${c.note}');
      said.add(trf('সঙ্গে লিখেছি — {0}', [c.note]));
    }
    if (said.isEmpty) {
      _say(out, trf('“{0}” — কী বদলাব, ঠিক ধরতে পারিনি।', [t.title]));
      return false;
    }
    await brain.saveTask(n);
    // A new day: its reminder moves with it, at the same time.
    var also = '';
    final rid = t.reminderId;
    final r = rid == null ? null : brain.data.reminders.where((x) => x.id == rid && x.enabled).firstOrNull;
    if (r != null && n.due != t.due) {
      if (n.due == null) {
        await brain.switchOffReminder(r.id);
        also = tr(' এর রিমাইন্ডারটা বন্ধ করেছি।');
      } else {
        await brain.saveReminder(r.copyWith(date: dayOnly(n.due!)));
        also = trf(' রিমাইন্ডারও {0}-এ সরিয়েছি।', [sayWhen(DateTime(n.due!.year, n.due!.month, n.due!.day, r.hour, r.minute), _now)]);
      }
    }
    _say(out, trf('“{0}” — {1}।{2}', [t.title, said.join('; '), also]), links: links);
    _history.add(AiTurn.app('[কাজ বদলানো হলো: ${t.title}]'));
    return true;
  }

  DateTime _nextWeekday(int wd) {
    final today = dayOnly(_now);
    var ahead = (wd - today.weekday) % 7;
    if (ahead == 0) ahead = 7;
    return today.add(Duration(days: ahead));
  }

  /// A reminder for the to-do: on its day at the hour said, or at the
  /// moment said. Morning or night is asked when only "আটটায়" was said.
  Future<bool> _taskRemind(TaskEdit c, Task t, List<String> out) async {
    final day0 = c.due ?? (t.due != null && t.span == TaskSpan.day ? dayOnly(t.due!) : null);
    if (c.remindNeedsTime) {
      _todoWaiting = _withTask(c, t);
      final when = day0 == null ? '' : sayWhen(day0, _now, withTime: false);
      final q = c.say != null && c.say!.contains('{0}')
          ? trf(c.say!, [day0 == null ? tr('সকালে') : '$when ${_partWord(c.transcript)}'.trim()])
          : (c.say != null ? tr(c.say!) : trf('“{0}” — কখন মনে করিয়ে দেব? যেমন “{1}”।', [t.title, day0 == null || day0 == dayOnly(_now) ? tr('সন্ধ্যা ৭টায়') : '$when ${tr('সকাল ৯টায়')}']));
      _offerAsked = false;
      _offeredTime = c.say != null ? null : (day0 == null || day0 == dayOnly(_now) ? 'সন্ধ্যা ৭টায়' : 'সকাল ৯টায়');
      _ask(out, q, ChatWait.taskTime);
      return false;
    }
    // A plan for a coming week or month has no day to ring on: which day
    // is asked — never its first day taken as the day.
    if (c.remindAt == null && day0 == null && t.span != TaskSpan.day && t.due != null && dayOnly(t.due!).isAfter(dayOnly(_now))) {
      _todoWaiting = TaskEdit(c.transcript, ref: TaskRef(ids: [t.id]), remindNeedsTime: true);
      _ask(out, trf('“{0}” {1} রাখা, নির্দিষ্ট দিন নেই। কোন দিন কয়টায় মনে করাব?', [t.title, taskWhen(t, _now) ?? '']), ChatWait.taskTime);
      return false;
    }
    DateTime at;
    if (c.remindAt != null) {
      at = c.remindAt!;
    } else {
      final d = day0 ?? dayOnly(_now);
      at = DateTime(d.year, d.month, d.day, c.remindHour!, c.remindMinute);
      if (!at.isAfter(_now) && day0 == null) at = at.add(const Duration(days: 1));
    }
    if (c.remindAmPm) {
      final r = ampmReadings(at, _now, daySaid: day0 != null || c.remindAt != null);
      _clarifyOptions = [for (final x in r) (bnTime(x.hour, x.minute), TaskEdit(c.transcript, ref: TaskRef(ids: [t.id]), remindAt: x))];
      _ask(out, trf('{0}, নাকি {1}?', [bnTime(r[0].hour, r[0].minute), bnTime(r[1].hour, r[1].minute)]), ChatWait.clarify, choices: [for (final o in _clarifyOptions) ChatChoice(o.$1, o.$1)]);
      return false;
    }
    if (!at.isAfter(_now)) {
      _todoWaiting = TaskEdit(c.transcript, ref: TaskRef(ids: [t.id]), remindNeedsTime: true);
      _ask(out, trf('{0} তো পার হয়ে গেছে। কখন মনে করাব?', [sayWhen(at, _now)]), ChatWait.taskTime);
      return false;
    }
    await _setTaskReminder(t, at, out);
    return true;
  }

  String _partWord(String said) {
    final f = fold(said);
    for (final p in ['সকালে', 'দুপুরে', 'বিকেলে', 'সন্ধ্যায়', 'রাতে']) {
      if (f.contains(fold(p))) return p;
    }
    return '';
  }

  Future<void> _setTaskReminder(Task t, DateTime at, List<String> out) async {
    final rid = t.reminderId;
    final old = rid == null ? null : brain.data.reminders.where((x) => x.id == rid).firstOrNull;
    // A new reminder past the free limit: the to-do stays; said plainly.
    if (old == null && !brain.canAddReminder) {
      _say(out, trf('“{0}” কাজটি তালিকায় আছে, তবে রিমাইন্ডার চালু হয়নি — ফ্রিতে একসাথে {1}টা রিমাইন্ডার রাখা যায়। পুরোনো কোনোটা বন্ধ করুন, বা প্রিমিয়াম নিন।', [t.title, bnDigits(freeReminders)]),
          links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন')), ChatLink(LinkKind.page, tr('প্রিমিয়াম দেখুন'), page: 'pro')]);
      return;
    }
    final Reminder r;
    if (old != null) {
      r = old.copyWith(date: dayOnly(at), hour: at.hour, minute: at.minute, enabled: true);
    } else {
      r = Reminder(title: t.title, date: dayOnly(at), hour: at.hour, minute: at.minute, daysBefore: 0);
    }
    await brain.saveReminder(r);
    if (t.reminderId != r.id) await brain.saveTask(_taskById(t.id)!.copyWith(reminderId: r.id));
    _focusReminderId = r.id;
    _focusReminderAt = _now;
    // Kept, but this phone will not show it: said, never promised.
    if (brain.scheduleFailed) {
      _say(out, trf('“{0}”-এর রিমাইন্ডার রাখা হয়েছে ({1}), কিন্তু ফোনে সেট করা যায়নি — তাই এখনো বাজবে না। অ্যাপটা একবার বন্ধ করে খুলুন; তবু না হলে রিমাইন্ডার পাতা থেকে আবার চালু করুন।', [t.title, sayWhen(at, _now)]),
          links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন'))]);
      return;
    }
    if (!(await brain.services.notifier.health()).notificationsOn) {
      _say(out, trf('“{0}”-এর রিমাইন্ডার রাখা হয়েছে ({1}), কিন্তু এই ফোনে অ্যাপের নোটিফিকেশন বন্ধ — তাই এখন বাজবে না। ফোনের সেটিংস থেকে My Assistant-এর নোটিফিকেশন চালু করুন।', [t.title, sayWhen(at, _now)]),
          links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন'))]);
      return;
    }
    final text = old == null ? trf('{0}-এ মনে করিয়ে দেব।', [sayWhen(at, _now)]) : trf('“{0}” রিমাইন্ডারটি {1}-এ করেছি।', [t.title, sayWhen(at, _now)]);
    _say(out, text, links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন'))]);
    _history.add(AiTurn.app('[কাজের রিমাইন্ডার: ${t.title}]'));
  }

  // ───────────────────────── Answers to the app's questions ─────────────────────────

  /// "কোনটা?" / "কয়টায়?" answered. False when [t] is something new instead.
  Future<bool> _todoAnswer(String t, List<String> out) async {
    final pending = _todoWaiting;
    if (wait == ChatWait.whichTask) {
      final choices = _todoChoices;
      var pick = _pickIndex(t, [for (final c in choices) (c.title, '')]);
      if (pick == null) {
        final said = _tdWordsOf(t);
        var best = -1, bestScore = 0, tie = false;
        for (var i = 0; i < choices.length; i++) {
          final s = taskScore(choices[i], said);
          if (s > bestScore) {
            best = i;
            bestScore = s;
            tie = false;
          } else if (s == bestScore && s > 0) {
            tie = true;
          }
        }
        if (bestScore > 0 && !tie) pick = best;
      }
      if (pick == null) {
        if (_looksNew(t)) return false;
        _say(out, tr('কোনটা, ধরতে পারিনি — নিচ থেকে একটা বেছে নিন।'));
        return true;
      }
      wait = ChatWait.none;
      this.choices = const [];
      _todoWaiting = null;
      _todoChoices = const [];
      if (pending != null) await _todo(_withTask(pending, choices[pick]), out);
      return true;
    }
    if (wait == ChatWait.taskTime && pending is TaskEdit) {
      final said = tidySpeech(t);
      var w = parseWhen(said, _now);
      // "আটটায়" after "সকালে কয়টায়?": the morning that was said.
      final part = _partWord(pending.transcript);
      if (w != null && w.hasTime && part.isNotEmpty && !RegExp(fold(r'(?:সকাল|দুপুর|বিকেল|বিকাল|সন্ধ্যা|রাত)')).hasMatch(fold(said))) {
        w = parseWhen('$part $said', _now);
      }
      // "হ্যাঁ দাও", "ঠিক আছে", "ওই সময়েই দাও": the time just offered.
      // A bare "হ্যাঁ" is no time: the time offered is asked back once
      // ("সকাল ৯টায় রাখব?"); "হ্যাঁ দাও", "ঠিক আছে", "ওই সময়েই" take it.
      final offered = _offeredTime;
      final bare = RegExp(fold(r'^\s*(?:হ্যাঁ|হ্যা|হুম|জি|জ্বি|yes|ha|haa)\s*[।.!]?\s*$')).hasMatch(fold(normalize(t)));
      if ((w == null || !w.hasTime) && offered != null && bare && !_offerAsked) {
        _offerAsked = true;
        _ask(out, trf('{0} রাখব? “হ্যাঁ দাও” বলুন, বা অন্য সময় বলুন।', [tr(offered)]), ChatWait.taskTime);
        return true;
      }
      if ((w == null || !w.hasTime) && offered != null && (yesNo(t) == true || RegExp(fold(r'(?:^|\s)(?:ওই|ঐ|সেই|ওটাই|সেটাই)\s*(?:সময়ে?|সময়েই|টাইমে?)?')).hasMatch(fold(normalize(t))))) {
        w = parseWhen(offered, _now);
      }
      if (w == null || !w.hasTime) {
        if (_looksNew(t)) return false;
        _say(out, tr('সময়টা ধরতে পারিনি — যেমন বলুন “সকাল ৯টায়”।'));
        return true;
      }
      _offeredTime = null;
      _offerAsked = false;
      wait = ChatWait.none;
      _todoWaiting = null;
      final ids = pending.ref.ids;
      final task = ids.isEmpty ? null : _taskById(ids.first);
      if (task == null) return true;
      final d0 = pending.due ?? (task.due != null && task.span == TaskSpan.day ? dayOnly(task.due!) : null);
      final at = w.hasDay || d0 == null ? w.at : DateTime(d0.year, d0.month, d0.day, w.at.hour, w.at.minute);
      final snap = brain.snapshot();
      await _taskRemind(TaskEdit(pending.transcript, ref: TaskRef(ids: [task.id]), remindAt: at, remindAmPm: part.isEmpty && hourOpen(said, w.at.hour)), task, out);
      _offerUndo(snap);
      return true;
    }
    return false;
  }

  /// To-dos whose name is the reminder's subject: "নোয়াখালী যাওয়ার" →
  /// "নোয়াখালী যাওয়া".
  Iterable<Task> _taskNamedLike(String title) {
    String key(String x) => fold(normalize(x)).replaceAll(RegExp(fold(r'\s+(?:কাজ|কাজের|কাজটির|কাজটা|কাজটি)$')), '').replaceAll(RegExp(fold(r'(?:ের|এর|র)$')), '').trim();
    final k = key(title);
    if (k.isEmpty) return const [];
    return brain.data.tasks.where((x) => !x.done && key(x.title) == k);
  }

  List<String> _tdWordsOf(String t) => [for (final w in words(normalize(t))) if (w.length >= 2) stem(w).replaceAll(RegExp(fold(r'(?:ের|এর|র)$')), '')];

  /// "না, এগারোটায়" / "না, কাল নয়, পরশু" right after a to-do or its
  /// reminder was set: the same one, changed — never a new to-do.
  Future<bool> _todoCorrection(String t, List<String> out) async {
    if (await _taskDayFix(t, out)) return true;
    if (await _taskDateAdd(t, out)) return true;
    if (await _splitJustKept(t, out)) return true;
    final f = ' ${fold(t).replaceAll(RegExp(r'[।,!?]'), ' ')} ';
    if (!RegExp(fold(r'^\s*(?:না|নাহ|উহু|না\s+না)\s')).hasMatch(f) && !RegExp(fold(r'\s(?:নয়|না)\s+\S+(?:\s+\S+){0,3}\s*$')).hasMatch(f)) return false;
    // Only time words after the "না".
    final rest = f.replaceFirst(RegExp(fold(r'^\s*(?:না|নাহ|উহু|না\s+না)\s')), ' ');
    // "জানুয়ারির ১ তারিখে" → "১ জানুয়ারি": the date in the app's own words.
    final last = tidySpeech(rest.split(RegExp(fold(r'\s(?:নয়|না)\s'))).last);
    final w = parseWhen(last, _now);
    if (w == null) return false;
    // "১৫ জুন ২০২৯ হবে": the year is part of the date, not a word left over.
    final leftover = words(normalize(withoutWhen(withoutClockWords(last)))).where((x) => !const ['টায়', 'করো', 'দাও', 'রাখো', 'হবে', 'করব', 'বরং', 'সালে', 'সালের', 'সাল'].map(normalize).contains(x) && !RegExp(r'^[0-9০-৯]{4}$').hasMatch(x));
    if (leftover.isNotEmpty) return false;
    final snap = brain.snapshot();
    // The reminder just set: a new time or day ("না, এগারোটায়", "না, কাল").
    if (_focusReminderId != null && _focusReminderAt != null && _now.difference(_focusReminderAt!).inMinutes <= 10) {
      final r = brain.data.reminders.where((x) => x.id == _focusReminderId).firstOrNull;
      if (r != null && (w.hasTime || w.hasDay)) {
        var d = w.hasDay ? w.day : r.date;
        // "কাল না, ১৫ জুনে" for "নোয়াখালী যাওয়ার রিমাইন্ডার": no year said —
        // the year of the to-do of that name on that day, if one is kept.
        if (w.hasDay && !RegExp(r'[০-৯0-9]{4}').hasMatch(last)) {
          final named = _taskNamedLike(r.title).where((x) => x.due != null && x.due!.month == d.month && x.due!.day == d.day).firstOrNull;
          if (named != null) d = DateTime(named.due!.year, d.month, d.day);
        }
        var at = DateTime(d.year, d.month, d.day, w.hasTime ? w.at.hour : r.hour, w.hasTime ? w.at.minute : r.minute);
        // A bare hour ("না, চারটায় নয়, পাঁচটায়") keeps the half of the day
        // of the reminder being corrected: "বিকেল ৪টা" → বিকেল ৫টা,
        // "সকাল ১০টা" → সকাল ১১টা. A part said with it decides instead.
        if (w.hasTime && hourOpen(last, w.at.hour)) {
          final h12 = w.at.hour % 12;
          final pm = r.hour >= 12;
          at = DateTime(at.year, at.month, at.day, pm ? h12 + 12 : h12, at.minute);
        }
        final task = brain.data.tasks.where((x) => x.reminderId == _focusReminderId).firstOrNull;
        if (task != null) {
          await _setTaskReminder(task, at, out);
        } else {
          await brain.saveReminder(r.copyWith(date: dayOnly(at), hour: at.hour, minute: at.minute, enabled: true));
          _focusReminderAt = _now;
          _say(out, trf('“{0}” রিমাইন্ডারটি {1}-এ করেছি।', [r.title, sayWhen(at, _now)]), links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন'))]);
        }
        _offerUndo(snap);
        return true;
      }
    }
    // The to-do just added or moved: another day.
    if (w.hasDay && _focusTaskFresh && _focusTaskId != null && _now.difference(_focusTaskAt!).inMinutes <= 10) {
      final task = _taskById(_focusTaskId!);
      if (task == null) return false;
      await _taskEdit(TaskEdit(t, ref: TaskRef(ids: [task.id]), due: w.day), out);
      _offerUndo(snap);
      return true;
    }
    return false;
  }

  /// "যেকোন দিন কেন রাখবা, বলেছি ৬ তারিখ … সে তারিখে লেখো": the to-do just
  /// kept, on the day said (a day of the month alone is in the to-do's own
  /// month). Nothing else is ticked or added.
  Future<bool> _taskDayFix(String t, List<String> out) async {
    final id = _focusTaskId;
    if (id == null || !_focusTaskFresh || _now.difference(_focusTaskAt!).inMinutes > 10) return false;
    final f = ' ${fold(normalize(t))} ';
    final fixing = RegExp(fold(r'(?:বলেছি|বললাম|বলছি|কেন\s+রাখ|কেন\s+দিল|কেন\s+লিখ|যেকোন|যে\s+কোন|ভুল|সে\s+তারিখ|ওই\s+তারিখ|সেই\s+তারিখ|তারিখে\s+(?:লেখ|লিখ|রাখ|দাও|করো))')).hasMatch(f);
    if (!fixing) return false;
    final task = _taskById(id);
    if (task == null) return false;
    final months = bnMonths.map(fold).join('|');
    final dm = RegExp(r'(?:^|\s)(\d{1,2})\s*' + fold('তারিখ')).firstMatch(f);
    DateTime? day;
    if (dm != null && !RegExp('(?:$months)').hasMatch(f) && task.due != null) {
      final n = int.parse(dm[1]!);
      final base = task.due!;
      final d = DateTime(base.year, base.month, n);
      if (d.month == base.month) day = d;
    }
    if (day == null) {
      final w = parseWhen(tidySpeech(t), _now);
      if (w != null && w.hasDay) day = dayOnly(w.day);
    }
    if (day == null) return false;
    final snap = brain.snapshot();
    await brain.saveTask(task.copyWith(due: day, span: TaskSpan.day));
    _focusTask(task);
    _say(out, task.reminderId == null ? trf('ঠিক আছে, “{0}” {1} তারিখে রাখলাম — রিমাইন্ডার ছাড়া।', [task.title, sayWhen(day, _now, withTime: false)]) : trf('ঠিক আছে, “{0}” {1} তারিখে রাখলাম।', [task.title, sayWhen(day, _now, withTime: false)]),
        links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
    _offerUndo(snap);
    return true;
  }

  /// "এগুলো তিনটা আলাদা কাজ", "একটা না, পাঁচটা", "অনেকগুলো কাজ, একটা না":
  /// the to-do just kept was really several — it is split into them (same
  /// day), never a note or a new category.
  Future<bool> _splitJustKept(String t, List<String> out) async {
    final f = ' ${fold(normalize(t))} ';
    if (!RegExp(fold(r'(?:আলাদা\s+(?:আলাদা\s+)?(?:কাজ|করে|রাখো|রাখ)|অনেক\s*গুলো\s+কাজ|অনেকগুলা\s+কাজ|(?<=\s)(?:একটা|একটি|এক)\s+(?:না|নয়|নয়)(?=\s|,))')).hasMatch(f)) return false;
    final id = _focusTaskId;
    if (id == null || _focusTaskAt == null || _now.difference(_focusTaskAt!).inMinutes > 10) return false;
    final task = _taskById(id);
    if (task == null || task.done) return false;
    final last = _lastSave;
    final said = last != null && last.$1 is TaskAdd && (last.$1 as TaskAdd).title == task.title ? last.$1.transcript : task.title;
    // By commas and "আর/ও": "মাছ, চাল, তেল কেনা" → মাছ কেনা, চাল কেনা, তেল কেনা.
    // The words as said ("…, ডাল আর লবণ কেনা"), not the tidied title that
    // lost the "আর"; the order around them ("কাজের তালিকায় রাখো:") left out.
    var source = task.title;
    if (said != task.title) {
      final body = said
          .replaceFirst(RegExp(r'^\s*(?:আমার\s+)?কাজের\s+(?:তালিকা|লিস্ট)\S*\s+(?:লিখে\s+রাখো|রাখো|যোগ\s+করো|যুক্ত\s+করো|লেখো|লিখো|তুলে\s+রাখো)\s*[:：,—–-]?\s*'), '')
          .replaceFirst(RegExp(r'\s*[—–-]?\s*(?:এগুলো\s+)?কাজের\s+(?:তালিকা|লিস্ট)\S*\s+\S+(?:\s+\S+)?\s*[।.]?\s*$'), '')
          .trim();
      if (RegExp(r'[,،]').hasMatch(body)) source = body.replaceAll(RegExp(r'[।.!]+$'), '');
    }
    var pieces = [for (final x in source.split(RegExp(fold(r'\s*[,،;]\s*|\s+(?:আর|ও|এবং)\s+')))) if (x.trim().isNotEmpty) x.trim()];
    if (pieces.length >= 2) {
      final verb = pieces.last.split(' ').last;
      final isNoun = RegExp(fold(r'(?:া|ানো|ওয়া|য়া)$')).hasMatch(fold(verb)) && pieces.last.contains(' ');
      if (isNoun) pieces = [for (final (i, x) in pieces.indexed) i == pieces.length - 1 || x.split(' ').length > 1 ? x : '$x $verb'];
    } else {
      // Said in one breath: one piece per "I will" verb.
      final bare = withoutWhen(tidySpeech(said));
      final p = Parser(ledger: brain.data.ledger, tasks: brain.data.tasks, now: _now);
      pieces = [
        for (final x in splitByWillVerbs(bare))
          if (p.parse('${x.trim()} — কাজের তালিকায় লিখে রাখো') case final TaskAdd c when c.title.trim().isNotEmpty) c.title else x.trim(),
      ];
    }
    if (pieces.length < 2) {
      _say(out, trf('“{0}” কাজটা কোথায় ভাগ হবে বুঝতে পারিনি — কাজগুলোর নাম আলাদা করে বলুন, যেমন “মাছ কেনা, চাল কেনা”।', [task.title]));
      return true;
    }
    final snap = brain.snapshot();
    await brain.deleteTask(task.id);
    if (task.reminderId != null) await brain.deleteReminder(task.reminderId!);
    final made = <Task>[];
    for (final x in pieces) {
      final n = Task(title: x, due: task.due, span: task.span, createdAt: _now, list: task.list, urgent: task.urgent);
      await brain.saveTask(n);
      made.add(n);
    }
    _batchTasks = ([for (final x in made) x.id], '', _turn);
    _say(out, trf('ঠিক আছে — একটার বদলে {0}টা আলাদা কাজ রাখলাম{1}।', [bnDigits(made.length), task.due == null ? '' : ' — ${taskWhen(made.first, _now) ?? ''}']), facts: [for (final x in made) x.title], links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
    _offerUndo(snap);
    return true;
  }

  /// "পার্টির তারিখ যুক্ত কর" (with or without the date): that open to-do
  /// gets its day — asked when not said. Never a note.
  Future<bool> _taskDateAdd(String t, List<String> out) async {
    final f = fold(normalize(t));
    final m = RegExp(fold(r'^(.+?)\s+(?:তারিখ|দিন|ডেট)(?:টা|টি)?(?:\s+[^\s]+){0,3}?\s+(?:যুক্ত|যোগ|দাও|দিন|বসাও|লিখ|লেখ|ঠিক|সেট|করো|কর)')).firstMatch(f);
    if (m == null) return false;
    final name = m[1]!.replaceAll(RegExp(fold(r'(?:কাজের|কাজটার|কাজটির|এর|ের|র)$')), '').replaceAll(RegExp(fold(r'^(?:আমার|এই|ওই)\s+')), '').trim();
    if (name.isEmpty) return false;
    final open = [for (final x in brain.data.tasks) if (!x.done && fold(normalize(x.title)).contains(name)) x];
    if (open.isEmpty) return false;
    // The newest one by that name (the one just kept, usually).
    open.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final task = open.first;
    final w = parseWhen(tidySpeech(t), _now);
    if (w != null && w.hasDay) {
      await _setTaskDay(task, dayOnly(w.day), out);
      return true;
    }
    _dateTaskId = task.id;
    _ask(out, trf('“{0}” — কোন তারিখে রাখব? যেমন “৩১ অক্টোবর”।', [task.title]), ChatWait.taskDate);
    return true;
  }

  Future<void> _setTaskDay(Task task, DateTime day, List<String> out) async {
    final snap = brain.snapshot();
    await brain.saveTask(task.copyWith(due: day, span: TaskSpan.day));
    _focusTask(task);
    _say(out, trf('ঠিক আছে, “{0}” {1} তারিখে রাখলাম।', [task.title, sayWhen(day, _now, withTime: false)]), links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
    _offerUndo(snap);
  }

  /// A to-do answer was given: remember which ones were named, in order.
  void _rememberShown(TaskQuery q) {
    final s = q.scope;
    final list = s == null ? openTasksOf(brain.data, _now) : taskScopeAnswer(brain.data, s, _now).$2;
    _shownTasks = [for (final t in list) t.id];
    _shownAt = _now;
    // The same list as a result set: "এগুলো সব …" means exactly these.
    // On screen: up to 30 lines (the facts under the answer).
    if (list.length > 1 || (s != null && list.isNotEmpty)) {
      _rememberSet('tasks', _scopeLabel(q), _shownTasks, matching: list.length, shown: list.length > 30 ? 30 : list.length, source: q.transcript);
    }
    if (list.length == 1) _focusTask(list.single);
  }

  /// "না, পাঁচটায় নয়, ছয়টায়": only a "no" and time words.
  bool _onlyCorrection(String t) {
    final f = ' ${fold(t).replaceAll(RegExp(r'[।,!?]'), ' ')} ';
    if (!RegExp(fold(r'^\s*(?:না|নাহ|উহু)\s')).hasMatch(f)) return false;
    final w = parseWhen(f, _now);
    if (w == null) return false;
    final left = words(normalize(withoutWhen(withoutClockWords(f)))).where((x) => !const ['না', 'নাহ', 'উহু', 'নয়', 'বরং', 'হবে', 'টায়'].map(normalize).contains(x));
    return left.isEmpty;
  }

  /// What was just kept at once, changed or taken back by the next words.
  Future<bool> _afterSave(String t, List<String> out) async {
    final last = _lastSave;
    if (last == null || _now.difference(last.$3).inMinutes > 3) return false;
    final c = last.$1;
    if (c is! TaskAdd && c is! ReminderAdd) return false;
    final task = c is TaskAdd ? brain.data.tasks.where((x) => x.title == c.title).lastOrNull : null;
    final rem = c is ReminderAdd ? brain.data.reminders.where((x) => x.id == _focusReminderId).firstOrNull : null;
    if (task == null && rem == null) return false;
    // "তোমাকে না রে ভাই, তুবাকে" (owner's video, 25 Oct): one word of what
    // was kept is wrong — that word, swapped; nothing else changes.
    // Also "আমি বলি তুবা কে, তুমি শুনতেছো তোমাকে" (I say Y, you hear X) and
    // "না, এখানে হবে তুবা" (no, here it is Y — the word the app could not
    // have meant: "তোমাকে").
    final had = task?.title ?? rem!.title;
    final ft = fold(normalize(t));
    String? from, to;
    final m1 = RegExp(fold(r'^\s*(\S+)\s+না(?:[\s,]+(?:রে|ভাই|আপা|তো|গো|বাবা|ভাইয়া|আপু))*[\s,।]+(\S+(?:\s+(?:কে|রে|এর|র|ের))?)\s*[।.!]*$')).firstMatch(fold(t));
    final m2 = RegExp(fold(r'আমি\s+(?:বলি|বলছি|বলতেছি|বললাম|কইলাম|কই)\s+(\S+(?:\s+কে)?)\s+(?:আর\s+|কিন্তু\s+)?তুমি\s+(?:শুনতেছো|শুনতেছ|শুনছো|শুনছ|শুনলে|শুনো|শুনলা|লিখলে|লিখছো|লেখো|লিখলা)\s+(\S+)')).firstMatch(ft);
    final m3 = RegExp(fold(r'^\s*না[\s,]+(?:এখানে|ওখানে|এটা|ওটা|ওইখানে)\s+(?:হবে|হইবো|হবে\s+না)\s+(\S+(?:\s+কে)?)(?:\s+(?:কেন|কে|তো|না))?\s*$')).firstMatch(ft);
    // "সেখানে তুমি বলছো তোমাকে, আমি বলছি টোবা কে" (you say X, I say Y).
    final m2b = RegExp(fold(r'তুমি\s+(?:বলছো|বলছ|বলতেছো|বলতেছ|লিখছো|লিখতেছো|শুনছো|শুনতেছো|লিখলা|বললা)\s+(\S+)\s+(?:আর\s+|কিন্তু\s+)?আমি\s+(?:বলছি|বলি|বলতেছি|বললাম|কইলাম)\s+(\S+(?:\s+কে)?)')).firstMatch(ft);
    // "এখানে তোমাকে না, এটা হবে (তোমাকে) তুবা": X not, here it is Y.
    final m4 = RegExp(fold(r'^\s*(?:এখানে\s+|ওখানে\s+|এইখানে\s+)?(\S+)\s+না[\s,]+(?:এটা\s+|ওটা\s+|এখানে\s+)?(?:হবে|হইবো)(?:\s+(.*))?$')).firstMatch(ft);
    // The word asked for a moment ago ("‘তোমাকে’-এর জায়গায় কী হবে?").
    final asked = _swapAsk;
    if (asked != null && _now.difference(asked.$2).inMinutes <= 3 && words(ft).isNotEmpty && words(ft).length <= 3 && m1 == null) {
      _swapAsk = null;
      (from, to) = (asked.$1, words(ft).join(' '));
    } else if (m1 != null) {
      (from, to) = (m1[1]!, m1[2]!);
    } else if (m2b != null) {
      (from, to) = (m2b[1]!, m2b[2]!);
    } else if (m4 != null && m3 == null && m2 == null) {
      final x = m4[1]!;
      final rest = [for (final w in words(m4[2] ?? '')) if (fold(w) != fold(x)) w];
      if (rest.isEmpty) {
        // The right word was lost (cut off by the speech engine): asked, never
        // kept as a to-do called "এখানে তোমাকে না".
        _swapAsk = (x, _now);
        _say(out, trf('“{0}”-এর জায়গায় কী হবে? শুধু সেটুকু বলুন — যেমন “তুবাকে”।', [x]));
        return true;
      }
      (from, to) = (x, rest.join(' '));
    } else if (m2 != null) {
      (from, to) = (m2[2]!, m2[1]!);
    } else if (m3 != null && RegExp(fold(r'(?:^|\s)(?:তোমাকে|তোমারে)(?=\s|$)')).hasMatch(fold(had))) {
      (from, to) = ('তোমাকে', m3[1]!.replaceAll(RegExp(fold(r'\s+কে$')), 'কে'));
    }
    // "তোমাকে" was only who the app was told, so it is not in the title:
    // the right one goes in front ("তুবাকে মাদ্রাসায় নিয়ে যেতে হয়").
    final toYou = from != null && RegExp(fold(r'^(?:তোমাকে|তোমারে|আপনাকে|তুমি|আপনি)$')).hasMatch(fold(from));
    if (from != null && to != null && (toYou || RegExp('(?:^|\\s)${RegExp.escape(fold(from))}(?=\\s|\$)').hasMatch(fold(had)))) {
      var put = words(normalize(to)).join(' ');
      if (!put.endsWith('কে') && RegExp(fold(r'^(?:তোমাকে|তোমারে|আপনাকে)$')).hasMatch(fold(from))) put = '$putকে';
      // Already so (said again, in other words): nothing to change.
      if (!RegExp('(?:^|\\s)${RegExp.escape(fold(from))}(?=\\s|\$)').hasMatch(fold(had)) && RegExp('(?:^|\\s)${RegExp.escape(fold(put))}(?=\\s|\$)').hasMatch(fold(had))) {
        _say(out, trf('ঠিক আছে — “{0}” এভাবেই রাখা আছে।', [had]));
        return true;
      }
      final inside = RegExp('(?<=^|\\s)${RegExp.escape(fold(from))}(?=\\s|\$)');
      final title = inside.hasMatch(fold(had)) ? fold(had).replaceFirst(inside, put) : '$put ${fold(had)}';
      if (put.isNotEmpty && title != fold(had)) {
        if (task != null) {
          await brain.saveTask(task.copyWith(title: title));
        } else {
          await brain.saveReminder(rem!.copyWith(title: title));
        }
        _say(out, trf('ঠিক আছে, লেখা বদলে “{0}” করেছি।', [title]));
        return true;
      }
    }
    final shorter = onlyWrite(t);
    if ((refusesSave(t) || notWhatISaid(t)) && shorter == null) {
      await brain.restoreSnapshot(last.$2);
      _lastSave = null;
      _focusTaskId = null;
      _focusReminderId = null;
      _say(out, tr('আচ্ছা, রাখলাম না।'));
      return true;
    }
    final drop = RegExp(fold(r'(\S+)\s+(?:শব্দটা|শব্দটি|কথাটা|শব্দ)\s+(?:বাদ|কেটে|মুছে)')).firstMatch(fold(t));
    String? title;
    final now = task?.title ?? rem!.title;
    if (drop != null) {
      final word = drop[1]!;
      final noun = todoTitle(word);
      final forms = {word, if (noun.isNotEmpty) noun};
      var x = ' ${fold(now)} ';
      for (final w in forms) {
        x = x.replaceAll(RegExp('(?<=\\s)${RegExp.escape(fold(w))}(?=\\s)'), ' ');
      }
      title = x.replaceAll(RegExp(r'\s+'), ' ').trim();
    } else if (shorter != null) {
      title = shorter;
    }
    if (title == null || title.isEmpty || title == now) return false;
    if (task != null) {
      await brain.saveTask(task.copyWith(title: title));
    } else {
      await brain.saveReminder(rem!.copyWith(title: title));
    }
    _say(out, trf('ঠিক আছে, লেখা বদলে “{0}” করেছি।', [title]));
    return true;
  }

  /// "দশ মিনিট পরে আবার মনে করিও": the reminder just set or just rung.
  /// A repeating one keeps its series; a one-time copy rings later.
  Future<bool> _snooze(ReminderSnooze c, List<String> out) async {
    Reminder? r;
    if (_focusReminderId != null && _focusReminderAt != null && _now.difference(_focusReminderAt!).inMinutes <= 60) {
      r = brain.data.reminders.where((x) => x.id == _focusReminderId).firstOrNull;
    }
    if (r == null) {
      final rung = [
        for (final x in brain.data.reminders)
          if (!x.repeat.isInterval)
            (x, DateTime(x.date.year, x.date.month, x.date.day, x.hour, x.minute)),
      ].where((e) => !e.$2.isAfter(_now) && _now.difference(e.$2).inHours < 3).toList()
        ..sort((a, b) => b.$2.compareTo(a.$2));
      r = rung.firstOrNull?.$1;
    }
    if (r == null) {
      _say(out, tr('কোন রিমাইন্ডারটা আবার মনে করাব, ধরতে পারিনি — নাম বলে আরেকবার বলুন।'));
      return false;
    }
    final at = _now.add(Duration(minutes: c.minutes));
    final again = r.repeat == Repeat.none
        ? r.copyWith(date: dayOnly(at), hour: at.hour, minute: at.minute, enabled: true)
        : Reminder(title: r.title, date: dayOnly(at), hour: at.hour, minute: at.minute, daysBefore: 0);
    await brain.saveReminder(again);
    _focusReminderId = again.id;
    _focusReminderAt = _now;
    if (!(await brain.services.notifier.health()).notificationsOn) {
      _say(out, trf('“{0}” {1}-এ রাখা হলো, কিন্তু এই ফোনে নোটিফিকেশন বন্ধ — তাই বাজবে না।', [r.title, sayWhen(at, _now)]));
      return true;
    }
    _say(out, trf('ঠিক আছে, “{0}” {1} মিনিট পরে ({2}) আবার মনে করাব।', [r.title, bnDigits(c.minutes), bnTime(at.hour, at.minute)]), links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন'))]);
    return true;
  }

  /// "আজকের", "অফিসের", "আগামীকালের" — said back in "আজকের এই ৫টা কাজ মুছে দেব?".
  String _scopeLabel(TaskQuery q) {
    final s = q.scope;
    if (s == null) return '';
    if (s.overdue) return tr('সময় পেরোনো');
    if (s.undated) return tr('তারিখ ছাড়া');
    if (s.about.isNotEmpty) return '${s.about.join(' ')}-এর';
    final from = s.from;
    if (from == null) return '';
    final today = dayOnly(_now);
    if (s.to == null || s.to == from) {
      if (dayOnly(from) == today) return tr('আজকের');
      if (dayOnly(from) == today.add(const Duration(days: 1))) return tr('আগামীকালের');
      return '${sayWhen(from, _now, withTime: false)}-এর';
    }
    return s.label.isNotEmpty ? s.label : '';
  }
}
