// The pieces of the approved design (docs/design/2026-10-24-home-final):
// flat cards with a 1 px hairline, a heading with a counter or a link, the
// one attention card, small buttons, chips, the tool tile, and the slot that
// turns between two short facts. Colours come from [C].
import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

/// A section's heading: 17/600, with a counter chip or a link on the right.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.counter, this.link, this.onLink, this.linkKey, this.counterKey, this.onCounter});
  final String title;
  final String? counter;
  final String? link;
  final VoidCallback? onLink;
  final Key? linkKey;
  final Key? counterKey;
  final VoidCallback? onCounter;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Row(children: [
            Expanded(child: Text(title, style: display(17, weight: 600))),
            if (counter != null) GestureDetector(key: counterKey, onTap: onCounter, child: Counter(counter!)),
            if (link != null) LinkText(link!, onTap: onLink, key: linkKey),
          ]),
        ),
      );
}

/// "অক্টোবর · খুলুন ›": accent 12.5/600 with a small chevron.
class LinkText extends StatelessWidget {
  const LinkText(this.text, {super.key, this.onTap});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(text, style: body(12.5, weight: FontWeight.w600, color: C.green)),
            Icon(Icons.chevron_right_rounded, size: 17, color: C.green),
          ]),
        ),
      );
}

/// "৩/৫ শেষ": a small quiet chip.
class Counter extends StatelessWidget {
  const Counter(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(7)),
        child: Text(text, style: body(11.5, color: C.muted, height: 1.2)),
      );
}

/// The card: surface, 1 px border, radius 17, no shadow.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 13), this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: C.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: BorderSide(color: C.border)),
        child: onTap == null ? Padding(padding: padding, child: child) : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

/// A hairline inside a card.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0, this.endIndent = 0});
  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) => Divider(height: 1, thickness: 1, indent: indent, endIndent: endIndent, color: C.border);
}

/// "কাল করব": accent text on the soft accent.
class SoftChip extends StatelessWidget {
  const SoftChip(this.text, {super.key, this.onTap, this.warn = false});
  final String text;
  final VoidCallback? onTap;
  final bool warn;

  @override
  Widget build(BuildContext context) => Material(
        color: warn ? C.warnBg : C.greenTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9), side: warn ? BorderSide(color: C.warnBorder) : BorderSide.none),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(text, style: body(11.5, weight: FontWeight.w600, color: warn ? C.warn : C.green, height: 1.3)),
          ),
        ),
      );
}

/// A small button (38 high): filled accent, or plain with a border.
class SmallButton extends StatelessWidget {
  const SmallButton({super.key, required this.label, this.icon, required this.onTap, this.primary = false});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? C.onAccent : C.ink;
    return Material(
      color: primary ? C.green : C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11), side: BorderSide(color: primary ? C.green : C.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 17, color: fg), const SizedBox(width: 6)],
            Text(label, style: body(12.5, weight: primary ? FontWeight.w600 : FontWeight.w500, color: fg)),
          ]),
        ),
      ),
    );
  }
}

/// One thing that needs a look ("রিমাইন্ডার নাও বাজতে পারে"): warm colours,
/// an icon, a title and a line, and one action. Only one on a page.
class AttentionCard extends StatelessWidget {
  const AttentionCard({super.key, required this.icon, required this.title, required this.text, required this.action, required this.onAction, this.onClose});
  final IconData icon;
  final String title;
  final String text;
  final String action;
  final VoidCallback onAction;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Material(
        color: C.warnBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: C.warnBorder)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onAction,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
            child: Row(children: [
              Icon(icon, size: 20, color: C.warn),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: body(13, weight: FontWeight.w600, color: C.warn, height: 1.35)),
                  const SizedBox(height: 2),
                  Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.warn, height: 1.35)),
                ]),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.warn,
                  side: BorderSide(color: C.warnBorder),
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(action, style: body(12, weight: FontWeight.w600, color: C.warn)),
              ),
              if (onClose != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, size: 18, color: C.warn),
                ),
            ]),
          ),
        ),
      );
}

/// A tool on the home: a 22 icon in a 40 soft square, its name below.
class ToolTile extends StatelessWidget {
  const ToolTile({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 22, color: C.green),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(11.5, height: 1.25)),
          ]),
        ),
      );
}

/// A soft square with an icon (the wallet on the money card, a tool).
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 40});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: size * 0.52, color: C.green),
      );
}

/// Two or more short facts that take turns every [every] (with tiny dots).
/// With "reduce motion" on it does not turn by itself; a swipe changes it.
/// A tap calls [onTap] with the one shown.
class RotatingSlot extends StatefulWidget {
  const RotatingSlot({super.key, required this.slides, this.trailing, this.every = const Duration(seconds: 5), this.onTap});
  final List<Widget> slides;

  /// Beside each slide (its icon), outside the dots.
  final List<Widget>? trailing;
  final Duration every;
  final ValueChanged<int>? onTap;

  @override
  State<RotatingSlot> createState() => _RotatingSlotState();
}

class _RotatingSlotState extends State<RotatingSlot> {
  int _i = 0;
  Timer? _t;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t?.cancel();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!still && widget.slides.length > 1) {
      _t = Timer.periodic(widget.every, (_) {
        if (mounted) setState(() => _i = (_i + 1) % widget.slides.length);
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _step(int by) => setState(() => _i = (_i + by) % widget.slides.length);

  @override
  Widget build(BuildContext context) {
    final n = widget.slides.length;
    if (n == 0) return const SizedBox.shrink();
    final i = _i % n;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap == null ? (n > 1 ? () => _step(1) : null) : () => widget.onTap!(i),
      onHorizontalDragEnd: n > 1 ? (d) => _step((d.primaryVelocity ?? 0) < 0 ? 1 : n - 1) : null,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerRight, children: [...prev, if (cur != null) cur]),
          child: KeyedSubtree(key: ValueKey(i), child: widget.slides[i]),
        ),
        if (n > 1) ...[
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (var k = 0; k < n; k++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(left: 3),
                width: k == i ? 12 : 4,
                height: 4,
                decoration: BoxDecoration(color: k == i ? C.green : C.border, borderRadius: BorderRadius.circular(2)),
              ),
          ]),
        ],
        ]),
        if (widget.trailing != null && widget.trailing!.length == n) ...[
          const SizedBox(width: 10),
          AnimatedSwitcher(duration: const Duration(milliseconds: 380), child: KeyedSubtree(key: ValueKey(i), child: widget.trailing![i])),
        ],
      ]),
    );
  }
}
