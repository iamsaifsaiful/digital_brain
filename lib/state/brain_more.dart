part of 'brain.dart';

/// Saving and changing the newer things: special days, the assistant's
/// memory, habits, medicines, accounts, savings, instalments, tags, the
/// emergency card, ready-made lists — and undo.
extension BrainMore on Brain {
  // ── Undo ──

  /// Everything as it is now, to put back with [restoreSnapshot].
  String snapshot() => jsonEncode(data.toJson());

  /// "ফিরিয়ে নিন": puts the data back as it was at [snap].
  Future<void> restoreSnapshot(String snap) async {
    data = AppData.fromJson((jsonDecode(snap) as Map).cast<String, Object?>());
    await _save();
    await _reschedule();
  }

  // ── Special days ──

  /// Saves [s] with its yearly reminder (at 9 in the morning, and
  /// [SpecialDay.daysBefore] days before).
  /// [hour]/[minute]: a ring time said for it; otherwise the time it
  /// already rang at (an edit keeps it), or 9 in the morning.
  Future<SpecialDay> saveSpecialDay(SpecialDay s, {int? hour, int minute = 0}) async {
    final now = services.now();
    final next = s.next(now);
    final old = s.reminderId == null ? null : reminderById(s.reminderId!);
    final r = Reminder(
      id: old?.id,
      title: '${s.kind.mark} ${specialTitle(s)}',
      date: next,
      hour: hour ?? old?.hour ?? 9,
      minute: hour != null ? minute : (old?.minute ?? 0),
      daysBefore: s.daysBefore,
      repeat: Repeat.yearly,
      note: s.note,
    );
    _upsert(data.reminders, r, (x) => x.id);
    final saved = s.copyWith(reminderId: r.id);
    _upsert(data.specialDays, saved, (x) => x.id);
    await _save();
    await services.notifier.requestPermission();
    await _reschedule();
    return saved;
  }

  Future<void> deleteSpecialDay(SpecialDay s) async {
    _trash('${s.person} — ${s.kind.bn}', [('specialDays', s.toJson()), ..._remindersJson([s.reminderId])]);
    data.specialDays.removeWhere((x) => x.id == s.id);
    if (s.reminderId != null) data.reminders.removeWhere((r) => r.id == s.reminderId);
    await _save();
    await _reschedule();
  }

  // ── The assistant's memory ──

  Future<void> addMemory(String text) async {
    final t = text.trim();
    if (t.isEmpty || data.memories.any((m) => m.text == t)) return;
    data.memories.add(Memory(text: t, createdAt: services.now()));
    await _save();
  }

  Future<void> deleteMemory(String id) async {
    for (final m in data.memories.where((m) => m.id == id)) {
      _trash(m.text, [('memories', m.toJson())]);
    }
    data.memories.removeWhere((m) => m.id == id);
    await _save();
  }

  Future<void> editMemory(Memory m, String text) async {
    _upsert(data.memories, Memory(id: m.id, text: text.trim(), createdAt: m.createdAt), (x) => x.id);
    await _save();
  }

  // ── Habits ──

  Future<void> saveHabit(Habit h) async {
    _upsert(data.habits, h, (x) => x.id);
    await _save();
  }

  Future<void> toggleHabit(Habit h, DateTime day) async {
    final k = dayKey(day);
    final done = [...h.done];
    done.contains(k) ? done.remove(k) : done.add(k);
    await saveHabit(h.copyWith(done: done));
  }

  /// A daily reminder for a habit at [minutes] (null removes it).
  Future<void> setHabitReminder(Habit h, int? minutes) async {
    if (h.reminderId != null) data.reminders.removeWhere((r) => r.id == h.reminderId);
    var next = h.copyWith(clearReminder: true);
    if (minutes != null) {
      final r = Reminder(title: h.name, date: dayOnly(services.now()), hour: minutes ~/ 60, minute: minutes % 60, repeat: Repeat.daily);
      data.reminders.add(r);
      next = next.copyWith(reminderId: r.id);
    }
    _upsert(data.habits, next, (x) => x.id);
    await _save();
    await _reschedule();
  }

