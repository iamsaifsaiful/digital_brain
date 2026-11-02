/// The country the app is used in and the currency its money is kept in
/// (global version, owner 2 Nov 2026: one app, language and country apart).
///
/// The country follows the place (a district → 'BD'; a city abroad → its
/// code), so it moves with the phone. The currency is the one the member's
/// own amounts are in: chosen in সেটিংস, or the country's own until the
/// first money is written — then it stays, so travelling never relabels old
/// amounts. With 'BDT' everything reads exactly as before.
library;

/// One currency: its code, how an amount is written ("৳", "AED "), and its
/// name in Bangla and English.
class Currency {
  const Currency(this.code, this.sign, this.bn, this.en, {this.lakh = false});
  final String code;

  /// Put before the digits: a symbol ("£") or a code with a space ("AED ").
  final String sign;
  final String bn;
  final String en;

  /// Grouped 1,00,000 (South Asia) rather than 100,000.
  final bool lakh;
}

const currencies = <Currency>[
  Currency('BDT', '৳', 'টাকা', 'taka', lakh: true),
  Currency('USD', r'$', 'ডলার', 'US dollar'),
  Currency('GBP', '£', 'পাউন্ড', 'pound'),
  Currency('EUR', '€', 'ইউরো', 'euro'),
  Currency('AED', 'AED ', 'দিরহাম', 'dirham'),
  Currency('SAR', 'SAR ', 'রিয়াল', 'riyal'),
  Currency('QAR', 'QAR ', 'কাতারি রিয়াল', 'Qatari riyal'),
  Currency('KWD', 'KWD ', 'কুয়েতি দিনার', 'Kuwaiti dinar'),
  Currency('OMR', 'OMR ', 'ওমানি রিয়াল', 'Omani rial'),
  Currency('BHD', 'BHD ', 'বাহরাইনি দিনার', 'Bahraini dinar'),
  Currency('MYR', 'RM ', 'রিঙ্গিত', 'ringgit'),
  Currency('SGD', r'S$', 'সিঙ্গাপুর ডলার', 'Singapore dollar'),
  Currency('INR', '₹', 'রুপি', 'rupee', lakh: true),
  Currency('PKR', 'PKR ', 'পাকিস্তানি রুপি', 'Pakistani rupee', lakh: true),
  Currency('NPR', 'NPR ', 'নেপালি রুপি', 'Nepali rupee', lakh: true),
  Currency('LKR', 'LKR ', 'শ্রীলঙ্কান রুপি', 'Sri Lankan rupee'),
  Currency('MVR', 'MVR ', 'রুফিয়া', 'rufiyaa'),
  Currency('BTN', 'Nu ', 'নুলট্রাম', 'ngultrum'),
  Currency('CAD', r'C$', 'কানাডিয়ান ডলার', 'Canadian dollar'),
  Currency('AUD', r'A$', 'অস্ট্রেলিয়ান ডলার', 'Australian dollar'),
  Currency('NZD', r'NZ$', 'নিউজিল্যান্ড ডলার', 'New Zealand dollar'),
  Currency('JPY', '¥', 'ইয়েন', 'yen'),
  Currency('KRW', '₩', 'ওন', 'won'),
  Currency('CNY', 'CN¥', 'ইউয়ান', 'yuan'),
  Currency('HKD', r'HK$', 'হংকং ডলার', 'Hong Kong dollar'),
  Currency('THB', '฿', 'বাত', 'baht'),
  Currency('IDR', 'Rp ', 'রুপিয়া', 'rupiah'),
  Currency('BND', r'B$', 'ব্রুনাই ডলার', 'Brunei dollar'),
  Currency('MMK', 'MMK ', 'কিয়াত', 'kyat'),
  Currency('TRY', '₺', 'লিরা', 'lira'),
  Currency('EGP', 'EGP ', 'মিশরীয় পাউন্ড', 'Egyptian pound'),
  Currency('JOD', 'JOD ', 'জর্ডানি দিনার', 'Jordanian dinar'),
  Currency('LBP', 'LBP ', 'লেবানিজ পাউন্ড', 'Lebanese pound'),
  Currency('IQD', 'IQD ', 'ইরাকি দিনার', 'Iraqi dinar'),
  Currency('IRR', 'IRR ', 'ইরানি রিয়াল', 'Iranian rial'),
  Currency('LYD', 'LYD ', 'লিবিয়ান দিনার', 'Libyan dinar'),
  Currency('MUR', 'MUR ', 'মরিশাস রুপি', 'Mauritian rupee'),
  Currency('KES', 'KES ', 'কেনিয়ান শিলিং', 'Kenyan shilling'),
  Currency('NGN', '₦', 'নাইরা', 'naira'),
  Currency('ZAR', 'R ', 'র‍্যান্ড', 'rand'),
  Currency('RUB', '₽', 'রুবল', 'ruble'),
  Currency('SEK', 'SEK ', 'সুইডিশ ক্রোনা', 'Swedish krona'),
];

