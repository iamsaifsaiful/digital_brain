import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/pin.dart' show verifyUser;
import '../services/files.dart' show StorageUse;
import 'bank_accounts_screen.dart';
import 'calls_screen.dart';
import 'cards_screen.dart' show CardsScreen;
import 'docs_screen.dart';
import 'home_page.dart' show helloFor;
import 'home_shell.dart';
import 'new_item_screen.dart';
import 'notes_screen.dart';
import 'search_screen.dart';
import 'store_more_screens.dart';
import 'vault_screen.dart';
import '../logic/lang.dart';
import '../logic/pro.dart' show medicalOff;

/// আমার ফাইল (owner, 20 Nov, after their reference picture): a hello and
/// search, a ring of how much room the app takes on the phone, the kinds of
/// things as soft square tiles, then the latest kept with a ⋮ to open or
/// share each one to any app.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

/// Bytes in a short form: "৮৯ GB", "৪২.১ MB", "৮৪০ KB".
String roomText(int bytes) {
  const g = 1024 * 1024 * 1024, m = 1024 * 1024;
  if (bytes >= g) return '${bnDigits((bytes / g).toStringAsFixed(bytes >= 10 * g ? 0 : 1))} GB';
  if (bytes >= m) return '${bnDigits((bytes / m).toStringAsFixed(1))} MB';
  return '${bnDigits((bytes / 1024).ceil())} KB';
}

