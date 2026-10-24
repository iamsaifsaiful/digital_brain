import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/cash.dart';
import '../logic/lang.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/widgets.dart';

/// "মূল হিসাবে যুক্ত" (owner, 24 Oct): a loan, a বকেয়া or another হিসাব's
/// entry can also be written in the main আয়-ব্যয়. Asked right after it is
/// written; it can be done later from the entry's menu.

/// What is said once it is in: "মূল হিসাবে যুক্ত হলো — আয়-ব্যয়ে ‘ধার দেওয়া’ ৳৫০০ খরচ".
String mainAddedText(CashEntry e) =>
    trf('মূল হিসাবে যুক্ত হলো — আয়-ব্যয়ে ‘{0}’ {1} {2}', [e.category, taka(e.amount), e.kind == CashKind.income ? tr('আয়') : tr('খরচ')]);

/// Asks whether [sourceId] goes in the main আয়-ব্যয় too; on yes it is put
/// there and a message says so. Nothing is asked for what cannot go or is there.
Future<void> askAddToMain(BuildContext context, String sourceId) async {
  final brain = BrainScope.read(context);
  if (!canGoToMain(brain.data, sourceId) || mainCopyOf(brain.data, sourceId) != null) return;
  final e = mainEntryFor(brain.data, sourceId);
  if (e == null) return;
  final ok = await confirmDialog(
    context,
    title: tr('মূল হিসাবেও যোগ করবেন?'),
    text: trf('আয়-ব্যয়ে ‘{0}’ খাতে {1} {2} হিসেবে লেখা হবে, “এখন আছে”-ও সেই মতো বদলাবে। পরে এন্ট্রির মেনু থেকেও যোগ বা বাদ দেওয়া যাবে।',
        [e.category, taka(e.amount), e.kind == CashKind.income ? tr('আয়') : tr('খরচ')]),
    yes: tr('হ্যাঁ, যোগ করুন'),
  );
  if (!ok || !context.mounted) return;
  final added = await brain.addToMain(sourceId);
  if (added != null && context.mounted) toast(context, mainAddedText(added));
}

/// The menu line for an entry: "মূল হিসাবে যোগ করুন" or "মূল হিসাব থেকে সরান"; null when it cannot go.
(String, IconData)? mainMenuLine(AppData d, String sourceId) {
  if (!canGoToMain(d, sourceId)) return null;
  return mainCopyOf(d, sourceId) == null
      ? (tr('মূল হিসাবে যোগ করুন'), Icons.add_card_outlined)
      : (tr('মূল হিসাব থেকে সরান'), Icons.remove_circle_outline_rounded);
}

/// Does what [mainMenuLine] offered, and says so.
Future<void> toggleMain(BuildContext context, String sourceId) async {
  final brain = BrainScope.read(context);
  if (mainCopyOf(brain.data, sourceId) == null) {
    final added = await brain.addToMain(sourceId);
    if (added != null && context.mounted) toast(context, mainAddedText(added));
  } else {
    await brain.removeFromMain(sourceId);
    if (context.mounted) toast(context, tr('মূল হিসাব থেকে সরানো হলো'));
  }
}

/// " · মূল হিসাবে যুক্ত" after an entry's line, when it is.
String mainMark(AppData d, String sourceId) => mainCopyOf(d, sourceId) == null ? '' : ' · ${tr('মূল হিসাবে যুক্ত')}';