/// A country's own currency ('' or unknown → taka).
String currencyOf(String country) => switch (country.toUpperCase()) {
      'BD' || '' => 'BDT',
      'US' => 'USD',
      'GB' => 'GBP',
      'DE' || 'ES' || 'FR' || 'GR' || 'IT' || 'NL' || 'PT' || 'IE' || 'AT' || 'BE' || 'FI' || 'CY' || 'MT' => 'EUR',
      'AE' => 'AED',
      'SA' => 'SAR',
      'QA' => 'QAR',
      'KW' => 'KWD',
      'OM' => 'OMR',
      'BH' => 'BHD',
      'MY' => 'MYR',
      'SG' => 'SGD',
      'IN' => 'INR',
      'PK' => 'PKR',
      'NP' => 'NPR',
      'LK' => 'LKR',
      'MV' => 'MVR',
      'BT' => 'BTN',
      'CA' => 'CAD',
      'AU' => 'AUD',
      'NZ' => 'NZD',
      'JP' => 'JPY',
      'KR' => 'KRW',
      'CN' => 'CNY',
      'HK' => 'HKD',
      'TH' => 'THB',
      'ID' => 'IDR',
      'BN' => 'BND',
      'MM' => 'MMK',
      'TR' => 'TRY',
      'EG' => 'EGP',
      'JO' => 'JOD',
      'LB' => 'LBP',
      'IQ' => 'IQD',
      'IR' => 'IRR',
      'LY' => 'LYD',
      'MU' => 'MUR',
      'KE' => 'KES',
      'NG' => 'NGN',
      'ZA' => 'ZAR',
      'RU' => 'RUB',
      'SE' => 'SEK',
      _ => 'USD',
    };

Currency currencyByCode(String code) => currencies.firstWhere((c) => c.code == code, orElse: () => currencies.first);

/// Where the app is used now: 'BD', a two-letter code abroad, or '' (abroad,
/// country not known). Set by the brain from the place.
String appCountry = 'BD';

/// The currency amounts are kept and shown in.
Currency appCurrency = currencies.first;

/// In Bangladesh (or not known to be elsewhere): bKash, BAJUS, districts,
/// Bangladesh's holidays and blood requests apply.
bool get inBangladesh => appCountry == 'BD';

/// The Bangladeshi part (bKash, Nagad, Rocket, BAJUS gold price, the
/// Bangla calendar and seasons): on when the app is in Bangla or the phone
/// is in Bangladesh — a Bangla-speaking member abroad keeps the family's
/// bKash and the Bangla date (owner, 2 Nov: "ভাষা + দেশ"). Can be switched.
bool bangladeshPart = true;

/// The Islamic part (prayer times, sehri and iftar, the qibla, the Hijri
/// date, zakat): on by default where most people are Muslim or the app is in
/// Bangla; anyone can switch it on or off.
bool islamicPart = true;

