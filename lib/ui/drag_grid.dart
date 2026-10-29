// Tiles the member arranges by hand (owner, 29 Oct): hold a tile, drag it
// onto another place, let go. Used by the home's সব সুবিধা and the
// document folders. The order is kept by the caller (Brain.setOrder).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/theme.dart';

/// [items] in the [saved] order: the saved ones first as saved, then any not
/// in it (new ones) in their own order.
List<T> inOrder<T>(List<T> items, String Function(T) keyOf, List<String> saved) {
  if (saved.isEmpty) return items;
  final at = {for (final (i, k) in saved.indexed) k: i};
  final known = [for (final x in items) if (at.containsKey(keyOf(x))) x]..sort((a, b) => at[keyOf(a)]!.compareTo(at[keyOf(b)]!));
  return [...known, for (final x in items) if (!at.containsKey(keyOf(x))) x];
}

/// A grid of [columns] whose tiles move by long-press and drag. [trailing]
/// stays at the end and does not move (a "new folder" tile).
class DragGrid<T> extends StatefulWidget {
  const DragGrid({
    super.key,
    required this.items,
    required this.keyOf,
    required this.tile,
    required this.onReorder,
    this.columns = 4,
    this.spacing = 6,
    this.runSpacing = 4,
    this.tileHeight,
    this.aspect,
    this.trailing,
  });

  final List<T> items;
  final String Function(T) keyOf;
  final Widget Function(T item) tile;

  /// The new order of the keys, once a tile is let go.
  final void Function(List<String> keys) onReorder;
  final int columns;
  final double spacing, runSpacing;

  /// Fixed height for each tile (null: its own height).
  final double? tileHeight;

  /// Width ÷ height of each tile, when [tileHeight] is not given.
  final double? aspect;
  final Widget? trailing;

  @override
  State<DragGrid<T>> createState() => _DragGridState<T>();
}

class _DragGridState<T> extends State<DragGrid<T>> {
  /// While dragging: the order as it moves; otherwise null (the items' order).
  List<T>? _live;
  String? _dragging;

  List<T> get _shown => _live ?? widget.items;

  void _moveOnto(String from, String to) {
    if (from == to) return;
    final l = [..._shown];
    final i = l.indexWhere((x) => widget.keyOf(x) == from);
    final j = l.indexWhere((x) => widget.keyOf(x) == to);
    if (i < 0 || j < 0) return;
    final x = l.removeAt(i);
    l.insert(j, x);
    setState(() => _live = l);
  }

  void _end() {
    final l = _live;
    setState(() {
      _live = null;
      _dragging = null;
    });
    if (l != null) widget.onReorder([for (final x in l) widget.keyOf(x)]);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = (box.maxWidth - widget.spacing * (widget.columns - 1)) / widget.columns;
        final h = widget.tileHeight ?? (widget.aspect == null ? null : w / widget.aspect!);
        Widget sized(Widget c) => SizedBox(width: w, height: h, child: c);
        return Wrap(spacing: widget.spacing, runSpacing: widget.runSpacing, children: [
          for (final x in _shown)
            DragTarget<String>(
              key: ValueKey('drag-${widget.keyOf(x)}'),
              onWillAcceptWithDetails: (d) {
                _moveOnto(d.data, widget.keyOf(x));
                return true;
              },
              onAcceptWithDetails: (_) {},
              builder: (context, _, __) => LongPressDraggable<String>(
                data: widget.keyOf(x),
                hapticFeedbackOnStart: true,
                onDragStarted: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _dragging = widget.keyOf(x);
                    _live = [...widget.items];
                  });
                },
                onDragEnd: (_) => _end(),
                feedback: Material(
                  color: Colors.transparent,
                  child: Transform.scale(
                    scale: 1.08,
                    child: Container(
                      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 6))]),
                      child: sized(widget.tile(x)),
                    ),
                  ),
                ),
                childWhenDragging: sized(DecoratedBox(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: C.green.withValues(alpha: 0.5), width: 1.5)),
                  child: Opacity(opacity: 0.25, child: widget.tile(x)),
                )),
                child: sized(Opacity(opacity: _dragging == widget.keyOf(x) ? 0.25 : 1, child: widget.tile(x))),
              ),
            ),
          if (widget.trailing != null) sized(widget.trailing!),
        ]);
      });
}
