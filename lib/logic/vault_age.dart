/// Passwords' dates (owner, 27 Oct): when each was put in, when its password
/// was last set, the earlier passwords kept faded, and a nudge to change the
/// ones six months old — on a Friday or a holiday. All on the phone, inside
/// the vault; nothing here is sent anywhere.
library;

import '../models/models.dart';

/// A password this old is due for a change (about six months).
const passwordMaxAge = Duration(days: 182);

/// Earlier passwords kept for each login (the oldest drop off).
const oldPasswordsKept = 10;

/// [v] as it should be saved, given what was there before ([was], null for a
/// new login): the date it was first put in stays, and when the password
/// changed the one it replaces is kept (newest first) and its date is set.
VaultItem vaultToSave(VaultItem? was, VaultItem v, DateTime now) {
  final changed = was != null && was.password.isNotEmpty && was.password != v.password;
  final old = [
    if (changed) OldPassword(password: was.password, from: was.passwordAt, until: now),
    ...?was?.old.where((o) => o.password != v.password),
  ].take(oldPasswordsKept).toList();
  return VaultItem(
    id: v.id,
    name: v.name,
    kind: v.kind,
    address: v.address,
    username: v.username,
    email: v.email,
    password: v.password,
    note: v.note,
    updatedAt: v.updatedAt,
    createdAt: was == null ? (v.createdAt ?? now) : was.createdAt,
    passwordAt: was == null || changed || (was.password.isEmpty && v.password.isNotEmpty) ? now : was.passwordAt,
    old: old,
  );
}

/// Whether [password] was used before for this login.
bool usedBefore(VaultItem v, String password) => password.isNotEmpty && v.old.any((o) => o.password == password);

/// When [v]'s password turns six months old, then twelve, and so on: the
/// first such moment after [after].
DateTime nextDue(VaultItem v, DateTime after) {
  var due = v.passwordSince.add(passwordMaxAge);
  while (!due.isAfter(after)) {
    due = due.add(passwordMaxAge);
  }
  return due;
}

/// Logins whose password is six months old or more.
List<VaultItem> stalePasswords(AppData d, DateTime now) => [
      for (final v in d.vault)
        if (v.password.isNotEmpty && !now.isBefore(v.passwordSince.add(passwordMaxAge))) v,
    ];
