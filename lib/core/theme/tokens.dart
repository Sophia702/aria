import 'package:flutter/material.dart';

/// Central design tokens for aria.
///
/// EVERYTHING tunable about the look lives here. Warm, premium, minimal — a
/// soft cream background, white cards that lift off the page, a clay primary
/// accent with a muted lavender secondary, and a small set of soft accent
/// colours for stat cards. Light mode only.
class AppColors {
  AppColors._();

  // Page background — warm cream vertical gradient.
  static const Color bgTop = Color(0xFFF8F3EB);
  static const Color bgBottom = Color(0xFFEFE7DA);

  // Text (warm near-black through muted browns).
  static const Color ink = Color(0xFF2C2823); // primary text, active nav
  static const Color inkSoft = Color(0xFF6E635A); // body / muted text
  static const Color label = Color(0xFF9C9286); // small labels

  // Primary accent — soft clay / terracotta.
  static const Color clay = Color(0xFFC77B57);
  static const Color clayDeep = Color(0xFFB0623F);

  // Secondary accent — muted lavender.
  static const Color lavender = Color(0xFF8E86C9);
  static const Color lavenderDeep = Color(0xFF6F66B0);

  // Extra soft accents (stat cards, variety — like the inspo task apps).
  static const Color sage = Color(0xFF6FA083);
  static const Color amber = Color(0xFFE0A93C);
  static const Color blush = Color(0xFFD78FA0);
  static const Color sky = Color(0xFF6E97C9);

  // Cards + warm surfaces.
  static const Color card = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF0E8DA); // warm tan chip
  static const Color surfaceDeep = Color(0xFFE6DAC7);

  // Status — always paired with an icon + label (colour is never the only cue).
  static const Color connected = Color(0xFF5E9C76); // green
  static const Color notConnected = Color(0xFFD2553B); // red-orange
  static const Color cue = Color(0xFFE0A93C); // amber — cue / pre-freeze

  // Soft warm wash for the live walking screen.
  static const Color walkingWashTop = Color(0xFFF5EFE4);
  static const Color walkingWashBottom = Color(0xFFECE1CF);

  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgBottom],
  );

  /// Primary action gradient (buttons, start ring).
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [clay, clayDeep],
  );

  /// Secondary gradient (lavender accent cards).
  static const LinearGradient lavenderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lavender, lavenderDeep],
  );

  static const LinearGradient walkingWash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [walkingWashTop, walkingWashBottom],
  );
}

class AppRadii {
  AppRadii._();
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 28;
  static const double pill = 999;
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 6;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Bottom padding tab content reserves so the floating nav doesn't cover it.
  static const double navClearance = 104;
}

class AppShadows {
  AppShadows._();

  /// White-card lift, warm-tinted: 0 8px 22px rgba(74,60,40,.10).
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x1A4A3C28),
      blurRadius: 22,
      offset: Offset(0, 8),
    ),
  ];

  /// Stronger lift for the raised start button / floating nav.
  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x33806A4A),
      blurRadius: 26,
      offset: Offset(0, 10),
    ),
  ];
}

/// Type scale. Min body ~18sp for low-vision / older-adult readability
/// (WCAG 2.2 §1.4.4; large type recommended by Parkinson's UI guidance,
/// Nunes et al. Springer 10.1007/s10209-015-0440-1).
class AppType {
  AppType._();

  static const TextStyle display = TextStyle(
    fontSize: 56,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    height: 1.0,
    letterSpacing: -1.5,
  );
  static const TextStyle h1 = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    letterSpacing: -0.5,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 23,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const TextStyle body = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.inkSoft,
    height: 1.35,
  );
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.label,
    letterSpacing: 0.3,
  );
  static const TextStyle button = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
}
