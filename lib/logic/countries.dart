// Every country in the UN's list (owner, 20 Nov: "বিশ্বের সব দেশ থাকতে হবে,
// জাতিসংঘের তালিকায় সকল দেশ") — the 193 members, the two observer states
// (Palestine, the Holy See) and Hong Kong (kept: members chose it before).
// Each with its Bengali and English name, its continent, its capital (where
// the weather and the clock are read when the country itself is picked)
// and, for countries Nager.Date has no list for, the main days off: the
// national day(s) and the great religious days the country keeps.
library;

import 'calendar_bd.dart' show hijriDate;
import 'holidays_abroad.dart' show AbroadHoliday;
import 'lang.dart' show isEn, tr;

class Country {
  const Country(this.code, this.bn, this.en, this.continent, this.capitalBn, this.capitalEn, this.lat, this.lon, this.tz, this.faith, this.days,
      {this.un = true, this.observer = false});

  /// Two letters (ISO 3166).
  final String code;
  final String bn, en;

  /// 'as', 'eu', 'af', 'na' (North and Central America, the Caribbean),
  /// 'sa', 'oc'.
  final String continent;
  final String capitalBn, capitalEn;
  final double lat, lon;

  /// Minutes from UTC at the capital (standard time).
  final int tz;

  /// The religious days kept: n (1 January), c (Christmas, Good Friday),
  /// o (Orthodox Christmas, 7 January), m (the two Eids).
  final String faith;

  /// The fixed national days: "MMDD Name;MMDD Name".
  final String days;

  /// A UN member; [observer]: a UN observer state.
  final bool un, observer;

  /// The name in the app's language.
  String get label => isEn ? en : bn;
  String get capitalLabel => isEn ? capitalEn : capitalBn;
}

const continents = <String, String>{
  'as': 'এশিয়া',
  'eu': 'ইউরোপ',
  'af': 'আফ্রিকা',
  'na': 'উত্তর ও মধ্য আমেরিকা',
  'sa': 'দক্ষিণ আমেরিকা',
  'oc': 'ওশেনিয়া',
};

/// A continent's name in the app's language.
String continentLabel(String c) => tr(continents[c] ?? c);

