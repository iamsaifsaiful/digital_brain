/// The newer things the app keeps: special days, the assistant's memory,
/// habits, medicines, money accounts, savings goals, instalments and the
/// emergency card. Stored inside [AppData] like everything else.
library;

import 'models.dart';

DateTime? _d(Object? v) => v is String ? DateTime.tryParse(v) : null;
int _i(Object? v, [int or = 0]) => (v as num?)?.toInt() ?? or;
String _s(Object? v, [String or = '']) => (v as String?) ?? or;
List<String> _ls(Object? v) => [for (final x in (v as List? ?? const [])) '$x'];

/// "2026-10-13": a day as a plain key.
String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "2026-10": a month as a plain key.
String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

// ───────────────────────── Special days ─────────────────────────

enum SpecialKind {
  birthday('জন্মদিন', 'Birthday', '🎂'),
  anniversary('বিবাহবার্ষিকী', 'Wedding anniversary', '💍'),
  deathday('মৃত্যুবার্ষিকী', 'Death anniversary', '🕯'),
  other('বিশেষ দিন', 'Special day', '⭐');

  const SpecialKind(this.bn, this.en, this.mark);
  final String bn;
  final String en;
  final String mark;

  static SpecialKind parse(Object? v) => SpecialKind.values.firstWhere((k) => k.name == v, orElse: () => SpecialKind.other);
}

/// A day that comes back every year: someone's birthday, a wedding
/// anniversary, a death anniversary. Rings through a yearly [Reminder].
class SpecialDay {
  SpecialDay({String? id, required this.person, this.kind = SpecialKind.birthday, required this.month, required this.day, this.year, this.note = '', this.daysBefore = 1, this.reminderId, this.phone = ''})
      : id = id ?? newId();

  final String id;

  /// Whose day, or what the day is ("রহিম", "আব্বা", "বিয়ের দিন").
  final String person;
  final SpecialKind kind;
  final int month;
  final int day;

  /// The first year (birth year, wedding year), when known — for "৩০ বছর".
  final int? year;
  final String note;

  /// Also remind this many days before (0 = only on the day).
  final int daysBefore;
  final String? reminderId;

  /// To call or send wishes.
  final String phone;

  SpecialDay copyWith({String? person, SpecialKind? kind, int? month, int? day, int? year, bool clearYear = false, String? note, int? daysBefore, String? reminderId, String? phone}) => SpecialDay(
        id: id,
        person: person ?? this.person,
        kind: kind ?? this.kind,
        month: month ?? this.month,
        day: day ?? this.day,
        year: clearYear ? null : (year ?? this.year),
        note: note ?? this.note,
        daysBefore: daysBefore ?? this.daysBefore,
        reminderId: reminderId ?? this.reminderId,
        phone: phone ?? this.phone,
      );

  /// The next time it comes, today or later. 29 February falls on 28 February in other years.
  DateTime next(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    DateTime on(int y) {
      final last = DateTime(y, month + 1, 0).day;
      return DateTime(y, month, day > last ? last : day);
    }

    final d = on(now.year);
    return d.isBefore(today) ? on(now.year + 1) : d;
  }

  /// How many years it will be on [next] (null when the year is unknown).
  int? yearsOn(DateTime next) => year == null ? null : next.year - year!;

  Map<String, Object?> toJson() => {
        'id': id,
        'person': person,
        'kind': kind.name,
        'month': month,
        'day': day,
        'year': year,
        'note': note,
        'daysBefore': daysBefore,
        'reminderId': reminderId,
        'phone': phone,
      };

  factory SpecialDay.fromJson(Map<String, Object?> j) => SpecialDay(
        id: j['id'] as String?,
        person: _s(j['person']),
        kind: SpecialKind.parse(j['kind']),
        month: _i(j['month'], 1).clamp(1, 12),
        day: _i(j['day'], 1).clamp(1, 31),
        year: (j['year'] as num?)?.toInt(),
        note: _s(j['note']),
        daysBefore: _i(j['daysBefore'], 1),
        reminderId: j['reminderId'] as String?,
        phone: _s(j['phone']),
      );
}

