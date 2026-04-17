import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/components.dart';
import '../services/api_services.dart';
import '../models/place_model.dart';
import 'screen2_locations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool    _loading = false;
  String? _error;

  Future<void> _startJourney() async {
    setState(() { _loading = true; _error = null; });
    try {
      final places = await ApiService().loadPlaces();
      if (!mounted) return;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => LocationsScreen(places: places)));
    } catch (e) {
      setState(() { _error = 'تعذّر تحميل البيانات.'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              // ── Top menu ──────────────────────────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.menu, color: AppColors.white),
                  onPressed: () {},
                ),
              ),

              // ── Title ─────────────────────────────────────────────
              Text('أنيس',
                  style: AppTextStyles.display(),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('اكتشف صوت تاريخ السعودية',
                  style: AppTextStyles.caption(color: AppColors.orange),
                  textAlign: TextAlign.center),

              const SizedBox(height: 32),

              // ── Orb ───────────────────────────────────────────────
              GlowOrb(size: 180, pulse: !_loading),

              // ── Loading indicator ─────────────────────────────────
              if (_loading) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(
                    color: AppColors.orange, strokeWidth: 2),
                const SizedBox(height: 8),
                Text('جاري تحميل المسار...',
                    style: AppTextStyles.caption()),
              ],

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!,
                      style: AppTextStyles.caption(color: Colors.redAccent),
                      textAlign: TextAlign.center),
                ),

              const Spacer(),

              // ── LARGE start button — easy to tap for all users ────
              GestureDetector(
                onTap: _loading ? null : _startJourney,
                child: Container(
                  width: double.infinity,
                  height: 80,   // taller than standard for accessibility
                  decoration: BoxDecoration(
                    color: _loading
                        ? AppColors.brownCard
                        : AppColors.orange,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: _loading ? [] : [
                      BoxShadow(
                        color: AppColors.orange.withOpacity(0.45),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _loading
                        ? const CircularProgressIndicator(
                        color: AppColors.white, strokeWidth: 3)
                        : const Text(
                      'ابدأ الرحلة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