  Future<void> deleteHabit(Habit h) async {
    _trash(h.name, [('habits', h.toJson()), ..._remindersJson([h.reminderId])]);
    data.habits.removeWhere((x) => x.id == h.id);
    if (h.reminderId != null) data.reminders.removeWhere((r) => r.id == h.reminderId);
    await _save();
    await _reschedule();
  }

  // ── Medicines ──

  /// Saves [m] with a daily alarm-like reminder at each of its times.
  Future<Medicine> saveMedicine(Medicine m) async {
    data.reminders.removeWhere((r) => m.reminderIds.contains(r.id));
    final today = dayOnly(services.now());
    final ids = <String>[];
    for (final t in m.times) {
      final r = Reminder(
        title: trf('ওষুধ: {0}', [m.name]),
        date: today,
        hour: t ~/ 60,
        minute: t % 60,
        repeat: Repeat.daily,
        note: m.dose > 1 ? trf('{0}টা করে', [bnDigits(m.dose)]) : m.note,
      );
      data.reminders.add(r);
      ids.add(r.id);
    }
    final saved = m.copyWith(reminderIds: ids);
    _upsert(data.medicines, saved, (x) => x.id);
    await _save();
    await services.notifier.requestPermission();
    await _reschedule();
    return saved;
  }

  /// "খেয়েছি": ticks the dose and takes it off the stock (or puts it back).
  Future<void> toggleDose(Medicine m, DateTime day, int time) async {
    final k = '${dayKey(day)} $time';
    final taken = [...m.taken];
    var stock = m.stock;
    if (taken.contains(k)) {
      taken.remove(k);
      if (stock > 0) stock += m.dose;
    } else {
      taken.add(k);
      if (stock > 0) stock = (stock - m.dose).clamp(0, 1 << 30);
    }
    _upsert(data.medicines, m.copyWith(taken: taken, stock: stock), (x) => x.id);
    await _save();
    await _reschedule();
  }

  Future<void> deleteMedicine(Medicine m) async {
    _trash(m.name, [('medicines', m.toJson()), ..._remindersJson(m.reminderIds)]);
    data.medicines.removeWhere((x) => x.id == m.id);
    data.reminders.removeWhere((r) => m.reminderIds.contains(r.id));
    await _save();
    await _reschedule();
  }

  // ── Money now ──

  /// "এখন আমার কাছে [amount] টাকা আছে": the main money starts afresh from now.
  Future<void> setCashOnHand(int amount) async {
    data.cashStart = amount;
    data.cashOffset = null;
    data.cashSetAt = services.now();
    await _save();
  }

  // ── Loans and other হিসাব in the main money ──

  /// Puts [sourceId] back in the main money (after the user took it out).
  Future<CashEntry?> addToMain(String sourceId) async {
    data.notInMain.remove(sourceId);
    await _intoMain(sourceId);
    await _save();
    return mainCopyOf(data, sourceId);
  }

  /// Takes [sourceId]'s line out of the main money (the source stays); it
  /// stays out until put back.
  Future<void> removeFromMain(String sourceId) async {
    data.notInMain.add(sourceId);
    final c = mainCopyOf(data, sourceId);
    if (c != null) data.cash.removeWhere((x) => x.id == c.id);
    await _save();
  }

  /// After [sourceId] was written or changed: its main line is made or
  /// follows. The line made, when it is new.
  Future<CashEntry?> _intoMain(String sourceId) async {
    final old = mainCopyOf(data, sourceId);
    if (!canGoToMain(data, sourceId)) {
      if (old != null) data.cash.removeWhere((x) => x.id == old.id);
      return null;
    }
    if (old == null && data.notInMain.contains(sourceId)) return null;
    final e = mainEntryFor(data, sourceId, old: old, now: services.now());
    if (e == null) return null;
    final placed = old == null && e.accountId == null
        ? CashEntry(kind: e.kind, amount: e.amount, category: e.category, note: e.note, date: e.date, accountId: defaultAccountId(data), linkId: e.linkId, addedAt: e.addedAt)
        : e;
    _upsert(data.cash, placed, (x) => x.id);
    return old == null ? placed : null;
  }

