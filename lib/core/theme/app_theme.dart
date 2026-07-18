import 'package:flutter/material.dart';

/// Retro CRT / terminal-inspired theme.
///
/// Dark: black background, cyan text, amber warnings, matrix green success —
/// evokes 90s DOS/Unix shells and CRT phosphor tubes.
/// Light: cream "paper terminal" with deep cyan ink.
class AppTheme {
  static const _radius = 2.0;
  // Menlo ships with macOS; Consolas on Windows; DejaVu Sans Mono on most Linux.
  static const _mono = 'Menlo';

  // Tron-inspired electric cyan on deep blue-black.
  static const _cyan     = Color(0xFF00E5FF);
  static const _cyanSoft = Color(0xFF4DE0FF);
  static const _paleFg   = Color(0xFFE0F7FA);
  static const _bgDark   = Color(0xFF04070A);
  // Reserve green for "success" states so a green pill still reads as OK
  // when a page is otherwise blue/cyan.
  static const _tronGreen = Color(0xFF00FF88);

  static ThemeData dark() => _base(
        brightness: Brightness.dark,
        surface: _bgDark,
        card:    const Color(0xFF0A1218),
        border:  const Color(0xFF1F4A5A),
        text:    _paleFg,
        subtle:  const Color(0xFF6EA0B8),
        accent:  _cyan,
        secondary: _cyanSoft,
        success: _tronGreen,
        warning: const Color(0xFFFFB000),
        danger:  const Color(0xFFFF3B4E),
      );

  static ThemeData light() => _base(
        brightness: Brightness.light,
        surface: const Color(0xFFEDF3F5),
        card:    const Color(0xFFFFFFFF),
        border:  const Color(0xFF2E5A6A),
        text:    const Color(0xFF061218),
        subtle:  const Color(0xFF3E606E),
        accent:  const Color(0xFF00778C),
        secondary: const Color(0xFF006B7A),
        success: const Color(0xFF00694A),
        warning: const Color(0xFF9E5A00),
        danger:  const Color(0xFFB80028),
      );

  static ThemeData _base({
    required Brightness brightness,
    required Color surface,
    required Color card,
    required Color border,
    required Color text,
    required Color subtle,
    required Color accent,
    required Color secondary,
    required Color success,
    required Color warning,
    required Color danger,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: brightness == Brightness.dark ? Colors.black : Colors.white,
      secondary: secondary,
      onSecondary: brightness == Brightness.dark ? Colors.black : Colors.white,
      surface: surface,
      onSurface: text,
      error: danger,
      onError: brightness == Brightness.dark ? Colors.black : Colors.white,
    );

    final baseText = TextTheme(
      headlineLarge:  TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: accent, height: 1.15, letterSpacing: 1.0),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: accent, height: 1.2,  letterSpacing: 0.8),
      headlineSmall:  TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text,   height: 1.25, letterSpacing: 0.6),
      titleMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text,   height: 1.3,  letterSpacing: 0.4),
      titleSmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text,   height: 1.3,  letterSpacing: 0.4),
      bodyLarge:      TextStyle(fontSize: 14, color: text,   height: 1.35),
      bodyMedium:     TextStyle(fontSize: 12, color: text,   height: 1.35),
      bodySmall:      TextStyle(fontSize: 11, color: subtle, height: 1.35),
      labelMedium:    TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: subtle, letterSpacing: 1.2),
      labelSmall:     TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: subtle, letterSpacing: 1.2),
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: _mono,
      fontFamilyFallback: const ['Menlo', 'Consolas', 'DejaVu Sans Mono', 'Courier New', 'monospace'],
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      dividerColor: border,
      textTheme: baseText,
      splashFactory: NoSplash.splashFactory,
      hoverColor: accent.withOpacity(0.05),
      highlightColor: Colors.transparent,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: baseText.bodyMedium?.copyWith(color: subtle),
      ),
      iconTheme: IconThemeData(color: text, size: 14),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : subtle),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent.withOpacity(0.35) : card),
        trackOutlineColor: WidgetStateProperty.all(border),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: border,
        thumbColor: accent,
        overlayColor: accent.withOpacity(0.2),
      ),
      extensions: [
        AppColors(
          surface: surface,
          card: card,
          border: border,
          text: text,
          subtle: subtle,
          accent: accent,
          success: success,
          warning: warning,
          danger: danger,
        ),
      ],
    );
  }
}

class AppColors extends ThemeExtension<AppColors> {
  final Color surface;
  final Color card;
  final Color border;
  final Color text;
  final Color subtle;
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;

  const AppColors({
    required this.surface,
    required this.card,
    required this.border,
    required this.text,
    required this.subtle,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
  });

  @override
  AppColors copyWith({
    Color? surface, Color? card, Color? border, Color? text, Color? subtle,
    Color? accent, Color? success, Color? warning, Color? danger,
  }) =>
      AppColors(
        surface: surface ?? this.surface,
        card: card ?? this.card,
        border: border ?? this.border,
        text: text ?? this.text,
        subtle: subtle ?? this.subtle,
        accent: accent ?? this.accent,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension AppColorsExt on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
