import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Bundled editorial faces (DESIGN.md section 16). Letter spacing stays zero.
abstract final class AppFonts {
  static const serif = 'SourceSerif4';
  static const sans = 'PublicSans';

  static const _licences = {
    'SourceSerif4': 'assets/fonts/OFL-SourceSerif4.txt',
    'PublicSans': 'assets/fonts/OFL-PublicSans.txt',
  };

  /// Adds the SIL OFL notices to the platform licence page.
  static void registerLicences() {
    LicenseRegistry.addLicense(() async* {
      for (final entry in _licences.entries) {
        yield LicenseEntryWithLineBreaks([
          entry.key,
        ], await rootBundle.loadString(entry.value));
      }
    });
  }
}

/// The one type scale shared by Today, Event Detail and Quiz.
abstract final class AppText {
  static const _serif = TextStyle(
    fontFamily: AppFonts.serif,
    color: AppColors.deepInk,
    letterSpacing: 0,
    fontWeight: FontWeight.w600,
  );
  static const _sans = TextStyle(
    fontFamily: AppFonts.sans,
    color: AppColors.deepInk,
    letterSpacing: 0,
    fontWeight: FontWeight.w400,
  );

  static const masthead = TextStyle(
    fontFamily: AppFonts.serif,
    color: AppColors.deepInk,
    letterSpacing: 0,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 1.2,
  );
  static final navTitle = _serif.copyWith(fontSize: 17, height: 1.2);
  static final sectionHeader = _serif.copyWith(fontSize: 22, height: 1.2);
  static final questionPrompt = _serif.copyWith(
    fontSize: 23,
    height: 1.28,
    fontWeight: FontWeight.w500,
  );
  static final questionPromptAnswered = questionPrompt.copyWith(fontSize: 20);
  static final listYear = _serif.copyWith(
    fontSize: 17,
    height: 1.2,
    color: AppColors.archivalCobalt,
  );
  static final eyebrow = _sans.copyWith(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static final tag = _sans.copyWith(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static const tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme() => TextTheme(
    displayLarge: _serif.copyWith(fontSize: 60, height: 1),
    displayMedium: _serif.copyWith(fontSize: 40, height: 1.05),
    displaySmall: _serif.copyWith(fontSize: 34, height: 1.1),
    headlineLarge: _serif.copyWith(fontSize: 32, height: 1.15),
    headlineMedium: _serif.copyWith(fontSize: 28, height: 1.15),
    headlineSmall: _serif.copyWith(fontSize: 26, height: 1.15),
    titleLarge: _serif.copyWith(fontSize: 22, height: 1.2),
    titleMedium: _sans.copyWith(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: _sans.copyWith(
      fontSize: 15,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: _sans.copyWith(fontSize: 16, height: 1.5),
    bodyMedium: _sans.copyWith(fontSize: 15, height: 1.5),
    bodySmall: _sans.copyWith(
      fontSize: 13,
      height: 1.45,
      color: AppColors.mutedGray,
    ),
    labelLarge: _sans.copyWith(
      fontSize: 15,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: _sans.copyWith(
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: _sans.copyWith(
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w500,
    ),
  );
}

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppFonts.sans,
    );
    final textTheme = AppText.textTheme();
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.archivalCobalt,
        onPrimary: AppColors.softIvory,
        primaryContainer: AppColors.cobaltTint,
        onPrimaryContainer: AppColors.archivalCobalt,
        secondary: AppColors.mutedCopper,
        onSecondary: AppColors.softIvory,
        surface: AppColors.softIvory,
        onSurface: AppColors.deepInk,
        onSurfaceVariant: AppColors.mutedGray,
        outline: AppColors.paleStone,
        outlineVariant: AppColors.hairline,
        // Incorrect and failure states are copper, never alarm red.
        error: AppColors.copperDark,
        onError: AppColors.softIvory,
        errorContainer: AppColors.copperTint,
        onErrorContainer: AppColors.copperDark,
        scrim: AppColors.deepInk,
      ),
      scaffoldBackgroundColor: AppColors.warmPaper,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: AppColors.warmPaper,
        foregroundColor: AppColors.deepInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppText.navTitle,
      ),
      iconTheme: const IconThemeData(color: AppColors.deepInk),
      dividerTheme: const DividerThemeData(
        color: AppColors.paleStone,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: buttonShape,
              textStyle: textTheme.titleMedium,
              disabledBackgroundColor: AppColors.softWarmGray,
              disabledForegroundColor: AppColors.mutedGray,
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.softWarmGray;
                }
                if (states.contains(WidgetState.pressed)) {
                  return AppColors.cobaltPressed;
                }
                return AppColors.archivalCobalt;
              }),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: AppColors.archivalCobalt,
          side: const BorderSide(color: AppColors.paleStone),
          shape: buttonShape,
          textStyle: textTheme.titleSmall,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.archivalCobalt,
          shape: buttonShape,
          textStyle: textTheme.titleSmall,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.deepInk,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(AppColors.softIvory),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.archivalCobalt
              : AppColors.paleStone,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbIcon: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Icon(Icons.check, color: AppColors.archivalCobalt)
              : null,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.archivalCobalt
              : AppColors.mutedGray,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: AppColors.softIvory,
          foregroundColor: AppColors.deepInk,
          selectedBackgroundColor: AppColors.cobaltTint,
          selectedForegroundColor: AppColors.archivalCobalt,
          side: const BorderSide(color: AppColors.paleStone),
          shape: buttonShape,
          textStyle: textTheme.titleSmall,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.softIvory,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: AppColors.scrim,
        showDragHandle: true,
        dragHandleColor: AppColors.paleStone,
        dragHandleSize: Size(36, 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.softIvory,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.archivalCobalt,
        linearTrackColor: AppColors.paleStone,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 60,
        backgroundColor: AppColors.softIvory,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.cobaltTint,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? AppColors.archivalCobalt : AppColors.mutedGray,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
