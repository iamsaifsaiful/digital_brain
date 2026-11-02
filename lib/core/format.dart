/// Numbers, money, phone numbers and dates, written the way the app shows
/// them: Bangla digits, Indian grouping (১,১৩,৭৫০), riyal as "SAR" and taka
/// as "৳".
library;

const _bnDigits = '০১২৩৪৫৬৭৮৯';

/// The app shows English instead of Bangla (see lang.dart).
bool appEnglish = false;

/// "123" → "১২৩". Other characters stay.
String bn(String s) => s.replaceAllMapped(RegExp('[0-9]'), (m) => _bnDigits[int.parse(m[0]!)]);

/// "১২৩" → "123". Other characters stay.
String en(String s) => s.replaceAllMapped(RegExp('[০-৯]'), (m) => '${_bnDigits.indexOf(m[0]!)}');

/// 113750 → "1,13,750" (Indian grouping). [decimals] digits after the
/// point; trailing ".00" is dropped unless [keepZeros].
String groupEn(num n, {int decimals = 0, bool keepZeros = false}) {
  final neg = n < 0;
  var s = n.abs().toStringAsFixed(decimals);
  var frac = '';
  if (decimals > 0) {
    final i = s.indexOf('.');
    frac = s.substring(i);
    s = s.substring(0, i);
    if (!keepZeros) {
      frac = frac.replaceFirst(RegExp(r'0+$'), '');
      if (frac == '.') frac = '';
    }
  }
  String head;
  if (s.length <= 3) {
    head = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    head = '${parts.join(',')},$last3';
  }
  return '${neg ? '-' : ''}$head$frac';
}

/// Bangla digits with Indian grouping: 113750 → "১,১৩,৭৫০".
String bnNum(num n, {int decimals = 0, bool keepZeros = false}) => bn(groupEn(n, decimals: decimals, keepZeros: keepZeros));

/// Riyal amount: "৫০০ SAR" (up to 2 decimals, only when needed).
String sar(num n) => '${bnNum(n, decimals: 2)} SAR';

/// Taka amount: "৳ ১৬,২৫০".
String taka(num n) => '৳ ${bnNum(n.round())}';

/// A rate with two decimals: 32.5 → "৩২.৫০".
String rateText(num r) => bn(r.toStringAsFixed(2));

/// Reads a number typed with Bangla or English digits, commas or spaces.
/// Null when there is no number.
double? parseNum(String s) {
  final t = en(s).replaceAll(RegExp(r'[,\s৳]'), '').replaceAll('SAR', '').trim();
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || v.isNaN || v.isInfinite) return null;
  return v;
}

/// A Bangladeshi mobile number in its 11-digit form ("01812345901"), or
/// null when it is not one. Accepts +880 / 880 / 88 prefixes, spaces,
/// dashes and Bangla digits.
String? bdMobile(String s) {
  var d = en(s).replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('880')) d = d.substring(2);
  if (d.startsWith('88') && d.length == 13) d = d.substring(2);
  if (d.length == 10 && d.startsWith('1')) d = '0$d';
  if (d.length != 11 || !d.startsWith('01')) return null;
  if (!'3456789'.contains(d[2])) return null;
  return d;
}

/// "01812345901" → "01812-345901" (English digits, for the agent to copy).
String bdShowEn(String d) => d.length == 11 ? '${d.substring(0, 5)}-${d.substring(5)}' : d;

/// "01812345901" → "০১৮১২ ৩৪৫৯০১".
String bdShow(String d) => d.length == 11 ? bn('${d.substring(0, 5)} ${d.substring(5)}') : bn(d);

/// "01812345901" → "০১৮••••৯০১".
String bdMasked(String d) => d.length == 11 ? bn('${d.substring(0, 3)}••••${d.substring(8)}') : bn(d);

/// The international digits WhatsApp links need (no plus). Saudi numbers
/// starting 05… become 9665…; Bangladeshi 01… become 8801….
String waNumber(String phone) {
  var d = en(phone).replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('00')) d = d.substring(2);
  if (d.length == 11 && d.startsWith('01')) return '88$d';
  if (d.length == 10 && d.startsWith('05')) return '966${d.substring(1)}';
  if (d.length == 9 && d.startsWith('5')) return '966$d';
  return d;
}

