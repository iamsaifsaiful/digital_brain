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

Accent accentFor(String key) => accents.firstWhere((a) => a.key == key, orElse: () => accents.first);

/// Colours from the design canvas (v2: clean grey ground, white cards,
/// one accent colour, amber for money going out), with a dark set.
class C {
  /// Set by the app before building; screens read colours through [C].
  static bool dark = false;
  static Accent accent = accents.first;

  static Color _p(int light, int night) => Color(dark ? night : light);

  static Color get ground => _p(0xFFF6F7F9, 0xFF0E1013);
  static Color get surface => _p(0xFFFFFFFF, 0xFF1A1D22);
  static Color get ink => _p(0xFF111827, 0xFFE8EAED);
  static Color get muted => _p(0xFF6B7280, 0xFF9AA1AC);
  static Color get muted2 => _p(0xFF374151, 0xFFC4C9D1);
  static Color get line => _p(0xFFE5E7EB, 0xFF2B3038);
  static Color get line2 => _p(0xFFF1F2F4, 0xFF23272E);
  static Color get border => _p(0xFFE5E7EB, 0xFF2F343C);
  static Color get inputBorder => _p(0xFFD1D5DB, 0xFF3A404A);
  static Color get disabled => _p(0xFFE5E7EB, 0xFF2F343C);
  static Color get chip => _p(0xFFECEEF1, 0xFF262A31);

  /// A solid dark fill for buttons and cards with white text (dark in both looks).
  static Color get fill => _p(0xFF111827, 0xFF2E3440);

  /// Always dark (lock screen, alarm page).
  static const night = Color(0xFF111827);

  static Color get green => dark ? Color.lerp(accent.main, Colors.white, 0.18)! : accent.main;
  static Color get greenDark => dark ? Color.lerp(accent.main, Colors.white, 0.45)! : accent.dark;
  static Color get greenTint => dark ? accent.tintDark : accent.tint;
  static Color get greenSoft => dark ? Color.lerp(accent.tintDark, const Color(0xFF1A1D22), 0.5)! : Color.lerp(accent.tint, Colors.white, 0.45)!;

  static Color get orange => _p(0xFFB45309, 0xFFF59E0B);
  static Color get orangeDark => _p(0xFF92400E, 0xFFFBBF24);
  static Color get orangeTint => _p(0xFFFEF3E2, 0xFF3A2A12);

  static Color get blue => _p(0xFF1D4ED8, 0xFF7AA2F7);
  static Color get blueTint => _p(0xFFEEF2FF, 0xFF1B2440);
  static Color get blueText => _p(0xFF1E3A8A, 0xFFB4C6F5);

  static Color get purple => _p(0xFF6D28D9, 0xFFB79CF5);
  static Color get purpleTint => _p(0xFFF3EEFF, 0xFF2A2140);

  static Color get ochre => _p(0xFF92400E, 0xFFF0B060);
  static Color get ochreTint => _p(0xFFFEF7E6, 0xFF35291A);

  static Color get red => _p(0xFFB91C1C, 0xFFF87171);

  static Color get teal => _p(0xFF0F766E, 0xFF5EC9BC);
  static Color get tealTint => _p(0xFFE6F6F4, 0xFF15302D);
  static Color get rose => _p(0xFFBE123C, 0xFFFB7185);
  static Color get roseDark => _p(0xFF9F1239, 0xFFFDA4AF);
  static Color get roseTint => _p(0xFFFFF1F2, 0xFF3A1820);
  static Color get waTint => _p(0xFFE3F6EA, 0xFF14301F);
  static Color get soft => _p(0xFFF3F4F6, 0xFF262A31);

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
