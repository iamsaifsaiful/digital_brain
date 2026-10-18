import 'package:flutter/material.dart';

import '../models/models.dart';
import 'theme.dart';
import '../logic/lang.dart';

/// First letter (grapheme) of a name: "সজীব" → "স", "নাসরিন" → "না".
String initialOf(String name) {
  final t = name.trim();
  if (t.isEmpty) return '?';
  final ascii = RegExp(r'^[A-Za-z0-9]{2}').firstMatch(t);
  if (ascii != null) return ascii[0]!.toUpperCase();
  return t.characters.first;
}

/// White rounded card with a hairline border.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = EdgeInsets.zero, Color? color, Color? borderColor, this.radius = 16}) : _color = color, _borderColor = borderColor;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? _color;
  Color get color => _color ?? C.surface;
  final Color? _borderColor;
  Color get borderColor => _borderColor ?? C.line;
  final double radius;

  /// A Material, so list tiles and ink splashes inside show properly.
  @override
  Widget build(BuildContext context) => Material(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: borderColor)),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      );
}

/// Rows separated by thin lines.
class Rows extends StatelessWidget {
  const Rows({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      );
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, Color? fg, Color? bg, this.size = 40, this.square = false}) : _fg = fg, _bg = bg;
  final String name;
  final Color? _fg;
  Color get fg => _fg ?? C.green;
  final Color? _bg;
  Color get bg => _bg ?? C.greenTint;
  final double size;
  final bool square;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(square ? size * 0.3 : size / 2),
        ),
        child: Text(initialOf(name), style: body(size * 0.42, weight: FontWeight.w600, color: fg, height: 1)),
      );
}

/// Avatar colours for a balance: green when they owe me, orange when I owe.
(Color, Color) balanceColors(int balance) => balance < 0 ? (C.orange, C.orangeTint) : (C.green, C.greenTint);

Color balanceColor(int balance) => balance < 0 ? C.orange : (balance > 0 ? C.green : C.muted);

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, Color? fg, Color? bg}) : _fg = fg, _bg = bg;
  final String text;
  final Color? _fg;
  Color get fg => _fg ?? C.greenDark;
  final Color? _bg;
  Color get bg => _bg ?? C.greenTint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: body(13, weight: FontWeight.w600, color: fg)),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: Text(title, style: body(15, weight: FontWeight.w600, color: C.muted2))),
            if (action != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: C.green, minimumSize: const Size(44, 40)),
                child: Text(action!, style: body(14, weight: FontWeight.w600, color: C.green)),
              ),
          ],
        ),
      );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, Color? color, this.height = 52}) : _color = color;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? _color;
  Color get color => _color ?? C.green;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: C.disabled,
            disabledForegroundColor: C.muted,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 8)],
              Flexible(child: Text(label, style: body(17, weight: FontWeight.w600, color: onPressed == null ? C.muted : Colors.white), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      );
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon, Color? fg, Color? borderColor, this.height = 48}) : _fg = fg, _borderColor = borderColor;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? _fg;
  Color get fg => _fg ?? C.ink;
  final Color? _borderColor;
  Color get borderColor => _borderColor ?? C.border;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: fg,
            backgroundColor: C.surface,
            side: BorderSide(color: borderColor),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 6)],
              Flexible(child: Text(label, style: body(15, weight: FontWeight.w600, color: fg), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      );
}

/// 44×44 round button used in headers.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.dark = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool dark;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: dark ? C.fill : C.surface,
          shape: CircleBorder(side: BorderSide(color: dark ? C.fill : C.line)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22, color: dark ? Colors.white : C.ink)),
          ),
        ),
      );
}

