import 'package:flutter/material.dart';

/// Colours from the design canvas (v2: clean grey ground, white cards,
/// one green accent, amber for money going out).
class C {
  static const ground = Color(0xFFF6F7F9);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const muted2 = Color(0xFF374151);
  static const line = Color(0xFFE5E7EB);
  static const line2 = Color(0xFFF1F2F4);
  static const border = Color(0xFFE5E7EB);
  static const inputBorder = Color(0xFFD1D5DB);
  static const disabled = Color(0xFFE5E7EB);
  static const chip = Color(0xFFECEEF1);

  static const green = Color(0xFF0E7A5F);
  static const greenDark = Color(0xFF0A5C47);
  static const greenTint = Color(0xFFE7F4EF);
  static const greenSoft = Color(0xFFF0F8F5);

  static const orange = Color(0xFFB45309);
  static const orangeDark = Color(0xFF92400E);
  static const orangeTint = Color(0xFFFEF3E2);

  static const blue = Color(0xFF1D4ED8);
  static const blueTint = Color(0xFFEEF2FF);
  static const blueText = Color(0xFF1E3A8A);

  static const purple = Color(0xFF6D28D9);
  static const purpleTint = Color(0xFFF3EEFF);

  static const ochre = Color(0xFF92400E);
  static const ochreTint = Color(0xFFFEF7E6);

  static const red = Color(0xFFB91C1C);

  // On the dark surfaces (alarm page, Pro card).
  static const dark2 = Color(0xFF1F2937);
  static const onDarkMuted = Color(0xFFD1D5DB);
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
TextStyle display(double size, {double weight = 600, Color color = C.ink, double? height}) =>
    TextStyle(fontFamily: displayFont, fontFamilyFallback: fontFallback, fontSize: size, height: height ?? 1.25, color: color, fontWeight: _w(weight));

TextStyle body(double size, {FontWeight weight = FontWeight.w400, Color color = C.ink, double? height}) =>
    TextStyle(fontFamily: bodyFont, fontFamilyFallback: fontFallback, fontSize: size, fontWeight: weight, color: color, height: height ?? 1.45);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: bodyFont,
    fontFamilyFallback: fontFallback,
    scaffoldBackgroundColor: C.ground,
    colorScheme: ColorScheme.fromSeed(seedColor: C.green, primary: C.green, surface: C.ground),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: bodyFont, fontFamilyFallback: fontFallback, bodyColor: C.ink, displayColor: C.ink),
    appBarTheme: const AppBarTheme(backgroundColor: C.ground, foregroundColor: C.ink, elevation: 0, scrolledUnderElevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: body(15, color: C.muted),
      hintStyle: body(15, color: const Color(0xFF7D8681)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.inputBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.green, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.red, width: 2)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.ink,
      contentTextStyle: body(15, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(color: C.line2, thickness: 1, space: 1),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: C.surface, showDragHandle: true),
    dialogTheme: DialogThemeData(backgroundColor: C.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.green : null),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.green : null),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: C.surface,
      selectedColor: C.greenTint,
      side: const BorderSide(color: C.line),
      shape: const StadiumBorder(),
      labelStyle: body(14, color: C.muted2),
      secondaryLabelStyle: body(14, color: C.greenDark, weight: FontWeight.w600),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.surface : C.chip),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.ink : C.muted2),
        side: const WidgetStatePropertyAll(BorderSide(color: C.chip, width: 3)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    ),
  );
}