/// Blood requests: Bangladesh's districts and hospitals only, so only while
/// the phone is in Bangladesh (owner, 2 Nov).
bool get bloodHere => appCountry == 'BD';

/// Countries where most people are Muslim (the Islamic part's default).
const muslimMajority = {
  'BD', 'PK', 'AF', 'ID', 'MY', 'BN', 'MV', 'SA', 'AE', 'QA', 'KW', 'OM', 'BH', 'YE', 'IQ', 'IR', 'JO', 'SY', 'PS',
  'EG', 'LY', 'TN', 'DZ', 'MA', 'MR', 'SD', 'SO', 'DJ', 'TR', 'AZ', 'KZ', 'UZ', 'TM', 'TJ', 'KG', 'SN', 'GM', 'GN',
  'ML', 'NE', 'BF', 'SL', 'TD', 'KM', 'XK', 'AL', 'LB',
};

/// The default of each part, before the member chooses ([choice] '' = auto,
/// 'on' or 'off').
bool partOn(String choice, bool auto) => choice == 'on' ? true : (choice == 'off' ? false : auto);
bool bangladeshAuto({required String country, required bool english}) => country == 'BD' || !english;
bool islamicAuto({required String country, required bool english}) => !english || muslimMajority.contains(country.toUpperCase());

/// The first day of the week where the app is used: Saturday in Bangladesh
/// (as always), Sunday in the Gulf and the Americas, Monday elsewhere.
int get weekStart => _weekStartOf(appCountry);
int _weekStartOf(String c) {
  if (const {'BD', 'AF', 'IR', 'EG', 'LY', 'DZ', 'SY', 'IQ', 'JO'}.contains(c)) return DateTime.saturday;
  if (const {'SA', 'QA', 'KW', 'OM', 'BH', 'YE', 'IL', 'US', 'CA', 'MX', 'BR', 'JP', 'PH', 'TH', 'HK', 'TW', 'ZA', 'KE', 'IN', 'PK', 'NP', 'BT'}.contains(c)) {
    return DateTime.sunday;
  }
  return DateTime.monday;
}

/// The weekend: Friday and Saturday in Bangladesh and most of the Gulf,
/// Friday alone in Iran, Saturday and Sunday elsewhere.
Set<int> get weekendDays {
  final c = appCountry;
  if (const {'BD', 'SA', 'QA', 'KW', 'OM', 'BH', 'YE', 'EG', 'JO', 'IQ', 'LY', 'DZ', 'SY', 'SD', 'MV'}.contains(c)) return const {DateTime.friday, DateTime.saturday};
  if (c == 'IR' || c == 'AF') return const {DateTime.friday};
  return const {DateTime.saturday, DateTime.sunday};
}

/// Temperatures in °F (the US and a few others), else °C.
bool get fahrenheit => const {'US', 'BS', 'BZ', 'KY', 'PW', 'LR', 'FM', 'MH'}.contains(appCountry);

/// A °C reading in the unit of the place, rounded.
int degrees(double celsius) => (fahrenheit ? celsius * 9 / 5 + 32 : celsius).round();

/// Taka: every text reads exactly as it always has.
bool get takaMoney => appCurrency.code == 'BDT';

/// "৳", "AED ", "£".
String get moneySign => appCurrency.sign;

/// For an amount box's prefix: "৳ ", "AED ", "£ ".
String get moneyPrefix => '${appCurrency.sign.trimRight()} ';

/// The currency's name in the app's language ("দিরহাম" / "dirham").
String currencyName({required bool english}) => english ? appCurrency.en : appCurrency.bn;