const worldCountries = <Country>[
  Country('AF', 'আফগানিস্তান', 'Afghanistan', 'as', 'কাবুল', 'Kabul', 34.53, 69.17, 270, 'm', '0321 Nowruz;0819 Independence Day'),
  Country('AM', 'আর্মেনিয়া', 'Armenia', 'as', 'ইয়েরেভান', 'Yerevan', 40.18, 44.51, 240, 'n', '0921 Independence Day'),
  Country('AZ', 'আজারবাইজান', 'Azerbaijan', 'as', 'বাকু', 'Baku', 40.41, 49.87, 240, 'nm', '0528 Independence Day'),
  Country('BH', 'বাহরাইন', 'Bahrain', 'as', 'মানামা', 'Manama', 26.2285, 50.586, 180, 'nm', '1216 National Day'),
  Country('BD', 'বাংলাদেশ', 'Bangladesh', 'as', 'ঢাকা', 'Dhaka', 23.81, 90.41, 360, 'nm', '0326 Independence Day;1216 Victory Day'),
  Country('BT', 'ভুটান', 'Bhutan', 'as', 'থিম্পু', 'Thimphu', 27.4728, 89.639, 360, 'n', '1217 National Day'),
  Country('BN', 'ব্রুনাই', 'Brunei', 'as', 'বন্দর সেরি বেগাওয়ান', 'Bandar Seri Begawan', 4.9, 114.94, 480, 'nmc', '0223 National Day'),
  Country('KH', 'কম্বোডিয়া', 'Cambodia', 'as', 'নমপেন', 'Phnom Penh', 11.56, 104.92, 420, 'n', '1109 Independence Day'),
  Country('CN', 'চীন', 'China', 'as', 'বেইজিং', 'Beijing', 39.9042, 116.4074, 480, 'n', '1001 National Day'),
  Country('GE', 'জর্জিয়া', 'Georgia', 'as', 'তিবিলিসি', 'Tbilisi', 41.72, 44.79, 240, 'no', '0526 Independence Day'),
  Country('IN', 'ভারত', 'India', 'as', 'নয়াদিল্লি', 'New Delhi', 28.61, 77.21, 330, 'nmc', '0126 Republic Day;0815 Independence Day;1002 Gandhi Jayanti'),
  Country('ID', 'ইন্দোনেশিয়া', 'Indonesia', 'as', 'জাকার্তা', 'Jakarta', -6.2088, 106.8456, 420, 'nmc', '0817 Independence Day'),
  Country('IR', 'ইরান', 'Iran', 'as', 'তেহরান', 'Tehran', 35.6892, 51.389, 210, 'm', '0211 Revolution Day;0321 Nowruz'),
  Country('IQ', 'ইরাক', 'Iraq', 'as', 'বাগদাদ', 'Baghdad', 33.3152, 44.3661, 180, 'nmc', '1003 National Day'),
  Country('IL', 'ইসরায়েল', 'Israel', 'as', 'তেল আবিব', 'Tel Aviv', 32.09, 34.78, 120, '', ''),
  Country('JP', 'জাপান', 'Japan', 'as', 'টোকিও', 'Tokyo', 35.6762, 139.6503, 540, 'n', '0211 National Foundation Day'),
  Country('JO', 'জর্ডান', 'Jordan', 'as', 'আম্মান', 'Amman', 31.9454, 35.9284, 180, 'nmc', '0525 Independence Day'),
  Country('KZ', 'কাজাখস্তান', 'Kazakhstan', 'as', 'আস্তানা', 'Astana', 51.17, 71.45, 300, 'nom', '1216 Independence Day'),
  Country('KW', 'কুয়েত', 'Kuwait', 'as', 'কুয়েত সিটি', 'Kuwait City', 29.3759, 47.9774, 180, 'nm', '0225 National Day'),
  Country('KG', 'কিরগিজস্তান', 'Kyrgyzstan', 'as', 'বিশকেক', 'Bishkek', 42.87, 74.59, 360, 'nom', '0831 Independence Day'),
  Country('LA', 'লাওস', 'Laos', 'as', 'ভিয়েনতিয়েন', 'Vientiane', 17.98, 102.63, 420, 'n', '1202 National Day'),
  Country('LB', 'লেবানন', 'Lebanon', 'as', 'বৈরুত', 'Beirut', 33.8938, 35.5018, 120, 'nmc', '1122 Independence Day'),
  Country('MY', 'মালয়েশিয়া', 'Malaysia', 'as', 'কুয়ালালামপুর', 'Kuala Lumpur', 3.139, 101.6869, 480, 'nmc', '0831 National Day'),
  Country('MV', 'মালদ্বীপ', 'Maldives', 'as', 'মালে', 'Malé', 4.1755, 73.5093, 300, 'm', '0726 Independence Day'),
  Country('MN', 'মঙ্গোলিয়া', 'Mongolia', 'as', 'উলানবাটর', 'Ulaanbaatar', 47.89, 106.91, 480, 'n', '0711 Naadam'),
  Country('MM', 'মিয়ানমার', 'Myanmar', 'as', 'নেপিডো', 'Naypyidaw', 19.76, 96.08, 390, 'nc', '0104 Independence Day'),
  Country('NP', 'নেপাল', 'Nepal', 'as', 'কাঠমান্ডু', 'Kathmandu', 27.7172, 85.324, 345, '', '0919 Constitution Day'),
  Country('KP', 'উত্তর কোরিয়া', 'North Korea', 'as', 'পিয়ংইয়ং', 'Pyongyang', 39.04, 125.76, 540, 'n', '0909 Founding Day'),
  Country('OM', 'ওমান', 'Oman', 'as', 'মাস্কাট', 'Muscat', 23.588, 58.3829, 240, 'm', '1120 National Day'),
  Country('PK', 'পাকিস্তান', 'Pakistan', 'as', 'ইসলামাবাদ', 'Islamabad', 33.6844, 73.0479, 300, 'm', '0814 Independence Day'),
  Country('PH', 'ফিলিপাইন', 'Philippines', 'as', 'ম্যানিলা', 'Manila', 14.6, 120.98, 480, 'nc', '0612 Independence Day'),
  Country('QA', 'কাতার', 'Qatar', 'as', 'দোহা', 'Doha', 25.2854, 51.531, 180, 'm', '1218 National Day'),
  Country('SA', 'সৌদি আরব', 'Saudi Arabia', 'as', 'রিয়াদ', 'Riyadh', 24.7136, 46.6753, 180, 'm', '0923 National Day'),
  Country('SG', 'সিঙ্গাপুর', 'Singapore', 'as', 'সিঙ্গাপুর', 'Singapore', 1.3521, 103.8198, 480, 'nmc', '0809 National Day'),
  Country('KR', 'দক্ষিণ কোরিয়া', 'South Korea', 'as', 'সিউল', 'Seoul', 37.5665, 126.978, 540, 'nc', '0815 Liberation Day'),
  Country('LK', 'শ্রীলঙ্কা', 'Sri Lanka', 'as', 'কলম্বো', 'Colombo', 6.9271, 79.8612, 330, 'nmc', '0204 Independence Day'),
  Country('SY', 'সিরিয়া', 'Syria', 'as', 'দামেস্ক', 'Damascus', 33.51, 36.28, 180, 'nmc', '0417 Evacuation Day'),
  Country('TJ', 'তাজিকিস্তান', 'Tajikistan', 'as', 'দুশানবে', 'Dushanbe', 38.56, 68.77, 300, 'nm', '0909 Independence Day'),
  Country('TH', 'থাইল্যান্ড', 'Thailand', 'as', 'ব্যাংকক', 'Bangkok', 13.7563, 100.5018, 420, 'n', '1205 National Day'),
  Country('TL', 'পূর্ব তিমুর', 'Timor-Leste', 'as', 'দিলি', 'Dili', -8.56, 125.57, 540, 'nc', '1128 Independence Day'),
  Country('TR', 'তুরস্ক', 'Türkiye', 'as', 'আঙ্কারা', 'Ankara', 39.93, 32.86, 180, 'nm', '1029 Republic Day'),
  Country('TM', 'তুর্কমেনিস্তান', 'Turkmenistan', 'as', 'আশখাবাদ', 'Ashgabat', 37.96, 58.33, 300, 'nm', '0927 Independence Day'),
  Country('AE', 'সংযুক্ত আরব আমিরাত', 'United Arab Emirates', 'as', 'আবুধাবি', 'Abu Dhabi', 24.4539, 54.3773, 240, 'nm', '1202 National Day'),
  Country('UZ', 'উজবেকিস্তান', 'Uzbekistan', 'as', 'তাসখন্দ', 'Tashkent', 41.3, 69.24, 300, 'nm', '0901 Independence Day'),
  Country('VN', 'ভিয়েতনাম', 'Vietnam', 'as', 'হ্যানয়', 'Hanoi', 21.03, 105.85, 420, 'n', '0902 National Day'),
  Country('YE', 'ইয়েমেন', 'Yemen', 'as', 'সানা', 'Sanaa', 15.37, 44.19, 180, 'nm', '0522 Unity Day'),
  Country('CY', 'সাইপ্রাস', 'Cyprus', 'eu', 'নিকোসিয়া', 'Nicosia', 35.19, 33.38, 120, 'nc', '1001 Independence Day'),
  Country('AL', 'আলবেনিয়া', 'Albania', 'eu', 'তিরানা', 'Tirana', 41.33, 19.82, 60, 'nmc', '1128 Independence Day'),
  Country('AD', 'অ্যান্ডোরা', 'Andorra', 'eu', 'আন্দোরা লা ভেলিয়া', 'Andorra la Vella', 42.51, 1.52, 60, 'nc', '0908 National Day'),
  Country('AT', 'অস্ট্রিয়া', 'Austria', 'eu', 'ভিয়েনা', 'Vienna', 48.21, 16.37, 60, 'nc', '1026 National Day'),
  Country('BY', 'বেলারুশ', 'Belarus', 'eu', 'মিনস্ক', 'Minsk', 53.9, 27.56, 180, 'noc', '0703 Independence Day'),
  Country('BE', 'বেলজিয়াম', 'Belgium', 'eu', 'ব্রাসেলস', 'Brussels', 50.85, 4.35, 60, 'nc', '0721 National Day'),
  Country('BA', 'বসনিয়া ও হার্জেগোভিনা', 'Bosnia and Herzegovina', 'eu', 'সারায়েভো', 'Sarajevo', 43.86, 18.41, 60, 'nmc', '0301 Independence Day'),
  Country('BG', 'বুলগেরিয়া', 'Bulgaria', 'eu', 'সোফিয়া', 'Sofia', 42.7, 23.32, 120, 'nc', '0303 Liberation Day'),
  Country('HR', 'ক্রোয়েশিয়া', 'Croatia', 'eu', 'জাগরেব', 'Zagreb', 45.81, 15.98, 60, 'nc', '0530 Statehood Day'),
  Country('CZ', 'চেক প্রজাতন্ত্র', 'Czechia', 'eu', 'প্রাগ', 'Prague', 50.08, 14.44, 60, 'nc', '1028 Independence Day'),
  Country('DK', 'ডেনমার্ক', 'Denmark', 'eu', 'কোপেনহেগেন', 'Copenhagen', 55.68, 12.57, 60, 'nc', '0605 Constitution Day'),
  Country('EE', 'এস্তোনিয়া', 'Estonia', 'eu', 'তালিন', 'Tallinn', 59.44, 24.75, 120, 'nc', '0224 Independence Day'),
  Country('FI', 'ফিনল্যান্ড', 'Finland', 'eu', 'হেলসিঙ্কি', 'Helsinki', 60.17, 24.94, 120, 'nc', '1206 Independence Day'),
  Country('FR', 'ফ্রান্স', 'France', 'eu', 'প্যারিস', 'Paris', 48.8566, 2.3522, 60, 'nc', '0714 Bastille Day'),
  Country('DE', 'জার্মানি', 'Germany', 'eu', 'বার্লিন', 'Berlin', 52.52, 13.405, 60, 'nc', '1003 German Unity Day'),
  Country('GR', 'গ্রিস', 'Greece', 'eu', 'এথেন্স', 'Athens', 37.9838, 23.7275, 120, 'nc', '0325 Independence Day'),
  Country('HU', 'হাঙ্গেরি', 'Hungary', 'eu', 'বুদাপেস্ট', 'Budapest', 47.5, 19.04, 60, 'nc', '0820 State Foundation Day'),
  Country('IS', 'আইসল্যান্ড', 'Iceland', 'eu', 'রেইকিয়াভিক', 'Reykjavik', 64.15, -21.94, 0, 'nc', '0617 National Day'),
  Country('IE', 'আয়ারল্যান্ড', 'Ireland', 'eu', 'ডাবলিন', 'Dublin', 53.35, -6.26, 0, 'nc', '0317 St Patrick\'s Day'),
  Country('IT', 'ইতালি', 'Italy', 'eu', 'রোম', 'Rome', 41.9028, 12.4964, 60, 'nc', '0602 Republic Day'),
  Country('LV', 'লাটভিয়া', 'Latvia', 'eu', 'রিগা', 'Riga', 56.95, 24.11, 120, 'nc', '1118 Independence Day'),
  Country('LI', 'লিশটেনস্টাইন', 'Liechtenstein', 'eu', 'ফাডুৎস', 'Vaduz', 47.14, 9.52, 60, 'nc', '0815 National Day'),
  Country('LT', 'লিথুয়ানিয়া', 'Lithuania', 'eu', 'ভিলনিয়ুস', 'Vilnius', 54.69, 25.28, 120, 'nc', '0216 Independence Day'),
  Country('LU', 'লুক্সেমবার্গ', 'Luxembourg', 'eu', 'লুক্সেমবার্গ', 'Luxembourg', 49.61, 6.13, 60, 'nc', '0623 National Day'),
  Country('MT', 'মাল্টা', 'Malta', 'eu', 'ভাল্লেত্তা', 'Valletta', 35.9, 14.51, 60, 'nc', '0921 Independence Day'),
  Country('MD', 'মলদোভা', 'Moldova', 'eu', 'কিশিনাউ', 'Chișinău', 47.01, 28.86, 120, 'noc', '0827 Independence Day'),
  Country('MC', 'মোনাকো', 'Monaco', 'eu', 'মোনাকো', 'Monaco', 43.74, 7.42, 60, 'nc', '1119 National Day'),
  Country('ME', 'মন্টিনিগ্রো', 'Montenegro', 'eu', 'পডগোরিৎসা', 'Podgorica', 42.44, 19.26, 60, 'no', '0713 Statehood Day'),
  Country('NL', 'নেদারল্যান্ডস', 'Netherlands', 'eu', 'আমস্টারডাম', 'Amsterdam', 52.3676, 4.9041, 60, 'nc', '0427 King\'s Day'),
  Country('MK', 'উত্তর মেসিডোনিয়া', 'North Macedonia', 'eu', 'স্কোপিয়ে', 'Skopje', 42.0, 21.43, 60, 'nom', '0908 Independence Day'),
  Country('NO', 'নরওয়ে', 'Norway', 'eu', 'অসলো', 'Oslo', 59.91, 10.75, 60, 'nc', '0517 Constitution Day'),
  Country('PL', 'পোল্যান্ড', 'Poland', 'eu', 'ওয়ারশ', 'Warsaw', 52.23, 21.01, 60, 'nc', '0503 Constitution Day;1111 Independence Day'),
  Country('PT', 'পর্তুগাল', 'Portugal', 'eu', 'লিসবন', 'Lisbon', 38.7223, -9.1393, 0, 'nc', '0610 Portugal Day'),
  Country('RO', 'রোমানিয়া', 'Romania', 'eu', 'বুখারেস্ট', 'Bucharest', 44.43, 26.1, 120, 'nc', '1201 National Day'),
  Country('RU', 'রাশিয়া', 'Russia', 'eu', 'মস্কো', 'Moscow', 55.7558, 37.6173, 180, 'no', '0612 Russia Day'),
  Country('SM', 'সান মারিনো', 'San Marino', 'eu', 'সান মারিনো', 'San Marino', 43.94, 12.45, 60, 'nc', '0903 Foundation Day'),
  Country('RS', 'সার্বিয়া', 'Serbia', 'eu', 'বেলগ্রেড', 'Belgrade', 44.79, 20.45, 60, 'no', '0215 Statehood Day'),
  Country('SK', 'স্লোভাকিয়া', 'Slovakia', 'eu', 'ব্রাতিস্লাভা', 'Bratislava', 48.15, 17.11, 60, 'nc', '0901 Constitution Day'),
  Country('SI', 'স্লোভেনিয়া', 'Slovenia', 'eu', 'লিউব্লিয়ানা', 'Ljubljana', 46.06, 14.51, 60, 'nc', '0625 Statehood Day'),
  Country('ES', 'স্পেন', 'Spain', 'eu', 'মাদ্রিদ', 'Madrid', 40.4168, -3.7038, 60, 'nc', '1012 National Day'),
  Country('SE', 'সুইডেন', 'Sweden', 'eu', 'স্টকহোম', 'Stockholm', 59.3293, 18.0686, 60, 'nc', '0606 National Day'),
  Country('CH', 'সুইজারল্যান্ড', 'Switzerland', 'eu', 'বার্ন', 'Bern', 46.95, 7.45, 60, 'nc', '0801 National Day'),
  Country('UA', 'ইউক্রেন', 'Ukraine', 'eu', 'কিয়েভ', 'Kyiv', 50.45, 30.52, 120, 'nc', '0824 Independence Day'),
  Country('GB', 'যুক্তরাজ্য', 'United Kingdom', 'eu', 'লন্ডন', 'London', 51.5074, -0.1278, 0, 'nc', ''),
  Country('DZ', 'আলজেরিয়া', 'Algeria', 'af', 'আলজিয়ার্স', 'Algiers', 36.75, 3.06, 60, 'nm', '0705 Independence Day;1101 Revolution Day'),
  Country('AO', 'অ্যাঙ্গোলা', 'Angola', 'af', 'লুয়ান্ডা', 'Luanda', -8.84, 13.23, 60, 'nc', '1111 Independence Day'),
  Country('BJ', 'বেনিন', 'Benin', 'af', 'পোর্তো-নোভো', 'Porto-Novo', 6.5, 2.6, 60, 'nmc', '0801 Independence Day'),
  Country('BW', 'বতসোয়ানা', 'Botswana', 'af', 'গ্যাবোরোনি', 'Gaborone', -24.65, 25.91, 120, 'nc', '0930 Botswana Day'),
  Country('BF', 'বুরকিনা ফাসো', 'Burkina Faso', 'af', 'ওয়াগাডুগু', 'Ouagadougou', 12.37, -1.52, 0, 'nmc', '0805 Independence Day'),
  Country('BI', 'বুরুন্ডি', 'Burundi', 'af', 'গিতেগা', 'Gitega', -3.43, 29.93, 120, 'nmc', '0701 Independence Day'),
  Country('CV', 'কেপ ভার্দ', 'Cabo Verde', 'af', 'প্রাইয়া', 'Praia', 14.93, -23.51, -60, 'nc', '0705 Independence Day'),
  Country('CM', 'ক্যামেরুন', 'Cameroon', 'af', 'ইয়াউন্ডে', 'Yaoundé', 3.85, 11.5, 60, 'nmc', '0520 National Day'),
  Country('CF', 'মধ্য আফ্রিকান প্রজাতন্ত্র', 'Central African Republic', 'af', 'বাঙ্গুই', 'Bangui', 4.39, 18.56, 60, 'nc', '0813 Independence Day'),
  Country('TD', 'চাদ', 'Chad', 'af', 'এনজামেনা', 'N\'Djamena', 12.13, 15.06, 60, 'nmc', '0811 Independence Day'),
  Country('KM', 'কোমোরোস', 'Comoros', 'af', 'মোরোনি', 'Moroni', -11.7, 43.26, 180, 'nm', '0706 Independence Day'),
  Country('CG', 'কঙ্গো প্রজাতন্ত্র', 'Congo', 'af', 'ব্রাজাভিল', 'Brazzaville', -4.26, 15.24, 60, 'nc', '0815 Independence Day'),
  Country('CD', 'কঙ্গো গণতান্ত্রিক প্রজাতন্ত্র', 'DR Congo', 'af', 'কিনশাসা', 'Kinshasa', -4.44, 15.27, 60, 'nc', '0630 Independence Day'),
  Country('CI', 'আইভরি কোস্ট', 'Côte d\'Ivoire', 'af', 'ইয়ামুসুক্রো', 'Yamoussoukro', 6.83, -5.29, 0, 'nmc', '0807 Independence Day'),
  Country('DJ', 'জিবুতি', 'Djibouti', 'af', 'জিবুতি', 'Djibouti', 11.59, 43.15, 180, 'nm', '0627 Independence Day'),
  Country('EG', 'মিশর', 'Egypt', 'af', 'কায়রো', 'Cairo', 30.0444, 31.2357, 120, 'nmo', '0723 Revolution Day'),
  Country('GQ', 'নিরক্ষীয় গিনি', 'Equatorial Guinea', 'af', 'মালাবো', 'Malabo', 3.75, 8.78, 60, 'nc', '1012 Independence Day'),
  Country('ER', 'ইরিত্রিয়া', 'Eritrea', 'af', 'আসমারা', 'Asmara', 15.32, 38.93, 180, 'nom', '0524 Independence Day'),
  Country('SZ', 'এসওয়াতিনি', 'Eswatini', 'af', 'এমবাবানে', 'Mbabane', -26.31, 31.14, 120, 'nc', '0906 Independence Day'),
  Country('ET', 'ইথিওপিয়া', 'Ethiopia', 'af', 'আদ্দিস আবাবা', 'Addis Ababa', 9.03, 38.74, 180, 'om', '0528 Derg Downfall Day;0911 Ethiopian New Year'),
  Country('GA', 'গ্যাবন', 'Gabon', 'af', 'লিব্রেভিল', 'Libreville', 0.42, 9.47, 60, 'nmc', '0817 Independence Day'),
  Country('GM', 'গাম্বিয়া', 'Gambia', 'af', 'বানজুল', 'Banjul', 13.45, -16.58, 0, 'nmc', '0218 Independence Day'),
  Country('GH', 'ঘানা', 'Ghana', 'af', 'আক্রা', 'Accra', 5.6, -0.19, 0, 'nmc', '0306 Independence Day'),
  Country('GN', 'গিনি', 'Guinea', 'af', 'কোনাক্রি', 'Conakry', 9.64, -13.58, 0, 'nmc', '1002 Independence Day'),
  Country('GW', 'গিনি-বিসাউ', 'Guinea-Bissau', 'af', 'বিসাউ', 'Bissau', 11.86, -15.6, 0, 'nmc', '0924 Independence Day'),
  Country('KE', 'কেনিয়া', 'Kenya', 'af', 'নাইরোবি', 'Nairobi', -1.2921, 36.8219, 180, 'nmc', '1212 Jamhuri Day'),
  Country('LS', 'লেসোথো', 'Lesotho', 'af', 'মাসেরু', 'Maseru', -29.31, 27.48, 120, 'nc', '1004 Independence Day'),
  Country('LR', 'লাইবেরিয়া', 'Liberia', 'af', 'মনরোভিয়া', 'Monrovia', 6.3, -10.8, 0, 'nc', '0726 Independence Day'),
  Country('LY', 'লিবিয়া', 'Libya', 'af', 'ত্রিপোলি', 'Tripoli', 32.8872, 13.1913, 120, 'm', '1224 Independence Day'),
  Country('MG', 'মাদাগাস্কার', 'Madagascar', 'af', 'আন্তানানারিভো', 'Antananarivo', -18.88, 47.51, 180, 'nc', '0626 Independence Day'),
  Country('MW', 'মালাউই', 'Malawi', 'af', 'লিলংওয়ে', 'Lilongwe', -13.96, 33.79, 120, 'nc', '0706 Independence Day'),
  Country('ML', 'মালি', 'Mali', 'af', 'বামাকো', 'Bamako', 12.64, -8.0, 0, 'nmc', '0922 Independence Day'),
  Country('MR', 'মৌরিতানিয়া', 'Mauritania', 'af', 'নুয়াকশট', 'Nouakchott', 18.07, -15.96, 0, 'nm', '1128 Independence Day'),
  Country('MU', 'মরিশাস', 'Mauritius', 'af', 'পোর্ট লুই', 'Port Louis', -20.1609, 57.5012, 240, 'nmc', '0312 National Day'),
  Country('MA', 'মরক্কো', 'Morocco', 'af', 'রাবাত', 'Rabat', 34.02, -6.84, 60, 'nm', '0730 Throne Day'),
  Country('MZ', 'মোজাম্বিক', 'Mozambique', 'af', 'মাপুতো', 'Maputo', -25.97, 32.57, 120, 'nc', '0625 Independence Day'),
  Country('NA', 'নামিবিয়া', 'Namibia', 'af', 'উইন্ডহোক', 'Windhoek', -22.56, 17.08, 120, 'nc', '0321 Independence Day'),
  Country('NE', 'নাইজার', 'Niger', 'af', 'নিয়ামে', 'Niamey', 13.51, 2.11, 60, 'nmc', '1218 Republic Day'),
  Country('NG', 'নাইজেরিয়া', 'Nigeria', 'af', 'আবুজা', 'Abuja', 9.08, 7.4, 60, 'nmc', '1001 Independence Day'),
  Country('RW', 'রুয়ান্ডা', 'Rwanda', 'af', 'কিগালি', 'Kigali', -1.94, 30.06, 120, 'nmc', '0701 Independence Day'),
  Country('ST', 'সাঁউ তুমি ও প্রিন্সিপি', 'São Tomé and Príncipe', 'af', 'সাঁউ তুমি', 'São Tomé', 0.34, 6.73, 0, 'nc', '0712 Independence Day'),
  Country('SN', 'সেনেগাল', 'Senegal', 'af', 'ডাকার', 'Dakar', 14.72, -17.47, 0, 'nmc', '0404 Independence Day'),
  Country('SC', 'সেশেলস', 'Seychelles', 'af', 'ভিক্টোরিয়া', 'Victoria', -4.62, 55.45, 240, 'nc', '0629 Independence Day'),
  Country('SL', 'সিয়েরা লিওন', 'Sierra Leone', 'af', 'ফ্রিটাউন', 'Freetown', 8.47, -13.23, 0, 'nmc', '0427 Independence Day'),
  Country('SO', 'সোমালিয়া', 'Somalia', 'af', 'মোগাদিশু', 'Mogadishu', 2.05, 45.32, 180, 'm', '0701 Independence Day'),
  Country('ZA', 'দক্ষিণ আফ্রিকা', 'South Africa', 'af', 'প্রিটোরিয়া', 'Pretoria', -25.75, 28.19, 120, 'nc', '0427 Freedom Day'),
  Country('SS', 'দক্ষিণ সুদান', 'South Sudan', 'af', 'জুবা', 'Juba', 4.86, 31.57, 120, 'nc', '0709 Independence Day'),
  Country('SD', 'সুদান', 'Sudan', 'af', 'খার্তুম', 'Khartoum', 15.5, 32.56, 120, 'nmc', '0101 Independence Day'),
  Country('TZ', 'তানজানিয়া', 'Tanzania', 'af', 'ডোডোমা', 'Dodoma', -6.16, 35.75, 180, 'nmc', '1209 Independence Day'),
  Country('TG', 'টোগো', 'Togo', 'af', 'লোমে', 'Lomé', 6.13, 1.22, 0, 'nmc', '0427 Independence Day'),
  Country('TN', 'তিউনিসিয়া', 'Tunisia', 'af', 'তিউনিস', 'Tunis', 36.81, 10.18, 60, 'nm', '0320 Independence Day'),
  Country('UG', 'উগান্ডা', 'Uganda', 'af', 'কাম্পালা', 'Kampala', 0.35, 32.58, 180, 'nmc', '1009 Independence Day'),
  Country('ZM', 'জাম্বিয়া', 'Zambia', 'af', 'লুসাকা', 'Lusaka', -15.39, 28.32, 120, 'nc', '1024 Independence Day'),
  Country('ZW', 'জিম্বাবুয়ে', 'Zimbabwe', 'af', 'হারারে', 'Harare', -17.83, 31.05, 120, 'nc', '0418 Independence Day'),
  Country('AG', 'অ্যান্টিগুয়া ও বার্বুডা', 'Antigua and Barbuda', 'na', 'সেন্ট জনস', 'St. John\'s', 17.12, -61.85, -240, 'nc', '1101 Independence Day'),
  Country('BS', 'বাহামা', 'Bahamas', 'na', 'নাসাউ', 'Nassau', 25.05, -77.36, -300, 'nc', '0710 Independence Day'),
  Country('BB', 'বার্বাডোস', 'Barbados', 'na', 'ব্রিজটাউন', 'Bridgetown', 13.1, -59.62, -240, 'nc', '1130 Independence Day'),
  Country('BZ', 'বেলিজ', 'Belize', 'na', 'বেলমোপান', 'Belmopan', 17.25, -88.77, -360, 'nc', '0921 Independence Day'),
  Country('CA', 'কানাডা', 'Canada', 'na', 'অটোয়া', 'Ottawa', 45.42, -75.7, -300, 'nc', '0701 Canada Day'),
  Country('CR', 'কোস্টা রিকা', 'Costa Rica', 'na', 'সান হোসে', 'San José', 9.93, -84.08, -360, 'nc', '0915 Independence Day'),
  Country('CU', 'কিউবা', 'Cuba', 'na', 'হাভানা', 'Havana', 23.11, -82.37, -300, 'nc', '0726 National Rebellion Day'),
  Country('DM', 'ডোমিনিকা', 'Dominica', 'na', 'রোসো', 'Roseau', 15.3, -61.39, -240, 'nc', '1103 Independence Day'),
  Country('DO', 'ডোমিনিকান প্রজাতন্ত্র', 'Dominican Republic', 'na', 'সান্তো দোমিঙ্গো', 'Santo Domingo', 18.49, -69.93, -240, 'nc', '0227 Independence Day'),
  Country('SV', 'এল সালভাদর', 'El Salvador', 'na', 'সান সালভাদর', 'San Salvador', 13.69, -89.22, -360, 'nc', '0915 Independence Day'),
  Country('GD', 'গ্রেনাডা', 'Grenada', 'na', 'সেন্ট জর্জেস', 'St. George\'s', 12.06, -61.75, -240, 'nc', '0207 Independence Day'),
  Country('GT', 'গুয়াতেমালা', 'Guatemala', 'na', 'গুয়াতেমালা সিটি', 'Guatemala City', 14.63, -90.51, -360, 'nc', '0915 Independence Day'),
  Country('HT', 'হাইতি', 'Haiti', 'na', 'পোর্ত-অ-প্রিন্স', 'Port-au-Prince', 18.59, -72.31, -300, 'nc', '0101 Independence Day'),
  Country('HN', 'হন্ডুরাস', 'Honduras', 'na', 'তেগুসিগালপা', 'Tegucigalpa', 14.07, -87.19, -360, 'nc', '0915 Independence Day'),
  Country('JM', 'জ্যামাইকা', 'Jamaica', 'na', 'কিংস্টন', 'Kingston', 18.02, -76.8, -300, 'nc', '0806 Independence Day'),
  Country('MX', 'মেক্সিকো', 'Mexico', 'na', 'মেক্সিকো সিটি', 'Mexico City', 19.43, -99.13, -360, 'nc', '0916 Independence Day'),
  Country('NI', 'নিকারাগুয়া', 'Nicaragua', 'na', 'মানাগুয়া', 'Managua', 12.11, -86.24, -360, 'nc', '0915 Independence Day'),
  Country('PA', 'পানামা', 'Panama', 'na', 'পানামা সিটি', 'Panama City', 8.98, -79.52, -300, 'nc', '1103 Independence Day'),
  Country('KN', 'সেন্ট কিটস ও নেভিস', 'Saint Kitts and Nevis', 'na', 'বাসেতেরে', 'Basseterre', 17.3, -62.72, -240, 'nc', '0919 Independence Day'),
  Country('LC', 'সেন্ট লুসিয়া', 'Saint Lucia', 'na', 'ক্যাস্ট্রিজ', 'Castries', 14.01, -60.99, -240, 'nc', '0222 Independence Day'),
  Country('VC', 'সেন্ট ভিনসেন্ট ও গ্রেনাডাইনস', 'Saint Vincent and the Grenadines', 'na', 'কিংসটাউন', 'Kingstown', 13.16, -61.22, -240, 'nc', '1027 Independence Day'),
  Country('TT', 'ত্রিনিদাদ ও টোবাগো', 'Trinidad and Tobago', 'na', 'পোর্ট অব স্পেন', 'Port of Spain', 10.65, -61.52, -240, 'nmc', '0831 Independence Day'),
  Country('US', 'যুক্তরাষ্ট্র', 'United States', 'na', 'ওয়াশিংটন', 'Washington, D.C.', 38.9072, -77.0369, -300, 'nc', '0704 Independence Day'),
  Country('AR', 'আর্জেন্টিনা', 'Argentina', 'sa', 'বুয়েনোস আইরেস', 'Buenos Aires', -34.6, -58.38, -180, 'nc', '0525 May Revolution;0709 Independence Day'),
  Country('BO', 'বলিভিয়া', 'Bolivia', 'sa', 'লা পাজ', 'La Paz', -16.49, -68.12, -240, 'nc', '0806 Independence Day'),
  Country('BR', 'ব্রাজিল', 'Brazil', 'sa', 'ব্রাসিলিয়া', 'Brasília', -15.79, -47.88, -180, 'nc', '0907 Independence Day'),
  Country('CL', 'চিলি', 'Chile', 'sa', 'সান্তিয়াগো', 'Santiago', -33.45, -70.67, -240, 'nc', '0918 Independence Day'),
  Country('CO', 'কলম্বিয়া', 'Colombia', 'sa', 'বোগোতা', 'Bogotá', 4.71, -74.07, -300, 'nc', '0720 Independence Day'),
  Country('EC', 'ইকুয়েডর', 'Ecuador', 'sa', 'কিতো', 'Quito', -0.18, -78.47, -300, 'nc', '0810 Independence Day'),
  Country('GY', 'গায়ানা', 'Guyana', 'sa', 'জর্জটাউন', 'Georgetown', 6.8, -58.16, -240, 'nmc', '0223 Republic Day'),
  Country('PY', 'প্যারাগুয়ে', 'Paraguay', 'sa', 'আসুনসিওন', 'Asunción', -25.26, -57.58, -180, 'nc', '0514 Independence Day'),
  Country('PE', 'পেরু', 'Peru', 'sa', 'লিমা', 'Lima', -12.05, -77.04, -300, 'nc', '0728 Independence Day'),
  Country('SR', 'সুরিনাম', 'Suriname', 'sa', 'পারামারিবো', 'Paramaribo', 5.85, -55.2, -180, 'nmc', '1125 Independence Day'),
  Country('UY', 'উরুগুয়ে', 'Uruguay', 'sa', 'মন্টেভিডিও', 'Montevideo', -34.9, -56.16, -180, 'nc', '0825 Independence Day'),
  Country('VE', 'ভেনেজুয়েলা', 'Venezuela', 'sa', 'কারাকাস', 'Caracas', 10.48, -66.9, -240, 'nc', '0705 Independence Day'),
  Country('AU', 'অস্ট্রেলিয়া', 'Australia', 'oc', 'ক্যানবেরা', 'Canberra', -35.28, 149.13, 600, 'nc', '0126 Australia Day'),
  Country('FJ', 'ফিজি', 'Fiji', 'oc', 'সুভা', 'Suva', -18.14, 178.44, 720, 'nmc', '1010 Fiji Day'),
  Country('KI', 'কিরিবাতি', 'Kiribati', 'oc', 'তারাওয়া', 'Tarawa', 1.33, 172.98, 720, 'nc', '0712 Independence Day'),
  Country('MH', 'মার্শাল দ্বীপপুঞ্জ', 'Marshall Islands', 'oc', 'মাজুরো', 'Majuro', 7.09, 171.38, 720, 'nc', '0501 Constitution Day'),
  Country('FM', 'মাইক্রোনেশিয়া', 'Micronesia', 'oc', 'পালিকির', 'Palikir', 6.92, 158.16, 660, 'nc', '1103 Independence Day'),
  Country('NR', 'নাউরু', 'Nauru', 'oc', 'ইয়ারেন', 'Yaren', -0.55, 166.92, 720, 'nc', '0131 Independence Day'),
  Country('NZ', 'নিউজিল্যান্ড', 'New Zealand', 'oc', 'ওয়েলিংটন', 'Wellington', -41.29, 174.78, 720, 'nc', '0206 Waitangi Day'),
  Country('PW', 'পালাউ', 'Palau', 'oc', 'এনগেরুলমুদ', 'Ngerulmud', 7.5, 134.62, 540, 'nc', '1001 Independence Day'),
  Country('PG', 'পাপুয়া নিউ গিনি', 'Papua New Guinea', 'oc', 'পোর্ট মোরেসবি', 'Port Moresby', -9.44, 147.18, 600, 'nc', '0916 Independence Day'),
  Country('WS', 'সামোয়া', 'Samoa', 'oc', 'আপিয়া', 'Apia', -13.83, -171.76, 780, 'nc', '0601 Independence Day'),
  Country('SB', 'সলোমন দ্বীপপুঞ্জ', 'Solomon Islands', 'oc', 'হোনিয়ারা', 'Honiara', -9.43, 159.95, 660, 'nc', '0707 Independence Day'),
  Country('TO', 'টোঙ্গা', 'Tonga', 'oc', 'নুকুয়ালোফা', 'Nuku\'alofa', -21.14, -175.2, 780, 'nc', '1104 Constitution Day'),
  Country('TV', 'টুভালু', 'Tuvalu', 'oc', 'ফুনাফুতি', 'Funafuti', -8.52, 179.2, 720, 'nc', '1001 Independence Day'),
  Country('VU', 'ভানুয়াতু', 'Vanuatu', 'oc', 'পোর্ট ভিলা', 'Port Vila', -17.73, 168.32, 660, 'nc', '0730 Independence Day'),
  Country('PS', 'ফিলিস্তিন', 'Palestine', 'as', 'জেরুজালেম', 'Jerusalem', 31.78, 35.23, 120, 'nmc', '1115 Independence Day', observer: true),
  Country('VA', 'ভ্যাটিকান সিটি', 'Vatican City', 'eu', 'ভ্যাটিকান সিটি', 'Vatican City', 41.9, 12.45, 60, 'nc', '0629 Saints Peter and Paul', observer: true),
  Country('HK', 'হংকং', 'Hong Kong', 'as', 'হংকং', 'Hong Kong', 22.3193, 114.1694, 480, 'nc', '0701 HKSAR Establishment Day', un: false),
];