/// Standard top bar: back chevron, title, optional trailing widgets.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.trailing = const [], this.close = false, this.onBack});
  final String title;
  final List<Widget> trailing;
  final bool close;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
        child: Row(
          children: [
            IconButton(
              tooltip: close ? tr('বন্ধ করুন') : tr('ফিরে যান'),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: Icon(close ? Icons.close_rounded : Icons.chevron_left_rounded, size: close ? 24 : 30, color: C.ink),
            ),
            const SizedBox(width: 2),
            Expanded(child: Text(title, style: display(21, weight: 700), overflow: TextOverflow.ellipsis)),
            ...trailing,
          ],
        ),
      );
}

/// Big page title for a main tab ("আজ", "হিসাব"…).
class TabTitle extends StatelessWidget {
  const TabTitle(this.title, {super.key, this.sub, this.trailing});
  final String title;
  final String? sub;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (sub != null) Text(sub!, style: body(13, color: C.muted)),
              Text(title, style: display(26, weight: 700, height: 1.2)),
            ]),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

/// Grey pill with 2–4 choices; the chosen one is white (iOS-style tabs).
class SegTabs<T> extends StatelessWidget {
  const SegTabs({super.key, required this.items, required this.value, required this.onChanged});
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final at = items.indexWhere((x) => x.$1 == value);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: 38,
        child: Stack(children: [
          // The white thumb glides to the chosen tab.
          if (at >= 0)
            AnimatedAlign(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment(items.length == 1 ? 0 : -1 + 2 * at / (items.length - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / items.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(9), boxShadow: const [BoxShadow(color: Color(0x14111827), blurRadius: 2, offset: Offset(0, 1))]),
                ),
              ),
            ),
          Row(children: [
            for (final (v, label) in items)
              Expanded(
                child: Semantics(
                  selected: v == value,
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(v),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: body(14, weight: v == value ? FontWeight.w600 : FontWeight.w400, color: v == value ? C.ink : C.muted2),
                        child: Text(label, maxLines: 1),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

/// Dark rounded "+ যোগ করুন" button floating at the bottom right.
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.label, required this.onPressed, this.icon = Icons.add_rounded});
  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        heroTag: null,
        onPressed: onPressed,
        backgroundColor: C.fill,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: const StadiumBorder(),
        icon: Icon(icon),
        label: Text(label, style: body(15, weight: FontWeight.w600, color: Colors.white)),
      );
}

/// Small round button (call, SMS, WhatsApp…).
class CircleAction extends StatelessWidget {
  const CircleAction({super.key, required this.icon, required this.tooltip, required this.onPressed, Color? fg, Color? bg, this.size = 40}) : _fg = fg, _bg = bg;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? _fg;
  Color get fg => _fg ?? C.green;
  final Color? _bg;
  Color get bg => _bg ?? C.greenTint;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(width: size, height: size, child: Icon(icon, size: size * 0.48, color: fg)),
          ),
        ),
      );
}

/// Label over a big amount (and an optional line under it).
class Figure extends StatelessWidget {
  const Figure({super.key, required this.label, required this.amount, Color? color, this.size = 20, this.sub}) : _color = color;
  final String label;
  final String amount;
  final Color? _color;
  Color get color => _color ?? C.ink;
  final double size;
  final String? sub;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: body(13, color: C.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(amount, style: display(size, weight: 700, color: color, height: 1.25)),
        ),
        if (sub != null) Text(sub!, style: body(12, color: C.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]);
}

/// "You said …" (dark, right) or the app's answer (white, left).
class Bubble extends StatelessWidget {
  const Bubble({super.key, required this.label, required this.text, this.fromUser = true});
  final String label;
  final String text;
  final bool fromUser;

  @override
  Widget build(BuildContext context) => Align(
        alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 310),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: fromUser ? C.ink : C.surface,
              border: fromUser ? null : Border.all(color: C.line),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(fromUser ? 20 : 6),
                bottomRight: Radius.circular(fromUser ? 6 : 20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: body(12, color: fromUser ? C.onInkMuted : C.green, weight: fromUser ? FontWeight.w400 : FontWeight.w600)),
                const SizedBox(height: 2),
                Text('“$text”', style: body(17, color: fromUser ? C.onInk : C.ink)),
              ],
            ),
          ),
        ),
      );
}