  // ── Accounts ──

  Future<void> saveAccount(MoneyAccount a) async {
    _upsert(data.accounts, a, (x) => x.id);
    await _save();
  }

  Future<void> deleteAccount(String id) async {
    data.accounts.removeWhere((x) => x.id == id);
    await _save();
  }

  Future<void> saveTransfer(Transfer t) async {
    _upsert(data.transfers, t, (x) => x.id);
    await _save();
  }

  Future<void> deleteTransfer(String id) async {
    data.transfers.removeWhere((x) => x.id == id);
    await _save();
  }

  // ── Savings goals ──

  Future<void> saveGoal(SavingsGoal g) async {
    _upsert(data.goals, g, (x) => x.id);
    await _save();
  }

  Future<void> addDeposit(SavingsGoal g, int amount) async {
    await saveGoal(g.copyWith(deposits: [...g.deposits, GoalDeposit(amount, services.now())]));
  }

  Future<void> deleteGoal(String id) async {
    for (final g in data.goals.where((x) => x.id == id)) {
      _trash(g.name, [('goals', g.toJson())]);
    }
    data.goals.removeWhere((x) => x.id == id);
    await _save();
  }

  // ── Zakat ──

  /// Leaves a line of the zakat count out (or puts it back).
  Future<void> setZakatIncluded(String key, bool included) async {
    if (included) {
      data.zakat.excluded.remove(key);
    } else {
      data.zakat.excluded.add(key);
    }
    await _save();
  }

  /// Something added to the zakat count by hand (an asset, or a debt to take off).
  Future<void> addZakatItem(String label, int amount, {bool debt = false}) async {
    data.zakat.items.add(ZakatItem(label: label.trim(), amount: amount, debt: debt, date: services.now()));
    await _save();
  }

  Future<void> deleteZakatItem(String id) async {
    data.zakat.items.removeWhere((i) => i.id == id);
    data.zakat.excluded.remove('manual:$id');
    await _save();
  }

  /// The day the user's zakat year began (the next due day is 354 days on).
  Future<void> setZakatYearStart(DateTime? day) async {
    data.zakat.yearStart = day;
    await _save();
  }

  // ── Instalments ──

  /// Saves [i] with a monthly reminder on its day (10 in the morning, and a day before).
  Future<Installment> saveInstallment(Installment i) async {
    if (i.reminderId != null) data.reminders.removeWhere((r) => r.id == i.reminderId);
    final now = services.now();
    var first = DateTime(now.year, now.month, i.dayOfMonth);
    if (first.isBefore(DateTime(i.start.year, i.start.month, i.dayOfMonth))) first = DateTime(i.start.year, i.start.month, i.dayOfMonth);
    if (first.isBefore(dayOnly(now))) first = DateTime(first.year, first.month + 1, i.dayOfMonth);
    final r = Reminder(
      title: trf('{0}-এর কিস্তি {1}', [i.name, taka(i.amount)]),
      date: first,
      hour: 10,
      daysBefore: 1,
      repeat: Repeat.monthly,
    );
    data.reminders.add(r);
    final saved = i.copyWith(reminderId: r.id);
    _upsert(data.installments, saved, (x) => x.id);
    await _save();
    await _reschedule();
    return saved;
  }

  /// Ticks (or unticks) the instalment for [month]. When all are paid the reminder stops.
  Future<void> toggleInstallmentPaid(Installment i, DateTime month) async {
    final k = monthKey(month);
    final paid = [...i.paid];
    paid.contains(k) ? paid.remove(k) : paid.add(k);
    final next = i.copyWith(paid: paid);
    if (next.left == 0 && next.reminderId != null) {
      final r = reminderById(next.reminderId!);
      if (r != null) _upsert(data.reminders, r.copyWith(enabled: false), (x) => x.id);
    } else if (next.reminderId != null) {
      final r = reminderById(next.reminderId!);
      if (r != null && !r.enabled) _upsert(data.reminders, r.copyWith(enabled: true), (x) => x.id);
    }
    _upsert(data.installments, next, (x) => x.id);
    await _save();
    await _reschedule();
  }

