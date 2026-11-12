import 'package:flutter/material.dart';

/// The app's look: light or dark, and the main accent colour. Chosen in
/// সেটিংস › চেহারা and read by [C] while the screens build.
/// [sun]: light by day, dark by night, changing once at dusk and dawn
/// while the home picture changes slowly (owner, 25–26 Oct) — the default.
enum Look { sun, system, light, dark }

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
  Accent('green', 'সবুজ', 'Green', Color(0xFF087866), Color(0xFF06594C), Color(0xFFE7F3EE), Color(0xFF223C31)),
  Accent('blue', 'নীল', 'Blue', Color(0xFF1D5FD8), Color(0xFF17459E), Color(0xFFE8F0FE), Color(0xFF15284A)),
  Accent('purple', 'বেগুনি', 'Purple', Color(0xFF6D3FD6), Color(0xFF4F2BA3), Color(0xFFF1ECFE), Color(0xFF2A1F4A)),
  // The owner's pick (7 Nov), the default since: #13718A.
  Accent('teal', 'ফিরোজা', 'Teal', Color(0xFF13718A), Color(0xFF0E5567), Color(0xFFE3F3F6), Color(0xFF123541)),
  Accent('rose', 'গোলাপি', 'Rose', Color(0xFFBE185D), Color(0xFF8E1246), Color(0xFFFCE8F1), Color(0xFF431628)),
  Accent('amber', 'কমলা', 'Amber', Color(0xFFC2570C), Color(0xFF8F3F08), Color(0xFFFEF0E2), Color(0xFF45260F)),
];

/// A preset ('green'…) or the user's own colour ('#1D5FD8').
/// The colour the app starts with.
const defaultAccentKey = 'teal';

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
      h.withLightness(0.95).withSaturation(h.saturation * 0.7).toColor(), Color.alphaBlend(main.withValues(alpha: 0.24), const Color(0xFF1A2342)));
}

/// The dark look's own colours (owner, 4 Nov: the user picks, dark ones
/// only). Every set keeps light letters readable on its ground and cards.
class DarkSet {
  const DarkSet(this.key, this.name, this.nameEn, this.ground, this.surface, this.surface2, this.line, this.input, this.disabled, this.fill, this.muted, this.muted2);
  final String key;
  final String name;
  final String nameEn;
  final Color ground;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color input;
  final Color disabled;
  final Color fill;
  final Color muted;
  final Color muted2;
}

const darkSets = [
  DarkSet('night', 'রাতের নীল', 'Night blue', Color(0xFF121A33), Color(0xFF1A2342), Color(0xFF242E50), Color(0xFF2E3859), Color(0xFF3A456A), Color(0xFF283252), Color(0xFF2A3558), Color(0xFFA3ADC6), Color(0xFFC7CEE0)),
  DarkSet('black', 'কালো', 'Black', Color(0xFF0A0A0C), Color(0xFF16161A), Color(0xFF212126), Color(0xFF2C2C33), Color(0xFF3A3A43), Color(0xFF242429), Color(0xFF2A2A31), Color(0xFFA6A6B0), Color(0xFFD4D4DA)),
  DarkSet('forest', 'গাঢ় সবুজ', 'Forest', Color(0xFF0D1915), Color(0xFF14231E), Color(0xFF1D2F28), Color(0xFF293D36), Color(0xFF354F46), Color(0xFF21332C), Color(0xFF24382F), Color(0xFF9EB5AC), Color(0xFFC8D7D1)),
  DarkSet('coffee', 'কফি', 'Coffee', Color(0xFF191311), Color(0xFF231B17), Color(0xFF2E2520), Color(0xFF3C312A), Color(0xFF4A3D35), Color(0xFF2B221D), Color(0xFF332822), Color(0xFFB6A89D), Color(0xFFDDD2C8)),
  DarkSet('plum', 'গাঢ় বেগুনি', 'Plum', Color(0xFF181225), Color(0xFF221932), Color(0xFF2D2241), Color(0xFF3A2E51), Color(0xFF493B63), Color(0xFF2A203F), Color(0xFF322749), Color(0xFFB4A9C9), Color(0xFFD9D1E7)),
  DarkSet('slate', 'স্লেট', 'Slate', Color(0xFF14171C), Color(0xFF1C2027), Color(0xFF262B34), Color(0xFF323843), Color(0xFF3F4655), Color(0xFF242932), Color(0xFF2B313B), Color(0xFFA4ACB9), Color(0xFFCED4DE)),
];

DarkSet darkSetFor(String key) => darkSets.firstWhere((d) => d.key == key, orElse: () => darkSets.first);

