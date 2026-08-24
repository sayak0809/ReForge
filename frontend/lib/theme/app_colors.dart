import 'package:flutter/material.dart';

/// White + classy green palette. Central source of truth for the app's colors —
/// screens reference these constants directly rather than hardcoding hex values.
class AppColors {
  AppColors._();

  // Base surfaces
  static const background = Color(0xFFF6F8F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFEFF3EF);
  static const border = Color(0xFFE1E7E1);

  // Brand green
  static const primary = Color(0xFF1F6D52);
  static const primaryLight = Color(0xFF3F8F6E);
  static const primaryDark = Color(0xFF154E3B);
  static const onPrimary = Color(0xFFFFFFFF);

  // Text
  static const textPrimary = Color(0xFF1B231F);
  static const textSecondary = Color(0xFF54635B);
  static const textMuted = Color(0xFF8B968F);
  static const textFaint = Color(0xFFB6BFB9);

  // Semantic
  static const error = Color(0xFFB3261E);
  static const success = primary;
  static const warning = Color(0xFFB07A1E);

  // Quest rarity tiers (tuned for legibility on a light background)
  static const rarityCommon = Color(0xFF8A968F);
  static const rarityRare = Color(0xFF3A6EA5);
  static const rarityEpic = Color(0xFF7A4F98);
  static const rarityLegendary = Color(0xFFB8860B);

  // Macro-nutrient accents (food detail tiles)
  static const macroCalories = Color(0xFFC9A227);
  static const macroProtein = Color(0xFF3A6EA5);
  static const macroFat = Color(0xFFB07A1E);
  static const macroCarbs = Color(0xFF4C8D6B);

  // Trophy tiers — each visually richer than the last
  static const trophyNovice = Color(0xFF9AA79F);
  static const trophyWalker = Color(0xFFAD7A4C);
  static const trophyRunner = Color(0xFF8E9B9E);
  static const trophyAthlete = primary;
  static const trophyChampion = Color(0xFFC9A227);
  static const trophyLegendStart = Color(0xFF1F6D52);
  static const trophyLegendEnd = Color(0xFFC9A227);
}