class _StoreScreenState extends State<StoreScreen> {
  Future<StorageUse>? _room;
  int _roomKey = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Measured again when papers are added or removed.
    final brain = BrainScope.of(context);
    final key = brain.data.docs.fold<int>(brain.data.docs.length, (a, d) => a + d.size);
    if (key != _roomKey) {
      _roomKey = key;
      _room = brain.services.files.storageUse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final now = brain.services.now();
    final today = DateTime(now.year, now.month, now.day);

    // The paper that runs out soonest, within a month.
    final dated = d.docs.where((x) => x.expiry != null).toList()..sort((a, b) => a.expiry!.compareTo(b.expiry!));
    final soon = dated.where((x) => !x.expiry!.isBefore(today) && x.expiry!.difference(now).inDays <= 30).firstOrNull;
    final gone = dated.where((x) => x.expiry!.isBefore(today)).firstOrNull;
    String? warning() {
      if (gone != null) return trf('{0}-এর মেয়াদ শেষ হয়ে গেছে', [gone.title]);
      if (soon != null) {
        final days = DateTime(soon.expiry!.year, soon.expiry!.month, soon.expiry!.day).difference(today).inDays;
        return days == 0 ? trf('{0} আজ শেষ', [soon.title]) : trf('{0} {1} দিন পর শেষ', [soon.title, bnDigits(days)]);
      }
      return null;
    }

    final warn = warning();
    final name = brain.userName.trim();

    Widget tile(Key key, String label, IconData icon, Color fg, Color bg, VoidCallback onTap, {bool dot = false}) => InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
                  child: Icon(icon, color: fg, size: 26),
                ),
                if (dot)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(width: 13, height: 13, decoration: BoxDecoration(color: C.warn, shape: BoxShape.circle, border: Border.all(color: C.ground, width: 2))),
                  ),
              ]),
              const SizedBox(height: 7),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: body(12.5, weight: FontWeight.w500, color: C.muted2)),
            ]),
          ),
        );

    // The latest kept: notes, papers and people. Passwords stay inside
    // their locked page.
    final recent = <_Recent>[
      for (final n in d.notes)
        _Recent(n.updatedAt, n.title, '${tr(n.category)} · ${relativeDay(n.updatedAt, now)}', Icons.description_outlined, C.ochre, C.ochreTint,
            open: () => push(NewItemScreen(note: n)), share: () => brain.services.files.shareText([n.title, if (n.body.isNotEmpty && n.body != n.title) n.body].join('\n'))),
      for (final x in d.docs)
        _Recent(x.updatedAt, x.title, x.files.isEmpty ? tr('ডকুমেন্টস') : roomText(x.size), x.files.any((f) => f.isImage) ? Icons.image_outlined : Icons.folder_outlined, C.teal, C.tealTint,
            open: () async {
              final ok = await verifyUser(context, reason: trf('{0} — দেখতে যাচাই করুন', [x.title]));
              if (ok && context.mounted) push(DocScreen(id: x.id, unlocked: true));
            },
            share: x.files.isEmpty ? null : () => shareDoc(context, x)),
      for (final c in d.contacts)
        _Recent(c.updatedAt, c.name, c.phone.isEmpty ? tr('যোগাযোগ') : bnDigits(c.phone), Icons.person_outline_rounded, C.purple, C.purpleTint,
            open: () => push(const CallsScreen()), share: () => brain.services.files.shareText([c.name, if (c.phone.isNotEmpty) c.phone, if (c.email.isNotEmpty) c.email].join('\n'))),
    ]..sort((a, b) => b.at.compareTo(a.at));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // A hello, the name of the tab, and search.
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? helloFor(now) : '${helloFor(now)}, $name', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, color: C.muted)),
              Text(tr('আমার ফাইল'), style: display(25, weight: 700, height: 1.3)),
            ]),
          ),
          Material(
            color: C.surface,
            shape: CircleBorder(side: BorderSide(color: C.border)),
            child: InkWell(
              key: const Key('store-search'),
              customBorder: const CircleBorder(),
              onTap: () => push(const SearchScreen()),
              onLongPress: () => openVoice(context),
              child: SizedBox(width: 46, height: 46, child: Icon(Icons.search_rounded, color: C.ink, size: 22)),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        FutureBuilder<StorageUse>(future: _room, builder: (context, snap) => _RoomRing(use: snap.data)),
        if (warn != null) ...[
          Material(
            color: C.warnBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: C.warnBorder)),
            child: InkWell(
              key: const Key('store-warn'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => push(const ExpiryScreen()),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 12, 11),
                child: Row(children: [
                  Icon(Icons.error_outline_rounded, color: C.warn, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(warn, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13.5, weight: FontWeight.w500, color: C.orangeDark))),
                  Text(tr('দেখুন'), style: body(13.5, weight: FontWeight.w700, color: C.warn)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Padding(padding: const EdgeInsets.fromLTRB(2, 12, 0, 10), child: Text(tr('সব ধরন'), style: display(17, weight: 600))),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: tile(const Key('store-notes'), trm('নোট'), Icons.description_outlined, C.ochre, C.ochreTint, () => push(const NotesScreen()))),
          Expanded(child: tile(const Key('store-vault'), trm('পাসওয়ার্ড'), Icons.key_outlined, C.blue, C.blueTint, () => push(const VaultPage()))),
          Expanded(child: tile(const Key('store-docs'), tr('ডকুমেন্টস'), Icons.folder_outlined, C.teal, C.tealTint, () => push(const DocsScreen()))),
          Expanded(child: tile(const Key('store-contacts'), tr('যোগাযোগ'), Icons.person_outline_rounded, C.purple, C.purpleTint, () => push(const CallsScreen()))),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: tile(const Key('store-accounts'), tr('ব্যাংক একাউন্ট'), Icons.account_balance_outlined, C.green, C.greenTint, () => push(const BankAccountsScreen()))),
          Expanded(child: tile(const Key('store-cards'), tr('ব্যাংক কার্ড'), Icons.credit_card_rounded, C.rose, C.roseTint, () => push(const CardsScreen()))),
          Expanded(child: tile(const Key('store-expiry'), tr('মেয়াদ'), Icons.event_outlined, C.warn, C.warnBg, () => push(const ExpiryScreen()), dot: warn != null)),
          Expanded(child: tile(const Key('store-tags'), tr('ট্যাগ'), Icons.sell_outlined, C.muted2, C.surface2, () => push(const TagsScreen()))),
        ]),
        if (!medicalOff)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Material(
              color: C.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: C.border)),
              child: InkWell(
                key: const Key('store-emergency'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => push(const EmergencyScreen()),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
                  child: Row(children: [
                    Icon(Icons.emergency_outlined, color: C.red, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(tr('জরুরি কার্ড'), style: body(14, weight: FontWeight.w500))),
                    Icon(Icons.chevron_right_rounded, color: C.muted, size: 20),
                  ]),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 0, 4),
          child: Row(children: [
            Expanded(child: Text(tr('সম্প্রতি'), style: display(17, weight: 600))),
            TextButton.icon(
              onPressed: () => push(const NewItemScreen(category: ItemCategory.note)),
              icon: Icon(Icons.add_rounded, size: 18, color: C.green),
              label: Text(tr('নতুন'), style: body(13.5, weight: FontWeight.w600, color: C.green)),
            ),
          ]),
        ),
        if (recent.isEmpty)
          Text(tr('এখনো কোনো নোট নেই। সহকারীকে বলুন — “মনে রাখো: গাড়ির কাগজ আলমারিতে”।'), style: body(14, color: C.muted, height: 1.5))
        else
          for (final (i, r) in recent.take(5).indexed) Padding(padding: const EdgeInsets.only(bottom: 8), child: _RecentCard(r, key: Key('store-recent-$i'))),
      ],
    );
  }
}

