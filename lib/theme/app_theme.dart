import 'package:flutter/material.dart';

/// Palette de l'application : c'est ici qu'il faut changer les couleurs.
abstract final class AppColors {
  static const indigo = Color(0xFF2430A0); // titres, boutons, éléments actifs
  static const headerDark = Color(0xFF1E1D45); // début du dégradé de l'en-tête
  static const neon = Color(0xFFE9FF00); // texte sur les éléments indigo
  static const teal = Color(0xFF26C6AE); // accent des statistiques
  static const lavender = Color(0xFFE0E1F4); // tuiles et pastilles
  static const background = Color(0xFFFAFAFD);
  static const surface = Colors.white;
  static const border = Color(0xFFE6E7F2);
  static const ink = Color(0xFF24234F); // texte principal
  static const textMuted = Color(0xFF666985);

  /// Dégradé de la barre du haut.
  static const headerGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [headerDark, indigo],
  );
}

/// Thème clair : en-tête indigo, cartes blanches, tuiles lavande et
/// boutons indigo à texte jaune fluo.
ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.indigo,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.indigo,
    onPrimary: AppColors.neon,
    primaryContainer: AppColors.lavender,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.teal,
    onSecondary: AppColors.ink,
    secondaryContainer: AppColors.lavender,
    onSecondaryContainer: AppColors.ink,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.textMuted,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surface,
    surfaceContainerHighest: AppColors.lavender,
    outline: AppColors.textMuted,
    outlineVariant: AppColors.border,
  );

  final baseText = ThemeData(
    colorScheme: colorScheme,
  ).textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  final textTheme = baseText.copyWith(
    headlineMedium: baseText.headlineMedium?.copyWith(
      color: AppColors.indigo,
      fontWeight: FontWeight.w800,
    ),
    titleLarge: baseText.titleLarge?.copyWith(
      color: AppColors.indigo,
      fontWeight: FontWeight.w800,
    ),
    titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w800),
  );

  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.indigo,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: const Border(
        bottom: BorderSide(color: AppColors.neon, width: 3),
      ),
      titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.indigo.withValues(alpha: 0.18),
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.ink,
      elevation: 8,
      indicatorColor: AppColors.neon,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.indigo
              : AppColors.ink,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelMedium?.copyWith(
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.indigo
              : AppColors.ink,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.indigo,
      foregroundColor: AppColors.neon,
      shape: buttonShape,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: buttonShape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.indigo,
        side: const BorderSide(color: AppColors.indigo, width: 2),
        shape: buttonShape,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lavender,
      selectedColor: AppColors.indigo,
      checkmarkColor: AppColors.neon,
      iconTheme: const IconThemeData(color: AppColors.ink),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: textTheme.labelLarge?.copyWith(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.neon
              : AppColors.ink,
        ),
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.indigo, width: 1.5),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.indigo,
      textColor: AppColors.ink,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
    ),
  );
}
