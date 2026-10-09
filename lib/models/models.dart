/// Everything the app stores. All of it lives in one encrypted file
/// (see services/data_store.dart).
library;

import 'dart:math';

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
    DateTime? createdAt,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String person;
  final LedgerKind kind;

  /// Whole taka, always positive.
  final int amount;
  final DateTime date;
  final String note;
  final DateTime createdAt;

  LedgerEntry copyWith({String? person, LedgerKind? kind, int? amount, DateTime? date, String? note}) => LedgerEntry(
        id: id,
        person: person ?? this.person,
        kind: kind ?? this.kind,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        note: note ?? this.note,
        createdAt: createdAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'person': person,
        'kind': kind.name,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LedgerEntry.fromJson(Map<String, Object?> j) => LedgerEntry(
        id: j['id'] as String?,
        person: (j['person'] as String?) ?? '',
        kind: LedgerKind.parse(j['kind']),
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        date: _date(j['date']) ?? DateTime.now(),
        note: (j['note'] as String?) ?? '',
        createdAt: _date(j['createdAt']),
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
  Contact({String? id, required this.name, this.phone = '', this.email = '', this.note = '', DateTime? updatedAt})
      : id = id ?? newId(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final String phone;
  final String email;
  final String note;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'note': note,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Contact.fromJson(Map<String, Object?> j) => Contact(
        id: j['id'] as String?,
        name: (j['name'] as String?) ?? '',
        phone: (j['phone'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
        note: (j['note'] as String?) ?? '',
        updatedAt: _date(j['updatedAt']),
      );
}

// ───────────────────────── Notes ─────────────────────────

/// The category manual notes go to.
const defaultNoteCategory = 'নোট';

/// A note or any other remembered piece of information. [category] groups
/// them ("নোট", or one the app created such as "যানবাহন").
class Note {
  Note({String? id, required this.title, this.body = '', this.category = defaultNoteCategory, DateTime? updatedAt})
      : id = id ?? newId(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;
  final String body;
  final String category;
  final DateTime updatedAt;

  Map<String, Object?> toJson() =>
      {'id': id, 'title': title, 'body': body, 'category': category, 'updatedAt': updatedAt.toIso8601String()};

  factory Note.fromJson(Map<String, Object?> j) => Note(
        id: j['id'] as String?,
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        category: ((j['category'] as String?) ?? '').trim().isEmpty ? defaultNoteCategory : (j['category'] as String).trim(),
        updatedAt: _date(j['updatedAt']),
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
    this.daysBefore = 1,
    this.repeat = Repeat.none,
    this.note = '',
    this.vaultId,
  }) : id = id ?? newId();

  final String id;
  final String title;

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
    // Count from the original date each time, so the 31st stays the 31st
    // (or the month's last day) instead of drifting after February.
    final step = repeat == Repeat.monthly ? 1 : 12;
    var d = start;
    for (var k = 1; d.isBefore(today) && k < 1200; k++) {
      d = _addMonths(start, k * step);
    }
    return d;
  }

  /// When the phone should notify for the next occurrence.
  DateTime notifyAt(DateTime now) {
    if (repeat.isInterval) {
      final at = anchor;
      if (at.isAfter(now)) return at;
      final step = repeat.minutes;
      final passed = now.difference(at).inMinutes ~/ step + 1;
      return at.add(Duration(minutes: passed * step));
    }
    final d = nextDate(now).subtract(Duration(days: repeat == Repeat.daily ? 0 : daysBefore));
    return DateTime(d.year, d.month, d.day, hour, minute);
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
      };

  factory Reminder.fromJson(Map<String, Object?> j) => Reminder(
        id: j['id'] as String?,
        title: (j['title'] as String?) ?? '',
        date: _date(j['date']) ?? DateTime.now(),
        hour: (j['hour'] as num?)?.toInt() ?? 10,
        minute: (j['minute'] as num?)?.toInt() ?? 0,
        daysBefore: (j['daysBefore'] as num?)?.toInt() ?? 1,
        repeat: Repeat.parse(j['repeat']),
        note: (j['note'] as String?) ?? '',
        vaultId: j['vaultId'] as String?,
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
  CashEntry({String? id, required this.kind, required this.amount, this.category = 'অন্যান্য', this.note = '', required this.date, this.projectId})
      : id = id ?? newId();

  final String id;
  final CashKind kind;
  final int amount;

  /// খাত: বাজার, ভাড়া, বেতন…
  final String category;
  final String note;
  final DateTime date;
  final String? projectId;

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date.toIso8601String(),
        'projectId': projectId,
      };

  factory CashEntry.fromJson(Map<String, Object?> j) => CashEntry(
        id: j['id'] as String?,
        kind: CashKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => CashKind.expense),
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        category: ((j['category'] as String?) ?? '').trim().isEmpty ? 'অন্যান্য' : (j['category'] as String).trim(),
        note: (j['note'] as String?) ?? '',
        date: _date(j['date']) ?? DateTime.now(),
        projectId: j['projectId'] as String?,
      );
}

/// A piece of work with its own money: "রহিম ভবন", "অফিস সাজানো".
class Project {
  Project({String? id, required this.name, DateTime? createdAt, this.closed = false})
      : id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final DateTime createdAt;
  final bool closed;

  Project copyWith({String? name, bool? closed}) => Project(id: id, name: name ?? this.name, createdAt: createdAt, closed: closed ?? this.closed);

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'createdAt': createdAt.toIso8601String(), 'closed': closed};

  factory Project.fromJson(Map<String, Object?> j) => Project(
        id: j['id'] as String?,
        name: (j['name'] as String?) ?? '',
        createdAt: _date(j['createdAt']),
        closed: j['closed'] == true,
      );
}

/// How to reach someone: a call, an SMS or WhatsApp.
enum Via { call, sms, whatsapp }

// ───────────────────────── Tasks ─────────────────────────

/// A to-do: "কাল ব্যাংকে যেতে হবে", "দুধ কিনতে হবে".
class Task {
  Task({String? id, required this.title, this.due, this.done = false, DateTime? createdAt, this.doneAt})
      : id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;

  /// The day it is for (null = any time).
  final DateTime? due;
  final bool done;
  final DateTime createdAt;
  final DateTime? doneAt;

  Task copyWith({String? title, DateTime? due, bool clearDue = false, bool? done, DateTime? doneAt}) => Task(
        id: id,
        title: title ?? this.title,
        due: clearDue ? null : (due ?? this.due),
        done: done ?? this.done,
        createdAt: createdAt,
        doneAt: (done ?? this.done) ? (doneAt ?? this.doneAt ?? DateTime.now()) : null,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'due': due?.toIso8601String(),
        'done': done,
        'createdAt': createdAt.toIso8601String(),
        'doneAt': doneAt?.toIso8601String(),
      };

  factory Task.fromJson(Map<String, Object?> j) => Task(
        id: j['id'] as String?,
        title: (j['title'] as String?) ?? '',
        due: _date(j['due']),
        done: j['done'] == true,
        createdAt: _date(j['createdAt']),
        doneAt: _date(j['doneAt']),
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
  })  : tasks = tasks ?? [],
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

  static const schema = 1;

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
    );
  }
}