/// The colour as saved ('#RRGGBB').
String colorKey(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Colours of the approved home design (24 Oct, docs/design/2026-10-24-home-final):
/// a calm green-grey ground, white cards with a 1 px hairline and no
/// shadow, one accent, a warm amber for attention; and the dark set, a
/// deep night blue (owner, 24 Oct) with the mint accent.
/// Old names stay and point at the new tokens.
class C {
  /// Set by the app before building; screens read colours through [C].
  /// [mix] is how far towards the dark set (0 light … 1 dark); [dark] is
  /// true from half way (bars, the platform brightness).
  static bool dark = false;
  static double mix = 0;
  /// The default (owner, 7 Nov: "কমলা রং এর পরিবর্তে" the teal of his screenshot).
  static Accent accent = accentFor(defaultAccentKey);
  static DarkSet darkSet = darkSets.first;
  static Color _pd(int light, Color night) => mix <= 0 ? Color(light) : (mix >= 1 ? night : Color.lerp(Color(light), night, mix)!);
  static Color _fd(int light, Color night) => mix < 0.5 ? Color(light) : night;

  static Color _p(int light, int night) => mix <= 0 ? Color(light) : (mix >= 1 ? Color(night) : Color.lerp(Color(light), Color(night), mix)!);

  /// Letters and marks: never a washed in-between grey — the light set's
  /// until half way, the dark set's after (the ground under them never
  /// stops in the middle either, see `duskMix`).
  static Color _f(int light, int night) => Color(mix < 0.5 ? light : night);
  static Color _mix(Color light, Color night) => mix <= 0 ? light : (mix >= 1 ? night : Color.lerp(light, night, mix)!);

  /// bg: the screen.
  static Color get ground => _pd(0xFFF5F7F6, darkSet.ground);
  static Color get surface => _pd(0xFFFFFFFF, darkSet.surface);

  /// surface2: counters, date blocks, quiet chips, the tabs' track.
  static Color get surface2 => _pd(0xFFEDF2F0, darkSet.surface2);
  static Color get ink => _f(0xFF192E28, 0xFFEEF1F8);
  static Color get muted => _fd(0xFF667871, darkSet.muted);
  static Color get muted2 => _fd(0xFF3E524B, darkSet.muted2);
  static Color get line => _pd(0xFFDFE7E3, darkSet.line);
  static Color get line2 => _pd(0xFFDFE7E3, darkSet.line);
  static Color get border => _pd(0xFFDFE7E3, darkSet.line);
  static Color get inputBorder => _pd(0xFFD3DED9, darkSet.input);
  static Color get disabled => _pd(0xFFE3E9E6, darkSet.disabled);
  static Color get chip => surface2;

  /// Attention (late, may-not-ring, money to give).
  static Color get warn => _f(0xFF92631C, 0xFFE5C487);
  static Color get warnBg => _p(0xFFFBF5E9, 0xFF2A2732);
  static Color get warnBorder => _p(0xFFEBDFC5, 0xFF4A4232);

  /// A solid dark fill for buttons and cards with white text (dark in both looks).
  static Color get fill => _pd(0xFF192E28, darkSet.fill);

  /// Always dark (lock screen, alarm page).
  static const night = Color(0xFF111827);

  /// In the dark look the accent glows: brighter and more saturated (not
  /// washed out with white), with white letters still readable on it.
  /// accent; in the dark look a light glow (mint for the default green)
  /// with dark letters on it ([onAccent]).
  static Color get green => mix < 0.5 ? accent.main : (accent.key == 'green' ? const Color(0xFF8BD8BF) : _glow(accent.main, 0.72));
  static Color get greenDark => mix < 0.5 ? accent.dark : (accent.key == 'green' ? const Color(0xFFA9E6D2) : _glow(accent.main, 0.82));

  /// accentSoft: icon tiles, the active tab's pill, soft chips.
  static Color get greenTint => _mix(accent.tint, accent.key == 'green' && darkSet.key == 'night' ? const Color(0xFF1F3B47) : Color.alphaBlend(_glow(accent.main, 0.45).withValues(alpha: 0.22), surface));
  static Color get greenSoft => _mix(Color.lerp(accent.tint, Colors.white, 0.45)!, Color.alphaBlend(_glow(accent.main, 0.45).withValues(alpha: 0.12), surface));

  /// Letters and icons on the accent: dark on a light fill, white on a deep
  /// one (decided by the fill itself, so it stays readable while it changes).
  static Color get onAccent => _readableOn(green, const Color(0xFF102C21), Colors.white);

  /// Of [a] and [b], the one that reads better on [bg] (higher contrast).
  static Color _readableOn(Color bg, Color a, Color b) {
    double c(Color x) {
      final l1 = bg.computeLuminance() + 0.05, l2 = x.computeLuminance() + 0.05;
      return l1 > l2 ? l1 / l2 : l2 / l1;
    }

    return c(a) >= c(b) ? a : b;
  }

  // Short names from the design.
  static Color get accentC => green;
  static Color get accentSoft => greenTint;

  static Color _glow(Color c, double lightness) {
    final h = HSLColor.fromColor(c);
    return h.withLightness(lightness).withSaturation((h.saturation * 1.15).clamp(0.0, 0.92)).toColor();
  }

  /// A colour's tint for its icon box: light in the light look, a glow over
  /// the card in the dark look.
  static Color _tint(int light, int night) => _mix(Color(light), Color.alphaBlend(Color(night).withValues(alpha: 0.20), surface));

  // Category colours (24 Oct): calm, earthy versions, so pages read as one
  // quiet set rather than a rainbow.
  static Color get orange => warn;
  static Color get orangeDark => _f(0xFF7A5216, 0xFFEDD3A0);
  static Color get orangeTint => warnBg;

  static Color get blue => _f(0xFF3D5F8A, 0xFF9DB7D6);
  static Color get blueTint => _tint(0xFFEDF1F6, 0xFF9DB7D6);
  static Color get blueText => _f(0xFF2A4466, 0xFFC5D3E4);

  static Color get purple => _f(0xFF6A5A8E, 0xFFB4A6D2);
  static Color get purpleTint => _tint(0xFFF0EDF5, 0xFFB4A6D2);

  static Color get ochre => _f(0xFF8A6420, 0xFFD9B56E);
  static Color get ochreTint => _tint(0xFFF6F0E3, 0xFFD9B56E);

  static Color get red => _f(0xFFB33A2B, 0xFFEE8670);

  static Color get teal => _f(0xFF2F6F67, 0xFF7FC4B8);
  static Color get tealTint => _tint(0xFFE7F0EE, 0xFF7FC4B8);
  static Color get rose => _f(0xFFA8434A, 0xFFE99AA0);
  static Color get roseDark => _f(0xFF8A333A, 0xFFF2BCC0);
  /// A rose fill that keeps white letters readable in both looks.
  static Color get roseFill => _p(0xFFA8434A, 0xFFC2554F);
  static Color get roseTint => _tint(0xFFF8EBEC, 0xFFE99AA0);
  static Color get waTint => _tint(0xFFE3F6EA, 0xFF34D399);
  static Color get soft => surface2;

  // On the dark surfaces (alarm page, Pro card).
  static const dark2 = Color(0xFF1F2937);
  static const onDarkMuted = Color(0xFFD1D5DB);

  /// Text on an [ink]-coloured fill (a selected chip, the user's bubble):
  /// white in the light look, dark in the dark look where [ink] is light.
  static Color get onInk => _readableOn(ink, const Color(0xFF111827), const Color(0xFFFFFFFF));
  static Color get onInkMuted => onInk == const Color(0xFF111827) ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB);
  static const mint = Color(0xFFA7F3D0);
  static const peach = Color(0xFFFDBA74);
  static const alarm = Color(0xFF0B3B30);
}

