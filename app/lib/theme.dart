import 'package:flutter/material.dart';

const Color kSeed = Color(0xFF2E7D5B);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: kSeed, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardTheme(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withAlpha(110),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// Alpha-tinted copy of a colour (avoids deprecated withOpacity).
Color tint(Color c, double opacity) =>
    c.withAlpha((opacity * 255).round().clamp(0, 255).toInt());

const List<int> kHabitColors = [
  0xFF2E7D5B, // green
  0xFF3B82F6, // blue
  0xFFF97316, // orange
  0xFFE11D48, // rose
  0xFF8B5CF6, // violet
  0xFFEAB308, // amber
  0xFF0EA5E9, // sky
];
