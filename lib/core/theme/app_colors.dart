import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary brand — Teal
  static const Color primary = Color(0xFF0D9488);        // teal-600
  static const Color primaryLight = Color(0xFF2DD4BF);   // teal-400
  static const Color primaryDark = Color(0xFF0F766E);    // teal-700
  static const Color primarySurface = Color(0xFFCCFBF1); // teal-100

  // Secondary — Green
  static const Color secondary = Color(0xFF16A34A);      // green-600
  static const Color secondaryLight = Color(0xFF4ADE80); // green-400
  static const Color secondaryDark = Color(0xFF15803D);  // green-700
  static const Color secondarySurface = Color(0xFFDCFCE7);// green-100

  // Accent — Light Blue
  static const Color accent = Color(0xFF38BDF8);         // sky-400
  static const Color accentLight = Color(0xFFBAE6FD);    // sky-200
  static const Color accentSurface = Color(0xFFE0F2FE);  // sky-100

  // Neutral
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF0A0A0A);
  static const Color background = Color(0xFFF8FFFE);     // very light teal tint
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1FDF9); // light teal surface

  // Text
  static const Color textPrimary = Color(0xFF1A2E2A);
  static const Color textSecondary = Color(0xFF4A6860);
  static const Color textTertiary = Color(0xFF8BADA5);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Border
  static const Color border = Color(0xFFD1EAE5);
  static const Color borderLight = Color(0xFFECF8F5);

  // Status
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0EA5E9);

  // Transparent
  static const Color transparent = Colors.transparent;
  static Color primaryTransparent = primary.withOpacity(0.08);
  static Color secondaryTransparent = secondary.withOpacity(0.08);
  static Color overlay = Colors.black.withOpacity(0.5);

  // Role colors
  static const Color farmerRole = Color(0xFF16A34A);
  static const Color expertRole = Color(0xFF0D9488);
  static const Color driverRole = Color(0xFFF59E0B);
  static const Color businessRole = Color(0xFF7C3AED);
  static const Color enthusiastRole = Color(0xFF38BDF8);
  static const Color customerRole = Color(0xFF64748B);
}
