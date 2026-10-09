import 'package:flutter/material.dart';

import '../models/models.dart';
import 'theme.dart';

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
  const Panel({super.key, required this.child, this.padding = EdgeInsets.zero, this.color = C.surface, this.borderColor = C.line, this.radius = 20});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
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
  const Avatar({super.key, required this.name, this.fg = C.green, this.bg = C.greenTint, this.size = 40, this.square = false});
  final String name;
  final Color fg;
  final Color bg;
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
  const Pill(this.text, {super.key, this.fg = C.greenDark, this.bg = C.greenTint});
  final String text;
  final Color fg;
  final Color bg;

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
            Expanded(child: Text(title, style: display(19))),
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
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.color = C.green, this.height = 56});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon, this.fg = C.ink, this.borderColor = C.border, this.height = 48});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color fg;
  final Color borderColor;
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
          color: dark ? C.ink : C.surface,
          shape: CircleBorder(side: BorderSide(color: dark ? C.ink : C.line)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22, color: dark ? Colors.white : C.ink)),
          ),
        ),
      );
}

/// Standard top bar: back button, title, optional trailing widgets.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.trailing = const [], this.close = false, this.onBack});
  final String title;
  final List<Widget> trailing;
  final bool close;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            RoundIconButton(
              icon: close ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
              tooltip: close ? 'বন্ধ করুন' : 'ফিরে যান',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: display(22), overflow: TextOverflow.ellipsis)),
            ...trailing,
          ],
        ),
      );
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
                Text(label, style: body(12, color: fromUser ? C.onDarkMuted : C.green, weight: fromUser ? FontWeight.w400 : FontWeight.w600)),
                const SizedBox(height: 2),
                Text('“$text”', style: body(17, color: fromUser ? Colors.white : C.ink)),
              ],
            ),
          ),
        ),
      );
}

/// Coloured note with an icon.
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.text, this.icon = Icons.verified_user_outlined, this.fg = C.blueText, this.iconColor = C.blue, this.bg = C.blueTint});
  final String text;
  final IconData icon;
  final Color fg;
  final Color iconColor;
  final Color bg;

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
  const SpokenLine(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Panel(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.volume_up_outlined, size: 22, color: C.green),
            const SizedBox(width: 10),
            Expanded(child: Text('“$text”', style: body(15, height: 1.5))),
          ],
        ),
      );
}

/// Date tile: big day number with a small label underneath.
class DateBlock extends StatelessWidget {
  const DateBlock({super.key, required this.top, required this.bottom});
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
  const KindLook(this.icon, this.fg, this.bg);
  final IconData icon;
  final Color fg;
  final Color bg;
}

KindLook vaultLook(VaultKind k) => switch (k) {
      VaultKind.website => const KindLook(Icons.language_rounded, C.blue, C.blueTint),
      VaultKind.app => const KindLook(Icons.apps_rounded, C.purple, C.purpleTint),
      VaultKind.wifi => const KindLook(Icons.wifi_rounded, C.green, C.greenTint),
      VaultKind.bank => const KindLook(Icons.account_balance_outlined, C.ochre, C.ochreTint),
      VaultKind.email => const KindLook(Icons.alternate_email_rounded, C.orange, C.orangeTint),
      VaultKind.other => const KindLook(Icons.key_rounded, C.muted2, C.line2),
    };

/// A row that opens something: leading, title, subtitle, trailing.
class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.leading, required this.title, this.subtitle, this.subtitleColor = C.muted, this.trailing, this.onTap, this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12)});
  final Widget leading;
  final String title;
  final String? subtitle;
  final Color subtitleColor;
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
  const EmptyState({super.key, required this.icon, required this.title, required this.text, this.action, this.onAction});
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
              decoration: const BoxDecoration(color: C.greenTint, shape: BoxShape.circle),
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

Future<bool> confirmDialog(BuildContext context, {required String title, required String text, String yes = 'হ্যাঁ', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: display(20)),
      content: Text(text, style: body(15, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text('না', style: body(15, weight: FontWeight.w600, color: C.muted))),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text(yes, style: body(15, weight: FontWeight.w600, color: danger ? C.red : C.green))),
      ],
    ),
  );
  return r ?? false;
}
