import 'package:flutter/material.dart';
import '../theme.dart';

// ─── Primary button ───────────────────────────────────────────────────────────
class AppButton extends StatelessWidget {
  final String       label;
  final VoidCallback onPressed;
  final Color?       backgroundColor;
  final Color?       textColor;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: backgroundColor ?? AppColors.orange,
          foregroundColor: textColor       ?? AppColors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(label,
            style: AppTextStyles.button()
                .copyWith(color: textColor ?? AppColors.white)),
      ),
    );
  }
}

// ─── Glowing orb ─────────────────────────────────────────────────────────────
class GlowOrb extends StatelessWidget {
  final double size;
  final bool   pulse;

  const GlowOrb({super.key, required this.size, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [AppColors.orangeLight, AppColors.orange, Color(0xFFB44F1B)],
          stops: [0.15, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color:        AppColors.orange.withOpacity(pulse ? 0.45 : 0.28),
            blurRadius:   pulse ? 40 : 24,
            spreadRadius: pulse ? 10 : 4,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.72, height: size * 0.72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withOpacity(0.35), width: 2),
          ),
        ),
      ),
    );
  }
}

// ─── Dark card container ──────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget              child;
  final EdgeInsetsGeometry? padding;
  final Color?              color;

  const AppCard({super.key, required this.child, this.padding, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AppColors.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.brownBorder.withOpacity(0.5), width: 1),
      ),
      child: child,
    );
  }
}

// ─── Stat box (used in SummaryScreen) ────────────────────────────────────────
class MetricBox extends StatelessWidget {
  final String value;
  final String label;

  const MetricBox({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92, height: 92,
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.brownBorder.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: AppTextStyles.statNumber()),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.statLabel()),
        ],
      ),
    );
  }
}
