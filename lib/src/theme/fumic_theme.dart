import 'package:flutter/material.dart';

class FumicAppearance extends ThemeExtension<FumicAppearance> {
  const FumicAppearance({this.cardOpacity = 0.35});
  final double cardOpacity;

  @override
  FumicAppearance copyWith({double? cardOpacity}) =>
      FumicAppearance(cardOpacity: cardOpacity ?? this.cardOpacity);

  @override
  FumicAppearance lerp(FumicAppearance? other, double t) => other == null
      ? this
      : FumicAppearance(
          cardOpacity: cardOpacity + (other.cardOpacity - cardOpacity) * t,
        );
}

class FumicTheme {
  const FumicTheme._();

  static const background = Color(0xFF0C101B);
  static const panel = Color(0x18182030);
  static const surface = Color(0x18212B3C);
  static const surfaceSoft = Color(0x10192334);
  static const muted = Color(0xFFA0ACC2);
  static const text = Color(0xFFF1F4FC);
  static const accent = Color(0xFF8CE5D4);
  static const brand = Color(0xFFABAEFF);
  static const edge = Color(0x18DCE7FF);
  static const inset = Color(0x80101524);

  // Keep broad surfaces clear so the artwork shows through the interface.
  static const glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0, 0.45, 1],
    colors: [Colors.transparent, Colors.transparent, Colors.transparent],
  );
  static const surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.transparent, Colors.transparent],
  );
  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC3F6EA), accent, Color(0xFF68C9BD)],
  );
  static const panelShadow = [
    BoxShadow(color: Color(0x24000000), blurRadius: 16, offset: Offset(0, 6)),
  ];

  static Color cardFill(BuildContext context, {bool hovered = false}) {
    final opacity =
        Theme.of(context).extension<FumicAppearance>()?.cardOpacity ?? 0.35;
    return const Color(
      0xFF101828,
    ).withValues(alpha: (opacity + (hovered ? 0.10 : 0.0)).clamp(0.0, 1.0));
  }

  static BoxDecoration glassDecoration(
    BuildContext context, {
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(18)),
    bool elevated = false,
    bool filled = true,
  }) {
    return BoxDecoration(
      color: filled ? cardFill(context) : Colors.transparent,
      borderRadius: borderRadius,
      border: Border.all(color: edge),
      boxShadow: null,
    );
  }

  static ThemeData dark({double cardOpacity = 0.35}) {
    return ThemeData(
      brightness: Brightness.dark,
      extensions: [FumicAppearance(cardOpacity: cardOpacity)],
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: accent,
        surface: const Color(0xFF1A2233),
        primary: accent,
        onPrimary: const Color(0xFF102B29),
        secondary: brand,
      ),
      fontFamily: 'Segoe UI',
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontWeight: FontWeight.w400, color: text),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          backgroundColor: const Color(0x99101828),
          foregroundColor: text,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inset,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          Colors.white.withValues(alpha: 0.18),
        ),
        trackColor: WidgetStatePropertyAll(
          Colors.white.withValues(alpha: 0.04),
        ),
        radius: const Radius.circular(999),
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 450),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        trackHeight: 3,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: const WidgetStatePropertyAll(BorderSide(color: edge)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? accent.withValues(alpha: 0.14)
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? muted.withValues(alpha: 0.4)
                : states.contains(WidgetState.selected)
                ? accent
                : muted,
          ),
        ),
      ),
      useMaterial3: true,
    );
  }
}
