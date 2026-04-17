import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/components.dart';
import '../models/place_model.dart';
import 'journey_screen.dart';

class LocationsScreen extends StatelessWidget {
  final List<PlaceModel> places;
  const LocationsScreen({super.key, required this.places});

  void _startFrom(BuildContext context, int index) {
    // Slice the list from the chosen starting point
    final routeFromHere = places.sublist(index);
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => JourneyScreen(places: routeFromHere)));
  }

  String _roleLabel(String role) => switch (role) {
        'intro'      => 'بداية',
        'movement'   => 'انتقال',
        'transition' => 'تحول',
        'ending'     => 'نهاية',
        _            => role,
      };

  Color _roleColor(String role) => switch (role) {
        'intro'      => AppColors.orange,
        'ending'     => const Color(0xFFE63A3A),
        'transition' => const Color(0xFF3A9AE6),
        _            => AppColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Header ─────────────────────────────────────────────
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Text('اختر نقطة البداية',
                      style: AppTextStyles.title()),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 34),
                child: Text('المسار: ${places.length} محطات',
                    style:
                        AppTextStyles.caption(color: AppColors.orange)),
              ),
              const SizedBox(height: 20),

              // ── List ───────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  itemCount: places.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final place = places[i];
                    final color = _roleColor(place.role);
                    return GestureDetector(
                      onTap: () => _startFrom(context, i),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.brownCard,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: color.withOpacity(0.5)),
                              ),
                              child: Center(
                                child: Text('${i + 1}',
                                    style: AppTextStyles.caption(
                                            color: color)
                                        .copyWith(
                                            fontWeight:
                                                FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(place.name,
                                      style: AppTextStyles.body(),
                                      textDirection: TextDirection.rtl),
                                  const SizedBox(height: 3),
                                  Text(_roleLabel(place.role),
                                      style: AppTextStyles.caption(
                                          color: color)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.play_circle_outline_rounded,
                                color: color.withOpacity(0.7),
                                size: 24),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // ── Quick start ────────────────────────────────────────
              AppButton(
                label: 'ابدأ من النقطة الأولى',
                onPressed: () => _startFrom(context, 0),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
