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
  // The new look (24 Oct): a deep green-black for fills and selections;
  // money in and success stay the green below ([C.green]).
  Accent('forest', 'গাঢ় সবুজ', 'Deep green', Color(0xFF1F2A27), Color(0xFF141C19), Color(0xFFE7ECE9), Color(0xFF1D2925)),
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

  // The new look (24 Oct, docs/design/2026-10-24-new-ui): warm paper,
  // white cards with soft shadows, a deep green-black accent.
  static Color get ground => _p(0xFFF3F2EE, 0xFF0F1312);
  static Color get surface => _p(0xFFFFFFFF, 0xFF181D1B);
  static Color get ink => _p(0xFF17191A, 0xFFEEF1EF);
  static Color get muted => _p(0xFF8C8C87, 0xFF8E9893);
  static Color get muted2 => _p(0xFF3B3F3E, 0xFFC9D1CD);
  static Color get line => _p(0xFFECEAE5, 0xFF262D2A);
  static Color get line2 => _p(0xFFF0EEE9, 0xFF222826);
  static Color get border => _p(0xFFE6E4DF, 0xFF2C3330);
  static Color get inputBorder => _p(0xFFDAD8D2, 0xFF39413D);
  static Color get disabled => _p(0xFFE6E4DF, 0xFF2A302D);
  static Color get chip => _p(0xFFE9E7E2, 0xFF212826);

  /// The accent the user chose (the deep green-black by default): primary
  /// buttons, selected days and chips, toggles, dark cards.
  static Color get primary => accent.key == 'forest' ? (dark ? const Color(0xFF3DBE8B) : accent.main) : green;

  /// Text on [primary].
  static Color get onPrimary => accent.key == 'forest' && dark ? const Color(0xFF0F1312) : Colors.white;

  /// A solid dark fill for buttons and cards with white text (dark in both looks).
  static Color get fill => accent.key == 'forest' ? _p(0xFF1F2A27, 0xFF22302B) : _p(0xFF111827, 0xFF2D333B);

  /// The dark cards' edge in the dark look.
  static Color get fillEdge => _p(0x00000000, 0xFF2E3D37);

  /// The floating button.
  static Color get fab => accent.key == 'forest' ? _p(0xFF2E3B37, 0xFF2E3D37) : green;

  /// Always dark (lock screen, alarm page).
  static const night = Color(0xFF111827);

  /// In the dark look the accent glows: brighter and more saturated (not
  /// washed out with white), with white letters still readable on it.
  /// With the deep green-black accent, [green] is the green of money in and
  /// of success.
  static Color get _g => accent.key == 'forest' ? const Color(0xFF0E7A5F) : accent.main;
  static Color get _gDark => accent.key == 'forest' ? const Color(0xFF0A5C47) : accent.dark;
  static Color get _gTint => accent.key == 'forest' ? const Color(0xFFE7EFEA) : accent.tint;
  static Color get green => dark ? _glow(_g, 0.34) : _g;
  static Color get greenDark => dark ? _glow(_g, 0.74) : (accent.key == 'forest' ? const Color(0xFF2F6B53) : _gDark);
  static Color get greenTint => dark ? Color.alphaBlend(_glow(_g, 0.45).withValues(alpha: 0.22), surface) : _gTint;
  static Color get greenSoft => dark ? Color.alphaBlend(_glow(_g, 0.45).withValues(alpha: 0.12), surface) : Color.lerp(_gTint, Colors.white, 0.45)!;

  // Warnings ("soon", expiry, what I owe) and danger (blood, emergency, the now-line).
  static Color get warn => _p(0xFF9A5F1E, 0xFFE0A55C);
  static Color get warnTint => _p(0xFFFBF1E3, 0xFF33281A);
  static Color get danger => _p(0xFFB2412E, 0xFFEE8670);
  static Color get dangerTint => _p(0xFFFBE7E3, 0xFF3A1E1A);
  static Color get nowLine => _p(0xFFD2553E, 0xFFEE8670);
  static Color get sun => const Color(0xFFE9A23B);

  /// Card shadow (light look only).
  static List<BoxShadow> get shadow => dark ? const [] : const [BoxShadow(color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 1))];

  static Color _glow(Color c, double lightness) {
    final h = HSLColor.fromColor(c);
    return h.withLightness(lightness).withSaturation((h.saturation * 1.15).clamp(0.0, 0.92)).toColor();
  }

  /// A colour's tint for its icon box: light in the light look, a glow over
  /// the card in the dark look.
  static Color _tint(int light, int night) => dark ? Color.alphaBlend(Color(night).withValues(alpha: 0.20), surface) : Color(light);

  // The category colours. With the deep green-black accent (24 Oct look)
  // they are calm, earthy versions, so a page reads as one quiet set.
  static bool get _calm => accent.key == 'forest';
  static Color _c(int calmLight, int calmNight, int light, int night) => _calm ? _p(calmLight, calmNight) : _p(light, night);
  static Color _ct(int calmLight, int calmNight, int light, int night) => _calm ? _tint(calmLight, calmNight) : _tint(light, night);

  static Color get orange => _c(0xFFB06A2C, 0xFFE0A55C, 0xFFB45309, 0xFFF59E0B);
  static Color get orangeDark => _c(0xFF8A4F1D, 0xFFF0C080, 0xFF92400E, 0xFFFBBF24);
  static Color get orangeTint => _ct(0xFFF7EEE3, 0xFFE0A55C, 0xFFFEF3E2, 0xFFF59E0B);

  static Color get blue => _c(0xFF466377, 0xFF9DB7C9, 0xFF1D4ED8, 0xFF60A5FA);
  static Color get blueTint => _ct(0xFFEBEFF1, 0xFF9DB7C9, 0xFFEEF2FF, 0xFF60A5FA);
  static Color get blueText => _c(0xFF2E4453, 0xFFC5D3DD, 0xFF1E3A8A, 0xFFB4C6F5);

  static Color get purple => _c(0xFF6E5C80, 0xFFB9A8CC, 0xFF6D28D9, 0xFFA78BFA);
  static Color get purpleTint => _ct(0xFFEFEBF2, 0xFFB9A8CC, 0xFFF3EEFF, 0xFFA78BFA);

  static Color get ochre => _c(0xFF8A6A2E, 0xFFD9B56E, 0xFF92400E, 0xFFF0B060);
  static Color get ochreTint => _ct(0xFFF5F0E4, 0xFFD9B56E, 0xFFFEF7E6, 0xFFF0B060);

  static Color get red => _c(0xFFB2412E, 0xFFEE8670, 0xFFB91C1C, 0xFFF87171);

  static Color get teal => _c(0xFF3F6F66, 0xFF8CC2B6, 0xFF0F766E, 0xFF2DD4BF);
  static Color get tealTint => _ct(0xFFE6EEEB, 0xFF8CC2B6, 0xFFE6F6F4, 0xFF2DD4BF);
  static Color get rose => _c(0xFFA84B48, 0xFFE99A94, 0xFFBE123C, 0xFFFB7185);
  static Color get roseDark => _c(0xFF8A3A37, 0xFFF2B8B3, 0xFF9F1239, 0xFFFDA4AF);
  /// A rose fill that keeps white letters readable in both looks.
  static Color get roseFill => _c(0xFFB2412E, 0xFFC2554F, 0xFFBE123C, 0xFFE11D48);
  static Color get roseTint => _ct(0xFFF6E9E7, 0xFFE99A94, 0xFFFFF1F2, 0xFFFB7185);
  static Color get waTint => _tint(0xFFE3F6EA, 0xFF34D399);
  static Color get soft => _p(0xFFF6F5F2, 0xFF212826);

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

