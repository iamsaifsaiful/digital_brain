/// Replies to conversation, in the way people in Bangladesh talk.
library;

import 'dart:math';

import 'bn.dart';
import 'parser.dart' show Talk;

final _rnd = Random();

String _pick(List<String> options) => options[_rnd.nextInt(options.length)];

String talkReply(Talk kind, DateTime now) => switch (kind) {
      Talk.howAreYou => _pick([
          'ভালো আছি, জিজ্ঞেস করার জন্য ধন্যবাদ! আপনি কেমন আছেন? কোনো কাজ থাকলে বলেন।',
          'আলহামদুলিল্লাহ, ভালো আছি! আপনার দিন কেমন যাচ্ছে? কী করে দিতে পারি বলেন।',
        ]),
      Talk.imFine => _pick(['শুনে ভালো লাগল! কিছু লাগলে বলবেন।', 'বাহ, ভালো তো! বলেন, কী করে দিতে পারি?']),
      Talk.greeting => _pick(['জি, বলেন! কী করে দিতে পারি?', 'হ্যালো! বলেন, কী করতে পারি?']),
      Talk.salam => 'ওয়ালাইকুম আসসালাম! বলেন, কী করতে পারি?',
      Talk.whoAreYou =>
        'আমি My Assistant, আপনার ব্যক্তিগত সহকারী। কাজের তালিকা, সময়মতো মনে করানো, ফোন-মেসেজ, বাকি ও লেনদেনের হিসাব, নোট আর পাসওয়ার্ড — আপনি বলবেন, আমি সামলাব।',
      Talk.whatCanYouDo =>
        'অনেক কিছুই পারি! যেমন বলুন — “কাল সকাল ১০টায় মিটিংয়ের কথা মনে করিয়ে দিও”, “কাল ব্যাংকে যেতে হবে”, “রহিমকে ফোন দাও”, “করিম ৫০০ টাকার মাল বাকিতে নিল”, অথবা “আজ আমার কী কী আছে?”।',
      Talk.thanks => _pick(['আপনাকেও ধন্যবাদ! আর কিছু লাগলে বলবেন।', 'কোনো ব্যাপার না! আর কিছু?']),
      Talk.bye => 'ঠিক আছে, ভালো থাকবেন! দরকার হলে আবার ডাকবেন।',
      Talk.time => 'এখন ${bnTime(now.hour, now.minute)}।',
      Talk.date => 'আজ ${weekdayName(now)}, ${bnDigits(now.day)} ${bnMonths[now.month - 1]}।',
    };

/// Phone numbers are read digit by digit ("০ ১ ৭ …"), not as one big number.
String speakableNumbers(String text) => text.replaceAllMapped(RegExp(r'[০-৯0-9][০-৯0-9\- ]{6,}[০-৯0-9]'), (m) {
      final digits = m[0]!.replaceAll(RegExp(r'[\- ]'), '');
      return digits.split('').join(' ');
    });
