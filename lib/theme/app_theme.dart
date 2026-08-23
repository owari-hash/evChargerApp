import 'package:flutter/material.dart';

/// Semantic surface and text colours that flip between light and dark.
///
/// The brand colours (forest, sage) stay put in both modes; what changes is
/// which of them carries text and which carries a surface. The old
/// `AppTheme.darkForest` did both jobs at once, which is why it could not
/// simply be swapped for a dark value.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.card,
    required this.border,
    required this.ink,
    required this.inkMuted,
    required this.panel,
    required this.onPanel,
    required this.accent,
    required this.shadow,
  });

  /// Scaffold background.
  final Color bg;

  /// Raised card surface sitting on [bg].
  final Color card;

  /// Hairline border around a [card].
  final Color border;

  /// Primary text and icon colour on [bg] / [card].
  final Color ink;

  /// Secondary text on [bg] / [card].
  final Color inkMuted;

  /// Deliberately dark feature surface (nav bar, hero, primary button).
  final Color panel;

  /// Text and icons drawn on [panel].
  final Color onPanel;

  /// Brand accent, identical in both modes.
  final Color accent;

  /// Ambient shadow colour, softened in dark mode.
  final Color shadow;

  static const AppPalette light = AppPalette(
    bg: Color(0xFFF4F7F4),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE1EBE4),
    ink: Color(0xFF0D2619),
    inkMuted: Color(0xFF5E7367),
    // Brighter than the ink colour: as a large surface the near-black forest
    // read as flat. Still 10:1 against white text.
    panel: Color(0xFF124A33),
    onPanel: Color(0xFFFFFFFF),
    accent: Color(0xFF25A269),
    shadow: Color(0x1A000000),
  );

  static const AppPalette dark = AppPalette(
    bg: Color(0xFF08130E),
    card: Color(0xFF122019),
    border: Color(0xFF20372B),
    ink: Color(0xFFE9F1EB),
    inkMuted: Color(0xFF8FA79A),
    panel: Color(0xFF192E23),
    onPanel: Color(0xFFF2F8F4),
    accent: Color(0xFF2FBE7C),
    shadow: Color(0x66000000),
  );

  /// Palette for the current theme. Falls back to [light] outside a theme.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? light;

  @override
  AppPalette copyWith({
    Color? bg,
    Color? card,
    Color? border,
    Color? ink,
    Color? inkMuted,
    Color? panel,
    Color? onPanel,
    Color? accent,
    Color? shadow,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      panel: panel ?? this.panel,
      onPanel: onPanel ?? this.onPanel,
      accent: accent ?? this.accent,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      onPanel: Color.lerp(onPanel, other.onPanel, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

/// Shorthand so screens can read `context.palette.card`.
extension AppPaletteContext on BuildContext {
  AppPalette get palette => AppPalette.of(this);
}

/// Holds the app's light/dark selection. Listened to by the root widget.
class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  static bool get isDark => mode.value == ThemeMode.dark;

  static void toggle() =>
      mode.value = isDark ? ThemeMode.light : ThemeMode.dark;
}

class AppTheme {
  // Brand Colors inspired by reference image
  static const Color darkForest = Color(0xFF0D2619);
  static const Color forestAccent = Color(0xFF1B4D3E);
  static const Color sageGreen = Color(0xFF25A269);
  static const Color lightSage = Color(0xFFD8ECE1);
  static const Color softBg = Color(0xFFF4F7F4);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color borderSubtle = Color(0xFFE1EBE4);
  static const Color textDark = Color(0xFF0A1E14);
  static const Color textMuted = Color(0xFF5E7367);
  static const Color warningOrange = Color(0xFFE67E22);
  static const Color errorRed = Color(0xFFE74C3C);

  static ThemeData get lightTheme => _build(AppPalette.light, Brightness.light);

  static ThemeData get darkTheme => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.bg,
      primaryColor: p.panel,
      canvasColor: p.bg,
      dividerColor: p.border,
      extensions: <ThemeExtension<dynamic>>[p],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: isDark ? p.accent : p.panel,
        onPrimary: p.onPanel,
        secondary: p.accent,
        onSecondary: Colors.white,
        surface: p.card,
        onSurface: p.ink,
        error: errorRed,
        onError: Colors.white,
      ),
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.ink,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: p.ink),
        titleTextStyle: TextStyle(
          color: p.ink,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.border, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          color: p.ink,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: TextStyle(
          color: p.inkMuted,
          fontSize: 14,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.card,
        selectedItemColor: isDark ? p.accent : p.panel,
        unselectedItemColor: p.inkMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.panel,
          foregroundColor: p.onPanel,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          side: BorderSide(color: p.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.ink),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.panel,
        contentTextStyle: TextStyle(color: p.onPanel),
      ),
    );
  }
}