/// Coloured note with an icon.
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.text, this.icon = Icons.verified_user_outlined, Color? fg, Color? iconColor, Color? bg}) : _fg = fg, _iconColor = iconColor, _bg = bg;
  final String text;
  final IconData icon;
  final Color? _fg;
  Color get fg => _fg ?? C.blueText;
  final Color? _iconColor;
  Color get iconColor => _iconColor ?? C.blue;
  final Color? _bg;
  Color get bg => _bg ?? C.blueTint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: body(14, color: fg, height: 1.5))),
          ],
        ),
      );
}

/// The speaker line: what the app says aloud.
class SpokenLine extends StatelessWidget {
  SpokenLine(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Panel(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.volume_up_outlined, size: 22, color: C.green),
            const SizedBox(width: 10),
            Expanded(child: Text('“$text”', style: body(15, height: 1.5))),
          ],
        ),
      );
}

/// Date tile: big day number with a small label underneath.
class DateBlock extends StatelessWidget {
  DateBlock({super.key, required this.top, required this.bottom});
  final String top;
  final String bottom;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 46,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(top, style: display(20, height: 1)),
            const SizedBox(height: 2),
            Text(bottom, style: body(12, color: C.muted, height: 1.1), maxLines: 1, overflow: TextOverflow.clip),
          ],
        ),
      );
}

/// Visual details for each kind of stored thing.
class KindLook {
  KindLook(this.icon, this.fg, this.bg);
  final IconData icon;
  final Color fg;
  final Color bg;
}

KindLook vaultLook(VaultKind k) => switch (k) {
      VaultKind.website => KindLook(Icons.language_rounded, C.blue, C.blueTint),
      VaultKind.app => KindLook(Icons.apps_rounded, C.purple, C.purpleTint),
      VaultKind.wifi => KindLook(Icons.wifi_rounded, C.green, C.greenTint),
      VaultKind.bank => KindLook(Icons.account_balance_outlined, C.ochre, C.ochreTint),
      VaultKind.email => KindLook(Icons.alternate_email_rounded, C.orange, C.orangeTint),
      VaultKind.other => KindLook(Icons.key_rounded, C.muted2, C.line2),
    };

/// A row that opens something: leading, title, subtitle, trailing.
class ListRow extends StatelessWidget {
  ListRow({super.key, required this.leading, required this.title, this.subtitle, Color? subtitleColor, this.trailing, this.onTap, this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12)}) : _subtitleColor = subtitleColor;
  final Widget leading;
  final String title;
  final String? subtitle;
  final Color? _subtitleColor;
  Color get subtitleColor => _subtitleColor ?? C.muted;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: body(16, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(subtitle!, style: body(13, color: subtitleColor, weight: subtitleColor == C.muted ? FontWeight.w400 : FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      );
}

/// Shown when a list is empty.
class EmptyState extends StatelessWidget {
  EmptyState({super.key, required this.icon, required this.title, required this.text, this.action, this.onAction});
  final IconData icon;
  final String title;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: C.greenTint, shape: BoxShape.circle),
              child: Icon(icon, color: C.green, size: 30),
            ),
            const SizedBox(height: 12),
            Text(title, style: display(19), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(text, style: body(14, color: C.muted, height: 1.5), textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 14),
              SizedBox(width: 220, child: PrimaryButton(label: action!, onPressed: onAction, height: 48)),
            ],
          ],
        ),
      );
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String text, String? yes, bool danger = false}) async {
  yes ??= tr('হ্যাঁ');
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: display(20)),
      content: Text(text, style: body(15, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('না'), style: body(15, weight: FontWeight.w600, color: C.muted))),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text(yes!, style: body(15, weight: FontWeight.w600, color: danger ? C.red : C.green))),
      ],
    ),
  );
  return r ?? false;
}

