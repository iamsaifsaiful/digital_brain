import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/parser.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/pin.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'new_item_screen.dart';
import 'vault_item_screen.dart';

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
    final ok = await verifyUser(context, reason: '${v.name} — তথ্য দেখতে যাচাই করুন');
    if (ok && mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => VaultItemScreen(id: v.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final all = [...brain.data.vault]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ভল্ট', style: display(26, weight: 700)),
                  Row(children: [
                    const Icon(Icons.lock_rounded, size: 14, color: C.greenDark),
                    const SizedBox(width: 4),
                    Text('এনক্রিপ্ট করা · ${bnDigits(all.length)}টি তথ্য', style: body(13, weight: FontWeight.w600, color: C.greenDark)),
                  ]),
                ],
              ),
            ),
            RoundIconButton(
              icon: Icons.add_rounded,
              tooltip: 'নতুন পাসওয়ার্ড যোগ করুন',
              dark: true,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.password))),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ওয়েবসাইট বা অ্যাপের নাম'),
        ),
        if (kinds.length > 1) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('সব', _kind == null, () => setState(() => _kind = null)),
            for (final k in kinds) _chip(k.label, _kind == k, () => setState(() => _kind = k)),
          ]),
        ],
        const SizedBox(height: 12),
        const InfoBanner(text: 'পাসওয়ার্ড দেখতে আঙুলের ছাপ বা PIN লাগে। ভয়েসে কখনো জোরে পড়া হয় না।'),
        const SizedBox(height: 12),
        if (all.isEmpty)
          EmptyState(
            icon: Icons.key_rounded,
            title: 'প্রথম পাসওয়ার্ডটি রাখুন',
            text: 'ওয়েবসাইট, অ্যাপ, Wi-Fi বা ব্যাংকের লগইন এখানে এনক্রিপ্ট করে রাখা হবে।',
            action: 'পাসওয়ার্ড যোগ করুন',
            onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.password))),
          )
        else if (list.isEmpty)
          Panel(padding: const EdgeInsets.all(16), child: Text('কিছু মেলেনি।', style: body(14, color: C.muted)))
        else
          Panel(
            child: Rows(children: [
              for (final v in list)
                ListRow(
                  leading: _KindIcon(kind: v.kind),
                  title: v.name,
                  subtitle: v.address.isEmpty || v.kind == VaultKind.wifi ? v.kind.label : '${v.kind.label} · ${v.address}',
                  trailing: Text('••••', style: body(18, color: const Color(0xFF9AA39E))),
                  onTap: () => _open(v),
                ),
            ]),
          ),
      ],
    );
  }

  Widget _chip(String label, bool on, VoidCallback tap) => ChoiceChip(
        label: Text(label, style: body(14, weight: on ? FontWeight.w600 : FontWeight.w400, color: on ? Colors.white : C.ink)),
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
