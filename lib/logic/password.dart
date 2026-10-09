import 'dart:math';

/// A random password: letters, digits and symbols, no look-alikes (0/O, 1/l).
String generatePassword({int length = 16}) {
  const lower = 'abcdefghijkmnopqrstuvwxyz';
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const digits = '23456789';
  const symbols = '!@#\$%&*?-_+=';
  final r = Random.secure();
  String pick(String s) => s[r.nextInt(s.length)];
  final chars = <String>[pick(lower), pick(upper), pick(digits), pick(symbols)];
  const all = lower + upper + digits + symbols;
  while (chars.length < length) {
    chars.add(pick(all));
  }
  chars.shuffle(r);
  return chars.join();
}

enum Strength {
  empty('', 0),
  weak('দুর্বল পাসওয়ার্ড', 1),
  fair('মাঝারি পাসওয়ার্ড', 2),
  strong('শক্ত পাসওয়ার্ড', 3);

  const Strength(this.label, this.level);
  final String label;
  final int level;
}

Strength strengthOf(String p) {
  if (p.isEmpty) return Strength.empty;
  var classes = 0;
  if (RegExp(r'[a-z]').hasMatch(p)) classes++;
  if (RegExp(r'[A-Z]').hasMatch(p)) classes++;
  if (RegExp(r'[0-9]').hasMatch(p)) classes++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) classes++;
  if (p.length >= 12 && classes >= 3) return Strength.strong;
  if (p.length >= 8 && classes >= 2) return Strength.fair;
  return Strength.weak;
}
