import 'package:flutter/material.dart';

class AppColors {
  static const Color background  = Color(0xFF0B0B0B);
  static const Color white       = Color(0xFFF8F8F8);
  static const Color orange      = Color(0xFFE67E3A);
  static const Color orangeLight = Color(0xFFFFA45B);
  static const Color brownCard   = Color(0xFF3A241B);
  static const Color brownBorder = Color(0xFF5A3728);
  static const Color darkCard    = Color(0xFF161616);
  static const Color muted       = Color(0xFF9A9A9A);
}

class AppTextStyles {
  static TextStyle display() => const TextStyle(
      fontSize: 34, fontWeight: FontWeight.w800,
      color: AppColors.white, height: 1.1);

  static TextStyle title() => const TextStyle(
      fontSize: 24, fontWeight: FontWeight.w700,
      color: AppColors.white, height: 1.2);

  static TextStyle caption({Color color = AppColors.muted}) =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w400,
                color: color, height: 1.4);

  static TextStyle body({Color color = AppColors.white}) =>
      TextStyle(fontSize: 16, fontWeight: FontWeight.w400,
                color: color, height: 1.6);

  static TextStyle button() => const TextStyle(
      fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.white);

  static TextStyle statNumber() => const TextStyle(
      fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.orange);

  static TextStyle statLabel() => const TextStyle(
      fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.muted);
}
