import 'package:flutter/material.dart';

/// The app's look: light or dark, and the main accent colour. Chosen in
/// সেটিংস › চেহারা and read by [C] while the screens build.
enum Look { system, light, dark }

class Accent {
  const Accent(this.key, this.name, this.nameEn, this.main, this.dark, this.tint, this.tintDark);
  final String key;
  final String name;
  final String nameEn;
  final Color main;
  final Color dark;
  final Color tint;
  final Color tintDark;
}

const accents = [
  Accent('green', 'সবুজ', 'Green', Color(0xFF0E7A5F), Color(0xFF0A5C47), Color(0xFFE7F4EF), Color(0xFF12352C)),
  Accent('blue', 'নীল', 'Blue', Color(0xFF1D5FD8), Color(0xFF17459E), Color(0xFFE8F0FE), Color(0xFF15284A)),
  Accent('purple', 'বেগুনি', 'Purple', Color(0xFF6D3FD6), Color(0xFF4F2BA3), Color(0xFFF1ECFE), Color(0xFF2A1F4A)),
  Accent('teal', 'ফিরোজা', 'Teal', Color(0xFF0E7490), Color(0xFF0B5468), Color(0xFFE3F4F8), Color(0xFF113541)),
  Accent('rose', 'গোলাপি', 'Rose', Color(0xFFBE185D), Color(0xFF8E1246), Color(0xFFFCE8F1), Color(0xFF431628)),
  Accent('amber', 'কমলা', 'Amber', Color(0xFFC2570C), Color(0xFF8F3F08), Color(0xFFFEF0E2), Color(0xFF45260F)),
];

/// A preset ('green'…) or the user's own colour ('#1D5FD8').
Accent accentFor(String key) {
  if (key.startsWith('#') && key.length == 7) {
    final v = int.tryParse(key.substring(1), radix: 16);
    if (v != null) return customAccent(Color(0xFF000000 | v));
  }
  return accents.firstWhere((a) => a.key == key, orElse: () => accents.first);
}