// ───────────────────────── Assistant memory ─────────────────────────

/// Something the user told the assistant about themselves or the people
/// around them ("আমি শুক্রবার অফিস করি না", "রহিম আমার শ্যালক").
class Memory {
  Memory({String? id, required this.text, DateTime? createdAt})
      : id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now();
  final String id;
  final String text;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {'id': id, 'text': text, 'createdAt': createdAt.toIso8601String()};
  factory Memory.fromJson(Map<String, Object?> j) => Memory(id: j['id'] as String?, text: _s(j['text']), createdAt: _d(j['createdAt']));
}

// ───────────────────────── Habits ─────────────────────────

/// Something done every day ("হাঁটা", "নামাজ", "পানি খাওয়া"), ticked off day by day.
class Habit {
  Habit({String? id, required this.name, List<String>? done, DateTime? createdAt, this.reminderId})
      : id = id ?? newId(),
        done = done ?? [],
        createdAt = createdAt ?? DateTime.now();
  final String id;
  final String name;

  /// Days it was done (see [dayKey]).
  final List<String> done;
  final DateTime createdAt;
  final String? reminderId;

  bool doneOn(DateTime d) => done.contains(dayKey(d));

  /// Days in a row up to today (or up to yesterday, when today is not ticked yet).
  int streak(DateTime now) {
    var d = DateTime(now.year, now.month, now.day);
    if (!doneOn(d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (doneOn(d)) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// The longest run ever.
  int best() {
    final days = [for (final k in done) DateTime.tryParse(k)].whereType<DateTime>().toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in days) {
      run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  Habit copyWith({String? name, List<String>? done, String? reminderId, bool clearReminder = false}) =>
      Habit(id: id, name: name ?? this.name, done: done ?? this.done, createdAt: createdAt, reminderId: clearReminder ? null : (reminderId ?? this.reminderId));

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'done': done, 'createdAt': createdAt.toIso8601String(), 'reminderId': reminderId};
  factory Habit.fromJson(Map<String, Object?> j) =>
      Habit(id: j['id'] as String?, name: _s(j['name']), done: _ls(j['done']), createdAt: _d(j['createdAt']), reminderId: j['reminderId'] as String?);
}

// ───────────────────────── Medicines ─────────────────────────

/// A medicine taken at set times every day, with how many are left.
class Medicine {
  Medicine({String? id, required this.name, this.dose = 1, List<int>? times, this.stock = 0, this.note = '', List<String>? reminderIds, List<String>? taken, this.until})
      : id = id ?? newId(),
        times = times ?? [9 * 60],
        reminderIds = reminderIds ?? [],
        taken = taken ?? [];
  final String id;
  final String name;

  /// Pills (or spoons) each time.
  final int dose;

  /// Minutes after midnight for each dose (9:00 → 540).
  final List<int> times;

  /// How many are left (0 = not counted).
  final int stock;
  final String note;

  /// Last day of the course, if it has one.
  final DateTime? until;
  final List<String> reminderIds;

  /// Doses taken: "2026-10-13 540".
  final List<String> taken;

  int get perDay => dose * times.length;

  /// Days the stock lasts.
  int? get daysLeft => stock <= 0 || perDay == 0 ? null : stock ~/ perDay;

  bool takenAt(DateTime day, int time) => taken.contains('${dayKey(day)} $time');

  Medicine copyWith({String? name, int? dose, List<int>? times, int? stock, String? note, List<String>? reminderIds, List<String>? taken, DateTime? until, bool clearUntil = false}) => Medicine(
        id: id,
        name: name ?? this.name,
        dose: dose ?? this.dose,
        times: times ?? this.times,
        stock: stock ?? this.stock,
        note: note ?? this.note,
        reminderIds: reminderIds ?? this.reminderIds,
        taken: taken ?? this.taken,
        until: clearUntil ? null : (until ?? this.until),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'dose': dose,
        'times': times,
        'stock': stock,
        'note': note,
        'reminderIds': reminderIds,
        'taken': taken.length > 400 ? taken.sublist(taken.length - 400) : taken,
        'until': until?.toIso8601String(),
      };
  factory Medicine.fromJson(Map<String, Object?> j) => Medicine(
        id: j['id'] as String?,
        name: _s(j['name']),
        dose: _i(j['dose'], 1),
        times: [for (final t in (j['times'] as List? ?? const [])) (t as num).toInt()],
        stock: _i(j['stock']),
        note: _s(j['note']),
        reminderIds: _ls(j['reminderIds']),
        taken: _ls(j['taken']),
        until: _d(j['until']),
      );
}

// ───────────────────────── Money accounts ─────────────────────────

enum AccountKind {
  cash('নগদ', 'Cash'),
  bkash('বিকাশ', 'bKash'),
  nagad('নগদ (মোবাইল)', 'Nagad'),
  rocket('রকেট', 'Rocket'),
  bank('ব্যাংক', 'Bank'),
  other('অন্য', 'Other');

  const AccountKind(this.bn, this.en);
  final String bn;
  final String en;
  static AccountKind parse(Object? v) => AccountKind.values.firstWhere((k) => k.name == v, orElse: () => AccountKind.other);
}

/// Where money sits: cash in hand, bKash, a bank account…
class MoneyAccount {
  MoneyAccount({String? id, required this.name, this.kind = AccountKind.cash, this.opening = 0}) : id = id ?? newId();
  final String id;
  final String name;
  final AccountKind kind;

  /// The balance when it was added.
  final int opening;

  MoneyAccount copyWith({String? name, AccountKind? kind, int? opening}) => MoneyAccount(id: id, name: name ?? this.name, kind: kind ?? this.kind, opening: opening ?? this.opening);

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'kind': kind.name, 'opening': opening};
  factory MoneyAccount.fromJson(Map<String, Object?> j) => MoneyAccount(id: j['id'] as String?, name: _s(j['name']), kind: AccountKind.parse(j['kind']), opening: _i(j['opening']));
}

/// Money moved between the user's own accounts ("বিকাশ থেকে ৫০০০ তুললাম").
class Transfer {
  Transfer({String? id, required this.from, required this.to, required this.amount, required this.date, this.fee = 0, this.note = ''}) : id = id ?? newId();
  final String id;
  final String from;
  final String to;
  final int amount;

  /// Cash-out or bank charge, taken from [from].
  final int fee;
  final DateTime date;
  final String note;

  Map<String, Object?> toJson() => {'id': id, 'from': from, 'to': to, 'amount': amount, 'fee': fee, 'date': date.toIso8601String(), 'note': note};
  factory Transfer.fromJson(Map<String, Object?> j) =>
      Transfer(id: j['id'] as String?, from: _s(j['from']), to: _s(j['to']), amount: _i(j['amount']), fee: _i(j['fee']), date: _d(j['date']) ?? DateTime.now(), note: _s(j['note']));
}

// ───────────────────────── Savings and instalments ─────────────────────────

/// A saving target ("ঈদের জন্য ২০ হাজার", "নতুন ফোন").
class SavingsGoal {
  SavingsGoal({String? id, required this.name, required this.target, this.deadline, List<GoalDeposit>? deposits, DateTime? createdAt})
      : id = id ?? newId(),
        deposits = deposits ?? [],
        createdAt = createdAt ?? DateTime.now();
  final String id;
  final String name;
  final int target;
  final DateTime? deadline;
  final List<GoalDeposit> deposits;
  final DateTime createdAt;

  int get saved => deposits.fold(0, (a, d) => a + d.amount);
  double get progress => target <= 0 ? 0 : (saved / target).clamp(0, 1).toDouble();

  /// What to put aside each month to reach it by [deadline].
  int? perMonth(DateTime now) {
    final dl = deadline;
    if (dl == null) return null;
    final months = (dl.year - now.year) * 12 + dl.month - now.month;
    final left = target - saved;
    if (left <= 0) return 0;
    return (left / (months < 1 ? 1 : months)).ceil();
  }

  SavingsGoal copyWith({String? name, int? target, DateTime? deadline, bool clearDeadline = false, List<GoalDeposit>? deposits}) => SavingsGoal(
      id: id, name: name ?? this.name, target: target ?? this.target, deadline: clearDeadline ? null : (deadline ?? this.deadline), deposits: deposits ?? this.deposits, createdAt: createdAt);

  Map<String, Object?> toJson() =>
      {'id': id, 'name': name, 'target': target, 'deadline': deadline?.toIso8601String(), 'deposits': [for (final d in deposits) d.toJson()], 'createdAt': createdAt.toIso8601String()};
  factory SavingsGoal.fromJson(Map<String, Object?> j) => SavingsGoal(
        id: j['id'] as String?,
        name: _s(j['name']),
        target: _i(j['target']),
        deadline: _d(j['deadline']),
        deposits: [for (final d in (j['deposits'] as List? ?? const [])) if (d is Map) GoalDeposit.fromJson(d.cast<String, Object?>())],
        createdAt: _d(j['createdAt']),
      );
}

class GoalDeposit {
  const GoalDeposit(this.amount, this.date);
  final int amount;
  final DateTime date;
  Map<String, Object?> toJson() => {'amount': amount, 'date': date.toIso8601String()};
  factory GoalDeposit.fromJson(Map<String, Object?> j) => GoalDeposit(_i(j['amount']), _d(j['date']) ?? DateTime.now());
}

enum InstallmentKind {
  dps('DPS / সঞ্চয়', 'DPS / savings'),
  loan('লোনের কিস্তি', 'Loan instalment'),
  insurance('বীমার প্রিমিয়াম', 'Insurance premium'),
  other('অন্য কিস্তি', 'Other instalment');

  const InstallmentKind(this.bn, this.en);
  final String bn;
  final String en;
  static InstallmentKind parse(Object? v) => InstallmentKind.values.firstWhere((k) => k.name == v, orElse: () => InstallmentKind.other);
}

/// A monthly payment with an end: DPS, a loan, insurance.
class Installment {
  Installment({String? id, required this.name, this.kind = InstallmentKind.dps, required this.amount, this.dayOfMonth = 5, this.months = 12, required this.start, List<String>? paid, this.reminderId})
      : id = id ?? newId(),
        paid = paid ?? [];
  final String id;
  final String name;
  final InstallmentKind kind;
  final int amount;
  final int dayOfMonth;

  /// How many instalments in all.
  final int months;
  final DateTime start;

  /// Months paid (see [monthKey]).
  final List<String> paid;
  final String? reminderId;

  int get paidCount => paid.length;
  int get left => (months - paid.length).clamp(0, months);
  int get paidTotal => paid.length * amount;
  int get total => months * amount;
  bool paidFor(DateTime month) => paid.contains(monthKey(month));

  /// The month the last instalment falls in.
  DateTime get end => DateTime(start.year, start.month + months - 1, 1);

  Installment copyWith({String? name, InstallmentKind? kind, int? amount, int? dayOfMonth, int? months, DateTime? start, List<String>? paid, String? reminderId}) => Installment(
        id: id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        amount: amount ?? this.amount,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        months: months ?? this.months,
        start: start ?? this.start,
        paid: paid ?? this.paid,
        reminderId: reminderId ?? this.reminderId,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'amount': amount,
        'dayOfMonth': dayOfMonth,
        'months': months,
        'start': start.toIso8601String(),
        'paid': paid,
        'reminderId': reminderId,
      };
  factory Installment.fromJson(Map<String, Object?> j) => Installment(
        id: j['id'] as String?,
        name: _s(j['name']),
        kind: InstallmentKind.parse(j['kind']),
        amount: _i(j['amount']),
        dayOfMonth: _i(j['dayOfMonth'], 5).clamp(1, 28),
        months: _i(j['months'], 12),
        start: _d(j['start']) ?? DateTime.now(),
        paid: _ls(j['paid']),
        reminderId: j['reminderId'] as String?,
      );
}

// ───────────────────────── Emergency card ─────────────────────────

/// Shown without the PIN (and, if chosen, on the phone's lock screen) so
/// someone helping in an emergency can see it.
class EmergencyCard {
  const EmergencyCard({this.name = '', this.blood = '', this.contacts = const [], this.medicines = '', this.allergies = '', this.conditions = '', this.onLockScreen = false});
  final String name;
  final String blood;

  /// "নাম|নম্বর|সম্পর্ক".
  final List<String> contacts;
  final String medicines;
  final String allergies;
  final String conditions;
  final bool onLockScreen;

  bool get isEmpty => blood.isEmpty && contacts.isEmpty && medicines.isEmpty && allergies.isEmpty && conditions.isEmpty;

  EmergencyCard copyWith({String? name, String? blood, List<String>? contacts, String? medicines, String? allergies, String? conditions, bool? onLockScreen}) => EmergencyCard(
        name: name ?? this.name,
        blood: blood ?? this.blood,
        contacts: contacts ?? this.contacts,
        medicines: medicines ?? this.medicines,
        allergies: allergies ?? this.allergies,
        conditions: conditions ?? this.conditions,
        onLockScreen: onLockScreen ?? this.onLockScreen,
      );

  Map<String, Object?> toJson() =>
      {'name': name, 'blood': blood, 'contacts': contacts, 'medicines': medicines, 'allergies': allergies, 'conditions': conditions, 'onLockScreen': onLockScreen};
  factory EmergencyCard.fromJson(Map<String, Object?> j) => EmergencyCard(
        name: _s(j['name']),
        blood: _s(j['blood']),
        contacts: _ls(j['contacts']),
        medicines: _s(j['medicines']),
        allergies: _s(j['allergies']),
        conditions: _s(j['conditions']),
        onLockScreen: j['onLockScreen'] == true,
      );
}

// ───────────────────────── Health ─────────────────────────

/// Someone whose health the user keeps track of: themself ([meId]) or a
/// family member (a parent's blood pressure, a child's vaccines).
class FamilyMember {
  FamilyMember({String? id, required this.name, this.relation = '', this.birth, this.sex = '', this.heightCm, this.blood = '', this.nextCheckup, this.checkupReminderId, List<String>? vaccineReminders})
      : id = id ?? newId(),
        vaccineReminders = vaccineReminders ?? [];
  static const meId = 'me';

  final String id;
  final String name;

  /// "আব্বা", "মেয়ে"…
  final String relation;
  final DateTime? birth;

  /// 'm', 'f' or '' (not said).
  final String sex;
  final double? heightCm;

  /// Blood group ("B+"). The user's own is kept on the emergency card.
  final String blood;

  /// The next doctor's check-up, with its reminder.
  final DateTime? nextCheckup;
  final String? checkupReminderId;

  /// Reminders made for the coming vaccine doses.
  final List<String> vaccineReminders;

  bool get isMe => id == meId;

  int? ageOn(DateTime now) {
    final b = birth;
    if (b == null) return null;
    var y = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) y--;
    return y;
  }

  FamilyMember copyWith({String? name, String? relation, DateTime? birth, bool clearBirth = false, String? sex, double? heightCm, String? blood, DateTime? nextCheckup, bool clearCheckup = false, String? checkupReminderId, bool clearCheckupReminder = false, List<String>? vaccineReminders}) =>
      FamilyMember(
        id: id,
        name: name ?? this.name,
        relation: relation ?? this.relation,
        birth: clearBirth ? null : (birth ?? this.birth),
        sex: sex ?? this.sex,
        heightCm: heightCm ?? this.heightCm,
        blood: blood ?? this.blood,
        nextCheckup: clearCheckup ? null : (nextCheckup ?? this.nextCheckup),
        checkupReminderId: clearCheckupReminder ? null : (checkupReminderId ?? this.checkupReminderId),
        vaccineReminders: vaccineReminders ?? this.vaccineReminders,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'relation': relation,
        'birth': birth?.toIso8601String(),
        'sex': sex,
        'heightCm': heightCm,
        if (blood.isNotEmpty) 'blood': blood,
        'nextCheckup': nextCheckup?.toIso8601String(),
        'checkupReminderId': checkupReminderId,
        if (vaccineReminders.isNotEmpty) 'vaccineReminders': vaccineReminders,
      };

  factory FamilyMember.fromJson(Map<String, Object?> j) => FamilyMember(
        id: j['id'] as String?,
        name: _s(j['name']),
        relation: _s(j['relation']),
        birth: _d(j['birth']),
        sex: _s(j['sex']),
        heightCm: (j['heightCm'] as num?)?.toDouble(),
        blood: _s(j['blood']),
        nextCheckup: _d(j['nextCheckup']),
        checkupReminderId: j['checkupReminderId'] as String?,
        vaccineReminders: _ls(j['vaccineReminders']),
      );
}

enum HealthKind {
  weight('ওজন', 'Weight'),
  bp('রক্তচাপ', 'Blood pressure'),
  sugar('ডায়াবেটিস (সুগার)', 'Blood sugar'),
  water('পানি', 'Water'),
  exercise('হাঁটা/ব্যায়াম', 'Walk/exercise'),
  sleep('ঘুম', 'Sleep');

