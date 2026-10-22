import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import 'theme.dart';

/// Several rows picked at once (long-press a row to start, tap to add or
/// remove), so one action — done, delete, share… — goes to all of them.
class Picks extends ChangeNotifier {
  final Set<String> _ids = {};

  Set<String> get ids => Set.unmodifiable(_ids);
  bool get on => _ids.isNotEmpty;
  int get count => _ids.length;
  bool has(String id) => _ids.contains(id);

  void toggle(String id) {
    if (!_ids.remove(id)) _ids.add(id);
    notifyListeners();
  }

  /// All of [all] picked, or none if they already were.
  void toggleAll(Iterable<String> all) {
    final a = all.toSet();
    if (a.isNotEmpty && _ids.containsAll(a)) {
      _ids.removeAll(a);
    } else {
      _ids.addAll(a);
    }
    notifyListeners();
  }

  /// Keeps only ids that still exist (a row deleted elsewhere drops out).
  /// Silent: called while building.
  void keepOnly(Iterable<String> existing) => _ids.retainAll(existing.toSet());

  void clear() {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
  }
}

/// One thing to do with the picked rows.
class PickAction {
  const PickAction(this.icon, this.label, this.run, {this.danger = false});
  final IconData icon;
  final String label;
  final Future<void> Function() run;
  final bool danger;
}

/// The bar shown while rows are picked: how many, pick all, the actions, ✕.
class PickBar extends StatelessWidget {
  const PickBar({super.key, required this.picks, required this.all, required this.actions, this.note});
  final Picks picks;

  /// Every id on the page now (for "সব").
  final Iterable<String> all;
  final List<PickAction> actions;

  /// A line about the picked rows (e.g. their total).
  final String? note;

  @override
  Widget build(BuildContext context) {
    final allIds = all.toSet();
    final everything = allIds.isNotEmpty && picks.ids.containsAll(allIds);
    return Material(
      key: const Key('pick-bar'),
      color: C.surface,
      shape: Border(top: BorderSide(color: C.border)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconButton(key: const Key('pick-close'), tooltip: tr('বাছাই বাতিল'), onPressed: picks.clear, icon: Icon(Icons.close_rounded, color: C.ink)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(trf('{0}টা বাছাই', [bnDigits(picks.count)]), style: body(15.5, weight: FontWeight.w700)),
                  if (note != null && note!.isNotEmpty) Text(note!, style: body(12.5, color: C.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              TextButton(key: const Key('pick-all'), onPressed: () => picks.toggleAll(allIds), child: Text(everything ? tr('কোনোটা না') : tr('সব'))),
            ]),
            Row(children: [
              for (final a in actions)
                Expanded(
                  child: InkWell(
                    key: Key('pick-${a.label}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: a.run,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(a.icon, size: 23, color: a.danger ? C.red : C.ink),
                        const SizedBox(height: 3),
                        Text(a.label, style: body(12, weight: FontWeight.w600, color: a.danger ? C.red : C.ink), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// The leading mark on a picked / not-picked row.
class PickMark extends StatelessWidget {
  const PickMark(this.picked, {super.key});
  final bool picked;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Icon(picked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: picked ? C.green : C.muted, size: 26),
        ),
      );
}

/// "৩টা মুছে দিলাম" with a way to bring them all back.
void deletedSnack(ScaffoldMessengerState messenger, int n, Future<void> Function() undo) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(trf('{0}টা মুছে দিলাম — ৩০ দিন “মুছে ফেলা”-তে থাকবে', [bnDigits(n)])),
      persist: false,
      duration: const Duration(seconds: 6),
      action: SnackBarAction(label: tr('ফিরিয়ে আনুন'), onPressed: undo),
    ));
}
