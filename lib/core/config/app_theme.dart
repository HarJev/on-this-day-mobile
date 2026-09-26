import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = base.textTheme.apply(
      bodyColor: AppColors.deepInk,
      displayColor: AppColors.deepInk,
    );

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.archivalCobalt,
        onPrimary: AppColors.softIvory,
        secondary: AppColors.mutedCopper,
        onSecondary: AppColors.softIvory,
        surface: AppColors.softIvory,
        onSurface: AppColors.deepInk,
        error: Color(0xFFB3261E),
        onError: AppColors.softIvory,
      ),
      scaffoldBackgroundColor: AppColors.warmPaper,
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.05,
        ),
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.55),
        bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.5),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: AppColors.warmPaper,
        foregroundColor: AppColors.deepInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: AppColors.deepInk,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.paleStone,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.paleStone),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: AppColors.softIvory,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? AppColors.archivalCobalt : AppColors.mutedGray,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.archivalCobalt
                : AppColors.mutedGray,
          );
        }),
      ),
    );
  }
}
