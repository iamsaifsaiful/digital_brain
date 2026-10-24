import 'package:flutter/material.dart';

import '../logic/cash.dart';
import '../logic/lang.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/widgets.dart';

/// মূল টাকা (owner, 24 Oct): an own loan and another হিসাব's entry go into
/// the main money by themselves, as their own line in আয়-ব্যয়; the entry's
/// menu can take one out (or put it back).

/// Says "মূল টাকায় যুক্ত হলো — …" when the last save made a main line.
void sayMainLine(BuildContext context) {
  final e = BrainScope.read(context).lastMainLine;
  if (e != null) toast(context, mainAddedText(e));
}

/// The menu line for an entry: "মূল টাকা থেকে বাদ দিন" or "মূল টাকায় যোগ করুন"; null when it cannot go.
(String, IconData)? mainMenuLine(AppData d, String sourceId) {
  if (!canGoToMain(d, sourceId)) return null;
  return mainCopyOf(d, sourceId) == null
      ? (tr('মূল টাকায় যোগ করুন'), Icons.add_card_outlined)
      : (tr('মূল টাকা থেকে বাদ দিন'), Icons.remove_circle_outline_rounded);
}

/// Does what [mainMenuLine] offered, and says so.
Future<void> toggleMain(BuildContext context, String sourceId) async {
  final brain = BrainScope.read(context);
  if (mainCopyOf(brain.data, sourceId) == null) {
    final added = await brain.addToMain(sourceId);
    if (added != null && context.mounted) toast(context, mainAddedText(added));
  } else {
    await brain.removeFromMain(sourceId);
    if (context.mounted) toast(context, tr('মূল টাকা থেকে বাদ দেওয়া হলো'));
  }
}

/// " · মূল টাকায় নেই" after an entry the user took out.
String mainMark(AppData d, String sourceId) => canGoToMain(d, sourceId) && mainCopyOf(d, sourceId) == null ? ' · ${tr('মূল টাকায় নেই')}' : '';