  const HealthKind(this.bn, this.en);
  final String bn;
  final String en;
  static HealthKind parse(Object? v) => HealthKind.values.firstWhere((k) => k.name == v, orElse: () => HealthKind.weight);
}

/// One reading: weight (kg in [a]), blood pressure ([a]/[b], pulse [c]),
/// blood sugar (mmol/L in [a], [tag] 'fasting' or 'after'), water (glasses),
/// exercise (minutes) or sleep (hours).
class HealthLog {
  HealthLog({String? id, this.member = FamilyMember.meId, required this.kind, required this.at, required this.a, this.b, this.c, this.tag = '', this.note = ''}) : id = id ?? newId();
  final String id;
  final String member;
  final HealthKind kind;
  final DateTime at;
  final double a;
  final double? b;
  final double? c;
  final String tag;
  final String note;

  HealthLog copyWith({double? a}) => HealthLog(id: id, member: member, kind: kind, at: at, a: a ?? this.a, b: b, c: c, tag: tag, note: note);

  Map<String, Object?> toJson() => {
        'id': id,
        'member': member,
        'kind': kind.name,
        'at': at.toIso8601String(),
        'a': a,
        if (b != null) 'b': b,
        if (c != null) 'c': c,
        if (tag.isNotEmpty) 'tag': tag,
        if (note.isNotEmpty) 'note': note,
      };