/// Swiping across a tabbed page changes the tab: right to left is the next
/// tab, left to right the one before. The page follows the finger a little
/// while dragging, and the new tab slides in from the side it came from. At
/// the last (or first) tab the swipe goes on to the [SwipeSwitch] around this
/// one, so the inner tabs of a page lead into the bottom tabs.
class SwipeSwitch extends StatefulWidget {
  const SwipeSwitch({super.key, required this.onStep, required this.child, this.pageKey, this.gestures = true});

  /// For tabs listed in order: steps [value] through [values], with the
  /// slide between them.
  static SwipeSwitch tabs<T>({Key? key, required List<T> values, required T value, required ValueChanged<T> onChanged, required Widget child}) =>
      SwipeSwitch(
        key: key,
        pageKey: value,
        onStep: (step) {
          final i = values.indexOf(value) + step;
          if (i < 0 || i >= values.length) return false;
          onChanged(values[i]);
          return true;
        },
        child: child,
      );

  /// +1 for the next tab, -1 for the one before; false when there is none.
  final bool Function(int step) onStep;
  final Widget child;

  /// Which tab [child] shows: when it changes, the new one slides in.
  final Object? pageKey;

  /// False: only passes swipes on (the pages scroll by themselves).
  final bool gestures;

  @override
  State<SwipeSwitch> createState() => _SwipeSwitchState();
}

class _SwipeSwitchState extends State<SwipeSwitch> with SingleTickerProviderStateMixin {
  double _dx = 0;

  /// The page's offset while dragging (a fraction of the finger's way, so
  /// it feels held), springing back on release.
  late final _pull = AnimationController.unbounded(vsync: this);

  /// +1: the new tab comes from the right; -1: from the left.
  int _dir = 1;

  @override
  void didUpdateWidget(SwipeSwitch old) {
    super.didUpdateWidget(old);
    // A tab chosen by tapping: slide from the side it is on.
    if (old.pageKey != widget.pageKey && _pendingDir == null) _dir = 1;
    if (_pendingDir != null) {
      _dir = _pendingDir!;
      _pendingDir = null;
    }
  }

  int? _pendingDir;

  @override
  void dispose() {
    _pull.dispose();
    super.dispose();
  }

  /// Handled here (true) or by a SwipeSwitch around this one.
  bool _step(int step) {
    _pendingDir = step;
    if (widget.onStep(step)) return true;
    _pendingDir = null;
    return context.findAncestorStateOfType<_SwipeSwitchState>()?._step(step) ?? false;
  }

  void _release() => _pull.animateTo(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final page = widget.pageKey == null
        ? widget.child
        : AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, if (current != null) current]),
            transitionBuilder: (child, anim) {
              final incoming = child.key == ValueKey<Object?>(widget.pageKey);
              final from = Offset((incoming ? 0.22 : -0.22) * _dir, 0);
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(position: Tween<Offset>(begin: from, end: Offset.zero).animate(anim), child: child),
              );
            },
            child: KeyedSubtree(key: ValueKey<Object?>(widget.pageKey), child: widget.child),
          );
    final moving = AnimatedBuilder(
      animation: _pull,
      builder: (context, child) => Transform.translate(offset: Offset(_pull.value, 0), child: child),
      child: page,
    );
    if (!widget.gestures) return moving;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) {
        _dx = 0;
        _pull.stop();
      },
      onHorizontalDragUpdate: (d) {
        _dx += d.delta.dx;
        // Held: the page moves a third of the way, at most 72 px.
        _pull.value = (_dx / 3).clamp(-72.0, 72.0);
      },
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        _release();
        // A clear swipe: far enough, or quick enough.
        if (_dx.abs() < 70 && v.abs() < 600) return;
        _step((v.abs() >= 600 ? v : _dx) < 0 ? 1 : -1);
      },
      onHorizontalDragCancel: _release,
      child: moving,
    );
  }
}
