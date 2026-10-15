import 'package:flutter/material.dart';

import '../logic/lang.dart';
import '../logic/report.dart';
import '../state/brain.dart';
import 'file_view.dart';
import 'theme.dart';
import 'widgets.dart';

export '../logic/report.dart' show ReportPart, ReportScope;

/// Makes the PDF and shows it, with ডাউনলোড, শেয়ার and অন্য অ্যাপে খুলুন
/// on top (the same viewer as a kept PDF).
Future<void> exportPdf(BuildContext context, Set<ReportPart> parts, {ReportScope scope = const ReportScope(), String? title, String? fileExtra}) async {
  if (parts.isEmpty) return;
  final brain = BrainScope.read(context);
  final now = brain.services.now();
  final spec = reportSpec(brain.data, parts, now, userName: brain.userName, scope: scope, title: title);
  final nav = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(width: 18),
          Expanded(child: Text(tr('PDF তৈরি হচ্ছে…'), style: body(16))),
        ]),
      ),
    ),
  );
  final bytes = await brain.services.files.pdfMake(spec);
  nav.pop();
  if (!context.mounted) return;
  if (bytes == null) {
    toast(context, tr('PDF তৈরি করা গেল না। আবার চেষ্টা করুন।'));
    return;
  }
  await viewFile(context, bytes, name: reportFileName(parts, now, extra: fileExtra), mime: 'application/pdf', title: '${spec['title']}');
}

/// The PDF button for a page's top bar.
class PdfButton extends StatelessWidget {
  const PdfButton(this.parts, {super.key, this.scope = const ReportScope(), this.title, this.fileExtra});
  final Set<ReportPart> parts;
  final ReportScope scope;
  final String? title;
  final String? fileExtra;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tr('PDF ডাউনলোড'),
        icon: Icon(Icons.picture_as_pdf_outlined, color: C.ink),
        onPressed: () => exportPdf(context, parts, scope: scope, title: title, fileExtra: fileExtra),
      );
}

/// সবকিছু PDF আকারে: pick the parts (all ticked), then make one PDF.
Future<void> exportEverything(BuildContext context) async {
  final picked = await showModalBottomSheet<Set<ReportPart>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _PickParts(),
  );
  if (picked == null || picked.isEmpty || !context.mounted) return;
  await exportPdf(context, picked);
}

class _PickParts extends StatefulWidget {
  const _PickParts();
  @override
  State<_PickParts> createState() => _PickPartsState();
}

class _PickPartsState extends State<_PickParts> {
  final _on = ReportPart.values.toSet();

  static IconData _icon(ReportPart p) => switch (p) {
        ReportPart.tasks => Icons.checklist_rounded,
        ReportPart.reminders => Icons.notifications_none_rounded,
        ReportPart.money => Icons.account_balance_wallet_outlined,
        ReportPart.ledger => Icons.handshake_outlined,
        ReportPart.projects => Icons.folder_open_rounded,
        ReportPart.accounts => Icons.savings_outlined,
        ReportPart.shops => Icons.storefront_outlined,
        ReportPart.notes => Icons.sticky_note_2_outlined,
        ReportPart.contacts => Icons.contacts_outlined,
        ReportPart.docs => Icons.description_outlined,
        ReportPart.specialDays => Icons.cake_outlined,
        ReportPart.health => Icons.favorite_border_rounded,
        ReportPart.memories => Icons.psychology_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final all = _on.length == ReportPart.values.length;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
            child: Row(children: [
              Expanded(child: Text(tr('সবকিছু PDF আকারে'), style: display(19, weight: 700))),
              TextButton(
                onPressed: () => setState(() => all ? _on.clear() : _on.addAll(ReportPart.values)),
                child: Text(all ? tr('সব বাদ') : tr('সব বাছুন')),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
            child: Text(tr('যা যা চান টিক দিন। পাসওয়ার্ড ও গোপন তথ্য PDF-এ যায় না।'), style: body(13.5, color: C.muted)),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final p in ReportPart.values)
                CheckboxListTile(
                  value: _on.contains(p),
                  onChanged: (v) => setState(() => v == true ? _on.add(p) : _on.remove(p)),
                  secondary: Icon(_icon(p), color: C.green),
                  title: Text(tr(p.label), style: body(15.5)),
                  dense: true,
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _on.isEmpty ? null : () => Navigator.pop(context, Set.of(_on)),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(tr('PDF তৈরি করুন')),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
