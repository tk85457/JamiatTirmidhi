import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color primaryRose = Color(0xFF7A1630); // Deep Persian Rose
  static const Color primaryDark = Color(0xFF5A1024); // Even Darker
  static const Color primaryLight = Color(0xFFA31F41); // Standard Rose as Light
  static const Color accentSilver = Color(0xFFE0E0E0);
  static const Color backgroundLight = Color(0xFFF4F6F8);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardWhite = Colors.white;
  static const Color cardDark = Color(0xFF252525);
  static const Color textDark = Color(0xFF1E1E1E);
  static const Color textLight = Color(0xFF616161);
  static const Color textOnDark = Colors.white;

  // Border Radius
  static const double borderRadius = 16.0;

  static Color getPrimaryColor(String colorName) {
    switch (colorName) {
      case 'Blue':
        return Colors.blue;
      case 'Purple':
        return Colors.deepPurple;
      case 'Orange':
        return Colors.deepOrange;
      case 'Dark Brown':
        return const Color(0xFF5D4037);
      case 'Dark Blue':
        return const Color(0xFF1A237E);
      case 'Green':
        return const Color(0xFF1B5E20);
      case 'Rose':
      default:
        return primaryRose;
    }
  }

  static ThemeData lightTheme(Color primaryColor) {
    final baseTextTheme = GoogleFonts.rubikTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        surface: cardWhite,
      ),
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      cardTheme: CardThemeData(
        color: cardWhite,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      textTheme: baseTextTheme.copyWith(
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: textDark,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: textDark),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cardWhite,
        foregroundColor: primaryColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withValues(alpha: 0.4);
          }
          return Colors.grey.withValues(alpha: 0.3);
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        thumbColor: primaryColor,
        inactiveTrackColor: const Color(0xFFE0E0E0),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF323232),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  static ThemeData darkTheme(Color primaryColor) {
    final baseTextTheme = GoogleFonts.rubikTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        surface: surfaceDark,
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white70,
      ),
      scaffoldBackgroundColor: backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(color: Colors.white),
        displayMedium: baseTextTheme.displayMedium?.copyWith(color: Colors.white),
        displaySmall: baseTextTheme.displaySmall?.copyWith(color: Colors.white),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(color: Colors.white),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(color: Colors.white),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(color: Colors.white),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(color: Colors.white),
        titleSmall: baseTextTheme.titleSmall?.copyWith(color: Colors.white),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: Colors.white),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.87),
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.7),
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(color: Colors.white),
        labelMedium: baseTextTheme.labelMedium?.copyWith(color: Colors.white),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRose,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cardDark,
        foregroundColor: primaryLight,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: const BorderSide(color: primaryLight, width: 2),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryLight;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryLight.withValues(alpha: 0.4);
          }
          return Colors.grey.withValues(alpha: 0.3);
        }),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primaryLight,
        thumbColor: primaryLight,
        inactiveTrackColor: Color(0xFF424242),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardDark,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.87),
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF424242),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardDark,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.white,
        subtitleTextStyle: TextStyle(color: Colors.white70, fontSize: 14),
        iconColor: Colors.white70,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        labelStyle: const TextStyle(color: Colors.white70),
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
    );
  }

  static TextStyle get arabicText {
    return GoogleFonts.amiri(
      fontSize: 24,
      height: 2.2,
      fontWeight: FontWeight.w400,
    );
  }

  static TextStyle get urduText {
    return GoogleFonts.notoNastaliqUrdu(
      fontSize: 24,
      height: 1.8,
      fontWeight: FontWeight.w500,
    );
  }

  static Color? getFontColor(String colorName, bool isDark) {
    switch (colorName) {
      case 'Black':
        return isDark ? Colors.white : Colors.black;
      case 'Dark Brown':
        return isDark ? const Color(0xFFFFCCBC) : const Color(0xFF5D4037);
      case 'Dark Blue':
        return isDark ? const Color(0xFFBBDEFB) : const Color(0xFF1A237E);
      case 'Dark Green':
        return isDark ? const Color(0xFFC8E6C9) : const Color(0xFF1B5E20);
      default:
        return isDark ? Colors.white : null;
    }
  }

  static TextStyle safeGetFont(
    String fontFamily, {
    double? fontSize,
    double? height,
    Color? color,
    FontWeight? fontWeight,
  }) {
    String lookupName = fontFamily;
    if (fontFamily == 'AlQalam' || fontFamily == 'PDMS Saleem') {
      lookupName = 'Amiri';
    } else if (fontFamily == 'Muhammadi' || fontFamily == 'NooreHira') {
      lookupName = 'Lateef';
    } else if (fontFamily == 'NooreHuda') {
      lookupName = 'Scheherazade New';
    } else if (fontFamily == 'Nastaleeq') {
      lookupName = 'Noto Nastaliq Urdu';
    } else if (fontFamily == 'Mehr') {
      lookupName = 'Gulzar';
    } else if (fontFamily == 'TypeSetting') {
      lookupName = 'Aref Ruqaa';
    } else if (fontFamily == 'RubikMedium') {
      lookupName = 'Rubik';
      fontWeight = FontWeight.w500;
    } else if (fontFamily == 'OpenSans') {
      lookupName = 'Open Sans';
    } else if (fontFamily == 'Google Sans Regular') {
      lookupName = 'Roboto';
    }

    try {
      return GoogleFonts.getFont(
        lookupName,
        fontSize: fontSize,
        height: height,
        color: color,
        fontWeight: fontWeight,
      );
    } catch (e) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        height: height,
        color: color,
        fontWeight: fontWeight,
      );
    }
  }
}