/// How people say the member's currency, besides টাকা/tk/৳ (which always
/// mean money): only the member's own, so a taka member's "৫০ ডলার" is
/// never written as ৳৫০.
const _spoken = <String, List<String>>{
  'USD': [r'$', 'usd', 'dollar', 'dollars', 'ডলার'],
  'GBP': ['£', 'gbp', 'pound', 'pounds', 'quid', 'পাউন্ড'],
  'EUR': ['€', 'eur', 'euro', 'euros', 'ইউরো'],
  'AED': ['aed', 'dirham', 'dirhams', 'dhs', 'দিরহাম'],
  'SAR': ['sar', 'riyal', 'riyals', 'rial', 'rials', 'রিয়াল', 'রিয়েল'],
  'QAR': ['qar', 'riyal', 'riyals', 'রিয়াল', 'রিয়েল'],
  'OMR': ['omr', 'rial', 'rials', 'riyal', 'রিয়াল'],
  'KWD': ['kwd', 'dinar', 'dinars', 'দিনার'],
  'BHD': ['bhd', 'dinar', 'dinars', 'দিনার'],
  'JOD': ['jod', 'dinar', 'dinars', 'দিনার'],
  'MYR': ['myr', 'rm', 'ringgit', 'রিঙ্গিত', 'রিংগিত'],
  'SGD': [r's$', 'sgd', 'dollar', 'dollars', 'ডলার'],
  'INR': ['₹', 'inr', 'rupee', 'rupees', 'rs', 'রুপি', 'রুপী', 'টাকা'],
  'PKR': ['pkr', 'rupee', 'rupees', 'rs', 'রুপি'],
  'CAD': [r'c$', 'cad', 'dollar', 'dollars', 'ডলার'],
  'AUD': [r'a$', 'aud', 'dollar', 'dollars', 'ডলার'],
  'NZD': [r'nz$', 'nzd', 'dollar', 'dollars', 'ডলার'],
  'JPY': ['¥', 'jpy', 'yen', 'ইয়েন'],
  'KRW': ['₩', 'krw', 'won', 'ওন'],
  'HKD': [r'hk$', 'hkd', 'dollar', 'dollars', 'ডলার'],
  'BND': [r'b$', 'bnd', 'dollar', 'dollars', 'ডলার'],
  'MVR': ['mvr', 'rufiyaa', 'রুফিয়া'],
  'LKR': ['lkr', 'rupee', 'rupees', 'রুপি'],
  'NPR': ['npr', 'rupee', 'rupees', 'রুপি'],
  'TRY': ['₺', 'lira', 'লিরা'],
  'ZAR': ['zar', 'rand', 'র‍্যান্ড'],
};

/// Taka said as the second currency: only words that cannot mean the main
/// money (a member on riyal often calls riyal "টাকা" too).
const _takaSecond = ['bdt', '৳', 'দেশি টাকা', 'দেশের টাকা', 'বাংলাদেশি টাকা', 'বাংলাদেশের টাকা', 'deshi taka'];

/// The words of the currency [code] (lower case), longest first.
List<String> currencyWords(String code, {bool second = false}) {
  if (code == 'BDT') return second ? (List.of(_takaSecond)..sort((a, b) => b.length.compareTo(a.length))) : const [];
  final c = currencyByCode(code);
  final w = {...?_spoken[code], code.toLowerCase(), c.en.toLowerCase(), c.bn};
  w.remove('টাকা');
  return w.toList()..sort((a, b) => b.length.compareTo(a.length));
}

/// The member's currency words (lower case), longest first; empty for taka.
/// With a second currency, its words too: both are read as amounts (which
/// one was meant is found by [mentionsSecond]).
List<String> spokenCurrency() {
  final w = <String>{if (!takaMoney) ...currencyWords(appCurrency.code), if (secondCurrency case final c?) ...currencyWords(c.code, second: true)};
  return w.toList()..sort((a, b) => b.length.compareTo(a.length));
}

/// The second currency (global version: "দুই মুদ্রা, দুই দেশের জীবন") —
/// its money is kept in its own হিসাব, never added to the main money.
Currency? secondCurrency;