  Future<void> deleteInstallment(Installment i) async {
    _trash(i.name, [('installments', i.toJson()), ..._remindersJson([i.reminderId])]);
    data.installments.removeWhere((x) => x.id == i.id);
    if (i.reminderId != null) data.reminders.removeWhere((r) => r.id == i.reminderId);
    await _save();
    await _reschedule();
  }

  // ── Tags ──

  List<String> tagsOf(String key) => data.tags[key] ?? const [];

  Future<void> setTags(String key, List<String> tags) async {
    final clean = {for (final t in tags) t.trim()}.where((t) => t.isNotEmpty).toList();
    if (clean.isEmpty) {
      data.tags.remove(key);
    } else {
      data.tags[key] = clean;
    }
    await _save();
  }

  // ── Emergency card ──

  Future<void> saveEmergency(EmergencyCard c) async {
    data.emergency = c;
    await _save();
    await services.notifier.showEmergency(c.onLockScreen && !c.isEmpty ? emergencyText(c) : null);
  }

  // ── Lists and days ──

  /// A ready-made list: each item becomes a to-do on the list [name].
  Future<void> addList(String name, List<String> items) async {
    for (final t in items) {
      data.tasks.add(Task(title: t, list: name, createdAt: services.now()));
    }
    await _save();
  }

  /// Moves a to-do to [day] (dragged in দিনলিপি, or "কাল করব").
  Future<void> moveTask(Task t, DateTime? day) => saveTask(day == null ? t.copyWith(clearDue: true) : t.copyWith(due: dayOnly(day)));

  /// Undone to-dos from past days are shown on today's list (the plan puts
  /// them under "সময় পেরিয়েছে"); their own planned day, span and deadline
  /// stay as they were — never rewritten to today. Returns how many.
  Future<int> carryOverTasks() async {
    if (!loaded || loadError != null) return 0;
    final today = dayOnly(services.now());
    // A finished medicine course stops ringing.
    var changed = false;
    for (final m in data.medicines) {
      if (m.until == null || !today.isAfter(dayOnly(m.until!))) continue;
      for (final id in m.reminderIds) {
        final r = reminderById(id);
        if (r != null && r.enabled) {
          _upsert(data.reminders, r.copyWith(enabled: false), (x) => x.id);
          changed = true;
        }
      }
    }
    if (changed) await _save();
    if (!carryOver) return 0;
    var n = 0;
    final now = services.now();
    for (final t in data.tasks) {
      if (t.lateAt(now) || t.windowPassed(now)) n++;
    }
    return n;
  }

  /// "কালকে সরিয়ে দেবো?": today's undone to-dos go to tomorrow.
  Future<int> moveLeftToTomorrow() async {
    final today = dayOnly(services.now());
    final tomorrow = today.add(const Duration(days: 1));
    var n = 0;
    for (var i = 0; i < data.tasks.length; i++) {
      final t = data.tasks[i];
      // One-day to-dos only: a week or month plan keeps its span.
      if (!t.done && t.span == TaskSpan.day && t.repeat == null && t.due != null && !dayOnly(t.due!).isAfter(today)) {
        data.tasks[i] = t.copyWith(due: tomorrow);
        n++;
      }
    }
    if (n > 0) {
      await _save();
      await _reschedule();
    }
    return n;
  }
}

/// The emergency card as a few lines (for the lock screen).
String emergencyText(EmergencyCard c) {
  final lines = <String>[];
  if (c.name.isNotEmpty) lines.add(c.name);
  if (c.blood.isNotEmpty) lines.add(trf('রক্তের গ্রুপ: {0}', [c.blood]));
  for (final x in c.contacts) {
    final p = x.split('|');
    if (p.length >= 2 && p[1].trim().isNotEmpty) lines.add('${p.length > 2 && p[2].isNotEmpty ? '${p[2]} ' : ''}${p[0]}: ${p[1]}');
  }
  if (c.conditions.isNotEmpty) lines.add(trf('রোগ: {0}', [c.conditions]));
  if (c.medicines.isNotEmpty) lines.add(trf('ওষুধ: {0}', [c.medicines]));
  if (c.allergies.isNotEmpty) lines.add(trf('অ্যালার্জি: {0}', [c.allergies]));
  return lines.join('\n');
}

