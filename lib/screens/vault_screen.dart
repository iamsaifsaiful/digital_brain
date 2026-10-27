import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/parser.dart';
import '../logic/services_list.dart';
import '../logic/vault_age.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/pin.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'new_item_screen.dart';
import 'vault_item_screen.dart';
import '../logic/lang.dart';

/// Passwords and logins. Opening one needs a fingerprint or the PIN.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  VaultKind? _kind;
  String _q = '';

  Future<void> _open(VaultItem v) async {
    final ok = await verifyUser(context, reason: trf('{0} — তথ্য দেখতে যাচাই করুন', [v.name]));
    if (ok && mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => VaultItemScreen(id: v.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final all = [...brain.data.vault]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final stale = {for (final v in stalePasswords(brain.data, brain.services.now())) v.id};
    final kinds = VaultKind.values.where((k) => all.any((v) => v.kind == k)).toList();
    final q = normalize(_q);
    final list = all.where((v) {
      if (_kind != null && v.kind != _kind) return false;
      if (q.isEmpty) return true;
      return normalize('${v.name} ${v.address} ${v.kind.label}').contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            if (Navigator.of(context).canPop())
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  tooltip: tr('ফিরে যান'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.chevron_left_rounded, size: 30),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('গোপন তথ্য'), style: display(24, weight: 700)),
                  Row(children: [
                    Icon(Icons.lock_rounded, size: 14, color: C.greenDark),
                    const SizedBox(width: 4),
                    Text(trf('এনক্রিপ্ট করা · {0}টি তথ্য', [bnDigits(all.length)]), style: body(13, weight: FontWeight.w600, color: C.greenDark)),
                  ]),
                ],
              ),
            ),
            RoundIconButton(
              icon: Icons.add_rounded,
              tooltip: tr('নতুন পাসওয়ার্ড যোগ করুন'),
              dark: true,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.password))),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: tr('ওয়েবসাইট বা অ্যাপের নাম')),
        ),
        if (kinds.length > 1) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip(tr('সব'), _kind == null, () => setState(() => _kind = null)),
            for (final k in kinds) _chip(k.label, _kind == k, () => setState(() => _kind = k)),
          ]),
        ],
        const SizedBox(height: 12),
        InfoBanner(text: tr('শুধু এই ফোনে, তালাবদ্ধ অবস্থায় থাকে। দেখতে আঙুলের ছাপ বা PIN লাগে। AI-তে কখনো যায় না, জোরে পড়াও হয় না।')),
        if (stale.isNotEmpty) ...[
          const SizedBox(height: 8),
          InfoBanner(
            text: trf('{0}টা পাসওয়ার্ড ৬ মাসের বেশি বদলানো হয়নি — নিচে “পুরোনো” লেখা আছে। সময় করে বদলে নিন।', [bnDigits(stale.length)]),
            icon: Icons.update_rounded,
            fg: C.orangeDark,
            iconColor: C.orange,
            bg: C.orangeTint,
          ),
        ],
        const SizedBox(height: 12),
        if (all.isEmpty)
          EmptyState(
            icon: Icons.key_rounded,
            title: tr('প্রথম পাসওয়ার্ডটি রাখুন'),
            text: tr('ওয়েবসাইট, অ্যাপ, Wi-Fi বা ব্যাংকের লগইন এখানে এনক্রিপ্ট করে রাখা হবে।'),
            action: tr('পাসওয়ার্ড যোগ করুন'),
            onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.password))),
          )
        else if (list.isEmpty)
          Panel(padding: const EdgeInsets.all(16), child: Text(tr('কিছু মেলেনি।'), style: body(14, color: C.muted)))
        else
          Panel(
            child: Rows(children: [
              for (final v in list)
                ListRow(
                  leading: knownServiceOf(v.name) == null ? _KindIcon(kind: v.kind) : ServiceBadge(service: knownServiceOf(v.name)!),
                  title: v.name,
                  subtitle: v.address.isEmpty || v.kind == VaultKind.wifi ? v.kind.label : '${v.kind.label} · ${v.address}',
                  trailing: stale.contains(v.id) ? Pill(tr('পুরোনো'), fg: C.orangeDark, bg: C.orangeTint) : Text('••••', style: body(18, color: C.muted)),
                  onTap: () => _open(v),
                ),
            ]),
          ),
      ],
    );
  }

  Widget _chip(String label, bool on, VoidCallback tap) => ChoiceChip(
        label: Text(label, style: body(14, weight: on ? FontWeight.w600 : FontWeight.w400, color: on ? C.onInk : C.ink)),
        selected: on,
        showCheckmark: false,
        selectedColor: C.ink,
        backgroundColor: C.surface,
        side: BorderSide(color: on ? C.ink : C.border),
        shape: const StadiumBorder(),
        onSelected: (_) => tap(),
      );
}

class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind});
  final VaultKind kind;

  @override
  Widget build(BuildContext context) {
    final l = vaultLook(kind);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: l.bg, borderRadius: BorderRadius.circular(12)),
      child: Icon(l.icon, color: l.fg, size: 20),
    );
  }
}

/// গোপন তথ্য as its own page (from তথ্য).
class VaultPage extends StatelessWidget {
  const VaultPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: SafeArea(child: VaultScreen()));
}
