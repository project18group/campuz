import 'package:flutter/material.dart';

class AppColors {
  // AIM-inspired school palette.
  static Color primary = const Color(0xFFB10E15);
  static Color primaryDark = const Color(0xFF6E070B);
  static Color primaryDeep = const Color(0xFF4F0508);
  static Color accent = const Color(0xFFE84A4A);

  static Color background = const Color(0xFFF7F1EF);
  static Color surface = const Color(0xFFFCF8F7);
  static Color surfaceMuted = const Color(0xFFF3E7E5);
  static Color border = const Color(0xFFE5CFCB);

  static Color text = const Color(0xFF3A1C1D);
  static Color textPrimary = const Color(0xFF3A1C1D);
  static Color textSecondary = const Color(0xFF7B5B5D);
  static Color textOnPrimary = Colors.white;
  static Color shadow = const Color(0x1A5C0A0D);

  static Color success = const Color(0xFF22C55E);
  static Color warning = const Color(0xFFF59E0B);
  static Color error = const Color(0xFFEF4444);

  static void setLightTheme() {
    primary = const Color(0xFFB10E15);
    primaryDark = const Color(0xFF6E070B);
    primaryDeep = const Color(0xFF4F0508);
    accent = const Color(0xFFE84A4A);

    background = const Color(0xFFF7F1EF);
    surface = const Color(0xFFFCF8F7);
    surfaceMuted = const Color(0xFFF3E7E5);
    border = const Color(0xFFE5CFCB);

    text = const Color(0xFF3A1C1D);
    textPrimary = const Color(0xFF3A1C1D);
    textSecondary = const Color(0xFF7B5B5D);
    textOnPrimary = Colors.white;
    shadow = const Color(0x1A5C0A0D);

    success = const Color(0xFF22C55E);
    warning = const Color(0xFFF59E0B);
    error = const Color(0xFFEF4444);
  }

  static void setDarkTheme() {
    primary = const Color(0xFFB10E15);
    primaryDark = const Color(0xFF4F0508);
    primaryDeep = const Color(0xFF250103);
    accent = const Color(0xFFD63C3C);

    background = const Color(0xFF140D0C);
    surface = const Color(0xFF1C1412);
    surfaceMuted = const Color(0xFF2A1C1A);
    border = const Color(0xFF3F2724);

    text = const Color(0xFFEBE0DF);
    textPrimary = const Color(0xFFF7F1EF);
    textSecondary = const Color(0xFFA58A88);
    textOnPrimary = Colors.white;
    shadow = const Color(0x40000000);

    success = const Color(0xFF22C55E);
    warning = const Color(0xFFF59E0B);
    error = const Color(0xFFEF4444);
  }
}
