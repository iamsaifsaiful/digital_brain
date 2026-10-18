/// Everything the app stores. All of it lives in one encrypted file
/// (see services/data_store.dart).
library;

import 'dart:math';

import 'extras.dart';

export 'extras.dart';

String newId() {
  final r = Random.secure();
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final n = List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
  return '$t$n';
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

// ───────────────────────── Ledger ─────────────────────────

/// What happened, from the user's side.
enum LedgerKind {
  /// I gave a loan: they owe me more.
  lent('ধার দিলাম', 'আমি দিলাম, পরে পাব'),

  /// I borrowed: I owe them more.
  borrowed('ধার নিলাম', 'আমি নিলাম, পরে দেব'),

  /// They paid me back: they owe me less.
  received('ফেরত পেলাম', 'আমার পাওনা থেকে'),

  /// I paid them back: I owe them less.
  repaid('শোধ করলাম', 'আমার দেনা থেকে');

  const LedgerKind(this.label, this.hint);
  final String label;
  final String hint;

  /// Effect on "they owe me" (positive) for an amount.
  int signed(int amount) => switch (this) {
        LedgerKind.lent || LedgerKind.repaid => amount,
        LedgerKind.borrowed || LedgerKind.received => -amount,
      };

  /// Money leaving my pocket?
  bool get outflow => this == LedgerKind.lent || this == LedgerKind.repaid;

  static LedgerKind parse(Object? v) =>
      LedgerKind.values.firstWhere((k) => k.name == v, orElse: () => LedgerKind.lent);
}

class LedgerEntry {
  LedgerEntry({
    String? id,
    required this.person,
    required this.kind,
    required this.amount,
    required this.date,
    this.note = '',
    this.phone = '',
    DateTime? createdAt,
    this.due,
    this.reminderId,
    this.shopId,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now();

  /// A customer's due from this shop (see [Shop]); null = personal or the first shop.
  final String? shopId;

  /// When it is to be paid back (for a loan given or taken), if agreed.
  final DateTime? due;

  /// The reminder made for [due].
  final String? reminderId;

  final String id;
  final String person;

  /// The person's mobile number, so two people with the same name
  /// ("রহিম মিস্ত্রি" and "রহিম অফিস") keep separate accounts. May be empty.
  final String phone;
  final LedgerKind kind;

  /// Whole taka, always positive.
  final int amount;
  final DateTime date;
  final String note;
  final DateTime createdAt;

  LedgerEntry copyWith({String? person, String? phone, LedgerKind? kind, int? amount, DateTime? date, String? note, DateTime? due, bool clearDue = false, String? reminderId, bool clearReminder = false}) =>
      LedgerEntry(
        id: id,
        person: person ?? this.person,
        phone: phone ?? this.phone,
        kind: kind ?? this.kind,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        note: note ?? this.note,
        createdAt: createdAt,
        due: clearDue ? null : (due ?? this.due),
        reminderId: clearReminder ? null : (reminderId ?? this.reminderId),
        shopId: shopId,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'person': person,
        'kind': kind.name,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        if (phone.isNotEmpty) 'phone': phone,
        'createdAt': createdAt.toIso8601String(),
        if (due != null) 'due': due!.toIso8601String(),
        if (reminderId != null) 'reminderId': reminderId,
        if (shopId != null) 'shopId': shopId,
      };

  factory LedgerEntry.fromJson(Map<String, Object?> j) => LedgerEntry(
        id: j['id'] as String?,
        person: (j['person'] as String?) ?? '',
        phone: (j['phone'] as String?) ?? '',
        kind: LedgerKind.parse(j['kind']),
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        date: _date(j['date']) ?? DateTime.now(),
        note: (j['note'] as String?) ?? '',
        createdAt: _date(j['createdAt']),
        due: _date(j['due']),
        reminderId: j['reminderId'] as String?,
        shopId: j['shopId'] as String?,
      );
}

// ───────────────────────── Vault ─────────────────────────

enum VaultKind {
  website('ওয়েবসাইট'),
  app('অ্যাপ'),
  wifi('Wi-Fi'),
  bank('ব্যাংক'),
  email('ইমেইল'),
  other('অন্যান্য');

  const VaultKind(this.label);
  final String label;

  static VaultKind parse(Object? v) => VaultKind.values.firstWhere((k) => k.name == v, orElse: () => VaultKind.other);
}

class VaultItem {
  VaultItem({
    String? id,
    required this.name,
    this.kind = VaultKind.website,
    this.address = '',
    this.username = '',
    this.email = '',
    this.password = '',
    this.note = '',
    DateTime? updatedAt,
  })  : id = id ?? newId(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final VaultKind kind;

  /// Web address, or the network name for Wi-Fi.
  final String address;
  final String username;
  final String email;
  final String password;
  final String note;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'address': address,
        'username': username,
        'email': email,
        'password': password,
        'note': note,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory VaultItem.fromJson(Map<String, Object?> j) => VaultItem(
        id: j['id'] as String?,
        name: (j['name'] as String?) ?? '',
        kind: VaultKind.parse(j['kind']),
        address: (j['address'] as String?) ?? '',
        username: (j['username'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
        password: (j['password'] as String?) ?? '',
        note: (j['note'] as String?) ?? '',
        updatedAt: _date(j['updatedAt']),
      );
}

// ───────────────────────── Contacts ─────────────────────────

class Contact {
  Contact({String? id, required this.name, this.phone = '', this.email = '', this.note = '', DateTime? updatedAt, this.address = '', this.files = const []})
      : id = id ?? newId(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final String phone;
  final String email;
  final String note;
  final DateTime updatedAt;

  /// Where they are (shop, house, office) — opens on the map.
  final String address;

  /// Photos and files kept with the contact (visiting card, papers).
  final List<DocFile> files;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'note': note,
        'updatedAt': updatedAt.toIso8601String(),
        if (address.isNotEmpty) 'address': address,
        if (files.isNotEmpty) 'files': [for (final f in files) f.toJson()],
      };

  factory Contact.fromJson(Map<String, Object?> j) => Contact(
        id: j['id'] as String?,
        name: (j['name'] as String?) ?? '',
        phone: (j['phone'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
        note: (j['note'] as String?) ?? '',
        updatedAt: _date(j['updatedAt']),
        address: (j['address'] as String?) ?? '',
        files: [for (final f in (j['files'] as List? ?? const [])) if (f is Map) DocFile.fromJson(f.cast<String, Object?>())],
      );
}

// ───────────────────────── Notes ─────────────────────────

/// The category manual notes go to.
const defaultNoteCategory = 'নোট';

/// A note or any other remembered piece of information. [category] groups
/// them ("নোট", or one the app created such as "যানবাহন").
class Note {
  Note({String? id, required this.title, this.body = '', this.category = defaultNoteCategory, DateTime? updatedAt, this.files = const []})
      : id = id ?? newId(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;
  final String body;
  final String category;
  final DateTime updatedAt;

  /// Photos and files kept with the note (encrypted like documents).
  final List<DocFile> files;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'category': category,
        'updatedAt': updatedAt.toIso8601String(),
        if (files.isNotEmpty) 'files': [for (final f in files) f.toJson()],
      };

  factory Note.fromJson(Map<String, Object?> j) => Note(
        id: j['id'] as String?,
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        category: ((j['category'] as String?) ?? '').trim().isEmpty ? defaultNoteCategory : (j['category'] as String).trim(),
        updatedAt: _date(j['updatedAt']),
        files: [for (final f in (j['files'] as List? ?? const [])) if (f is Map) DocFile.fromJson(f.cast<String, Object?>())],
      );
}

// ───────────────────────── Reminders ─────────────────────────

enum Repeat {
  none('একবার'),
  every5('প্রতি ৫ মিনিটে', minutes: 5),
  every10('প্রতি ১০ মিনিটে', minutes: 10),
  every30('প্রতি ৩০ মিনিটে', minutes: 30),
  hourly('প্রতি ঘণ্টায়', minutes: 60),
  daily('প্রতিদিন'),
  weekly('প্রতি সপ্তাহে'),
  monthly('প্রতি মাসে'),
  yearly('প্রতি বছর');

  const Repeat(this.label, {this.minutes = 0});
  final String label;

  /// For the short repeats (every 5 minutes … every hour); 0 otherwise.
  final int minutes;
  bool get isInterval => minutes > 0;

  /// The nearest short repeat for "every N minutes".
  static Repeat everyMinutes(int m) => m <= 7 ? every5 : (m <= 19 ? every10 : (m <= 44 ? every30 : hourly));

  static Repeat parse(Object? v) => Repeat.values.firstWhere((k) => k.name == v, orElse: () => Repeat.none);
}

class Reminder {
  Reminder({
    String? id,
    required this.title,
    required this.date,
    this.hour = 10,
    this.minute = 0,
    this.daysBefore = 0,
    this.repeat = Repeat.none,
    this.note = '',
    this.vaultId,
    this.alarm = false,
    this.enabled = true,
    this.weekdays = const [],
    this.minutesBefore = 0,
  }) : id = id ?? newId();

  final String id;
  final String title;

  /// An early notice this many minutes before each ring ("৩০ মিনিট আগে",
  /// "১ ঘণ্টা আগে"); 0 = none. Works with every kind of repeat.
  final int minutesBefore;

  /// Set as an alarm (shown on the অ্যালার্ম page).
  final bool alarm;

  /// Switched off: kept, but does not ring.
  final bool enabled;

  /// For [Repeat.weekly]: the days it rings (DateTime.monday … sunday).
  /// Empty: the weekday of [date].
  final List<int> weekdays;

  /// The days a weekly reminder rings.
  Set<int> get ringDays => weekdays.isEmpty ? {date.weekday} : weekdays.toSet();

  Reminder copyWith({String? title, DateTime? date, int? hour, int? minute, Repeat? repeat, bool? alarm, bool? enabled, List<int>? weekdays, String? note, int? daysBefore, int? minutesBefore}) => Reminder(
        id: id,
        title: title ?? this.title,
        date: date ?? this.date,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        daysBefore: daysBefore ?? this.daysBefore,
        minutesBefore: minutesBefore ?? this.minutesBefore,
        repeat: repeat ?? this.repeat,
        note: note ?? this.note,
        vaultId: vaultId,
        alarm: alarm ?? this.alarm,
        enabled: enabled ?? this.enabled,
        weekdays: weekdays ?? this.weekdays,
      );

  /// The day itself (the due date, renewal date, appointment day…).
  final DateTime date;

  /// Time of day the notification shows.
  final int hour;
  final int minute;

  /// Notify this many days before [date] (0 = on the day).
  final int daysBefore;
  final Repeat repeat;
  final String note;

  /// A linked vault item (e.g. the domain panel login).
  final String? vaultId;

  /// The next date this reminder is about, on or after [now]'s day.
  DateTime nextDate(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(date.year, date.month, date.day);
    if (repeat == Repeat.none) return start;
    if (repeat.isInterval) {
      final n = notifyAt(now);
      return DateTime(n.year, n.month, n.day);
    }
    if (repeat == Repeat.daily) {
      if (start.isAfter(today)) return start;
      final at = DateTime(today.year, today.month, today.day, hour, minute);
      return at.isBefore(now) ? today.add(const Duration(days: 1)) : today;
    }
    if (repeat == Repeat.weekly) {
      final from = start.isAfter(today) ? start : today;
      for (var i = 0; i < 8; i++) {
        final c = from.add(Duration(days: i));
        if (!ringDays.contains(c.weekday)) continue;
        if (c == today && DateTime(c.year, c.month, c.day, hour, minute).isBefore(now)) continue;
        return c;
      }
      return from;
    }
    // Count from the original date each time, so the 31st stays the 31st
    // (or the month's last day) instead of drifting after February.
    final step = repeat == Repeat.monthly ? 1 : 12;
    var d = start;
    for (var k = 1; d.isBefore(today) && k < 1200; k++) {
      d = _addMonths(start, k * step);
    }
    return d;
  }

  /// When it rings next: the day itself at the set time. (A reminder always
  /// rings on its own day; [daysBefore] only adds an early notice, see
  /// [earlyAt].) For a one-time reminder this may be in the past.
  DateTime notifyAt(DateTime now) {
    if (repeat.isInterval) {
      final at = anchor;
      if (at.isAfter(now)) return at;
      final step = repeat.minutes;
      final passed = now.difference(at).inMinutes ~/ step + 1;
      return at.add(Duration(minutes: passed * step));
    }
    final d = nextDate(now);
    final at = DateTime(d.year, d.month, d.day, hour, minute);
    if (at.isAfter(now) || repeat == Repeat.none || repeat == Repeat.daily || repeat == Repeat.weekly) return at;
    // Today's monthly/yearly time has passed: the following one.
    final step = repeat == Repeat.monthly ? 1 : 12;
    final start = DateTime(date.year, date.month, date.day);
    for (var k = 1; k < 1200; k++) {
      final n = _addMonths(start, k * step);
      final t = DateTime(n.year, n.month, n.day, hour, minute);
      if (t.isAfter(now)) return t;
    }
    return at;
  }

  /// The early notice ("২ দিন আগে মনে করাও") before the next ring, if one
  /// is set and still ahead.
  DateTime? earlyAt(DateTime now) {
    if (daysBefore <= 0 || repeat.isInterval || repeat == Repeat.daily || repeat == Repeat.weekly) return null;
    final main = notifyAt(now);
    final e = DateTime(main.year, main.month, main.day - daysBefore, hour, minute);
    return e.isAfter(now) ? e : null;
  }

  /// The first moment it rings (date + time).
  DateTime get anchor => DateTime(date.year, date.month, date.day, hour, minute);

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'hour': hour,
        'minute': minute,
        'daysBefore': daysBefore,
        'repeat': repeat.name,
        'note': note,
        'vaultId': vaultId,
        if (alarm) 'alarm': true,
        if (!enabled) 'enabled': false,
        if (weekdays.isNotEmpty) 'weekdays': weekdays,
        if (minutesBefore > 0) 'minutesBefore': minutesBefore,
      };

  factory Reminder.fromJson(Map<String, Object?> j) => Reminder(
        id: j['id'] as String?,
        title: (j['title'] as String?) ?? '',
        date: _date(j['date']) ?? DateTime.now(),
        hour: (j['hour'] as num?)?.toInt() ?? 10,
        minute: (j['minute'] as num?)?.toInt() ?? 0,
        daysBefore: (j['daysBefore'] as num?)?.toInt() ?? 0,
        repeat: Repeat.parse(j['repeat']),
        note: (j['note'] as String?) ?? '',
        vaultId: j['vaultId'] as String?,
        alarm: j['alarm'] == true,
        enabled: j['enabled'] != false,
        weekdays: [for (final x in (j['weekdays'] as List? ?? const [])) if (x is num) x.toInt()],
        minutesBefore: (j['minutesBefore'] as num?)?.toInt() ?? 0,
      );
}

DateTime _addMonths(DateTime d, int months) {
  final y = d.year + (d.month - 1 + months) ~/ 12;
  final m = (d.month - 1 + months) % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, min(d.day, last));
}

// ───────────────────────── Everything ─────────────────────────

// ───────────────────────── Income & spending ─────────────────────────

enum CashKind {
  income('আয়'),
  expense('খরচ');

  const CashKind(this.label);
  final String label;
}

/// Money in or out that is not owed by anyone: monthly spending and
/// income, or a project's receipts and costs ([projectId] set).
class CashEntry {
  CashEntry({String? id, required this.kind, required this.amount, this.category = 'অন্যান্য', this.note = '', required this.date, this.projectId, this.accountId, this.shopId})
      : id = id ?? newId();

  final String id;
  final CashKind kind;
  final int amount;

  /// খাত: বাজার, ভাড়া, বেতন…
  final String category;
  final String note;
  final DateTime date;
  final String? projectId;

  /// The account the money came into or went out of (see [MoneyAccount]); null = not said.
  final String? accountId;

  /// The shop (see [Shop]) a sale or shop cost belongs to; null = the first shop / not a shop.
  final String? shopId;

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date.toIso8601String(),
        'projectId': projectId,
        if (accountId != null) 'accountId': accountId,
        if (shopId != null) 'shopId': shopId,
      };

  factory CashEntry.fromJson(Map<String, Object?> j) => CashEntry(
        id: j['id'] as String?,
        kind: CashKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => CashKind.expense),
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        category: ((j['category'] as String?) ?? '').trim().isEmpty ? 'অন্যান্য' : (j['category'] as String).trim(),
        note: (j['note'] as String?) ?? '',
        date: _date(j['date']) ?? DateTime.now(),
        projectId: j['projectId'] as String?,
        accountId: j['accountId'] as String?,
        shopId: j['shopId'] as String?,
      );
}

/// A piece of work with its own money: "রহিম ভবন", "অফিস সাজানো".
class Project {
  Project({String? id, required this.name, DateTime? createdAt, this.closed = false, this.budget = 0})
      : id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final DateTime createdAt;
  final bool closed;

  /// How much may be spent (an Eid or wedding budget); 0 = none set.
  final int budget;

  Project copyWith({String? name, bool? closed, int? budget}) =>
      Project(id: id, name: name ?? this.name, createdAt: createdAt, closed: closed ?? this.closed, budget: budget ?? this.budget);

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'createdAt': createdAt.toIso8601String(), 'closed': closed, if (budget > 0) 'budget': budget};

  factory Project.fromJson(Map<String, Object?> j) => Project(
        id: j['id'] as String?,
        name: (j['name'] as String?) ?? '',
        createdAt: _date(j['createdAt']),
        closed: j['closed'] == true,
        budget: (j['budget'] as num?)?.toInt() ?? 0,
      );
}

/// How to reach someone: a call, an SMS or WhatsApp.
enum Via { call, sms, whatsapp }

// ───────────────────────── Tasks ─────────────────────────

/// The first day of the app's week (Saturday, as weeks are counted in
/// Bangladesh). One rule for the rules, the AI, the answers and the screens.
const firstWeekday = DateTime.saturday;

/// The first day of the week [d] is in.
DateTime weekStartOf(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: (d.weekday - firstWeekday + 7) % 7));

/// How wide a to-do's date is: "শুক্রবার" is one day, "আগামী সপ্তাহে"
/// the whole week, "ডিসেম্বরে" the month, "পরের বছর" the year. [Task.due]
/// is then the first day of that span — never a day the user did not say.
enum TaskSpan { day, week, month, year }

/// A to-do that comes back: every day, on some weekdays, on a day of each
/// month, or every few days. [Task.due] is always the next time it is due.
class TaskRepeat {
  const TaskRepeat.daily() : kind = 'daily', weekdays = const [], monthDay = 0, every = 1, strict = false;
  const TaskRepeat.weekly(this.weekdays) : kind = 'weekly', monthDay = 0, every = 1, strict = false;
  const TaskRepeat.monthly(this.monthDay, {this.strict = false}) : kind = 'monthly', weekdays = const [], every = 1;
  const TaskRepeat.everyDays(this.every) : kind = 'every', weekdays = const [], monthDay = 0, strict = false;

  /// 'daily', 'weekly', 'monthly' or 'every' (every [every] days).
  final String kind;

  /// DateTime.monday … DateTime.sunday, for 'weekly'.
  final List<int> weekdays;

  /// 1–31, for 'monthly'. In a shorter month: its last day, or (when
  /// [strict]) that month is skipped.
  final int monthDay;
  final bool strict;
  final int every;

  /// The first time it is due on or after [from].
  DateTime nextOnOrAfter(DateTime from, {DateTime? anchor}) {
    final d0 = DateTime(from.year, from.month, from.day);
    switch (kind) {
      case 'weekly':
        for (var i = 0; i < 7; i++) {
          final d = DateTime(d0.year, d0.month, d0.day + i);
          if (weekdays.contains(d.weekday)) return d;
        }
        return d0;
      case 'monthly':
        DateTime? inMonth(int y, int m) {
          final last = DateTime(y, m + 1, 0).day;
          if (monthDay > last && strict) return null;
          return DateTime(y, m, monthDay > last ? last : monthDay);
        }
        for (var k = 0; k < 14; k++) {
          final c = inMonth(d0.year, d0.month + k);
          if (c != null && !c.isBefore(d0)) return c;
        }
        return d0;
      case 'every':
        final a = anchor == null ? d0 : DateTime(anchor.year, anchor.month, anchor.day);
        if (!a.isBefore(d0)) return a;
        final gap = d0.difference(a).inDays;
        final steps = (gap + every - 1) ~/ every;
        return DateTime(a.year, a.month, a.day + steps * every);
      default:
        return d0;
    }
  }

  /// The time after [due] (once that one is done or skipped).
  DateTime after(DateTime due) => kind == 'every' ? DateTime(due.year, due.month, due.day + every) : nextOnOrAfter(DateTime(due.year, due.month, due.day + 1));

  Map<String, Object?> toJson() => {'kind': kind, if (weekdays.isNotEmpty) 'weekdays': weekdays, if (monthDay > 0) 'monthDay': monthDay, if (strict) 'strict': true, if (every > 1) 'every': every};

  static TaskRepeat? fromJson(Object? j) {
    if (j is! Map) return null;
    return switch (j['kind']) {
      'daily' => const TaskRepeat.daily(),
      'weekly' => TaskRepeat.weekly([for (final x in (j['weekdays'] as List? ?? const [])) if (x is int) x]),
      'monthly' => TaskRepeat.monthly((j['monthDay'] as int?) ?? 1, strict: j['strict'] == true),
      'every' => TaskRepeat.everyDays((j['every'] as int?) ?? 2),
      _ => null,
    };
  }

  @override
  bool operator ==(Object o) => o is TaskRepeat && o.kind == kind && o.monthDay == monthDay && o.strict == strict && o.every == every && o.weekdays.join(',') == weekdays.join(',');

  @override
  int get hashCode => Object.hash(kind, monthDay, every, weekdays.join(','));
}

/// A to-do: "কাল ব্যাংকে যেতে হবে", "দুধ কিনতে হবে".
class Task {
  Task({
    String? id,
    required this.title,
    this.due,
    this.done = false,
    DateTime? createdAt,
    this.doneAt,
    this.list = '',
    this.reminderId,
    this.span = TaskSpan.day,
    this.urgent = false,
    this.note = '',
    this.repeat,
    this.deadline,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;

  /// The day it is for (null = any time). With a wider [span], the first
  /// day of that week, month or year.
  final DateTime? due;
  final bool done;
  final DateTime createdAt;

  /// When it was ticked; for a repeating to-do, the last time it was done.
  final DateTime? doneAt;

  /// The list it belongs to ("ঈদের কেনাকাটা"); '' = the main to-do list.
  final String list;

  /// The reminder set for it (the ⏰ beside the task).
  final String? reminderId;

  final TaskSpan span;

  /// "এটা জরুরি": shown and said first.
  final bool urgent;

  /// More about it ("কাগজপত্র নিতে হবে").
  final String note;

  /// Null for a one-time to-do.
  final TaskRepeat? repeat;

  /// The last day for it, kept apart from the day it is planned for
  /// ([due]): "বৃহস্পতিবার করব, শুক্রবারের মধ্যে জমা দিতে হবে". Moving the
  /// planned day never changes it; being late never changes either.
  final DateTime? deadline;

  /// The last day of its span (the due day itself for a one-day to-do).
  DateTime? get dueEnd {
    final d = due;
    if (d == null) return null;
    return switch (span) {
      TaskSpan.day => d,
      TaskSpan.week => DateTime(d.year, d.month, d.day + 6),
      TaskSpan.month => DateTime(d.year, d.month + 1, 0),
      TaskSpan.year => DateTime(d.year, 12, 31),
    };
  }

  static DateTime _d0(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Planned for [day]: that day, or a week/month/year plan that holds it.
  bool onDay(DateTime day) => due != null && !_d0(day).isBefore(_d0(due!)) && !_d0(day).isAfter(_d0(dueEnd!));

  /// Its planned day or span meets [from]–[to] (both days counted).
  bool touches(DateTime from, DateTime to) => due != null && !_d0(dueEnd!).isBefore(_d0(from)) && !_d0(due!).isAfter(_d0(to));

  /// Really late, said as "দেরি হয়ে গেছে": its deadline has passed, or (no
  /// deadline) the one day it was planned for has. A week, month or year
  /// plan has no day that was promised — when its time is over it is
  /// [windowPassed] (to look at again), never claimed late on a date.
  bool lateAt(DateTime now) {
    if (done) return false;
    final today = _d0(now);
    if (deadline != null) return _d0(deadline!).isBefore(today);
    return due != null && span == TaskSpan.day && _d0(due!).isBefore(today);
  }

  /// A week/month/year plan whose time is over (no deadline was said).
  bool windowPassed(DateTime now) => !done && deadline == null && due != null && span != TaskSpan.day && _d0(dueEnd!).isBefore(_d0(now));

  /// Still open and its day or time has come: late, planned for today,
  /// or a plan whose span holds today or is over.
  bool dueBy(DateTime now) => !done && due != null && !_d0(due!).isAfter(_d0(now));

  Task copyWith({
    String? title,
    DateTime? due,
    bool clearDue = false,
    bool? done,
    DateTime? doneAt,
    String? list,
    String? reminderId,
    bool clearReminder = false,
    TaskSpan? span,
    bool? urgent,
    String? note,
    TaskRepeat? repeat,
    bool clearRepeat = false,
    DateTime? deadline,
    bool clearDeadline = false,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        due: clearDue ? null : (due ?? this.due),
        done: done ?? this.done,
        createdAt: createdAt,
        doneAt: (done ?? this.done) ? (doneAt ?? this.doneAt ?? DateTime.now()) : (repeat ?? this.repeat) != null ? (doneAt ?? this.doneAt) : null,
        list: list ?? this.list,
        reminderId: clearReminder ? null : (reminderId ?? this.reminderId),
        // A new date said as a day ("কাল") is a day, unless a span comes with it.
        // The same date handed back (a form saved as it was) keeps the span.
        span: clearDue ? TaskSpan.day : (span ?? (due != null && (this.due == null || _d0(due) != _d0(this.due!)) ? TaskSpan.day : this.span)),
        urgent: urgent ?? this.urgent,
        note: note ?? this.note,
        repeat: clearRepeat ? null : (repeat ?? this.repeat),
        deadline: clearDeadline ? null : (deadline ?? this.deadline),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'due': due?.toIso8601String(),
        'done': done,
        'createdAt': createdAt.toIso8601String(),
        'doneAt': doneAt?.toIso8601String(),
        if (list.isNotEmpty) 'list': list,
        if (reminderId != null) 'reminderId': reminderId,
        if (span != TaskSpan.day) 'span': span.name,
        if (urgent) 'urgent': true,
        if (note.isNotEmpty) 'note': note,
        if (repeat != null) 'repeat': repeat!.toJson(),
        if (deadline != null) 'deadline': deadline!.toIso8601String(),
      };

  factory Task.fromJson(Map<String, Object?> j) => Task(
        id: j['id'] as String?,
        title: (j['title'] as String?) ?? '',
        due: _date(j['due']),
        done: j['done'] == true,
        createdAt: _date(j['createdAt']),
        doneAt: _date(j['doneAt']),
        list: (j['list'] as String?) ?? '',
        reminderId: j['reminderId'] as String?,
        span: TaskSpan.values.where((s) => s.name == j['span']).firstOrNull ?? TaskSpan.day,
        urgent: j['urgent'] == true,
        note: (j['note'] as String?) ?? '',
        repeat: TaskRepeat.fromJson(j['repeat']),
        deadline: _date(j['deadline']),
      );
}

// ───────────────────────── Documents ─────────────────────────

/// One page or file of a document (a photo, a PDF…). The bytes are kept
/// encrypted in their own file on the phone (see `DocFiles`).
class DocFile {
  DocFile({String? id, required this.name, required this.mime, required this.size, this.text = ''}) : id = id ?? newId();
  final String id;
  final String name;
  final String mime;

  /// Bytes as kept (after shrinking a photo).
  final int size;

  /// The printed text read from it on the phone (searchable); empty until
  /// read, and for files kept before reading existed.
  final String text;
  bool get isImage => mime.startsWith('image/');

  DocFile withText(String t) => DocFile(id: id, name: name, mime: mime, size: size, text: t);

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'mime': mime, 'size': size, if (text.isNotEmpty) 't': text};
  factory DocFile.fromJson(Map<String, Object?> j) => DocFile(
      id: j['id'] as String?,
      name: (j['name'] as String?) ?? '',
      mime: (j['mime'] as String?) ?? 'application/octet-stream',
      size: (j['size'] as num?)?.toInt() ?? 0,
      text: (j['t'] as String?) ?? '');
}

/// A field the user adds to a document ("NID নম্বর", "মেয়াদ").
class DocField {
  const DocField(this.label, this.value);
  final String label;
  final String value;
  Map<String, Object?> toJson() => {'l': label, 'v': value};
  factory DocField.fromJson(Map<String, Object?> j) => DocField((j['l'] as String?) ?? '', (j['v'] as String?) ?? '');
}

/// জাতীয় পরিচয়পত্র, পাসপোর্ট, জমির কাগজ, রসিদ…: photos/files plus notes.
class Doc {
  Doc({
    String? id,
    required this.title,
    this.folder = 'অন্যান্য',
    this.files = const [],
    this.fields = const [],
    this.expiry,
    this.reminderId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.about = '',
    this.people = '',
    this.place = '',
    this.taken,
    this.text = '',
  })  : id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;
  final String folder;
  final List<DocFile> files;

  /// The printed text read from its photos/pages on the phone (searchable;
  /// empty until read). Older saved documents simply have none.
  final String text;
  final List<DocField> fields;

  /// When it runs out (passport, licence…), if known.
  final DateTime? expiry;

  /// The reminder made for [expiry].
  final String? reminderId;

  /// What it shows, in the user's words ("বিয়ের দিনের ছবি", "জমির খারিজ").
  final String about;

  /// Who is in it or whose paper it is.
  final String people;

  /// Where (a place, a shop, a city).
  final String place;

  /// When the photos were taken / the paper was made.
  final DateTime? taken;

  /// Everything the assistant searches in.
  String get searchText => [title, folder, about, people, place, for (final f in fields) '${f.label} ${f.value}', if (taken != null) '${taken!.year}', text, for (final f in files) f.text].join(' ');
  final DateTime createdAt;
  final DateTime updatedAt;

  int get size => files.fold(0, (a, f) => a + f.size);

  Doc copyWith({
    String? title,
    String? folder,
    List<DocFile>? files,
    List<DocField>? fields,
    DateTime? expiry,
    bool clearExpiry = false,
    String? reminderId,
    bool clearReminder = false,
    String? about,
    String? people,
    String? place,
    DateTime? taken,
    bool clearTaken = false,
    String? text,
  }) =>
      Doc(
        id: id,
        title: title ?? this.title,
        folder: folder ?? this.folder,
        files: files ?? this.files,
        fields: fields ?? this.fields,
        expiry: clearExpiry ? null : (expiry ?? this.expiry),
        reminderId: clearReminder ? null : (reminderId ?? this.reminderId),
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        about: about ?? this.about,
        people: people ?? this.people,
        place: place ?? this.place,
        taken: clearTaken ? null : (taken ?? this.taken),
        text: text ?? this.text,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'folder': folder,
        'files': [for (final f in files) f.toJson()],
        'fields': [for (final f in fields) f.toJson()],
        'expiry': expiry?.toIso8601String(),
        'reminderId': reminderId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (about.isNotEmpty) 'about': about,
        if (people.isNotEmpty) 'people': people,
        if (place.isNotEmpty) 'place': place,
        if (taken != null) 'taken': taken!.toIso8601String(),
        if (text.isNotEmpty) 'text': text,
      };

  factory Doc.fromJson(Map<String, Object?> j) => Doc(
        id: j['id'] as String?,
        title: (j['title'] as String?) ?? '',
        folder: (j['folder'] as String?) ?? 'অন্যান্য',
        files: [for (final f in (j['files'] as List? ?? const [])) if (f is Map) DocFile.fromJson(f.cast<String, Object?>())],
        fields: [for (final f in (j['fields'] as List? ?? const [])) if (f is Map) DocField.fromJson(f.cast<String, Object?>())],
        expiry: _date(j['expiry']),
        reminderId: j['reminderId'] as String?,
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
        about: (j['about'] as String?) ?? '',
        people: (j['people'] as String?) ?? '',
        place: (j['place'] as String?) ?? '',
        taken: _date(j['taken']),
        text: (j['text'] as String?) ?? '',
      );
}

/// The folders offered from the start (the user can make more).
const docFolders = ['জাতীয় পরিচয়পত্র', 'পাসপোর্ট', 'জমি ও বাড়ির কাগজ', 'বিল ও রসিদ', 'সার্টিফিকেট', 'চিকিৎসা', 'প্রেসক্রিপশন', 'ওয়ারেন্টি ও গ্যারান্টি', 'গাড়ি ও লাইসেন্স', 'পরিবারের ছবি', 'অন্যান্য'];

/// Something the user deleted, kept for [TrashItem.keepDays] days so it can
/// be brought back (আরও › মুছে ফেলা). [items] are (list key in
/// [AppData.toJson], the item's JSON) — the thing itself first, then what
/// went with it (its reminder, a project's entries…). [files] are its
/// attached files, kept on the phone until it is gone for good.
class TrashItem {
  TrashItem({String? id, required this.kind, required this.title, required this.deletedAt, required this.items, this.files = const []}) : id = id ?? newId();
  final String id;

  /// The list key of the main item ('notes', 'tasks', …).
  final String kind;
  final String title;
  final DateTime deletedAt;
  final List<(String, Map<String, Object?>)> items;
  final List<String> files;

  static const keepDays = 30;

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'deletedAt': deletedAt.toIso8601String(),
        'items': [for (final (k, j) in items) {'k': k, 'j': j}],
        if (files.isNotEmpty) 'files': files,
      };

  static TrashItem fromJson(Map<String, Object?> j) => TrashItem(
        id: j['id'] as String?,
        kind: '${j['kind'] ?? ''}',
        title: '${j['title'] ?? ''}',
        deletedAt: DateTime.tryParse('${j['deletedAt']}') ?? DateTime.now(),
        items: [
          for (final x in (j['items'] as List? ?? const []))
            if (x is Map && x['j'] is Map) ('${x['k']}', (x['j'] as Map).cast<String, Object?>()),
        ],
        files: [for (final f in (j['files'] as List? ?? const [])) '$f'],
      );
}

class AppData {
  AppData({
    List<LedgerEntry>? ledger,
    List<VaultItem>? vault,
    List<Contact>? contacts,
    List<Note>? notes,
    List<Reminder>? reminders,
    List<Task>? tasks,
    List<CashEntry>? cash,
    List<Project>? projects,
    List<Doc>? docs,
    List<SpecialDay>? specialDays,
    List<Memory>? memories,
    List<Habit>? habits,
    List<Medicine>? medicines,
    List<MoneyAccount>? accounts,
    List<Transfer>? transfers,
    List<SavingsGoal>? goals,
    List<Installment>? installments,
    Map<String, List<String>>? tags,
    this.emergency = const EmergencyCard(),
    List<FamilyMember>? members,
    List<HealthLog>? health,
    Map<String, String>? vaccines,
    List<InboxMessage>? inbox,
    List<Shop>? shops,
    List<Receipt>? receipts,
    List<TrashItem>? trash,
  })  : tasks = tasks ?? [],
        trash = trash ?? [],
        inbox = inbox ?? [],
        shops = shops ?? [],
        receipts = receipts ?? [],
        members = members ?? [],
        health = health ?? [],
        vaccines = vaccines ?? {},
        specialDays = specialDays ?? [],
        memories = memories ?? [],
        habits = habits ?? [],
        medicines = medicines ?? [],
        accounts = accounts ?? [],
        transfers = transfers ?? [],
        goals = goals ?? [],
        installments = installments ?? [],
        tags = tags ?? {},
        docs = docs ?? [],
        cash = cash ?? [],
        projects = projects ?? [],
        ledger = ledger ?? [],
        vault = vault ?? [],
        contacts = contacts ?? [],
        notes = notes ?? [],
        reminders = reminders ?? [];

  final List<LedgerEntry> ledger;
  final List<VaultItem> vault;
  final List<Contact> contacts;
  final List<Note> notes;
  final List<Reminder> reminders;
  final List<Task> tasks;
  final List<CashEntry> cash;
  final List<Project> projects;
  final List<Doc> docs;
  final List<SpecialDay> specialDays;
  final List<Memory> memories;
  final List<Habit> habits;
  final List<Medicine> medicines;
  final List<MoneyAccount> accounts;
  final List<Transfer> transfers;
  final List<SavingsGoal> goals;
  final List<Installment> installments;

  /// Tags on notes, documents and contacts, keyed "note:<id>", "doc:<id>", "contact:<id>".
  final Map<String, List<String>> tags;
  EmergencyCard emergency;

  /// The people whose health is tracked (the user is [FamilyMember.meId]).
  final List<FamilyMember> members;
  final List<HealthLog> health;

  /// Vaccine doses given: "<member id>:<dose key>" → the day (ISO).
  final Map<String, String> vaccines;

  /// Messages read from other apps' notifications (newest last).
  final List<InboxMessage> inbox;

  /// The user's shops (দোকান), first one first.
  final List<Shop> shops;

  /// Receipts made in the shops.
  final List<Receipt> receipts;

  /// Deleted things, kept 30 days (newest last).
  final List<TrashItem> trash;

  static const schema = 1;

  /// Every tag in use, by name.
  List<String> get allTags => ({for (final l in tags.values) ...l}.toList()..sort());

  /// Note categories in use: "নোট" first, then the others by name.
  List<String> get noteCategories {
    final set = <String>{for (final n in notes) n.category};
    final others = set.where((c) => c != defaultNoteCategory).toList()..sort();
    return [if (set.contains(defaultNoteCategory)) defaultNoteCategory, ...others];
  }

  Map<String, Object?> toJson() => {
        'schema': schema,
        'ledger': ledger.map((e) => e.toJson()).toList(),
        'vault': vault.map((e) => e.toJson()).toList(),
        'contacts': contacts.map((e) => e.toJson()).toList(),
        'notes': notes.map((e) => e.toJson()).toList(),
        'reminders': reminders.map((e) => e.toJson()).toList(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'cash': cash.map((e) => e.toJson()).toList(),
        'projects': projects.map((e) => e.toJson()).toList(),
        'docs': docs.map((e) => e.toJson()).toList(),
        'specialDays': specialDays.map((e) => e.toJson()).toList(),
        'memories': memories.map((e) => e.toJson()).toList(),
        'habits': habits.map((e) => e.toJson()).toList(),
        'medicines': medicines.map((e) => e.toJson()).toList(),
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'transfers': transfers.map((e) => e.toJson()).toList(),
        'goals': goals.map((e) => e.toJson()).toList(),
        'installments': installments.map((e) => e.toJson()).toList(),
        'tags': {for (final e in tags.entries) if (e.value.isNotEmpty) e.key: e.value},
        'emergency': emergency.toJson(),
        'members': members.map((e) => e.toJson()).toList(),
        'health': health.map((e) => e.toJson()).toList(),
        if (vaccines.isNotEmpty) 'vaccines': vaccines,
        if (inbox.isNotEmpty) 'inbox': inbox.map((e) => e.toJson()).toList(),
        if (shops.isNotEmpty) 'shops': shops.map((e) => e.toJson()).toList(),
        if (receipts.isNotEmpty) 'receipts': receipts.map((e) => e.toJson()).toList(),
        if (trash.isNotEmpty) 'trash': trash.map((e) => e.toJson()).toList(),
      };

  factory AppData.fromJson(Map<String, Object?> j) {
    List<T> list<T>(String key, T Function(Map<String, Object?>) f) =>
        ((j[key] as List?) ?? const []).whereType<Map>().map((m) => f(m.cast<String, Object?>())).toList();
    return AppData(
      ledger: list('ledger', LedgerEntry.fromJson),
      vault: list('vault', VaultItem.fromJson),
      contacts: list('contacts', Contact.fromJson),
      notes: list('notes', Note.fromJson),
      reminders: list('reminders', Reminder.fromJson),
      tasks: list('tasks', Task.fromJson),
      cash: list('cash', CashEntry.fromJson),
      projects: list('projects', Project.fromJson),
      docs: list('docs', Doc.fromJson),
      specialDays: list('specialDays', SpecialDay.fromJson),
      memories: list('memories', Memory.fromJson),
      habits: list('habits', Habit.fromJson),
      medicines: list('medicines', Medicine.fromJson),
      accounts: list('accounts', MoneyAccount.fromJson),
      transfers: list('transfers', Transfer.fromJson),
      goals: list('goals', SavingsGoal.fromJson),
      installments: list('installments', Installment.fromJson),
      tags: {
        for (final e in ((j['tags'] as Map?) ?? const {}).entries)
          if (e.value is List) '${e.key}': [for (final t in e.value as List) '$t']
      },
      emergency: j['emergency'] is Map ? EmergencyCard.fromJson((j['emergency'] as Map).cast<String, Object?>()) : const EmergencyCard(),
      members: list('members', FamilyMember.fromJson),
      inbox: list('inbox', InboxMessage.fromJson),
      shops: list('shops', Shop.fromJson),
      receipts: list('receipts', Receipt.fromJson),
      trash: list('trash', TrashItem.fromJson),
      health: list('health', HealthLog.fromJson),
      vaccines: {for (final e in ((j['vaccines'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'},
    );
  }
}
