import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── CHARTE COULEURS OFFICIELLE MOBILE JLG ─────────────────────────────────
  // Bleu royal (primaire) : Barre d’app, boutons principaux, onglet actif
  static const Color primaryRoyal = Color(0xFF0A5FCB);

  // Bleu profond (primaire foncé) : Barre d’état (status bar), bouton pressé, en-têtes
  static const Color primaryDeep = Color(0xFF0449A6);

  // Bleu ciel (accent) : Bouton flottant (FAB), icônes, badges, barres de progression
  static const Color accentSky = Color(0xFF049DF7);

  // Bleu givre (fond) : Fond des écrans, séparateurs légers
  static const Color bgFrost = Color(0xFFF4F8FD);

  // Bleu nuit (texte) : Titres, textes, icônes sur fond clair
  static const Color textNight = Color(0xFF0B2A55);

  // ─── ALIAS DE COMPATIBILITÉ POUR L'ENSEMBLE DES MODULES EXISTANTS ──────────
  static const Color primaryEmerald = primaryRoyal;
  static const Color primaryDark = primaryDeep;
  static const Color accentMint = accentSky;
  static const Color accentMintDark = primaryDeep;
  static const Color accentMintLight = Color(0xFF38BDF8);

  // ─── NUANCES LIGHT DÉRIVÉES ───────────────────────────────────────────────
  static const Color bgLight = bgFrost;                  // #F4F8FD
  static const Color cardLight = Colors.white;          // Surface blanche pure
  static const Color cardLightSubtle = Color(0xFFEBF3FC); // Surface subtile bleu givre
  static const Color borderLight = Color(0xFFD6E4F7);    // Séparateur léger bleu givre
  static const Color textDark = textNight;               // #0B2A55
  static const Color textBody = Color(0xFF1E3A60);       // Corps de texte bleu nuit nuancé
  static const Color textMuted = Color(0xFF5B7A9F);      // Texte atténué bleu ardoise
  static const Color textPlaceholder = Color(0xFF8FA9C8); // Placeholder bleuté

  // ─── NUANCES DARK OBSIDIAN / BLEU NUIT ────────────────────────────────────
  static const Color bgDark = Color(0xFF061121);         // Nuit profonde bleutée
  static const Color cardDark = Color(0xFF0B1A30);       // Surface sombre bleu nuit
  static const Color cardDarkSubtle = Color(0xFF071426); // Surface imbriquée
  static const Color cardDarkElevated = Color(0xFF122644); // Surface surélevée
  static const Color borderDark = Color(0xFF142C4E);     // Bordure subtile
  static const Color borderDarkSubtle = Color(0xFF1E3F6E); // Bordure active
  static const Color textDarkTitle = Color(0xFFF4F8FD);  // Titre clair bleu givre
  static const Color textDarkBody = Color(0xFFC7DCF5);   // Corps clair bleuté
  static const Color textDarkMuted = Color(0xFF7E9EC4);  // Texte atténué sombre
  static const Color textDarkPlaceholder = Color(0xFF4C6B91); // Placeholder sombre

  // ─── STATUTS MÉTIER ────────────────────────────────────────────────────────
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusActive = accentSky;
  static const Color statusDone = primaryRoyal;
  static const Color statusCancelled = Color(0xFFEF4444);

  // ─── HELPER CONTEXT METHODS (THEME AWARENESS) ──────────────────────────────
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static Color surfaceColor(BuildContext context) => isDark(context) ? cardDark : cardLight;
  static Color surfaceSubtleColor(BuildContext context) => isDark(context) ? cardDarkSubtle : cardLightSubtle;
  static Color borderColor(BuildContext context) => isDark(context) ? borderDarkSubtle : borderLight;
  static Color titleColor(BuildContext context) => isDark(context) ? textDarkTitle : textNight;
  static Color bodyColor(BuildContext context) => isDark(context) ? textDarkBody : textBody;
  static Color mutedColor(BuildContext context) => isDark(context) ? textDarkMuted : textMuted;
  static Color brandPrimary(BuildContext context) => isDark(context) ? accentSky : primaryRoyal;

  // ─── BADGES STATUTS AVEC ACCENTS BLEUS ─────────────────────────────────────
  static Color badgeBg(BuildContext context, String type) {
    final dark = isDark(context);
    switch (type) {
      case 'DONE':
      case 'ACTIVE':
        return dark ? const Color(0xFF0C243B).withValues(alpha: 0.6) : const Color(0xFFEFF6FF);
      case 'PENDING':
        return dark ? const Color(0xFF78350F).withValues(alpha: 0.5) : Colors.amber.shade50;
      case 'IN_PROGRESS':
        return dark ? primaryDeep.withValues(alpha: 0.6) : const Color(0xFFE0F2FE);
      case 'CANCELLED':
      case 'DISPUTE':
        return dark ? const Color(0xFF7F1D1D).withValues(alpha: 0.6) : Colors.red.shade50;
      default:
        return dark ? cardDarkSubtle : cardLightSubtle;
    }
  }

  static Color badgeText(BuildContext context, String type) {
    final dark = isDark(context);
    switch (type) {
      case 'DONE':
      case 'ACTIVE':
        return dark ? const Color(0xFF38BDF8) : primaryDeep;
      case 'PENDING':
        return dark ? const Color(0xFFFBBF24) : Colors.amber.shade900;
      case 'IN_PROGRESS':
        return dark ? accentSky : primaryDeep;
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
        return dark ? const Color(0xFF0284C7) : const Color(0xFFBAE6FD);
      case 'PENDING':
        return dark ? const Color(0xFF92400E) : Colors.amber.shade300;
      case 'IN_PROGRESS':
        return dark ? primaryRoyal : const Color(0xFFBAE6FD);
      case 'CANCELLED':
      case 'DISPUTE':
        return dark ? const Color(0xFF991B1B) : Colors.red.shade200;
      default:
        return dark ? borderDark : borderLight;
    }
  }

  // ─── LIGHT THEME ───────────────────────────────────────────────────────────
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryRoyal,
    scaffoldBackgroundColor: bgFrost,
    canvasColor: bgFrost,
    cardColor: cardLight,
    colorScheme: const ColorScheme.light(
      primary: primaryRoyal,
      secondary: accentSky,
      surface: cardLight,
      surfaceContainer: cardLightSubtle,
      error: statusCancelled,
      outline: borderLight,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme).copyWith(
      headlineLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: textNight, letterSpacing: -0.5),
      headlineMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: textNight, letterSpacing: -0.3),
      titleLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: textNight),
      titleMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: textNight),
      bodyLarge: GoogleFonts.plusJakartaSans(color: textNight, fontWeight: FontWeight.w500),
      bodyMedium: GoogleFonts.plusJakartaSans(color: textBody),
      bodySmall: GoogleFonts.plusJakartaSans(color: textMuted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primaryRoyal,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: primaryDeep,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentSky,
      foregroundColor: Colors.white,
      elevation: 3,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryRoyal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
        elevation: 1,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed) ? primaryDeep : null,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryRoyal,
        side: const BorderSide(color: primaryRoyal, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryRoyal,
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
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryRoyal, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: statusCancelled)),
      labelStyle: const TextStyle(color: textMuted, fontSize: 14),
      hintStyle: const TextStyle(color: textPlaceholder, fontSize: 14),
      prefixIconColor: primaryRoyal,
      suffixIconColor: textMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: cardLight,
      selectedItemColor: primaryRoyal,
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
      titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: textNight),
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
      selectedColor: accentSky.withValues(alpha: 0.18),
      side: const BorderSide(color: borderLight),
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: textNight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: accentSky),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: textNight,
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),
  );

  // ─── ULTRA PREMIUM OBSIDIAN DARK THEME ─────────────────────────────────────
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: accentSky,
    scaffoldBackgroundColor: bgDark,
    canvasColor: bgDark,
    cardColor: cardDark,
    colorScheme: const ColorScheme.dark(
      primary: accentSky,
      secondary: primaryRoyal,
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
      iconTheme: const IconThemeData(color: accentSky),
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF041830),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentSky,
      foregroundColor: Color(0xFF03162C),
      elevation: 3,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentSky,
        foregroundColor: const Color(0xFF03162C),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900),
        elevation: 0,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed) ? primaryRoyal : null,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accentSky,
        side: const BorderSide(color: borderDarkSubtle, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentSky,
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
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentSky, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: statusCancelled)),
      labelStyle: const TextStyle(color: textDarkMuted, fontSize: 14),
      hintStyle: const TextStyle(color: textDarkPlaceholder, fontSize: 14),
      prefixIconColor: accentSky,
      suffixIconColor: textDarkMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: cardDark,
      selectedItemColor: accentSky,
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
      selectedColor: accentSky.withValues(alpha: 0.18),
      side: const BorderSide(color: borderDarkSubtle),
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: textDarkTitle),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accentSky : textDarkPlaceholder,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accentSky.withValues(alpha: 0.35) : cardDarkElevated,
      ),
      trackOutlineColor: WidgetStateProperty.all(borderDarkSubtle),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accentSky : Colors.transparent,
      ),
      checkColor: WidgetStateProperty.all(const Color(0xFF03162C)),
      side: const BorderSide(color: borderDarkSubtle, width: 1.5),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: accentSky),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: cardDarkElevated,
      contentTextStyle: const TextStyle(color: textDarkTitle, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: borderDarkSubtle)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
