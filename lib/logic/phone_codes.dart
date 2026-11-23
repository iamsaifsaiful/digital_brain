// The country of a mobile number (owner, 19 Nov): the profile's number always
// has a country code (Bangladesh +880 first), and no more digits can be typed
// than that country's mobile numbers have. Lengths are the number after the
// country code, without the 0 some countries dial at home.
library;

import 'bn.dart';
import 'countries.dart';

class PhoneCountry {
  const PhoneCountry(this.country, this.dial, this.min, this.max, {this.starts, this.zero = true});

  /// The country (names, continent) from the UN list the location picker uses.
  final Country country;

  /// The country code's digits, without the plus (880).
  final String dial;

  /// Fewest and most digits of a mobile number after the code.
  final int min;
  final int max;

  /// What a mobile number must start with, when that is known for sure.
  final RegExp? starts;

  /// A 0 typed first is only the home trunk digit and is dropped. False where
  /// the 0 is part of the number itself (Côte d'Ivoire, Congo, Benin, Gabon).
  final bool zero;

  String get iso => country.code;
  String get bn => country.bn;
  String get en => country.en;
  String get continent => country.continent;
  String get name => country.label;
  String get code => '+$dial';

  /// How many digits, said on the field ("১০ অঙ্ক" or "৯–১০ অঙ্ক").
  String get lengthLabel => min == max ? bnDigits(max) : '${bnDigits(min)}–${bnDigits(max)}';
}

// ISO code, country code, digits after it ("8-10"); "z": the leading 0 is part of the number.
const _table =
    'AF 93 9;AM 374 8;AZ 994 9;BH 973 8;BD 880 10;BT 975 8;BN 673 7;KH 855 8-9;CN 86 11;GE 995 9;IN 91 10;ID 62 9-12;IR 98 10;IQ 964 10;IL 972 9;JP 81 10;JO 962 9;KZ 7 10;KW 965 8;KG 996 9;LA 856 10;LB 961 7-8;MY 60 9-10;MV 960 7;MN 976 8;MM 95 8-10;NP 977 10;KP 850 10;OM 968 8;PK 92 10;PH 63 10;QA 974 8;SA 966 9;SG 65 8;KR 82 9-10;LK 94 9;SY 963 9;TJ 992 9;TH 66 9;TL 670 8;TR 90 10;TM 993 8;AE 971 9;UZ 998 9;VN 84 9;YE 967 9;CY 357 8;AL 355 9;AD 376 6-9;AT 43 10-13;BY 375 9;BE 32 9;BA 387 8-9;BG 359 9;HR 385 8-9;CZ 420 9;DK 45 8;EE 372 7-8;FI 358 7-10;FR 33 9;DE 49 10-11;GR 30 10;HU 36 9;IS 354 7;IE 353 9;IT 39 9-10;LV 371 8;LI 423 7-9;LT 370 8;LU 352 9;MT 356 8;MD 373 8;MC 377 8-9;ME 382 8;NL 31 9;MK 389 8;NO 47 8;PL 48 9;PT 351 9;RO 40 9;RU 7 10;SM 378 8-10;RS 381 8-9;SK 421 9;SI 386 8;ES 34 9;SE 46 9;CH 41 9;UA 380 9;GB 44 10;DZ 213 9;AO 244 9;BJ 229 8-10z;BW 267 8;BF 226 8;BI 257 8;CV 238 7;CM 237 9;CF 236 8;TD 235 8;KM 269 7;CG 242 9z;CD 243 9;CI 225 10z;DJ 253 8;EG 20 10;GQ 240 9;ER 291 7;SZ 268 8;ET 251 9;GA 241 7-8z;GM 220 7;GH 233 9;GN 224 9;GW 245 9;KE 254 9;LS 266 8;LR 231 7-9;LY 218 9;MG 261 9;MW 265 9;ML 223 8;MR 222 8;MU 230 8;MA 212 9;MZ 258 9;NA 264 9;NE 227 8;NG 234 10;RW 250 9;ST 239 7;SN 221 9;SC 248 7;SL 232 8;SO 252 7-9;ZA 27 9;SS 211 9;SD 249 9;TZ 255 9;TG 228 8;TN 216 8;UG 256 9;ZM 260 9;ZW 263 9;AG 1 10;BS 1 10;BB 1 10;BZ 501 7;CA 1 10;CR 506 8;CU 53 8;DM 1 10;DO 1 10;SV 503 8;GD 1 10;GT 502 8;HT 509 8;HN 504 8;JM 1 10;MX 52 10;NI 505 8;PA 507 8;KN 1 10;LC 1 10;VC 1 10;TT 1 10;US 1 10;AR 54 10-11;BO 591 8;BR 55 11;CL 56 9;CO 57 10;EC 593 9;GY 592 7;PY 595 9;PE 51 9;SR 597 7;UY 598 8;VE 58 10;AU 61 9;FJ 679 7;KI 686 8;MH 692 7;FM 691 7;NR 674 7;NZ 64 8-10;PW 680 7;PG 675 8;WS 685 7-10;SB 677 7;TO 676 7;TV 688 6-7;VU 678 7;PS 970 9;VA 39 9-10;HK 852 8';