const _months = ['জানু', 'ফেব্রু', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টে', 'অক্টো', 'নভে', 'ডিসে'];
const monthsLong = ['জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'];
const _days = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহস্পতি', 'শুক্র', 'শনি', 'রবি'];

String monthShort(int m) => _months[m - 1];

/// "রাত ১১:৫৮".
String timeText(DateTime t) {
  final h = t.hour;
  final part = h < 4
      ? 'রাত'
      : h < 6
          ? 'ভোর'
          : h < 12
              ? 'সকাল'
              : h < 15
                  ? 'দুপুর'
                  : h < 18
                      ? 'বিকাল'
                      : h < 20
                          ? 'সন্ধ্যা'
                          : 'রাত';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$part ${bn('$h12:${t.minute.toString().padLeft(2, '0')}')}';
}

/// "২৫ অক্টো".
String dateShort(DateTime t) => '${bn('${t.day}')} ${_months[t.month - 1]}';

/// "রবি, ২৫ অক্টো ২০২৬".
String dateLong(DateTime t) => '${_days[t.weekday - 1]}, ${dateShort(t)} ${bn('${t.year}')}';

/// "আজ", "গতকাল" or "রবি, ২৫ অক্টো".
String dayLabel(DateTime t, DateTime now) {
  final a = DateTime(t.year, t.month, t.day);
  final b = DateTime(now.year, now.month, now.day);
  final diff = b.difference(a).inDays;
  if (diff == 0) return 'আজ · ${_days[t.weekday - 1]}, ${dateShort(t)}';
  if (diff == 1) return 'গতকাল · ${_days[t.weekday - 1]}, ${dateShort(t)}';
  return '${_days[t.weekday - 1]}, ${dateShort(t)}${t.year != now.year ? ' ${bn('${t.year}')}' : ''}';
}

/// "আজ", "গতকাল", "৩ দিন আগে", "২৫ অক্টো".
String ago(DateTime t, DateTime now) {
  final a = DateTime(t.year, t.month, t.day);
  final b = DateTime(now.year, now.month, now.day);
  final d = b.difference(a).inDays;
  if (d <= 0) return 'আজ';
  if (d == 1) return 'গতকাল';
  if (d < 30) return '${bn('$d')} দিন আগে';
  return dateShort(t);
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// A Saudi mobile number as "05XXXXXXXX", from 05…, 5…, 9665… or +9665…;
/// null when it is not one.
String? saMobile(String s) {
  var d = en(s).replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('00966')) d = d.substring(2);
  if (d.startsWith('966')) d = '0${d.substring(3)}';
  if (d.startsWith('5')) d = '0$d';
  return RegExp(r'^05[0-9]{8}$').hasMatch(d) ? d : null;
}

/// How many digits a Saudi mobile number may have, as it is being typed.
int saMaxDigits(String typed) {
  final d = en(typed).replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('00966')) return 14;
  if (d.startsWith('966')) return 12;
  if (d.startsWith('5')) return 9;
  return 10;
}

/// A rough "sound" of a name in either script, so "karim" finds "করিম" and
/// "রহিম" finds "Rahim": consonants only, look-alike sounds merged.
String soundKey(String s) {
  const bnMap = {
    'ক': 'k', 'খ': 'k', 'গ': 'g', 'ঘ': 'g', 'ঙ': 'n', 'চ': 'c', 'ছ': 'c', 'জ': 'j', 'ঝ': 'j', 'য': 'j', 'ঞ': 'n', //
    'ট': 't', 'ঠ': 't', 'ড': 'd', 'ঢ': 'd', 'ণ': 'n', 'ত': 't', 'থ': 't', 'দ': 'd', 'ধ': 'd', 'ন': 'n', //
    'প': 'p', 'ফ': 'f', 'ব': 'b', 'ভ': 'b', 'ম': 'm', 'র': 'r', 'ড়': 'r', 'ঢ়': 'r', 'ল': 'l', 'শ': 's', 'ষ': 's', 'স': 's', //
    'হ': 'h', 'ৎ': 't', 'ং': 'ng', 'ঃ': 'h', 'য়': '',
  };
  final t = s.toLowerCase().replaceAll('়', '').replaceAll('ড়', 'ড়').replaceAll('ঢ়', 'ঢ়').replaceAll('য়', 'য়');
  final out = StringBuffer();
  final latin = t
      .replaceAll(RegExp(r'[^a-zঀ-৿]'), '')
      .replaceAll('kh', 'k')
      .replaceAll('gh', 'g')
      .replaceAll('ch', 'c')
      .replaceAll('jh', 'j')
      .replaceAll('th', 't')
      .replaceAll('dh', 'd')
      .replaceAll('ph', 'f')
      .replaceAll('bh', 'b')
      .replaceAll('sh', 's');
  for (final r in latin.runes) {
    final c = String.fromCharCode(r);
    if (bnMap.containsKey(c)) {
      out.write(bnMap[c]);
    } else if (RegExp('[bcdfghjklmnprst]').hasMatch(c)) {
      out.write(c);
    } else if (c == 'q') {
      out.write('k');
    } else if (c == 'z') {
      out.write('j');
    } else if (c == 'v' || c == 'w') {
      out.write('b');
    } else if (c == 'x') {
      out.write('ks');
    }
    // Vowels, vowel signs, য়/y and the rest carry no weight here.
  }
  // Doubled letters (মম্মদ / mohammad) count once.
  return out.toString().replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);
}

String weekdayName(DateTime d) => const ['সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার', 'রবিবার'][d.weekday - 1];