/// Health: people, readings, check-ups and the child vaccine card.
extension BrainHealth on Brain {
  /// The user and the family members, the user first.
  List<FamilyMember> get healthPeople {
    final me = data.members.where((m) => m.isMe).firstOrNull ?? FamilyMember(id: FamilyMember.meId, name: userName.isEmpty ? tr('আমি') : userName);
    return [me, ...data.members.where((m) => !m.isMe)];
  }

  FamilyMember personById(String id) => healthPeople.firstWhere((m) => m.id == id, orElse: () => healthPeople.first);

  /// Keeps a blood group: the user's on the emergency card, a family
  /// member's on their health page (a new member when not there yet).
  /// Returns whose, ready for a sentence ("আপনার", "আম্মার").
  Future<String> setBlood(String who, String group) async {
    if (who.isEmpty) {
      await saveEmergency(data.emergency.copyWith(blood: group));
      return tr('আপনার');
    }
    final m = memberCalled(data, who) ?? FamilyMember(name: who, relation: who);
    _upsert(data.members, m.copyWith(blood: group), (x) => x.id);
    await _save();
    return possessive(m.relation.isNotEmpty ? m.relation : m.name);
  }

  /// Keeps a height (cm): the user's own, or a family member's.
  Future<String> setHeight(String who, double cm) async {
    final FamilyMember m;
    if (who.isEmpty) {
      m = data.members.where((x) => x.isMe).firstOrNull ?? FamilyMember(id: FamilyMember.meId, name: userName.isEmpty ? tr('আমি') : userName);
    } else {
      m = memberCalled(data, who) ?? FamilyMember(name: who, relation: who);
    }
    _upsert(data.members, m.copyWith(heightCm: cm), (x) => x.id);
    await _save();
    return who.isEmpty ? tr('আপনার') : possessive(m.relation.isNotEmpty ? m.relation : m.name);
  }

  Future<void> saveMember(FamilyMember m) async {
    _upsert(data.members, m, (x) => x.id);
    await _save();
    await _vaccineReminders(m);
  }

  Future<void> deleteMember(FamilyMember m) async {
    data.members.removeWhere((x) => x.id == m.id);
    data.health.removeWhere((h) => h.member == m.id);
    data.vaccines.removeWhere((k, _) => k.startsWith('${m.id}:'));
    data.reminders.removeWhere((r) => m.vaccineReminders.contains(r.id) || r.id == m.checkupReminderId);
    await _save();
    await _reschedule();
  }

  Future<void> addHealth(HealthLog h) async {
    data.health.add(h);
    await _save();
  }

  // ── Changing or removing by voice ──

  /// Removes what [t] points at.
  Future<void> deleteTarget(Target t) async {
    switch (t.kind) {
      case ItemKind.reminder:
        await deleteReminder(t.id);
      case ItemKind.task:
        await deleteTask(t.id);
      case ItemKind.note:
        await deleteNote(t.id);
      case ItemKind.ledger:
        await deleteEntry(t.id);
      case ItemKind.cash:
        await deleteCash(t.id);
      case ItemKind.contact:
        await deleteContact(t.id);
      case ItemKind.special:
        final s = data.specialDays.where((x) => x.id == t.id).firstOrNull;
        if (s != null) await deleteSpecialDay(s);
      case ItemKind.medicine:
        final m = data.medicines.where((x) => x.id == t.id).firstOrNull;
        if (m != null) await deleteMedicine(m);
      case ItemKind.habit:
        final h = data.habits.where((x) => x.id == t.id).firstOrNull;
        if (h != null) await deleteHabit(h);
      case ItemKind.memory:
        await deleteMemory(t.id);
      case ItemKind.doc:
        final x = data.docs.where((d) => d.id == t.id).firstOrNull;
        if (x != null) await deleteDoc(x);
    }
  }

