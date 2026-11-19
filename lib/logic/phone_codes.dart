// The country of a mobile number (owner, 19 Nov): the profile's number always
// has a country code (Bangladesh +880 first), and no more digits can be typed
// than that country's mobile numbers have. Lengths are the number after the
// country code, without the 0 some countries dial at home.
library;

import 'bn.dart';
import 'lang.dart';

class PhoneCountry {
  const PhoneCountry(this.iso, this.bn, this.en, this.dial, this.min, this.max, [this.starts]);

  /// Two letters (BD), also the flag.
  final String iso;
  final String bn;
  final String en;

  /// The country code's digits, without the plus (880).
  final String dial;

  /// Fewest and most digits of a mobile number after the code.
  final int min;
  final int max;

  /// What a mobile number must start with, when that is known for sure.
  final RegExp? starts;

  String get name => isEn ? en : bn;
  String get code => '+$dial';

  /// The flag, drawn by the phone from the two letters.
  String get flag => String.fromCharCodes(iso.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 65));

  /// How many digits, said on the field ("১০ অঙ্ক" or "৯–১০ অঙ্ক").
  String get lengthLabel => min == max ? bnDigits(max) : '${bnDigits(min)}–${bnDigits(max)}';
}

/// Bangladesh first, then where most Bangladeshis live and work, then the rest by name.
final List<PhoneCountry> phoneCountries = [
  PhoneCountry('BD', 'বাংলাদেশ', 'Bangladesh', '880', 10, 10, RegExp(r'^1[3-9]')),
  const PhoneCountry('SA', 'সৌদি আরব', 'Saudi Arabia', '966', 9, 9),
  const PhoneCountry('AE', 'সংযুক্ত আরব আমিরাত', 'United Arab Emirates', '971', 9, 9),
  const PhoneCountry('MY', 'মালয়েশিয়া', 'Malaysia', '60', 9, 10),
  const PhoneCountry('QA', 'কাতার', 'Qatar', '974', 8, 8),
  const PhoneCountry('KW', 'কুয়েত', 'Kuwait', '965', 8, 8),
  const PhoneCountry('OM', 'ওমান', 'Oman', '968', 8, 8),
  const PhoneCountry('SG', 'সিঙ্গাপুর', 'Singapore', '65', 8, 8),
  const PhoneCountry('GB', 'যুক্তরাজ্য', 'United Kingdom', '44', 10, 10),
  const PhoneCountry('US', 'যুক্তরাষ্ট্র', 'United States', '1', 10, 10),
  const PhoneCountry('IN', 'ভারত', 'India', '91', 10, 10),
  const PhoneCountry('IT', 'ইতালি', 'Italy', '39', 9, 10),
  const PhoneCountry('BH', 'বাহরাইন', 'Bahrain', '973', 8, 8),
  const PhoneCountry('JO', 'জর্ডান', 'Jordan', '962', 9, 9),
  const PhoneCountry('LB', 'লেবানন', 'Lebanon', '961', 7, 8),
  const PhoneCountry('MV', 'মালদ্বীপ', 'Maldives', '960', 7, 7),
  const PhoneCountry('CA', 'কানাডা', 'Canada', '1', 10, 10),
  const PhoneCountry('AU', 'অস্ট্রেলিয়া', 'Australia', '61', 9, 9),
  const PhoneCountry('JP', 'জাপান', 'Japan', '81', 10, 10),
  const PhoneCountry('KR', 'দক্ষিণ কোরিয়া', 'South Korea', '82', 9, 10),
  const PhoneCountry('PK', 'পাকিস্তান', 'Pakistan', '92', 10, 10),
  const PhoneCountry('NP', 'নেপাল', 'Nepal', '977', 10, 10),
  const PhoneCountry('LK', 'শ্রীলঙ্কা', 'Sri Lanka', '94', 9, 9),
  const PhoneCountry('BT', 'ভুটান', 'Bhutan', '975', 8, 8),
  const PhoneCountry('MM', 'মিয়ানমার', 'Myanmar', '95', 8, 10),
  const PhoneCountry('CN', 'চীন', 'China', '86', 11, 11),
  const PhoneCountry('HK', 'হংকং', 'Hong Kong', '852', 8, 8),
  const PhoneCountry('TH', 'থাইল্যান্ড', 'Thailand', '66', 9, 9),
  const PhoneCountry('ID', 'ইন্দোনেশিয়া', 'Indonesia', '62', 9, 12),
  const PhoneCountry('BN', 'ব্রুনাই', 'Brunei', '673', 7, 7),
  const PhoneCountry('TR', 'তুরস্ক', 'Turkey', '90', 10, 10),
  const PhoneCountry('IQ', 'ইরাক', 'Iraq', '964', 10, 10),
  const PhoneCountry('LY', 'লিবিয়া', 'Libya', '218', 9, 9),
  const PhoneCountry('EG', 'মিশর', 'Egypt', '20', 10, 10),
  const PhoneCountry('ZA', 'দক্ষিণ আফ্রিকা', 'South Africa', '27', 9, 9),
  const PhoneCountry('MU', 'মরিশাস', 'Mauritius', '230', 8, 8),
  const PhoneCountry('DE', 'জার্মানি', 'Germany', '49', 10, 11),
  const PhoneCountry('FR', 'ফ্রান্স', 'France', '33', 9, 9),
  const PhoneCountry('ES', 'স্পেন', 'Spain', '34', 9, 9),
  const PhoneCountry('PT', 'পর্তুগাল', 'Portugal', '351', 9, 9),
  const PhoneCountry('GR', 'গ্রিস', 'Greece', '30', 10, 10),
  const PhoneCountry('NL', 'নেদারল্যান্ডস', 'Netherlands', '31', 9, 9),
  const PhoneCountry('IE', 'আয়ারল্যান্ড', 'Ireland', '353', 9, 9),
  const PhoneCountry('SE', 'সুইডেন', 'Sweden', '46', 9, 9),
  const PhoneCountry('PL', 'পোল্যান্ড', 'Poland', '48', 9, 9),
  const PhoneCountry('RO', 'রোমানিয়া', 'Romania', '40', 9, 9),
  const PhoneCountry('RU', 'রাশিয়া', 'Russia', '7', 10, 10),
  const PhoneCountry('NZ', 'নিউজিল্যান্ড', 'New Zealand', '64', 8, 10),
];

PhoneCountry get homeCountry => phoneCountries.first;

/// A kept number split into its country and the digits after the code.
/// Old numbers without a code ("01712345678") are Bangladeshi.
(PhoneCountry, String) splitPhone(String kept) {
  final s = asciiDigits(kept).replaceAll(RegExp(r'[^0-9+]'), '');
  if (s.startsWith('+')) {
    final d = s.substring(1);
    // The longest code that fits (+1 is both the US and Canada: the US).
    PhoneCountry? best;
    for (final c in phoneCountries) {
      if (d.startsWith(c.dial) && (best == null || c.dial.length > best.dial.length)) best = c;
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
  d = d.replaceFirst(RegExp(r'^0+'), '');
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
