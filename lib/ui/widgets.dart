import '../logic/services_list.dart' show KnownService;
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
  const Panel({super.key, required this.child, this.padding = EdgeInsets.zero, Color? color, Color? borderColor, this.radius = 17})
      : _color = color,
        _borderColor = borderColor;
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
  const Avatar({super.key, required this.name, Color? fg, Color? bg, this.size = 40, this.square = false})
      : _fg = fg,
        _bg = bg;
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
  const Pill(this.text, {super.key, Color? fg, Color? bg})
      : _fg = fg,
        _bg = bg;
  final String text;
  final Color? _fg;
  Color get fg => _fg ?? C.greenDark;
  final Color? _bg;
  Color get bg => _bg ?? C.greenTint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
        child: Text(text, style: body(12, weight: FontWeight.w600, color: fg)),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        // Space above too, so a heading never sits on the card before it.
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text(title, style: display(17, weight: 600))),
              if (action != null)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onAction,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(action!, style: body(12.5, weight: FontWeight.w600, color: C.green)),
                      Icon(Icons.chevron_right_rounded, size: 17, color: C.green),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, Color? color, this.height = 50}) : _color = color;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? _color;
  Color get color => _color ?? C.green;
  final double height;

  @override
  Widget build(BuildContext context) {
    // The old dark "second" button is the design's outlined one now.
    if (_color != null && _color == C.fill) {
      return SecondaryButton(label: label, onPressed: onPressed, icon: icon, height: height);
    }
    return _filled();
  }

  Widget _filled() => SizedBox(
        height: height,
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: _color == null ? C.onAccent : Colors.white,
            disabledBackgroundColor: C.disabled,
            disabledForegroundColor: C.muted,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Flexible(child: Text(label, style: body(15.5, weight: FontWeight.w600, color: onPressed == null ? C.muted : (_color == null ? C.onAccent : Colors.white)), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      );
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon, Color? fg, Color? borderColor, this.height = 48})
      : _fg = fg,
        _borderColor = borderColor;
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
              Flexible(child: Text(label, style: body(14, weight: FontWeight.w500, color: fg), overflow: TextOverflow.ellipsis)),
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
        // Plain (no box); the main action of a page ([dark]) is the accent square.
        child: Material(
          color: dark ? C.green : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22, color: dark ? C.onAccent : C.ink)),
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
            Expanded(child: Text(title, style: display(21, weight: 600), overflow: TextOverflow.ellipsis)),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: display(25, weight: 600, height: 1.3)),
              if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13.5, color: C.muted))),
            ]),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

/// Grey pill with 2–4 choices; the chosen one is white (iOS-style tabs).
class SegTabs<T> extends StatelessWidget {
  const SegTabs({super.key, required this.items, required this.value, required this.onChanged, this.pages});
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;

  /// The pages under these tabs ([TabPages]): the thumb follows the finger
  /// while they are dragged, not only after.
  final PageController? pages;

  @override
  Widget build(BuildContext context) {
    final p = pages;
    if (p == null) return _build(items.indexWhere((x) => x.$1 == value).toDouble(), animate: true);
    return AnimatedBuilder(
      animation: p,
      builder: (context, _) {
        final at = p.hasClients && p.position.haveDimensions ? (p.page ?? 0) : items.indexWhere((x) => x.$1 == value).toDouble();
        return _build(at.clamp(0, (items.length - 1).toDouble()).toDouble(), animate: false);
      },
    );
  }

