/// The live list of medicine names under a name box (owner, 17 Nov), shared
/// by the medicine page and the Play app's medicine reminder (owner, 18 Nov).
library;

import 'package:flutter/material.dart';

import '../logic/lang.dart';
import '../logic/medicine_catalog.dart';
import 'theme.dart';

class MedSearchHits extends StatelessWidget {
  /// [showUse]: also what the medicine is usually taken for. Off in the Play
  /// app, which keeps no health information of its own (pro.dart medicalOff).
  const MedSearchHits({super.key, required this.hits, required this.onPick, this.showUse = true});
  final List<MedInfo> hits;
  final ValueChanged<MedInfo> onPick;
  final bool showUse;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
        child: Column(children: [
          for (final (i, m) in hits.indexed) ...[
            if (i > 0) Divider(height: 1, color: C.line),
            InkWell(
              key: Key('med-hit-${m.en}'),
              onTap: () => onPick(m),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(children: [
                  Icon(Icons.medication_outlined, size: 20, color: C.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${m.bn} · ${m.en}', style: body(15, weight: FontWeight.w600)),
                      Text(showUse ? '${m.genericBn} — ${tr(m.use)}' : m.genericBn, style: body(12.5, color: C.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ]),
              ),
            ),
          ],
        ]),
      );
}
