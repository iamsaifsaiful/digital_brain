/// A last guard on everything sent to the AI: phone, card, account and ID
/// numbers (any run of 10 or more digits, spaces and dashes allowed) and
/// e-mail addresses are replaced before the text leaves the phone — on top
/// of the rules that already keep passwords, the vault, PINs and secret
/// notes out.
library;

final _longNumber = RegExp(r'\+?[0-9০-৯](?:[\s\-]?[0-9০-৯]){9,}');
final _email = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');

/// Dates and times the app itself writes ("2026-10-21 10:00", "2026-10-21"):
/// never a phone or card number, so they are kept as they are (before 21 Oct
/// 2026 the "Now is …" line itself was blanked, and the AI never saw today).
final _isoDate = RegExp(r'(?<![0-9])[0-9]{4}-[0-9]{2}-[0-9]{2}(?:[ T][0-9]{2}:[0-9]{2})?(?![0-9])');

String redactForAi(String text) {
  final kept = <String>[];
  final shielded = text.replaceAllMapped(_isoDate, (m) {
    kept.add(m[0]!);
    return '\u0000${kept.length - 1}\u0000';
  });
  final clean = shielded.replaceAll(_email, '[ইমেইল]').replaceAll(_longNumber, '[নম্বর]');
  return clean.replaceAllMapped(RegExp('\u0000([0-9]+)\u0000'), (m) => kept[int.parse(m[1]!)]);
}

/// Health stays on the phone (owner's rule; review of 27 Oct): a reminder,
/// to-do, note, habit or document whose words are about medicine, a doctor,
/// an illness or a test is left out of what the AI sees. [extra] are the
/// member's own medicine names. A word-list check, so it errs on leaving out.
const _healthWords = [
  'ওষুধ', 'ঔষধ', 'ওষুদ', 'অষুধ', 'ট্যাবলেট', 'ক্যাপসুল', 'সিরাপ', 'ইনসুলিন', 'ইনজেকশন', 'ইঞ্জেকশন', 'ডোজ',
  'ডাক্তার', 'ডাক্তারের', 'চিকিৎসা', 'চিকিৎসক', 'হাসপাতাল', 'ক্লিনিক', 'প্রেসক্রিপশন', 'প্রেশার', 'প্রেসার', 'রক্তচাপ',
  'সুগার', 'ডায়াবেটিস', 'ডায়বেটিস', 'হার্ট', 'কিডনি', 'ক্যান্সার', 'ক্যানসার', 'থাইরয়েড', 'হাঁপানি', 'অ্যাজমা',
  'টিকা', 'ভ্যাকসিন', 'ডেঙ্গু', 'জ্বর', 'ব্যথা', 'গর্ভ', 'প্রেগন্যান্সি', 'থেরাপি', 'ফিজিওথেরাপি', 'কাউন্সেলিং',
  'মানসিক', 'ডিপ্রেশন', 'ডায়ালাইসিস', 'সার্জারি', 'এক্স-রে', 'এক্সরে', 'আল্ট্রাসনো', 'রক্ত পরীক্ষা', 'ব্লাড টেস্ট',
  'ইসিজি', 'কোলেস্টেরল', 'স্বাস্থ্য', 'রোগ', 'অসুখ', 'ফার্মেসি', 'নাপা', 'প্যারাসিটামল',
];
final _healthEn = RegExp(
    r'\b(medicines?|medication|tablets?|pills?|capsules?|syrup|insulin|injection|doctor|dr\.|hospital|clinic|prescription|dose|mg|bp|blood\s*pressure|diabetes|cholesterol|therapy|vaccine|dentist|pharmacy|paracetamol|napa)\b',
    caseSensitive: false);

bool mentionsHealth(String text, {Iterable<String> extra = const []}) {
  final t = text.toLowerCase();
  if (t.trim().isEmpty) return false;
  for (final w in _healthWords) {
    if (t.contains(w)) return true;
  }
  if (_healthEn.hasMatch(t)) return true;
  for (final m in extra) {
    final n = m.trim().toLowerCase();
    if (n.length >= 3 && t.contains(n)) return true;
  }
  return false;
}
