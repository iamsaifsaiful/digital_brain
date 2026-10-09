import '../models/models.dart';
import 'parser.dart';

/// One thing found by a search.
sealed class Hit {
  const Hit(this.score);
  final int score;
}

class VaultHit extends Hit {
  const VaultHit(this.item, super.score);
  final VaultItem item;
}

class ContactHit extends Hit {
  const ContactHit(this.contact, super.score);
  final Contact contact;
}

class NoteHit extends Hit {
  const NoteHit(this.note, super.score);
  final Note note;
}

class ReminderHit extends Hit {
  const ReminderHit(this.reminder, super.score);
  final Reminder reminder;
}

class PersonHit extends Hit {
  const PersonHit(this.person, super.score);
  final String person;
}

/// How many of [terms] appear in [fields]. Field text goes through the same
/// normalising as the terms, so "ABC ওয়েবসাইট" matches "abc".
int score(List<String> terms, List<String> fields) {
  if (terms.isEmpty) return 0;
  final hay = normalize(fields.join(' '));
  var s = 0;
  for (final raw in terms) {
    final t = normalize(raw);
    if (t.length >= 2 && hay.contains(t)) s++;
  }
  return s;
}

List<VaultItem> searchVault(AppData d, List<String> terms, {bool wifiOnly = false}) {
  final pool = wifiOnly ? d.vault.where((v) => v.kind == VaultKind.wifi).toList() : d.vault;
  if (terms.isEmpty) return wifiOnly ? pool : const [];
  // Never search inside the password itself.
  final scored = [
    for (final v in pool) (v, score(terms, [v.name, v.kind.label, v.address, v.username, v.email, v.note]))
  ].where((e) => e.$2 > 0).toList()
    ..sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final e in scored) e.$1];
}

List<Reminder> searchReminders(AppData d, List<String> terms) {
  final scored = [for (final r in d.reminders) (r, score(terms, [r.title, r.note]))].where((e) => e.$2 > 0).toList()
    ..sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final e in scored) e.$1];
}

/// Everything matching [terms], best first.
List<Hit> searchAll(AppData d, List<String> terms) {
  final out = <Hit>[];
  for (final v in d.vault) {
    final s = score(terms, [v.name, v.kind.label, v.address, v.username, v.email, v.note]);
    if (s > 0) out.add(VaultHit(v, s));
  }
  for (final c in d.contacts) {
    final s = score(terms, [c.name, c.phone, c.email, c.note]);
    if (s > 0) out.add(ContactHit(c, s));
  }
  for (final n in d.notes) {
    final s = score(terms, [n.title, n.body]);
    if (s > 0) out.add(NoteHit(n, s));
  }
  for (final r in d.reminders) {
    final s = score(terms, [r.title, r.note]);
    if (s > 0) out.add(ReminderHit(r, s));
  }
  final people = <String>{};
  for (final e in d.ledger) {
    if (people.contains(e.person)) continue;
    final s = score(terms, [e.person]);
    if (s > 0) {
      people.add(e.person);
      out.add(PersonHit(e.person, s));
    }
  }
  out.sort((a, b) => b.score.compareTo(a.score));
  return out;
}