/// Page titles, the greeting and section titles (the new look): Hind
/// Siliguri, bold. Amounts stay in [display] (Noto's digits).
TextStyle heading(double size, {double weight = 700, Color? color, double? height}) =>
    TextStyle(fontFamily: 'Hind', fontFamilyFallback: const ['NotoBengali'], fontSize: size * textScale, height: height ?? 1.2, color: color ?? C.ink, fontWeight: _w(weight));

/// The small hand-written notes (Galada).
TextStyle hand(double size, {Color? color}) =>
    TextStyle(fontFamily: 'Galada', fontFamilyFallback: const ['Hind', 'NotoBengali'], fontSize: size * textScale, height: 1.2, color: color ?? C.muted2);

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
      seedColor: C.primary,
      brightness: C.dark ? Brightness.dark : Brightness.light,
      primary: C.primary,
      onPrimary: C.onPrimary,
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
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: C.inputBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: C.primary, width: 2)),
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
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.onPrimary : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.primary : null),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.primary : null),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: C.surface,
      selectedColor: C.primary,
      side: BorderSide(color: C.line),
      shape: const StadiumBorder(),
      labelStyle: body(14, color: C.muted2),
      secondaryLabelStyle: body(14, color: C.onPrimary, weight: FontWeight.w600),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.surface : C.chip),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.ink : C.muted2),
        side: WidgetStatePropertyAll(BorderSide(color: C.chip, width: 3)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ),
    ),
  );
}