final Map<String, Country> _byCode = {for (final c in worldCountries) c.code: c};

/// The country with code [cc] (two letters), or null.
Country? countryOf(String cc) => _byCode[cc.toUpperCase()];

/// The countries in the UN's list: members and the observer states.
Iterable<Country> get unCountries => worldCountries.where((c) => c.un);

/// Bangla and English, lower case, no spaces: what is matched.
String _fold(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s\-.’\x27]+'), '');

/// Countries whose name (Bengali or English), code or capital matches [q];
/// a name that starts with it first.
List<Country> findCountries(String q) {
  final f = _fold(q);
  if (f.isEmpty) return [...worldCountries];
  final starts = <Country>[], inside = <Country>[];
  for (final c in worldCountries) {
    final names = [c.bn, c.en];
    if (names.any((n) => _fold(n).startsWith(f)) || c.code.toLowerCase() == f) {
      starts.add(c);
    } else if (names.any((n) => _fold(n).contains(f)) || _fold(c.capitalBn).startsWith(f) || _fold(c.capitalEn).startsWith(f)) {
      inside.add(c);
    }
  }
  return [...starts, ...inside];
}

/// The countries of a continent, by name in the app's language.
List<Country> countriesIn(String continent) {
  final l = worldCountries.where((c) => c.continent == continent).toList();
  if (isEn) {
    l.sort((a, b) => a.en.compareTo(b.en));
  } else {
    l.sort((a, b) => a.bn.compareTo(b.bn));
  }
  return l;
}

