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