  Widget _build(double at, {required bool animate}) {
    final align = Alignment(items.length == 1 ? 0 : -1 + 2 * at / (items.length - 1), 0);
    final thumb = FractionallySizedBox(
      widthFactor: 1 / items.length,
      heightFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(9), border: Border.all(color: C.border)),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(11)),
      child: SizedBox(
        height: 38,
        child: Stack(children: [
          // The white thumb glides to the chosen tab (with the finger, on pages).
          if (at >= 0) animate ? AnimatedAlign(duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic, alignment: align, child: thumb) : Align(alignment: align, child: thumb),
          Row(children: [
            for (final (i, (v, label)) in items.indexed)
              Expanded(
                child: Semantics(
                  selected: v == value,
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(v),
                    child: Center(
                      child: animate
                          ? AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: body(13, weight: v == value ? FontWeight.w600 : FontWeight.w400, color: v == value ? C.ink : C.muted),
                              child: Text(label, maxLines: 1),
                            )
                          : Text(label,
                              maxLines: 1,
                              style: body(13, weight: (at - i).abs() < 0.5 ? FontWeight.w600 : FontWeight.w400, color: Color.lerp(C.ink, C.muted, (at - i).abs().clamp(0.0, 1.0).toDouble()))),
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

/// Swiping left or right over [child] moves to the next or previous of
/// [items] — for tabs whose content is not its own page ([TabPages] slides
/// with the finger; this switches on a flick).
class SwipeTabs<T> extends StatelessWidget {
  const SwipeTabs({super.key, required this.items, required this.value, required this.onChanged, required this.child});
  final List<T> items;
  final T value;
  final ValueChanged<T> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() < 250) return;
          final i = items.indexOf(value) + (v < 0 ? 1 : -1);
          if (i >= 0 && i < items.length) onChanged(items[i]);
        },
        child: child,
      );
}

/// Tabs over pages that follow the finger: the page beside slides in as
/// it is dragged (and the tabs' thumb with it), like the bottom menu.
/// [top] is what scrolls away above (a title, tools) with the tabs placed
/// in it; each tab's [page] is its own up-down list. Dragged past the first
/// or last tab, the bottom menu's tab changes instead.
class TabPages<T> extends StatefulWidget {
  const TabPages({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.top,
    required this.page,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 28),
    this.tabsPadding = const EdgeInsets.fromLTRB(20, 4, 20, 8),
  });
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;

  /// The children above the pages, scrolling away; [tabs] is the tab row,
  /// to be placed among them. Null: the tabs stay put above the pages.
  final List<Widget> Function(Widget tabs)? top;

  /// Around the tabs when they stay put ([top] null).
  final EdgeInsets tabsPadding;
  final List<Widget> Function(T value) page;
  final EdgeInsets padding;

  @override
  State<TabPages<T>> createState() => _TabPagesState<T>();
}

class _TabPagesState<T> extends State<TabPages<T>> {
  late final PageController _pages = PageController(initialPage: _index(widget.value));
  double _over = 0;

  int _index(T v) => widget.items.indexWhere((x) => x.$1 == v).clamp(0, widget.items.length - 1);

  @override
  void didUpdateWidget(TabPages<T> old) {
    super.didUpdateWidget(old);
    // Chosen from outside (a tap on the tabs, a link): slide there.
    final i = _index(widget.value);
    if (_pages.hasClients && (_pages.page ?? i.toDouble()).round() != i) {
      _pages.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool _edge(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.horizontal) return false;
    if (n is ScrollStartNotification) _over = 0;
    if (n is OverscrollNotification) _over += n.overscroll;
    if (n is ScrollEndNotification) {
      // Pulled on past the first or last tab: the bottom menu's tab beside.
      if (_over.abs() > 24) context.findAncestorStateOfType<_SwipeSwitchState>()?._step(_over > 0 ? 1 : -1);
      _over = 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = SegTabs<T>(
        items: widget.items,
        value: widget.value,
        pages: _pages,
        onChanged: (v) {
          widget.onChanged(v);
          _pages.animateToPage(_index(v), duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
        });
    final pad = widget.padding;
    final top = widget.top;
    Widget pages({required bool nested}) => NotificationListener<ScrollNotification>(
          onNotification: _edge,
          child: PageView(
            controller: _pages,
            onPageChanged: (i) {
              if (widget.items[i].$1 != widget.value) widget.onChanged(widget.items[i].$1);
            },
            children: [
              for (final (v, _) in widget.items)
                _KeepPage(
                  child: ListView(
                    key: PageStorageKey<Object?>('tab-$v'),
                    primary: nested ? true : null,
                    padding: EdgeInsets.fromLTRB(pad.left, nested ? 0 : pad.top, pad.right, pad.bottom),
                    children: widget.page(v),
                  ),
                ),
            ],
          ),
        );
    if (top == null) {
      return Column(children: [
        Padding(padding: widget.tabsPadding, child: tabs),
        Expanded(child: pages(nested: false)),
      ]);
    }
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 0),
          sliver: SliverList(delegate: SliverChildListDelegate(top(tabs))),
        ),
      ],
      body: pages(nested: true),
    );
  }
}

/// A tab's page stays as it was (scroll place, open parts) while another is shown.
class _KeepPage extends StatefulWidget {
  const _KeepPage({required this.child});
  final Widget child;
  @override
  State<_KeepPage> createState() => _KeepPageState();
}

class _KeepPageState extends State<_KeepPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
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
        backgroundColor: C.green,
        foregroundColor: C.onAccent,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        icon: Icon(icon),
        label: Text(label, style: body(14.5, weight: FontWeight.w600, color: C.onAccent)),
      );
}

/// Small round button (call, SMS, WhatsApp…).
class CircleAction extends StatelessWidget {
  const CircleAction({super.key, required this.icon, required this.tooltip, required this.onPressed, Color? fg, Color? bg, this.size = 40})
      : _fg = fg,
        _bg = bg;
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
  const InfoBanner({super.key, required this.text, this.icon = Icons.verified_user_outlined, Color? fg, Color? iconColor, Color? bg})
      : _fg = fg,
        _iconColor = iconColor,
        _bg = bg;
  final String text;
  final IconData icon;
  final Color? _fg;
  Color get fg => _fg ?? C.muted2;
  final Color? _iconColor;
  Color get iconColor => _iconColor ?? C.green;
  final Color? _bg;
  Color get bg => _bg ?? C.greenTint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: iconColor),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: body(13, color: fg, height: 1.5))),
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
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 46,
        decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(top, style: body(17, weight: FontWeight.w700, height: 1.1)),
            Text(bottom, style: body(10.5, color: C.muted, height: 1.2), maxLines: 1, overflow: TextOverflow.clip),
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
  ListRow(
      {super.key,
      required this.leading,
      required this.title,
      this.subtitle,
      Color? subtitleColor,
      this.trailing,
      this.onTap,
      this.onLongPress,
      this.picked = false,
      this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10)})
      : _subtitleColor = subtitleColor;
  final Widget leading;
  final String title;
  final String? subtitle;
  final Color? _subtitleColor;
  Color get subtitleColor => _subtitleColor ?? C.muted;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Starts picking several rows (see lib/ui/pick.dart).
  final VoidCallback? onLongPress;

  /// Shown as picked (tinted).
  final bool picked;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          color: picked ? C.greenTint : null,
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
                      Text(title, style: body(14.5, weight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(subtitle!, style: body(12, color: subtitleColor, weight: subtitleColor == C.muted ? FontWeight.w400 : FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
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
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(17)),
              child: Icon(icon, color: C.green, size: 26),
            ),
            const SizedBox(height: 12),
            Text(title, style: display(17), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(text, style: body(13.5, color: C.muted, height: 1.5), textAlign: TextAlign.center),
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
  static SwipeSwitch tabs<T>({Key? key, required List<T> values, required T value, required ValueChanged<T> onChanged, required Widget child}) => SwipeSwitch(
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

/// Every bottom sheet in the app: like [showModalBottomSheet], but its
/// content stays above the phone's own buttons and gesture bar (Android now
/// draws apps under them), so a sheet's last button is never covered.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool? showDragHandle,
  bool useSafeArea = false,
  Color? backgroundColor,
  ShapeBorder? shape,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      useSafeArea: useSafeArea,
      backgroundColor: backgroundColor,
      shape: shape,
      builder: (ctx) => SafeArea(top: false, child: builder(ctx)),
    );


/// A known app or site as a letter on its colour (not the company's logo).
class ServiceBadge extends StatelessWidget {
  const ServiceBadge({super.key, required this.service, this.size = 40});
  final KnownService service;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: service.color, borderRadius: BorderRadius.circular(size * 0.3)),
        child: Text(service.letter, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.5, height: 1)),
      );
}