  factory HealthLog.fromJson(Map<String, Object?> j) => HealthLog(
        id: j['id'] as String?,
        member: _s(j['member'], FamilyMember.meId),
        kind: HealthKind.parse(j['kind']),
        at: _d(j['at']) ?? DateTime.now(),
        a: (j['a'] as num?)?.toDouble() ?? 0,
        b: (j['b'] as num?)?.toDouble(),
        c: (j['c'] as num?)?.toDouble(),
        tag: _s(j['tag']),
        note: _s(j['note']),
      );
}

/// A message seen in another app's notification (WhatsApp, Telegram, imo,
/// Gmail, SMS…). Kept only on the phone, inside the encrypted data.
class InboxMessage {
  InboxMessage({required this.id, required this.app, required this.appName, this.chat = '', this.from = '', required this.text, required this.at, this.key = '', this.group = false, this.state = ''});
  final String id;

  /// The app's package ("com.whatsapp") and its name ("WhatsApp").
  final String app;
  final String appName;

  /// The chat or group, and who wrote.
  final String chat;
  final String from;
  final String text;
  final DateTime at;

  /// The notification it came in (for its reply button while it is on the phone).
  final String key;
  final bool group;

  /// '' (new), 'saved' (made into a task/reminder/entry), 'replied', 'dismissed'.
  final String state;

