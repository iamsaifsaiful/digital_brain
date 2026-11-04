/// The home picture (owner, 4 Nov): which painting, and what lives on it —
/// the six seasons by the Bangla calendar, a region the member picks, the
/// real moon, the weather, small movements and the national and Eid days.
/// Chosen in আরও › চেহারা ও ভাষা › হোমের ছবি; "অটো" by default.
library;

import 'dart:math' as math;

import 'calendar_bd.dart';

/// The paintings in assets/sky/ (each has _day and _night).
const seasonKeys = ['grishma', 'borsha', 'shorot', 'hemonto', 'sheet', 'boshonto'];
const regionKeys = ['sylhet', 'cox', 'sundarbans', 'chattogram', 'rajshahi', 'dhaka'];

/// The names as shown in the setting.
const sceneNames = {
  'auto': 'অটো — ঋতু অনুযায়ী',
  'river': 'নদীর পাড় (আগের ছবি)',
  'grishma': 'গ্রীষ্ম',
  'borsha': 'বর্ষা',
  'shorot': 'শরৎ',
  'hemonto': 'হেমন্ত',
  'sheet': 'শীত',
  'boshonto': 'বসন্ত',
  'sylhet': 'সিলেটের চা বাগান',
  'cox': 'কক্সবাজারের সমুদ্র',
  'sundarbans': 'সুন্দরবন',
  'chattogram': 'চট্টগ্রামের পাহাড়',
  'rajshahi': 'রাজশাহীর পদ্মা',
  'dhaka': 'ঢাকার আকাশরেখা',
};

/// বৈশাখ–জ্যৈষ্ঠ গ্রীষ্ম, আষাঢ়–শ্রাবণ বর্ষা, ভাদ্র–আশ্বিন শরৎ, কার্তিক–অগ্রহায়ণ
/// হেমন্ত, পৌষ–মাঘ শীত, ফাল্গুন–চৈত্র বসন্ত.
String seasonOf(DateTime now) => seasonKeys[banglaDate(now).month ~/ 2];

/// The painting to show: the member's choice, or the season ("auto" and anything unknown).
String sceneFor(String choice, DateTime now) {
  if (choice == 'river' || seasonKeys.contains(choice) || regionKeys.contains(choice)) return choice;
  return seasonOf(now);
}

String sceneAsset(String scene, {required bool night}) => 'assets/sky/${scene}_${night ? 'night' : 'day'}.webp';

/// A day the picture marks: 'boishakh' (১ বৈশাখ), 'ekushey' (21 Feb),
/// 'independence' (26 Mar), 'victory' (16 Dec), 'eid' (the three days of
/// each Eid by the Hijri date), or null.
String? specialDayOf(DateTime now, HijriDate hj) {
  final bd = banglaDate(now);
  if (bd.month == 0 && bd.day == 1) return 'boishakh';
  if (now.month == 2 && now.day == 21) return 'ekushey';
  if (now.month == 3 && now.day == 26) return 'independence';
  if (now.month == 12 && now.day == 16) return 'victory';
  if ((hj.month == 10 && hj.day <= 3) || (hj.month == 12 && hj.day >= 10 && hj.day <= 12)) return 'eid';
  return null;
}

/// The moon by the Hijri day: how much is lit (0 new … 1 full) and whether
/// it is growing. The Hijri month starts at the new crescent, so day 15 is
/// about full.
({double lit, bool waxing}) moonOf(HijriDate hj) {
  final age = (hj.day - 1 + 0.5).clamp(0.0, 29.5);
  final lit = (1 - math.cos(2 * math.pi * age / 29.53)) / 2;
  return (lit: lit, waxing: age < 14.77);
}

/// What the sky is doing, from the WMO weather code: 'storm', 'rain', 'fog', 'cloud' or ''.
String weatherKind(int? code) {
  if (code == null) return '';
  if (code >= 95) return 'storm';
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return 'rain';
  if (code == 45 || code == 48) return 'fog';
  if (code == 3) return 'cloud';
  return '';
}
