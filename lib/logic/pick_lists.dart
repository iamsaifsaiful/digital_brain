/// Ready lists to pick from (owner, 22 Nov): good daily habits, the family's
/// special days and the well-known days of the year.
library;

import '../models/models.dart';

/// A group of good daily habits: its name, an icon key and the habits.
typedef HabitGroup = ({String name, String icon, List<String> items});

const habitGroups = <HabitGroup>[
  (name: 'শরীর ভালো রাখা', icon: 'body', items: [
    'সকালে ৩০ মিনিট হাঁটা',
    '৮ গ্লাস পানি পান',
    '১৫ মিনিট ব্যায়াম',
    'রাত ১১টার আগে ঘুমানো',
    'ফল বা সবজি খাওয়া',
    'চিনি ও ভাজাপোড়া কম খাওয়া',
  ]),
  (name: 'মন ও শেখা', icon: 'mind', items: [
    '২০ মিনিট বই পড়া',
    'নতুন কিছু শেখা',
    'আজকের ৩টি ভালো কথা লেখা',
    'ঘুমের আগে ফোন দূরে রাখা',
    '৫ মিনিট চুপচাপ বসে শ্বাস নেওয়া',
  ]),
  (name: 'ইবাদত', icon: 'faith', items: [
    '৫ ওয়াক্ত নামাজ',
    'কুরআন তিলাওয়াত',
    'সকাল-সন্ধ্যার জিকির',
    'দান-সদকা',
  ]),
  (name: 'পরিবার ও ঘর', icon: 'home', items: [
    'আব্বা-আম্মার খোঁজ নেওয়া',
    'পরিবারের সাথে সময় কাটানো',
    'দিনের খরচ লিখে রাখা',
    'কিছু টাকা জমানো',
    '১০ মিনিট ঘর গোছানো',
  ]),
];

/// The faith group for a member who chose another religion in the profile.
const otherFaithHabits = ['প্রার্থনা', 'ধর্মগ্রন্থ পড়া', 'দান করা'];

/// A family day to pick: the kind, whose ('' = the user types the name) and
/// the line shown.
typedef SpecialIdea = ({SpecialKind kind, String person, String label});

const familyDayIdeas = <SpecialIdea>[
  (kind: SpecialKind.birthday, person: 'আম্মা', label: 'আম্মার জন্মদিন'),
  (kind: SpecialKind.birthday, person: 'আব্বা', label: 'আব্বার জন্মদিন'),
  (kind: SpecialKind.birthday, person: 'আমার', label: 'নিজের জন্মদিন'),
  (kind: SpecialKind.birthday, person: '', label: 'স্বামী/স্ত্রীর জন্মদিন'),
  (kind: SpecialKind.birthday, person: '', label: 'সন্তানের জন্মদিন'),
  (kind: SpecialKind.birthday, person: '', label: 'ভাই/বোনের জন্মদিন'),
  (kind: SpecialKind.birthday, person: '', label: 'বন্ধুর জন্মদিন'),
  (kind: SpecialKind.anniversary, person: 'আমাদের', label: 'আমাদের বিবাহবার্ষিকী'),
  (kind: SpecialKind.deathday, person: '', label: 'প্রিয়জনের মৃত্যুবার্ষিকী'),
];

/// Days of the year with a fixed date: one tap keeps them.
typedef YearDay = ({String name, int month, int day});

const yearDayIdeas = <YearDay>[
  (name: 'আন্তর্জাতিক মাতৃভাষা দিবস', month: 2, day: 21),
  (name: 'আন্তর্জাতিক নারী দিবস', month: 3, day: 8),
  (name: 'স্বাধীনতা দিবস', month: 3, day: 26),
  (name: 'পহেলা বৈশাখ', month: 4, day: 14),
  (name: 'বিশ্ব পরিবেশ দিবস', month: 6, day: 5),
  (name: 'বিশ্ব শিক্ষক দিবস', month: 10, day: 5),
  (name: 'বিজয় দিবস', month: 12, day: 16),
];