  /// Applies a said change (new time, day or amount) to [t].
  Future<void> applyChange(Target t, Change c) async {
    switch (t.kind) {
      case ItemKind.reminder:
        final r = reminderById(t.id);
        final at = c.at;
        if (r != null && at != null) await saveReminder(r.copyWith(date: DateTime(at.year, at.month, at.day), hour: at.hour, minute: at.minute, enabled: true));
      case ItemKind.task:
        final task = data.tasks.where((x) => x.id == t.id).firstOrNull;
        if (task != null && c.day != null) await saveTask(task.copyWith(due: c.day));
      case ItemKind.ledger:
        final e = data.ledger.where((x) => x.id == t.id).firstOrNull;
        if (e != null && c.amount != null) await saveEntry(e.copyWith(amount: c.amount), guessPhone: false);
      case ItemKind.cash:
        final e = data.cash.where((x) => x.id == t.id).firstOrNull;
        if (e != null && c.amount != null) {
          await saveCash(CashEntry(id: e.id, kind: e.kind, amount: c.amount!, category: e.category, note: e.note, date: e.date, projectId: e.projectId, accountId: e.accountId, shopId: e.shopId, linkId: e.linkId));
        }
      default:
        break;
    }
  }

  Future<void> saveHealth(HealthLog h) async {
    _upsert(data.health, h, (x) => x.id);
    await _save();
  }

  Future<void> deleteHealth(String id) async {
    for (final h in data.health.where((h) => h.id == id)) {
      _trash(tr('স্বাস্থ্যের মাপ'), [('health', h.toJson())]);
    }
    data.health.removeWhere((h) => h.id == id);
    await _save();
  }

  /// The next check-up: a reminder a day before and that morning.
  Future<void> setCheckup(FamilyMember m, DateTime? day) async {
    if (m.checkupReminderId != null) data.reminders.removeWhere((r) => r.id == m.checkupReminderId);
    var next = m.copyWith(nextCheckup: day, clearCheckup: day == null, clearCheckupReminder: true);
    if (day != null) {
      final r = Reminder(title: trf('{0} — ডাক্তারের চেকআপ', [m.name]), date: dayOnly(day), hour: 9, daysBefore: 1);
      data.reminders.add(r);
      next = next.copyWith(checkupReminderId: r.id);
    }
    _upsert(data.members, next, (x) => x.id);
    await _save();
    await _reschedule();
  }

  /// Ticks (or unticks) a vaccine dose as given; the reminders follow.
  Future<void> setDoseGiven(FamilyMember m, VaccineDose v, DateTime? on) async {
    final key = '${m.id}:${v.key}';
    if (on == null) {
      data.vaccines.remove(key);
    } else {
      data.vaccines[key] = dayOnly(on).toIso8601String();
    }
    await _save();
    await _vaccineReminders(m);
  }

  /// One reminder for each coming vaccine day (doses due together share it).
  Future<void> _vaccineReminders(FamilyMember m) async {
    data.reminders.removeWhere((r) => m.vaccineReminders.contains(r.id));
    final ids = <String>[];
    final today = dayOnly(services.now());
    if (m.birth != null && !m.isMe) {
      final byDay = <DateTime, List<String>>{};
      for (final v in epiSchedule) {
        if (givenOn(data, m, v) != null) continue;
        final day = doseDay(m, v);
        if (day.isBefore(today)) continue;
        byDay.putIfAbsent(day, () => []).add(tr(v.name));
      }
      for (final e in byDay.entries) {
        final r = Reminder(title: trf('{0}-এর টিকা: {1}', [m.name, e.value.join(', ')]), date: e.key, hour: 9, daysBefore: 1);
        data.reminders.add(r);
        ids.add(r.id);
      }
    }
    final i = data.members.indexWhere((x) => x.id == m.id);
    if (i >= 0) data.members[i] = data.members[i].copyWith(vaccineReminders: ids);
    await _save();
    await _reschedule();
  }
}