/// The words said name the second currency ("৫০০ রিয়াল খরচ", "দেশের টাকা ১০ হাজার").
bool mentionsSecond(String said) {
  final c = secondCurrency;
  if (c == null) return false;
  String fold(String x) => x.toLowerCase().replaceAll('\u09DF', '\u09AF\u09BC').replaceAll('\u09DC', '\u09A1\u09BC');
  final t = fold(said);
  for (final w0 in currencyWords(c.code, second: true)) {
    final w = fold(w0);
    final at = t.indexOf(w);
    if (at < 0) continue;
    // A word, not part of another ("rs" in "hours").
    final before = at == 0 ? ' ' : t[at - 1];
    final after = at + w.length >= t.length ? ' ' : t[at + w.length];
    bool letter(String ch) => RegExp('[a-z]').hasMatch(ch);
    if (RegExp('[a-z]').hasMatch(w) && (letter(before) || letter(after))) continue;
    return true;
  }
  return false;
}

final _shown = <Currency>[];

/// A page about the second currency's হিসাব is open: amounts show in that
/// currency until [endCurrencyView] (the page's own life).
void startCurrencyView(String code) {
  _shown.add(appCurrency);
  appCurrency = currencyByCode(code);
}

void endCurrencyView() {
  if (_shown.isNotEmpty) appCurrency = _shown.removeLast();
}

/// The currency of the main money, even while a second-currency page is open.
Currency get mainCurrency => _shown.isEmpty ? appCurrency : _shown.first;

/// Sets both at once (tests and the brain).
void setRegion({String? country, String? currency, String? second}) {
  if (country != null) appCountry = country.toUpperCase();
  if (currency != null) {
    if (_shown.isEmpty) {
      appCurrency = currencyByCode(currency);
    } else {
      _shown[0] = currencyByCode(currency);
    }
  }
  if (second != null) secondCurrency = second.isEmpty || second == mainCurrency.code ? null : currencyByCode(second);
}

final _tkAfterValue = RegExp('(\\{\\d\\}) টাকা(র|\u09DF|\u09AF\u09BC)?(?![\u0980-\u09FF])');
final _takaAfterValueEn = RegExp(r'(\{\d\}) taka\b');

/// A text template with ৳ and "{n} টাকা" put in the member's currency.
/// Untouched for taka. Only amounts are changed: "{1} টাকা" → "{1}
/// দিরহাম", "৳{0}" → "AED {0}"; a plain "টাকা" (money in general, or an
/// example sentence) stays.
String inCurrency(String s, {required bool english}) {
  if (takaMoney) return s;
  var out = s;
  if (english) {
    out = out.replaceAllMapped(_takaAfterValueEn, (m) => '$moneySign${m[1]}');
  } else {
    out = out.replaceAllMapped(_tkAfterValue, (m) {
      final name = appCurrency.bn;
      final tail = switch (m[2]) {
        'র' => _bnPossessive(name),
        '\u09DF' || '\u09AF\u09BC' => _bnLocative(name),
        _ => '',
      };
      return '${m[1]} $name$tail';
    });
  }
  if (out.contains('৳')) {
    // Before an amount: the sign as written before digits ("AED {0}");
    // alone ("(৳)"), the bare sign.
    out = out.replaceAll('৳ ', moneyPrefix).replaceAllMapped(RegExp(r'৳(?=[\{0-9০-৯])|৳'), (m) => m[0]!.length == 1 && m.end < out.length && RegExp(r'[\{0-9০-৯]').hasMatch(out[m.end]) ? moneySign : moneySign.trimRight());
  }
  return out;
}

bool _endsInVowelSign(String w) {
  if (w.isEmpty) return false;
  final c = w.codeUnitAt(w.length - 1);
  return (c >= 0x09BE && c <= 0x09CC) || c == 0x09D7;
}

/// "দিরহাম" → "দিরহামের", "রুপি" → "রুপির".
String _bnPossessive(String w) => _endsInVowelSign(w) ? 'র' : 'ের';

/// "দিরহাম" → "দিরহামে", "রুপি" → "রুপিতে".
String _bnLocative(String w) => _endsInVowelSign(w) ? 'তে' : 'ে';
