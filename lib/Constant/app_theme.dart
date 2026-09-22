import 'package:chess_cash/Constant/color_resources.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const String fontFamily = 'Nunito';

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: ColorResources.primary,
      onPrimary: ColorResources.onPrimary,
      secondary: ColorResources.accent,
      onSecondary: ColorResources.background,
      surface: ColorResources.surface,
      onSurface: ColorResources.textPrimary,
      error: ColorResources.error,
      onError: ColorResources.textPrimary,
    );

    final baseText = ThemeData.dark().textTheme.apply(
          fontFamily: fontFamily,
          bodyColor: ColorResources.textPrimary,
          displayColor: ColorResources.textPrimary,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      primaryColor: ColorResources.primary,
      scaffoldBackgroundColor: ColorResources.background,
      canvasColor: ColorResources.background,
      dividerColor: ColorResources.divider,
      textTheme: baseText.copyWith(
        headlineLarge: baseText.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: ColorResources.textPrimary,
          letterSpacing: -0.4,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: ColorResources.textPrimary,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: ColorResources.textPrimary,
          fontSize: 20,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: ColorResources.textPrimary,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(
          color: ColorResources.textPrimary,
          height: 1.4,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          color: ColorResources.textSecondary,
          height: 1.4,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: ColorResources.background,
        foregroundColor: ColorResources.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: ColorResources.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: ColorResources.accentSoft),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: ColorResources.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ColorResources.divider),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ColorResources.elevatedSurface,
        hintStyle: const TextStyle(color: ColorResources.textSecondary),
        labelStyle: const TextStyle(color: ColorResources.textSecondary),
        prefixStyle: const TextStyle(color: ColorResources.textPrimary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ColorResources.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: ColorResources.accent, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ColorResources.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ColorResources.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorResources.primary,
          foregroundColor: ColorResources.onPrimary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ColorResources.accentSoft,
          side: const BorderSide(color: ColorResources.divider),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ColorResources.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ColorResources.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ColorResources.divider),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: ColorResources.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: ColorResources.textSecondary,
          fontSize: 15,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ColorResources.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: ColorResources.surface,
        selectedItemColor: ColorResources.accentSoft,
        unselectedItemColor: ColorResources.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(fontFamily: fontFamily, fontSize: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: ColorResources.divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ColorResources.elevatedSurface,
        contentTextStyle: const TextStyle(color: ColorResources.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ColorResources.accent,
        circularTrackColor: ColorResources.divider,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor:
              WidgetStateProperty.all(ColorResources.elevatedSurface),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ColorResources.accentSoft;
          }
          return ColorResources.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ColorResources.primary;
          }
          return ColorResources.divider;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ColorResources.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(ColorResources.onPrimary),
        side: const BorderSide(color: ColorResources.divider),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: ColorResources.accentSoft,
        unselectedLabelColor: ColorResources.textSecondary,
        indicatorColor: ColorResources.accent,
        dividerColor: ColorResources.divider,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ColorResources.primary,
        foregroundColor: ColorResources.onPrimary,
        elevation: 2,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ColorResources.elevatedSurface,
        selectedColor: ColorResources.primary,
        labelStyle: const TextStyle(color: ColorResources.textPrimary),
        side: const BorderSide(color: ColorResources.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