/// Easter Sunday of [year] (Gregorian; the Anonymous Gregorian algorithm).
DateTime easterSunday(int year) {
  final a = year % 19, b = year ~/ 100, c = year % 100, d = b ~/ 4, e = b % 4;
  final f = (b + 8) ~/ 25, g = (b - f + 1) ~/ 3, h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31, day = (h + l - 7 * m + 114) % 31 + 1;
  return DateTime(year, month, day);
}

/// The main days off of [cc] in [year], worked out on the phone for a
/// country with no full list: its national days and the great religious
/// days it keeps. Null when [cc] is not known. [adjust]: days the Hijri
/// date is moved for the moon there.
List<AbroadHoliday>? mainHolidays(String cc, int year, {int adjust = 1}) {
  final c = countryOf(cc);
  if (c == null) return null;
  final out = <AbroadHoliday>[];
  void add(DateTime d, String name) {
    if (!out.any((h) => h.date == d)) out.add(AbroadHoliday(d, name));
  }

  for (final part in c.days.split(';')) {
    if (part.length < 6) continue;
    add(DateTime(year, int.parse(part.substring(0, 2)), int.parse(part.substring(2, 4))), part.substring(5));
  }
  if (c.faith.contains('n')) add(DateTime(year, 1, 1), "New Year's Day");
  if (c.faith.contains('o')) add(DateTime(year, 1, 7), 'Orthodox Christmas');
  if (c.faith.contains('c')) {
    add(easterSunday(year).subtract(const Duration(days: 2)), 'Good Friday');
    add(DateTime(year, 12, 25), 'Christmas Day');
  }
  if (c.faith.contains('m')) {
    for (var d = DateTime(year, 1, 1); d.year == year; d = DateTime(d.year, d.month, d.day + 1)) {
      final h = hijriDate(d, adjust: adjust);
      if (h.month == 10 && h.day == 1) add(d, 'Eid al-Fitr');
      if (h.month == 12 && h.day == 10) add(d, 'Eid al-Adha');
    }
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}
