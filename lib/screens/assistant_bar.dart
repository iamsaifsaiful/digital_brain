import 'package:flutter/material.dart';

import '../logic/lang.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import 'home_shell.dart';
import 'search_screen.dart';

/// Home's bar at the bottom, where the thumb reaches: one-tap questions,
/// one box to find, save or ask, and a big mic.
class AssistantBar extends StatelessWidget {
  const AssistantBar({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final qs = brain.quickQuestions;
    return Container(
      decoration: BoxDecoration(
        color: C.surface,
        border: Border(top: BorderSide(color: C.line)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: C.dark ? 0.3 : 0.05), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (qs.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final q in qs)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(q),
                      labelStyle: body(13.5, weight: FontWeight.w500, color: C.greenDark),
                      backgroundColor: C.greenTint,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => openChatWith(context, q),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(
              child: Material(
                color: C.soft,
                borderRadius: BorderRadius.circular(26),
                child: InkWell(
                  borderRadius: BorderRadius.circular(26),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
                  child: SizedBox(
                    height: 52,
                    child: Row(children: [
                      const SizedBox(width: 16),
                      Icon(Icons.search_rounded, color: C.muted, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(tr('খুঁজুন, রাখুন বা জিজ্ঞেস করুন…'), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, color: C.muted)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              button: true,
              label: tr('বলুন'),
              child: Tooltip(
                message: tr('বলুন'),
                child: Material(
                  color: C.green,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => openVoice(context),
                    child: const SizedBox(width: 56, height: 56, child: Icon(Icons.mic_rounded, color: Colors.white, size: 28)),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
