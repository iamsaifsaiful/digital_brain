import 'package:flutter/material.dart';

import 'theme.dart';

/// Each খাত's own icon and colour (owner, 3 Nov: the approved হিসাব design),
/// quiet tones from the app's family, each with a brighter one for the dark look.
class CatStyle {
  const CatStyle(this.icon, this._light, this._dark);
  final IconData icon;
  final int _light;
  final int _dark;

  Color get color => Color(C.dark ? _dark : _light);

  /// The tile behind the icon.
  Color get tint => color.withValues(alpha: C.dark ? 0.18 : 0.10);
}

const _amber = (0xFFC2570C, 0xFFF0A36B);
const _rust = (0xFFB4533F, 0xFFEE9A86);
const _blue = (0xFF3D5F8A, 0xFF9DB7D6);
const _gold = (0xFF92631C, 0xFFE5C487);
const _violet = (0xFF6E5A9A, 0xFFBBA9E0);
const _brown = (0xFF8F3F08, 0xFFF2BB8E);
const _teal = (0xFF2C7A6B, 0xFF8FD3C3);
const _rose = (0xFFA8434A, 0xFFE99AA0);
const _olive = (0xFF5E7A2E, 0xFFB9D58A);
const _grey = (0xFF667871, 0xFFA3ADC6);

CatStyle _s(IconData i, (int, int) c) => CatStyle(i, c.$1, c.$2);

final _known = <String, CatStyle>{
  'বাজার': _s(Icons.shopping_cart_outlined, _amber),
  'খাবার': _s(Icons.restaurant_outlined, _rust),
  'যাতায়াত': _s(Icons.directions_bus_outlined, _blue),
  'বিল': _s(Icons.bolt_outlined, _gold),
  'মোবাইল': _s(Icons.smartphone_outlined, _violet),
  'বাসা ভাড়া': _s(Icons.home_outlined, _brown),
  'দোকান ভাড়া': _s(Icons.storefront_outlined, _brown),
  'চিকিৎসা': _s(Icons.medication_outlined, _teal),
  'শিক্ষা': _s(Icons.menu_book_outlined, _blue),
  'কেনাকাটা': _s(Icons.checkroom_outlined, _rose),
  'উপহার': _s(Icons.card_giftcard_outlined, _rose),
  'দান-সদকা': _s(Icons.volunteer_activism_outlined, _teal),
  'কিস্তি-লোন': _s(Icons.account_balance_outlined, _violet),
  'বেড়ানো': _s(Icons.luggage_outlined, _olive),
  'ব্যক্তিগত': _s(Icons.content_cut_rounded, _violet),
  'মজুরি': _s(Icons.engineering_outlined, _gold),
  'মাল কেনা': _s(Icons.inventory_2_outlined, _brown),
  'কৃষি': _s(Icons.agriculture_outlined, _olive),
  'পরিবারে পাঠানো': _s(Icons.family_restroom_outlined, _rose),
  'বেতন': _s(Icons.work_outline_rounded, _blue),
  'পেনশন': _s(Icons.elderly_outlined, _blue),
  'কাজের আয়': _s(Icons.laptop_outlined, _blue),
  'হাতখরচ': _s(Icons.payments_outlined, _teal),
  'রেমিট্যান্স': _s(Icons.public_rounded, _teal),
  'বিক্রি': _s(Icons.point_of_sale_outlined, _olive),
  'ভাড়া আয়': _s(Icons.key_outlined, _brown),
  'ব্যবসা': _s(Icons.trending_up_rounded, _olive),
};

const _cycle = [_amber, _blue, _teal, _violet, _gold, _rose, _olive, _rust];

/// The style of [category]: a known one, else a steady colour picked from its name.
CatStyle catStyle(String category) {
  final k = _known[category.trim()];
  if (k != null) return k;
  final h = category.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff);
  return _s(category.trim().isEmpty ? Icons.more_horiz_rounded : Icons.label_outline_rounded, category.trim().isEmpty ? _grey : _cycle[h % _cycle.length]);
}

/// The coloured square with a খাত's icon.
class CatIcon extends StatelessWidget {
  const CatIcon(this.category, {super.key, this.size = 40, this.filled = false});
  final String category;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final s = catStyle(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: filled ? s.color : s.tint, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(s.icon, size: size * 0.5, color: filled ? (C.dark ? const Color(0xFF14181F) : Colors.white) : s.color),
    );
  }
}
