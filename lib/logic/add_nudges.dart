/// "কিছু যুক্ত করুন" nudges (owner, 25 Oct): a floating message on the home
/// for every menu that is still empty — tap it to go there and add. A menu
/// with something in it has no message. ✕ hides them all for a day; after
/// that the still-empty menus show again.
library;

import '../models/models.dart';

class AddNudge {
  const AddNudge(this.id, this.text, this.place);

  /// Also the key of its icon on the home.
  final String id;
  final String text;

  /// Where tapping it goes (see `openPlace`).
  final String place;
}

/// The nudges for [d]'s empty menus, in the order they are shown.
List<AddNudge> addNudges(AppData d) => [
      if (d.tasks.isEmpty) const AddNudge('tasks', 'কাজের তালিকায় কিছু যুক্ত করুন', 'tasks'),
      if (!d.reminders.any((r) => !r.alarm)) const AddNudge('reminders', 'রিমাইন্ডার যুক্ত করুন', 'reminders'),
      if (d.cash.isEmpty) const AddNudge('money', 'হিসাবে আয়-ব্যয় যুক্ত করুন', 'money'),
      if (d.ledger.isEmpty) const AddNudge('ledger', 'ধার-দেনা থাকলে লিখে রাখুন', 'ledger'),
      if (d.notes.isEmpty) const AddNudge('notes', 'একটা নোট লিখে রাখুন', 'notes'),
      if (d.docs.isEmpty) const AddNudge('docs', 'জরুরি কাগজের ছবি রাখুন — NID, পাসপোর্ট', 'docs'),
      if (d.vault.isEmpty) const AddNudge('vault', 'পাসওয়ার্ড তালাবদ্ধ করে রাখুন', 'vault'),
      if (d.contacts.isEmpty) const AddNudge('contacts', 'জরুরি নম্বর যুক্ত করুন', 'contacts'),
      if (d.health.isEmpty) const AddNudge('health', 'স্বাস্থ্যে ওজন বা রক্তচাপ যুক্ত করুন', 'health'),
      if (d.medicines.isEmpty) const AddNudge('medicines', 'ওষুধ খেলে তার সময়সূচি যুক্ত করুন', 'medicines'),
      if (d.habits.isEmpty) const AddNudge('habits', 'একটা ভালো অভ্যাস যুক্ত করুন', 'habits'),
      if (d.specialDays.isEmpty) const AddNudge('special', 'জন্মদিন বা বিশেষ দিন যুক্ত করুন', 'special'),
      if (d.goals.isEmpty) const AddNudge('savings', 'সঞ্চয়ের লক্ষ্য যুক্ত করুন', 'savings'),
      if (!d.reminders.any((r) => r.alarm)) const AddNudge('alarms', 'অ্যালার্ম যুক্ত করুন', 'alarms'),
    ];

/// Hidden with ✕ at [hiddenAt]: shown again a day later.
bool nudgesShown(DateTime now, DateTime? hiddenAt) => hiddenAt == null || now.difference(hiddenAt) >= const Duration(days: 1);
