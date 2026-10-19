import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors (Strictly matching JLG Web App tokens)
  static const Color primaryEmerald = Color(0xFF0C4E55); // Web --primary-main: #0C4E55
  static const Color primaryDark = Color(0xFF08373C);    // Web --primary-hover: #08383D
  static const Color accentMint = Color(0xFF10B981);     // Web --primary-accent: #10B981
  static const Color accentMintDark = Color(0xFF059669); // Emerald-600
  static const Color accentMintLight = Color(0xFF34D399); // Emerald-400

  // Neutral Light Colors (Web light palette)
  static const Color bgLight = Color(0xFFF8FAFC);        // Web --bg-app: #F8FAFC
  static const Color cardLight = Colors.white;          // Web --bg-card: #FFFFFF
  static const Color cardLightSubtle = Color(0xFFF1F5F9); // Web --bg-subtle: #F1F5F9
  static const Color borderLight = Color(0xFFE2E8F0);    // Web --border-default: #E2E8F0
  static const Color textDark = Color(0xFF0F172A);       // Web --text-title: #0F172A
  static const Color textBody = Color(0xFF334155);       // Web --text-body: #334155
  static const Color textMuted = Color(0xFF64748B);      // Web --text-muted: #64748B
  static const Color textPlaceholder = Color(0xFF94A3B8); // Web --text-placeholder: #94A3B8

  // Neutral Dark Colors (Linear/Shadcn Obsidian Dark Mode)
  static const Color bgDark = Color(0xFF0B0F19);         // Ultra sleek obsidian canvas
  static const Color cardDark = Color(0xFF111827);       // Elevated surface (slate-900)
  static const Color cardDarkSubtle = Color(0xFF0F172A); // Nested surface (slate-950)
  static const Color cardDarkElevated = Color(0xFF1E293B); // Higher elevation (slate-800)
  static const Color borderDark = Color(0xFF1E293B);     // Subtle slate border
  static const Color borderDarkSubtle = Color(0xFF334155); // Card border & inputs
  static const Color textDarkTitle = Color(0xFFF8FAFC);  // Crisp white/slate title
  static const Color textDarkBody = Color(0xFFCBD5E1);   // Slate-300 body text
  static const Color textDarkMuted = Color(0xFF94A3B8);  // Slate-400 muted text
  static const Color textDarkPlaceholder = Color(0xFF64748B); // Slate-500 placeholder

  // Status Colors
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusActive = Color(0xFF10B981);
  static const Color statusDone = Color(0xFF3B82F6);
  static const Color statusCancelled = Color(0xFFEF4444);

  // Helper Context Methods for Dynamic Theme Awareness
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static Color surfaceColor(BuildContext context) => isDark(context) ? cardDark : cardLight;
  static Color surfaceSubtleColor(BuildContext context) => isDark(context) ? cardDarkSubtle : bgLight;
  static Color borderColor(BuildContext context) => isDark(context) ? borderDarkSubtle : borderLight;
  static Color titleColor(BuildContext context) => isDark(context) ? textDarkTitle : textDark;
  static Color bodyColor(BuildContext context) => isDark(context) ? textDarkBody : textBody;
  static Color mutedColor(BuildContext context) => isDark(context) ? textDarkMuted : textMuted;
  static Color brandPrimary(BuildContext context) => isDark(context) ? accentMint : primaryEmerald;

  // Badge Status Helpers with Dark Mode support
  static Color badgeBg(BuildContext context, String type) {
    final dark = isDark(context);
    switch (type) {
      case 'DONE':
      case 'ACTIVE':
        return dark ? const Color(0xFF064E3B).withValues(alpha: 0.6) : Colors.teal.shade50;
      case 'PENDING':
        return dark ? const Color(0xFF78350F).withValues(alpha: 0.5) : Colors.amber.shade50;
      case 'IN_PROGRESS':
        return dark ? const Color(0xFF0C4A6E).withValues(alpha: 0.6) : Colors.blue.shade50;
      case 'CANCELLED':
      case 'DISPUTE':
        return dark ? const Color(0xFF7F1D1D).withValues(alpha: 0.6) : Colors.red.shade50;
      default:
        return dark ? cardDarkSubtle : Colors.grey.shade100;
    }
  }

  static Color badgeText(BuildContext context, String type) {
    final dark = isDark(context);
    switch (type) {
      case 'DONE':
      case 'ACTIVE':
        return dark ? const Color(0xFF34D399) : Colors.teal.shade800;
      case 'PENDING':
        return dark ? const Color(0xFFFBBF24) : Colors.amber.shade900;
      case 'IN_PROGRESS':
        return dark ? const Color(0xFF38BDF8) : Colors.blue.shade900;
      case 'CANCELLED':
      case 'DISPUTE':
        return dark ? const Color(0xFFF87171) : Colors.red.shade900;
      default:
        return dark ? textDarkMuted : textMuted;
    }
  }

  static Color badgeBorder(BuildContext context, String type) {
    final dark = isDark(context);
    switch (type) {
      case 'DONE':
      case 'ACTIVE':
        return dark ? const Color(0xFF065F46) : Colors.teal.shade200;
      case 'PENDING':
        return dark ? const Color(0xFF92400E) : Colors.amber.shade300;
      case 'IN_PROGRESS':
        return dark ? const Color(0xFF0369A1) : Colors.blue.shade200;
      case 'CANCELLED':
      case 'DISPUTE':
        return dark ? const Color(0xFF991B1B) : Colors.red.shade200;
      default:
        return dark ? borderDark : Colors.grey.shade300;
    }
  }

  // ─── LIGHT THEME ───────────────────────────────────────────────────────────
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryEmerald,
    scaffoldBackgroundColor: bgLight,
    canvasColor: bgLight,
    cardColor: cardLight,
    colorScheme: const ColorScheme.light(
      primary: primaryEmerald,
      secondary: accentMint,
      surface: cardLight,
      surfaceContainer: cardLightSubtle,
      error: statusCancelled,
      outline: borderLight,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme).copyWith(
      headlineLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: textDark, letterSpacing: -0.5),
      headlineMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: textDark, letterSpacing: -0.3),
      titleLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: textDark),
      titleMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: textDark),
      bodyLarge: GoogleFonts.plusJakartaSans(color: textDark, fontWeight: FontWeight.w500),
      bodyMedium: GoogleFonts.plusJakartaSans(color: textBody),
      bodySmall: GoogleFonts.plusJakartaSans(color: textMuted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primaryEmerald,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryEmerald,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
        elevation: 1,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryEmerald,
        side: const BorderSide(color: primaryEmerald, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryEmerald,
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      color: cardLight,
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderLight, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderLight)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderLight)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryEmerald, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: statusCancelled)),
      labelStyle: const TextStyle(color: textMuted, fontSize: 14),
      hintStyle: const TextStyle(color: textPlaceholder, fontSize: 14),
      prefixIconColor: primaryEmerald,
      suffixIconColor: textMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: cardLight,
      selectedItemColor: primaryEmerald,
      unselectedItemColor: textMuted,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardLight,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: textDark),
      contentTextStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: textBody),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: cardLight,
      modalBackgroundColor: cardLight,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dividerTheme: const DividerThemeData(color: borderLight, thickness: 1, space: 1),
    chipTheme: ChipThemeData(
      backgroundColor: cardLightSubtle,
      selectedColor: accentMint.withValues(alpha: 0.18),
      side: const BorderSide(color: borderLight),
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: textDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: primaryEmerald),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: textDark,
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),
  );

  // ─── ULTRA PREMIUM OBSIDIAN DARK THEME ─────────────────────────────────────
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: accentMint,
    scaffoldBackgroundColor: bgDark,
    canvasColor: bgDark,
    cardColor: cardDark,
    colorScheme: const ColorScheme.dark(
      primary: accentMint,
      secondary: accentMintLight,
      surface: cardDark,
      surfaceContainer: cardDarkSubtle,
      surfaceContainerHigh: cardDarkElevated,
      error: statusCancelled,
      outline: borderDarkSubtle,
      onSurface: textDarkTitle,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).copyWith(
      headlineLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: textDarkTitle, letterSpacing: -0.5),
      headlineMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: textDarkTitle, letterSpacing: -0.3),
      titleLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: textDarkTitle),
      titleMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: textDarkTitle),
      bodyLarge: GoogleFonts.plusJakartaSans(color: textDarkTitle, fontWeight: FontWeight.w500),
      bodyMedium: GoogleFonts.plusJakartaSans(color: textDarkBody),
      bodySmall: GoogleFonts.plusJakartaSans(color: textDarkMuted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bgDark,
      foregroundColor: textDarkTitle,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textDarkTitle,
      ),
      iconTheme: const IconThemeData(color: accentMint),
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentMint,
        foregroundColor: const Color(0xFF042124),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accentMint,
        side: const BorderSide(color: borderDarkSubtle, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentMint,
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderDarkSubtle, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardDarkSubtle,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderDarkSubtle)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderDarkSubtle)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentMint, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: statusCancelled)),
      labelStyle: const TextStyle(color: textDarkMuted, fontSize: 14),
      hintStyle: const TextStyle(color: textDarkPlaceholder, fontSize: 14),
      prefixIconColor: accentMint,
      suffixIconColor: textDarkMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: cardDark,
      selectedItemColor: accentMint,
      unselectedItemColor: textDarkPlaceholder,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardDark,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: borderDarkSubtle, width: 1),
      ),
      titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: textDarkTitle),
      contentTextStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: textDarkBody),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: cardDark,
      modalBackgroundColor: cardDark,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dividerTheme: const DividerThemeData(color: borderDark, thickness: 1, space: 1),
    chipTheme: ChipThemeData(
      backgroundColor: cardDarkSubtle,
      selectedColor: accentMint.withValues(alpha: 0.18),
      side: const BorderSide(color: borderDarkSubtle),
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: textDarkTitle),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accentMint : textDarkPlaceholder,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accentMint.withValues(alpha: 0.35) : cardDarkElevated,
      ),
      trackOutlineColor: WidgetStateProperty.all(borderDarkSubtle),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accentMint : Colors.transparent,
      ),
      checkColor: WidgetStateProperty.all(const Color(0xFF042124)),
      side: const BorderSide(color: borderDarkSubtle, width: 1.5),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: accentMint),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: cardDarkElevated,
      contentTextStyle: const TextStyle(color: textDarkTitle, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: borderDarkSubtle)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