class _Recent {
  _Recent(this.at, this.title, this.sub, this.icon, this.fg, this.bg, {required this.open, this.share});
  final DateTime at;
  final String title;
  final String sub;
  final IconData icon;
  final Color fg;
  final Color bg;
  final VoidCallback open;
  final VoidCallback? share;
}

/// One of the latest kept, as a soft card: open on tap, ⋮ to open or share.
class _RecentCard extends StatelessWidget {
  const _RecentCard(this.r, {super.key});
  final _Recent r;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: C.mix > 0.5 ? 0 : 0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: r.open,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 2, 10),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: r.bg, borderRadius: BorderRadius.circular(13)),
                  child: Icon(r.icon, color: r.fg, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14.5, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(r.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
                  ]),
                ),
                PopupMenuButton<int>(
                  tooltip: tr('আরও'),
                  icon: Icon(Icons.more_vert_rounded, color: C.muted),
                  color: C.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (v) => v == 0 ? r.open() : r.share?.call(),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 0, child: Row(children: [Icon(Icons.open_in_new_rounded, size: 19, color: C.ink), const SizedBox(width: 12), Text(tr('খুলুন'), style: body(14.5))])),
                    if (r.share != null)
                      PopupMenuItem(value: 1, child: Row(children: [Icon(Icons.share_outlined, size: 19, color: C.ink), const SizedBox(width: 12), Text(tr('শেয়ার'), style: body(14.5))])),
                  ],
                ),
              ]),
            ),
          ),
        ),
      );
}

/// How the room is drawn: 0 a soft gradient ring, 1 a ring in three colours
/// with a key, 2 a card with a small ring beside the numbers — the one the
/// owner picked (20 Nov).
int roomStyle = 2;

/// The ring: how much the app takes on the phone, what part of it is
/// photos and files, and the phone's free room.
class _RoomRing extends StatelessWidget {
  const _RoomRing({this.use});
  final StorageUse? use;