/// Noto Sans Bengali for every Bengali letter and digit, body and headings
/// alike (Hind's ১ is hard to read: owner, 24 Oct); Hind Siliguri only
/// fills in English letters and punctuation that Noto's Bengali font lacks.
const bodyFont = 'NotoBengali';
const displayFont = 'NotoBengali';
const fontFallback = ['Hind'];
const _displayFallback = ['Hind'];

FontWeight _w(double weight) => weight >= 650 ? FontWeight.w700 : (weight >= 550 ? FontWeight.w600 : FontWeight.w500);

/// Headings and amounts.
TextStyle display(double size, {double weight = 600, Color? color, double? height}) =>
    TextStyle(fontFamily: displayFont, fontFamilyFallback: _displayFallback, fontSize: size * textScale, height: height ?? 1.3, color: color ?? C.ink, fontWeight: _w(weight));

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
      onPrimary: C.onAccent,
      surface: C.ground,
      onSurface: C.ink,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: bodyFont, fontFamilyFallback: fontFallback, bodyColor: C.ink, displayColor: C.ink),
    appBarTheme: AppBarTheme(backgroundColor: C.ground, foregroundColor: C.ink, elevation: 0, scrolledUnderElevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.ground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: body(14, color: C.muted),
      floatingLabelStyle: body(12.5, color: C.muted),
      hintStyle: body(14, color: C.muted),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: C.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: C.green, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: C.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: C.red, width: 1.5)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.fill,
      contentTextStyle: body(15, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(color: C.line2, thickness: 1, space: 1),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: C.surface, surfaceTintColor: Colors.transparent, showDragHandle: true, dragHandleColor: C.border, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20)))),
    dialogTheme: DialogThemeData(backgroundColor: C.surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.onAccent : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.green : null),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.green : null),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: C.surface,
      selectedColor: C.greenTint,
      side: BorderSide(color: C.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      labelStyle: body(13.5, color: C.muted2),
      secondaryLabelStyle: body(14, color: C.greenDark, weight: FontWeight.w600),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.surface : C.chip),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.ink : C.muted2),
        side: WidgetStatePropertyAll(BorderSide(color: C.border)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
      ),
    ),
  );
}
