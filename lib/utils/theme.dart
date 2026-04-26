import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF3B82F6);
  static const Color secondaryColor = Color(0xFF10B981);
  static const Color backgroundColor = Color(0xFFF3F4F6);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimaryColor = Color(0xFF1F2937);
  static const Color textSecondaryColor = Color(0xFF6B7280);
  static const Color errorColor = Color(0xFFEF4444);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
      ),
      textTheme: GoogleFonts.josefinSansTextTheme().copyWith(
        displayLarge: GoogleFonts.ubuntu(
          color: textPrimaryColor,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.ubuntu(
          color: textPrimaryColor,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: GoogleFonts.ubuntu(
          color: textPrimaryColor,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: GoogleFonts.ubuntu(
          color: textPrimaryColor,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.ubuntu(
          color: textPrimaryColor,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: GoogleFonts.ubuntu(
          color: textPrimaryColor,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: GoogleFonts.ubuntu(
          color: textPrimaryColor,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: GoogleFonts.ubuntu(
          color: textPrimaryColor,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: GoogleFonts.ubuntu(
          color: textPrimaryColor,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(color: textPrimaryColor),
        bodyMedium: const TextStyle(color: textSecondaryColor),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.ubuntu(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondaryColor),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