  bool get isNew => state.isEmpty;

  InboxMessage withState(String s) => InboxMessage(id: id, app: app, appName: appName, chat: chat, from: from, text: text, at: at, key: key, group: group, state: s);

  Map<String, Object?> toJson() => {
        'id': id, 'app': app, 'appName': appName, 'chat': chat, 'from': from, 'text': text, 'at': at.toIso8601String(),
        if (key.isNotEmpty) 'key': key, if (group) 'group': true, if (state.isNotEmpty) 'state': state,
      };

  factory InboxMessage.fromJson(Map<String, Object?> j) => InboxMessage(
        id: _s(j['id']),
        app: _s(j['app']),
        appName: _s(j['appName']),
        chat: _s(j['chat']),
        from: _s(j['from']),
        text: _s(j['text']),
        at: _d(j['at']) ?? DateTime.now(),
        key: _s(j['key']),
        group: j['group'] == true,
        state: _s(j['state']),
      );
}

// ───────────────────────── Shops ─────────────────────────

/// One of the user's shops or businesses. The first one also takes the
/// sales said without a shop ("আজ ৫০০০ টাকা বিক্রি হলো").
class Shop {
  Shop({String? id, required this.name, this.phone = '', this.address = '', DateTime? createdAt})
      : id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now();
  final String id;
  final String name;
  final String phone;
  final String address;
  final DateTime createdAt;

