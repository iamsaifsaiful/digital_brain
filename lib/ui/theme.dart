import 'package:flutter/material.dart';

/// Colours from the design canvas.
class C {
  static const ground = Color(0xFFF3F4F0);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF17211D);
  static const muted = Color(0xFF5A645F);
  static const muted2 = Color(0xFF3F4A45);
  static const line = Color(0xFFE1E4DE);
  static const line2 = Color(0xFFECEEE9);
  static const border = Color(0xFFD3D8D1);
  static const inputBorder = Color(0xFFC8CEC6);
  static const disabled = Color(0xFFDDE1DB);

  static const green = Color(0xFF0B6B55);
  static const greenDark = Color(0xFF0B5546);
  static const greenTint = Color(0xFFE1F0EA);
  static const greenSoft = Color(0xFFF1F8F5);

  static const orange = Color(0xFFA3440F);
  static const orangeDark = Color(0xFF8A3A0C);
  static const orangeTint = Color(0xFFFBE8DA);

  static const blue = Color(0xFF1F5FA8);
  static const blueTint = Color(0xFFE2ECF8);
  static const blueText = Color(0xFF1B3F6B);

  static const purple = Color(0xFF6B3FA0);
  static const purpleTint = Color(0xFFEFE7F7);

  static const ochre = Color(0xFF7A5C0E);
  static const ochreTint = Color(0xFFF6EED8);

  static const red = Color(0xFFA8321A);

  // On the dark ink surfaces.
  static const dark2 = Color(0xFF26332E);
  static const onDarkMuted = Color(0xFFC9D3CE);
  static const mint = Color(0xFF7FE0C0);
  static const peach = Color(0xFFF8B88E);
}

const bodyFont = 'Hind';
const displayFont = 'Anek';

/// Anek Bangla is a variable font: pick the weight through its axis.
TextStyle display(double size, {double weight = 600, Color color = C.ink, double? height}) => TextStyle(
      fontFamily: displayFont,
      fontSize: size,
      height: height ?? 1.15,
      color: color,
      fontWeight: weight >= 650 ? FontWeight.w700 : FontWeight.w600,
      fontVariations: [FontVariation('wght', weight), const FontVariation('wdth', 100)],
    );

TextStyle body(double size, {FontWeight weight = FontWeight.w400, Color color = C.ink, double? height}) =>
    TextStyle(fontFamily: bodyFont, fontSize: size, fontWeight: weight, color: color, height: height ?? 1.4);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: bodyFont,
    scaffoldBackgroundColor: C.ground,
    colorScheme: ColorScheme.fromSeed(seedColor: C.green, primary: C.green, surface: C.ground),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: bodyFont, bodyColor: C.ink, displayColor: C.ink),
    appBarTheme: const AppBarTheme(backgroundColor: C.ground, foregroundColor: C.ink, elevation: 0, scrolledUnderElevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: body(15, color: C.muted),
      hintStyle: body(15, color: const Color(0xFF7D8681)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.inputBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.green, width: 2)),
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
  );
}