/// An accent made from any colour: kept dark enough for white letters on it.
Accent customAccent(Color c) {
  var h = HSLColor.fromColor(c);
  if (h.lightness > 0.45) h = h.withLightness(0.45);
  if (h.lightness < 0.22) h = h.withLightness(0.22);
  if (h.saturation < 0.35) h = h.withSaturation(0.35);
  final main = h.toColor();
  final hex = (main.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  return Accent('#$hex', 'নিজের রং', 'Your colour', main, h.withLightness(h.lightness * 0.72).toColor(),
      h.withLightness(0.95).withSaturation(h.saturation * 0.7).toColor(), Color.alphaBlend(main.withValues(alpha: 0.24), const Color(0xFF161B22)));
}

/// The colour as saved ('#RRGGBB').
String colorKey(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Colours from the design canvas (v2: clean grey ground, white cards,
/// one accent colour, amber for money going out), with a dark set.
class C {
  /// Set by the app before building; screens read colours through [C].
  static bool dark = false;
  static Accent accent = accents.first;

  static Color _p(int light, int night) => Color(dark ? night : light);

  static Color get ground => _p(0xFFF6F7F9, 0xFF0B0F14);
  static Color get surface => _p(0xFFFFFFFF, 0xFF161B22);
  static Color get ink => _p(0xFF111827, 0xFFF0F3F6);
  static Color get muted => _p(0xFF6B7280, 0xFF9DA7B3);
  static Color get muted2 => _p(0xFF374151, 0xFFC9D1D9);
  static Color get line => _p(0xFFE5E7EB, 0xFF2A313C);
  static Color get line2 => _p(0xFFF1F2F4, 0xFF21262D);
  static Color get border => _p(0xFFE5E7EB, 0xFF30363D);
  static Color get inputBorder => _p(0xFFD1D5DB, 0xFF3D4550);
  static Color get disabled => _p(0xFFE5E7EB, 0xFF2F343C);
  static Color get chip => _p(0xFFECEEF1, 0xFF21262D);

  /// A solid dark fill for buttons and cards with white text (dark in both looks).
  static Color get fill => _p(0xFF111827, 0xFF2D333B);

  /// Always dark (lock screen, alarm page).
  static const night = Color(0xFF111827);

  /// In the dark look the accent glows: brighter and more saturated (not
  /// washed out with white), with white letters still readable on it.
  static Color get green => dark ? _glow(accent.main, 0.34) : accent.main;
  static Color get greenDark => dark ? _glow(accent.main, 0.74) : accent.dark;
  static Color get greenTint => dark ? Color.alphaBlend(_glow(accent.main, 0.45).withValues(alpha: 0.22), surface) : accent.tint;
  static Color get greenSoft => dark ? Color.alphaBlend(_glow(accent.main, 0.45).withValues(alpha: 0.12), surface) : Color.lerp(accent.tint, Colors.white, 0.45)!;

  static Color _glow(Color c, double lightness) {
    final h = HSLColor.fromColor(c);
    return h.withLightness(lightness).withSaturation((h.saturation * 1.15).clamp(0.0, 0.92)).toColor();
  }

  /// A colour's tint for its icon box: light in the light look, a glow over
  /// the card in the dark look.
  static Color _tint(int light, int night) => dark ? Color.alphaBlend(Color(night).withValues(alpha: 0.20), surface) : Color(light);

  // Category colours (24 Oct): calm, earthy versions, so pages read as one
  // quiet set rather than a rainbow.
  static Color get orange => _p(0xFFA85F1F, 0xFFE0A55C);
  static Color get orangeDark => _p(0xFF84481A, 0xFFF0C080);
  static Color get orangeTint => _tint(0xFFFBF1E4, 0xFFE0A55C);

  static Color get blue => _p(0xFF3D5F8A, 0xFF9DB7D6);
  static Color get blueTint => _tint(0xFFEDF1F6, 0xFF9DB7D6);
  static Color get blueText => _p(0xFF2A4466, 0xFFC5D3E4);

  static Color get purple => _p(0xFF6A5A8E, 0xFFB4A6D2);
  static Color get purpleTint => _tint(0xFFF0EDF5, 0xFFB4A6D2);

  static Color get ochre => _p(0xFF8A6420, 0xFFD9B56E);
  static Color get ochreTint => _tint(0xFFF6F0E3, 0xFFD9B56E);

  static Color get red => _p(0xFFB33A2B, 0xFFEE8670);

  static Color get teal => _p(0xFF2F6F67, 0xFF7FC4B8);
  static Color get tealTint => _tint(0xFFE7F0EE, 0xFF7FC4B8);
  static Color get rose => _p(0xFFA8434A, 0xFFE99AA0);
  static Color get roseDark => _p(0xFF8A333A, 0xFFF2BCC0);
  /// A rose fill that keeps white letters readable in both looks.
  static Color get roseFill => _p(0xFFA8434A, 0xFFC2554F);
  static Color get roseTint => _tint(0xFFF8EBEC, 0xFFE99AA0);
  static Color get waTint => _tint(0xFFE3F6EA, 0xFF34D399);
  static Color get soft => _p(0xFFF3F4F6, 0xFF1F252D);

  // On the dark surfaces (alarm page, Pro card).
  static const dark2 = Color(0xFF1F2937);
  static const onDarkMuted = Color(0xFFD1D5DB);

  /// Text on an [ink]-coloured fill (a selected chip, the user's bubble):
  /// white in the light look, dark in the dark look where [ink] is light.
  static Color get onInk => _p(0xFFFFFFFF, 0xFF111827);
  static Color get onInkMuted => _p(0xFFD1D5DB, 0xFF4B5563);
  static const mint = Color(0xFFA7F3D0);
  static const peach = Color(0xFFFDBA74);
  static const alarm = Color(0xFF0B3B30);
}

/// Noto Sans Bengali for Bengali (clear, familiar digits); Hind Siliguri
/// fills in English letters and punctuation that Noto's Bengali font lacks.
const bodyFont = 'NotoBengali';
const displayFont = 'NotoBengali';
const fontFallback = ['Hind'];

FontWeight _w(double weight) => weight >= 650 ? FontWeight.w700 : (weight >= 550 ? FontWeight.w600 : FontWeight.w500);

/// Headings and amounts.
TextStyle display(double size, {double weight = 600, Color? color, double? height}) =>
    TextStyle(fontFamily: displayFont, fontFamilyFallback: fontFallback, fontSize: size * textScale, height: height ?? 1.25, color: color ?? C.ink, fontWeight: _w(weight));

TextStyle body(double size, {FontWeight weight = FontWeight.w400, Color? color, double? height}) =>
    TextStyle(fontFamily: bodyFont, fontFamilyFallback: fontFallback, fontSize: size * textScale, fontWeight: weight, color: color ?? C.ink, height: height ?? 1.45);

/// Bigger letters (সেটিংস › লেখার আকার, and easy mode).
double textScale = 1.0;

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: bodyFont,
    fontFamilyFallback: fontFallback,
    scaffoldBackgroundColor: C.ground,
    brightness: C.dark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.green,
      brightness: C.dark ? Brightness.dark : Brightness.light,
      primary: C.green,
      onPrimary: Colors.white,
      surface: C.ground,
      onSurface: C.ink,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: bodyFont, fontFamilyFallback: fontFallback, bodyColor: C.ink, displayColor: C.ink),
    appBarTheme: AppBarTheme(backgroundColor: C.ground, foregroundColor: C.ink, elevation: 0, scrolledUnderElevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: body(15, color: C.muted),
      hintStyle: body(15, color: const Color(0xFF7D8681)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: C.inputBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: C.green, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.red, width: 2)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.fill,
      contentTextStyle: body(15, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(color: C.line2, thickness: 1, space: 1),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: C.surface, showDragHandle: true),
    dialogTheme: DialogThemeData(backgroundColor: C.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.green : null),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.green : null),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: C.surface,
      selectedColor: C.greenTint,
      side: BorderSide(color: C.line),
      shape: const StadiumBorder(),
      labelStyle: body(14, color: C.muted2),
      secondaryLabelStyle: body(14, color: C.greenDark, weight: FontWeight.w600),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.surface : C.chip),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.ink : C.muted2),
        side: WidgetStatePropertyAll(BorderSide(color: C.chip, width: 3)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    ),
  );
}