  @override
  Widget build(BuildContext context) {
    final u = use;
    final total = u == null || u.app == 0 ? 1 : u.app;
    final parts = u == null ? <(double, Color)>[] : [(u.docs / total, C.green), (u.data / total, C.blue), (u.other / total, C.ochre)];
    final docsPart = u == null ? 0.0 : (u.docs / total).clamp(0.0, 1.0);
    Widget centre(double size) => Column(mainAxisSize: MainAxisSize.min, children: [
          Text(u == null ? '…' : roomText(u.app), key: const Key('store-room'), style: display(size, weight: 700, height: 1.15)),
          Text(tr('অ্যাপ নিয়েছে'), style: body(12.5, color: C.muted)),
        ]);
    Widget animated(double size, double stroke, Widget child, {bool multi = false}) => SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, child) => CustomPaint(
              painter: multi ? _PartsPainter(parts, v, stroke, C.surface2) : _RingPainter(docsPart * v, C.green, C.surface2, stroke),
              child: child,
            ),
            child: Center(child: child),
          ),
        );
    Widget key(Color c, String label, String value) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: body(12.5, color: C.muted)),
          const SizedBox(width: 5),
          Text(value, style: body(12.5, weight: FontWeight.w600)),
        ]);

    switch (roomStyle) {
      case 1:
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 14),
          child: Column(children: [
            animated(184, 16, centre(24), multi: true),
            const SizedBox(height: 16),
            if (u != null)
              Wrap(alignment: WrapAlignment.center, spacing: 16, runSpacing: 6, children: [
                key(C.green, tr('ছবি ও ফাইল'), roomText(u.docs)),
                key(C.blue, tr('আপনার তথ্য'), roomText(u.data)),
                key(C.ochre, tr('অ্যাপ নিজে'), roomText(u.other)),
              ]),
            if (u?.free != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(trf('ফোনে খালি {0}', [roomText(u!.free!)]), style: body(12.5, color: C.muted))),
          ]),
        );
      case 2:
        return Container(
          margin: const EdgeInsets.only(top: 12, bottom: 14),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.border)),
          child: Row(children: [
            animated(112, 12, Text(u == null ? '' : '${bnDigits((docsPart * 100).round())}%', style: body(18, weight: FontWeight.w700, color: C.green))),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('অ্যাপ নিয়েছে'), style: body(12.5, color: C.muted)),
                Text(u == null ? '…' : roomText(u.app), key: const Key('store-room'), style: display(24, weight: 700, height: 1.25)),
                const SizedBox(height: 8),
                if (u != null) key(C.green, tr('ছবি ও ফাইল'), roomText(u.docs)),
                if (u?.free != null) ...[const SizedBox(height: 4), key(C.surface2, tr('ফোনে খালি'), roomText(u!.free!))],
              ]),
            ),
          ]),
        );
      default:
        Widget label(String big, String small, CrossAxisAlignment a) => Column(crossAxisAlignment: a, mainAxisSize: MainAxisSize.min, children: [
              Text(big, style: body(14.5, weight: FontWeight.w700, height: 1.2)),
              Text(small, style: body(12, color: C.muted, height: 1.3)),
            ]);
        return SizedBox(
          height: 240,
          child: Stack(children: [
            if (u?.free != null) Positioned(left: 0, top: 8, child: label(roomText(u!.free!), tr('ফোনে খালি'), CrossAxisAlignment.start)),
            if (u != null) Positioned(right: 0, bottom: 12, child: label(roomText(u.docs), tr('ছবি ও ফাইল'), CrossAxisAlignment.end)),
            Center(child: animated(188, 16, centre(26))),
          ]),
        );
    }
  }
}

/// One arc on a soft track, its colour deepening along the way.
class _RingPainter extends CustomPainter {
  _RingPainter(this.part, this.color, this.track, this.stroke);
  final double part;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2 - stroke / 2);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = track);
    if (part <= 0) return;
    final sweep = math.pi * 2 * part.clamp(0.02, 1.0);
    final light = Color.lerp(color, Colors.white, 0.55)!;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 2);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawArc(
        rect,
        0,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(colors: [light, color], stops: const [0, 1], endAngle: math.max(sweep, 0.01)).createShader(rect));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.part != part || old.color != color || old.track != track;
}

/// Several arcs one after another, with small gaps, growing in with [t].
class _PartsPainter extends CustomPainter {
  _PartsPainter(this.parts, this.t, this.stroke, this.track);
  final List<(double, Color)> parts;
  final double t;
  final double stroke;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2 - stroke / 2);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = track);
    final gap = stroke / (size.shortestSide / 2) + 0.06;
    var at = -math.pi / 2;
    for (final (p, c) in parts) {
      final sweep = math.pi * 2 * p * t;
      if (sweep > gap + 0.01) {
        canvas.drawArc(rect, at + gap / 2, sweep - gap, false, Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round..color = c);
      }
      at += sweep;
    }
  }

  @override
  bool shouldRepaint(_PartsPainter old) => old.t != t || old.parts != parts;
}
