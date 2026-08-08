import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryEmerald = Color(0xFF0C4E55);
  static const Color primaryDark = Color(0xFF08373C);
  static const Color accentMint = Color(0xFF10B981);
  static const Color accentMintDark = Color(0xFF059669);
  
  // Neutral Colors
  static const Color bgDark = Color(0xFF0F172A);
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E293B);
  
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Status Colors
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusActive = Color(0xFF10B981);
  static const Color statusDone = Color(0xFF3B82F6);
  static const Color statusCancelled = Color(0xFFEF4444);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryEmerald,
    scaffoldBackgroundColor: bgLight,
    colorScheme: const ColorScheme.light(
      primary: primaryEmerald,
      secondary: accentMint,
      surface: cardLight,
      error: statusCancelled,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme).copyWith(
      headlineMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: textDark),
      titleLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: textDark),
      bodyMedium: GoogleFonts.plusJakartaSans(color: textDark),
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
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryEmerald,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    cardTheme: CardThemeData(
      color: cardLight,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderLight, width: 1),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryEmerald,
    scaffoldBackgroundColor: bgDark,
    colorScheme: const ColorScheme.dark(
      primary: primaryEmerald,
      secondary: accentMint,
      surface: cardDark,
      error: statusCancelled,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).copyWith(
      headlineMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white),
      titleLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
      bodyMedium: GoogleFonts.plusJakartaSans(color: Colors.white),
      bodySmall: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryEmerald,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155), width: 1),
      ),
    ),
  );
}
