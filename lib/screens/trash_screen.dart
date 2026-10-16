import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/pin.dart' show verifyUser;
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// আরও › মুছে ফেলা: everything deleted in the last 30 days, newest first.
/// Bring it back (with its reminder or files), or remove it for good.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  static const _kinds = <String, (String, IconData)>{
    'ledger': ('ধার-দেনা', Icons.payments_outlined),
    'vault': ('পাসওয়ার্ড', Icons.lock_outline_rounded),
    'contacts': ('যোগাযোগ', Icons.call_outlined),
    'notes': ('নোট', Icons.sticky_note_2_outlined),
    'docs': ('ডকুমেন্ট', Icons.folder_copy_outlined),
    'reminders': ('রিমাইন্ডার', Icons.notifications_none_rounded),
    'tasks': ('কাজ', Icons.checklist_rounded),
    'cash': ('আয়-ব্যয়', Icons.account_balance_wallet_outlined),
    'projects': ('অন্যান্য হিসাব', Icons.folder_special_outlined),
    'specialDays': ('বিশেষ দিন', Icons.cake_outlined),
    'memories': ('মনে রাখা কথা', Icons.psychology_outlined),
    'habits': ('অভ্যাস', Icons.local_fire_department_outlined),
    'medicines': ('ওষুধ', Icons.medication_outlined),
    'goals': ('সঞ্চয়', Icons.savings_outlined),
    'installments': ('কিস্তি', Icons.event_repeat_outlined),
    'health': ('স্বাস্থ্য', Icons.favorite_border_rounded),
  };

  Future<void> _restore(BuildContext context, Brain brain, TrashItem t) async {
    // A password comes back only for the owner.
    if (t.kind == 'vault' && !await verifyUser(context, reason: tr('পাসওয়ার্ড ফিরিয়ে আনতে যাচাই করুন'))) return;
    await brain.restoreTrash(t);
    if (context.mounted) toast(context, trf('“{0}” ফিরিয়ে আনা হলো', [t.title]));
  }

  Future<void> _forget(BuildContext context, Brain brain, TrashItem t) async {
    final ok = await confirmDialog(context, title: tr('চিরতরে মুছবেন?'), text: trf('“{0}” আর ফিরিয়ে আনা যাবে না।', [t.title]), yes: tr('মুছুন'), danger: true);
    if (ok) await brain.forgetTrash(t);
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final list = brain.data.trash.reversed.toList();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('মুছে ফেলা'), trailing: [
            if (list.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final ok = await confirmDialog(context, title: tr('সব চিরতরে মুছবেন?'), text: tr('এই তালিকার কিছুই আর ফিরিয়ে আনা যাবে না।'), yes: tr('সব মুছুন'), danger: true);
                  if (ok) await brain.emptyTrash();
                },
                child: Text(tr('সব মুছুন'), style: body(14, weight: FontWeight.w600, color: C.red)),
              ),
          ]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              Text(tr('যা মুছেছেন, ৩০ দিন এখানে থাকে — এর মধ্যে ফিরিয়ে আনতে পারবেন। তারপর নিজে থেকে চিরতরে মুছে যায়।'), style: body(13.5, color: C.muted2, height: 1.55)),
              const SizedBox(height: 14),
              if (list.isEmpty)
                EmptyState(icon: Icons.delete_outline_rounded, title: tr('কিছু মোছা হয়নি'), text: tr('কিছু মুছলে ৩০ দিন এখানে থাকবে।'))
              else
                Panel(
                  child: Rows(children: [
                    for (final t in list)
                      ListRow(
                        key: Key('trash-${t.id}'),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(12)),
                          child: Icon(_kinds[t.kind]?.$2 ?? Icons.description_outlined, color: C.muted2, size: 21),
                        ),
                        title: t.title.isEmpty ? tr(_kinds[t.kind]?.$1 ?? '') : t.title,
                        subtitle: '${tr(_kinds[t.kind]?.$1 ?? '')} · ${trf('আর {0} দিন থাকবে', [bnDigits(TrashItem.keepDays - now.difference(t.deletedAt).inDays)])}',
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(key: Key('restore-${t.id}'), tooltip: tr('ফিরিয়ে আনুন'), onPressed: () => _restore(context, brain, t), icon: Icon(Icons.restore_rounded, color: C.green)),
                          IconButton(tooltip: tr('চিরতরে মুছুন'), onPressed: () => _forget(context, brain, t), icon: Icon(Icons.delete_forever_outlined, color: C.muted)),
                        ]),
                      ),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