/// Every country in the UN list (owner, 23 Nov: "যেমনটা আমরা লোকেশনে
/// করেছিলাম"), Bangladesh first, then the rest in the list's order.
final List<PhoneCountry> phoneCountries = () {
  final out = <PhoneCountry>[];
  for (final row in _table.split(';')) {
    final p = row.split(' ');
    final c = countryOf(p[0]);
    if (c == null) continue;
    final zero = !p[2].endsWith('z');
    final len = p[2].replaceAll('z', '').split('-');
    out.add(PhoneCountry(c, p[1], int.parse(len.first), int.parse(len.last), zero: zero, starts: p[0] == 'BD' ? RegExp(r'^1[3-9]') : null));
  }
  final bd = out.indexWhere((p) => p.iso == 'BD');
  return [out.removeAt(bd), ...out];
}();

/// The countries of a continent, by name in the app's language.
List<PhoneCountry> phoneCountriesIn(String continent) => [
      for (final c in countriesIn(continent))
        for (final p in phoneCountries)
          if (p.iso == c.code) p,
    ];

/// The countries whose name (Bangla or English) or code matches [q].
List<PhoneCountry> findPhoneCountries(String q) {
  final f = asciiDigits(q).toLowerCase().replaceAll(RegExp(r'[+\s]'), '');
  if (f.isEmpty) return phoneCountries;
  final digits = RegExp(r'^\d+$').hasMatch(f);
  final starts = <PhoneCountry>[], inside = <PhoneCountry>[];
  for (final p in phoneCountries) {
    final names = [p.bn.replaceAll(' ', ''), p.en.toLowerCase().replaceAll(' ', '')];
    if (digits ? p.dial == f : names.any((n) => n.startsWith(f)) || p.iso.toLowerCase() == f) {
      starts.add(p);
    } else if (digits ? p.dial.startsWith(f) : names.any((n) => n.contains(f))) {
      inside.add(p);
    }
  }
  return [...starts, ...inside];
}

/// When codes are shared (+1, +7, +39), the country a number is read as.
const _shared = {'1': 'US', '7': 'RU', '39': 'IT'};

PhoneCountry get homeCountry => phoneCountries.first;

/// A kept number split into its country and the digits after the code.
/// Old numbers without a code ("01712345678") are Bangladeshi.
(PhoneCountry, String) splitPhone(String kept) {
  final s = asciiDigits(kept).replaceAll(RegExp(r'[^0-9+]'), '');
  if (s.startsWith('+')) {
    final d = s.substring(1);
    // The longest code that fits; a shared one is read as [_shared] says.
    PhoneCountry? best;
    for (final c in phoneCountries) {
      if (!d.startsWith(c.dial)) continue;
      if (best == null || c.dial.length > best.dial.length || (c.dial == best.dial && _shared[c.dial] == c.iso)) best = c;
    }
    if (best != null) return (best, d.substring(best.dial.length));
  }
  if (s.startsWith('880')) return (homeCountry, s.substring(3));
  return (homeCountry, s.replaceFirst(RegExp(r'^0+'), ''));
}

/// The digits a person may keep for [c]: a leading 0 (dialled at home) is
/// dropped, and nothing past the country's length.
String phoneDigits(PhoneCountry c, String typed) {
  var d = asciiDigits(typed).replaceAll(RegExp(r'[^0-9]'), '');
  // Pasted with the code ("+8801712…", "008801712…").
  d = d.replaceFirst(RegExp(r'^00'), '');
  if (d.length > c.max && d.startsWith(c.dial)) d = d.substring(c.dial.length);
  if (c.zero) d = d.replaceFirst(RegExp(r'^0+'), '');
  return d.length > c.max ? d.substring(0, c.max) : d;
}

/// Whether [digits] (after the code) can be a mobile number of [c].
bool validPhone(PhoneCountry c, String digits) =>
    digits.length >= c.min && digits.length <= c.max && RegExp(r'^\d+$').hasMatch(digits) && (c.starts?.hasMatch(digits) ?? true);

/// As kept: "+8801712345678".
String fullPhone(PhoneCountry c, String digits) => '+${c.dial}$digits';

/// As shown: "+880 1712-345678" (Bangla digits in Bangla).
String showPhone(String kept) {
  if (kept.isEmpty) return '';
  final (c, d) = splitPhone(kept);
  final body = c.iso == 'BD' && d.length == 10 ? '${d.substring(0, 4)}-${d.substring(4)}' : d;
  return bnDigits('${c.code} $body');
}
