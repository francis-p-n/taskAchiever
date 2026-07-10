import 'package:flutter/material.dart';

/// System font stack, like Notion itself uses — no runtime font fetching.
const _fontFallback = ['Segoe UI', 'Inter', 'Roboto', 'Helvetica Neue'];

/// Notion dark-mode palette, matching the Ashlynn Aspires gamification
/// template: charcoal surfaces, muted text, soft colored callouts.
class NotionColors {
  static const background = Color(0xFF191919);
  static const surface = Color(0xFF202020);
  static const surfaceHover = Color(0xFF2A2A2A);
  static const border = Color(0xFF333333);

  static const textPrimary = Color(0xFFD4D4D4);
  static const textMuted = Color(0xFF9B9B9B);
  static const textFaint = Color(0xFF6F6F6F);

  // Notion tag/callout colors (dark mode): muted background + brighter accent.
  static const greenBg = Color(0xFF243D30);
  static const green = Color(0xFF6FCF97);
  static const purpleBg = Color(0xFF3B2C4A);
  static const purple = Color(0xFFB18CE0);
  static const yellowBg = Color(0xFF453C21);
  static const yellow = Color(0xFFD3A94C);
  static const blueBg = Color(0xFF25384A);
  static const blue = Color(0xFF6CB1E0);
  static const redBg = Color(0xFF4A2C2A);
  static const red = Color(0xFFE06C62);
  static const orangeBg = Color(0xFF48331F);
  static const orange = Color(0xFFDE9A54);
  static const pinkBg = Color(0xFF482B3C);
  static const pink = Color(0xFFDE87B0);
}

/// Focus ring color, shadcn-style: a soft outline that appears on
/// keyboard focus instead of Material's ripple/overlay.
const _focusRing = Color(0xFF5A5A5A);

ThemeData buildGameTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: NotionColors.background,
    // shadcn components don't ripple — they shift background subtly.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: NotionColors.surfaceHover,
    focusColor: NotionColors.surfaceHover,
    colorScheme: const ColorScheme.dark(
      primary: NotionColors.green,
      secondary: NotionColors.purple,
      surface: NotionColors.surface,
      error: NotionColors.red,
      onPrimary: NotionColors.background,
      onSurface: NotionColors.textPrimary,
    ),
  );

  final text = base.textTheme
      .apply(
        bodyColor: NotionColors.textPrimary,
        displayColor: NotionColors.textPrimary,
        fontFamilyFallback: _fontFallback,
      );

  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: NotionColors.background,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: NotionColors.textPrimary,
        fontFamilyFallback: _fontFallback,
      ),
      iconTheme: const IconThemeData(color: NotionColors.textMuted, size: 20),
    ),
    cardTheme: CardThemeData(
      color: NotionColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: NotionColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: NotionColors.border),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        animationDuration: const Duration(milliseconds: 150),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? NotionColors.textPrimary
              : NotionColors.textMuted,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? NotionColors.surfaceHover
              : Colors.transparent,
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.focused)
                ? _focusRing
                : NotionColors.border,
          ),
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        animationDuration: const Duration(milliseconds: 150),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? NotionColors.textPrimary
              : NotionColors.textMuted,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? NotionColors.surfaceHover
              : Colors.transparent,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        animationDuration: const Duration(milliseconds: 150),
        foregroundColor:
            const WidgetStatePropertyAll(NotionColors.background),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? NotionColors.green.withValues(alpha: 0.9)
              : NotionColors.green,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NotionColors.surface,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle:
          const TextStyle(fontSize: 13, color: NotionColors.textFaint),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: NotionColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: _focusRing, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: NotionColors.red),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: NotionColors.surfaceHover,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: NotionColors.border),
      ),
      textStyle: const TextStyle(
        fontSize: 12,
        color: NotionColors.textPrimary,
        fontFamilyFallback: _fontFallback,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: NotionColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: NotionColors.border),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: NotionColors.surfaceHover,
      contentTextStyle: const TextStyle(
        color: NotionColors.textPrimary,
        fontSize: 13,
        fontFamilyFallback: _fontFallback,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: NotionColors.border),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