  Shop copyWith({String? name, String? phone, String? address}) =>
      Shop(id: id, name: name ?? this.name, phone: phone ?? this.phone, address: address ?? this.address, createdAt: createdAt);

  Map<String, Object?> toJson() => {'id': id, 'name': name, if (phone.isNotEmpty) 'phone': phone, if (address.isNotEmpty) 'address': address, 'createdAt': createdAt.toIso8601String()};
  factory Shop.fromJson(Map<String, Object?> j) => Shop(id: j['id'] as String?, name: _s(j['name']), phone: _s(j['phone']), address: _s(j['address']), createdAt: _d(j['createdAt']));
}

/// A receipt (memo) given in a shop.
class Receipt {
  Receipt({String? id, required this.shopId, required this.no, this.customer = '', this.phone = '', required this.items, required this.paid, required this.date}) : id = id ?? newId();
  final String id;
  final String shopId;
  final int no;
  final String customer;
  final String phone;

  /// (item, quantity, unit price).
  final List<(String, int, int)> items;
  final int paid;
  final DateTime date;

  int get total => items.fold(0, (s, x) => s + x.$2 * x.$3);
  int get due => (total - paid).clamp(0, total);

  Map<String, Object?> toJson() => {
        'id': id,
        'shopId': shopId,
        'no': no,
        if (customer.isNotEmpty) 'customer': customer,
        if (phone.isNotEmpty) 'phone': phone,
        'items': [for (final x in items) {'i': x.$1, 'q': x.$2, 'p': x.$3}],
        'paid': paid,
        'date': date.toIso8601String(),
      };
  factory Receipt.fromJson(Map<String, Object?> j) => Receipt(
        id: j['id'] as String?,
        shopId: _s(j['shopId']),
        no: _i(j['no']),
        customer: _s(j['customer']),
        phone: _s(j['phone']),
        items: [
          for (final x in (j['items'] as List? ?? const []))
            if (x is Map) (_s(x['i']), _i(x['q'], 1), _i(x['p'])),
        ],
        paid: _i(j['paid']),
        date: _d(j['date']) ?? DateTime.now(),
      );
}
