import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/components.dart';
import '../models/place_model.dart';
import '../services/api_services.dart';
import '../services/tts_service.dart';

// SCREEN 3 — FINDING
// Shows a spinner for 2 seconds, then auto-navigates to MapScreen.
class FindingScreen extends StatefulWidget {
  final List<PlaceModel> places;
  final int startIndex;
  const FindingScreen(
      {super.key, required this.places, required this.startIndex});

  @override
  State<FindingScreen> createState() => _FindingScreenState();
}

class _FindingScreenState extends State<FindingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => MapScreen(
              places: widget.places,
              currentIndex: widget.startIndex)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.places[widget.startIndex];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GlowOrb(size: 120, pulse: true),
              const SizedBox(height: 24),
              Text('جاري تحديد موقعك...',
                  style: AppTextStyles.title(),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(place.name,
                  style: AppTextStyles.caption(color: AppColors.orange),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}


// SCREEN 4 — MAP  (placeholder map with orange route overlay)

class MapScreen extends StatelessWidget {
  final List<PlaceModel> places;
  final int currentIndex;
  const MapScreen(
      {super.key, required this.places, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final place = places[currentIndex];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      CustomPaint(
                          painter: _FakeMapPainter(),
                          child: const SizedBox.expand()),
                      Positioned(
                        top: 12, right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text('اتجهي إلى ${place.name}',
                              style: AppTextStyles.caption(
                                  color: AppColors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      child: Column(children: [
                        Text('2.4',
                            style:
                                AppTextStyles.display().copyWith(fontSize: 26)),
                        Text('km left',
                            style: AppTextStyles.caption(),
                            textDirection: TextDirection.ltr),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppCard(
                      child: Column(children: [
                        Text('8',
                            style:
                                AppTextStyles.display().copyWith(fontSize: 26)),
                        Text('minutes',
                            style: AppTextStyles.caption(),
                            textDirection: TextDirection.ltr),
                      ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'انتقل',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => ArrivedScreen(
                            places: places,
                            currentIndex: currentIndex))),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _FakeMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF132A1A));
    final road = Paint()..color = const Color(0xFF21452B);
    for (final x in [size.width*0.18, size.width*0.42, size.width*0.68]) {
      canvas.drawRect(Rect.fromLTWH(x, 0, size.width*0.08, size.height), road);
    }
    for (final y in [size.height*0.22, size.height*0.48, size.height*0.74]) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, size.height*0.08), road);
    }
    final route = Paint()
      ..color = AppColors.orange
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(size.width*0.20, size.height*0.88)
        ..lineTo(size.width*0.20, size.height*0.58)
        ..lineTo(size.width*0.45, size.height*0.58)
        ..lineTo(size.width*0.45, size.height*0.30)
        ..lineTo(size.width*0.72, size.height*0.14),
      route,
    );
    canvas.drawCircle(Offset(size.width*0.20, size.height*0.88), 9,
        Paint()..color = AppColors.orange);
    canvas.drawCircle(Offset(size.width*0.72, size.height*0.14), 12,
        Paint()..color = AppColors.orange);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// SCREEN 5 — ARRIVED

class ArrivedScreen extends StatelessWidget {
  final List<PlaceModel> places;
  final int currentIndex;
  const ArrivedScreen(
      {super.key, required this.places, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final place = places[currentIndex];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text('لقد وصلت',
                  style: AppTextStyles.display()
                      .copyWith(fontSize: 28, color: AppColors.orange)),
              const SizedBox(height: 6),
              Text(place.name, style: AppTextStyles.title()),
              const SizedBox(height: 24),
              const GlowOrb(size: 150, pulse: true),
              const SizedBox(height: 18),
              AppCard(
                child: Text(place.transition,
                    style: AppTextStyles.body(),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right),
              ),
              const Spacer(),
              AppButton(
                label: 'ابدأ الجولة',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => AudioScreen(
                            places: places,
                            currentIndex: currentIndex))),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}


// SCREEN 6 — AUDIO
// Generates story via LLM, displays text, plays TTS.
// Next/prev navigate through the route checkpoints.

class AudioScreen extends StatefulWidget {
  final List<PlaceModel> places;
  final int currentIndex;
  const AudioScreen(
      {super.key, required this.places, required this.currentIndex});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  final ApiService _api = ApiService();
  final TtsService _tts = TtsService();

  bool   _loading = true;
  bool   _playing = false;
  String _story   = '';

  PlaceModel get _place => widget.places[widget.currentIndex];

  @override
  void initState() {
    super.initState();
    _tts.init();
    // Reset play button when audio ends naturally
    _tts.onPlaybackEnded = () {
      if (mounted) setState(() => _playing = false);
    };
    _loadStory();
  }

  Future<void> _loadStory() async {
    setState(() { _loading = true; _story = ''; _playing = false; });
    try {
      final story = await _api.getStory(_place);
      if (!mounted) return;
      setState(() { _story = story; _loading = false; });
      await _tts.speak(story);
      if (!mounted) return;
      setState(() => _playing = true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _story   = 'حدث خطأ أثناء تحميل القصة.';
        _loading = false;
        _playing = false;
      });
    }
  }

  Future<void> _togglePlay() async {
    if (_story.isEmpty) return;
    if (_playing) {
      await _tts.pause();
      if (!mounted) return;
      setState(() => _playing = false);
    } else {
      // Resume from current position — does NOT restart from beginning
      await _tts.resume();
      if (!mounted) return;
      setState(() => _playing = true);
    }
  }

  Future<void> _goNext() async {
    await _tts.stop();
    if (!mounted) return;
    if (widget.currentIndex < widget.places.length - 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => AudioScreen(
              places: widget.places,
              currentIndex: widget.currentIndex + 1)));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => SummaryScreen(places: widget.places)));
    }
  }

  Future<void> _goPrev() async {
    await _tts.stop();
    if (!mounted) return;
    if (widget.currentIndex > 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => AudioScreen(
              places: widget.places,
              currentIndex: widget.currentIndex - 1)));
    }
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = widget.currentIndex == widget.places.length - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await _tts.stop();
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    child: Text('إيقاف',
                        style: AppTextStyles.body(color: AppColors.orange)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.brownCard,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'محطة ${widget.currentIndex + 1} من ${widget.places.length}',
                      style: AppTextStyles.caption(color: AppColors.orange),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GlowOrb(size: 150, pulse: _playing),
              const SizedBox(height: 20),
              Text(_place.name,
                  style: AppTextStyles.title(),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              // Story card
              Expanded(
                child: AppCard(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.orange))
                      : SingleChildScrollView(
                          child: Text(_story,
                              style: AppTextStyles.body(),
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // Playback controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: widget.currentIndex > 0 ? _goPrev : null,
                    icon: const Icon(Icons.skip_previous_rounded,
                        color: AppColors.white),
                    iconSize: 34,
                  ),
                  const SizedBox(width: 18),
                  IconButton(
                    onPressed: _loading ? null : _togglePlay,
                    icon: Icon(
                      _playing
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: AppColors.orange,
                    ),
                    iconSize: 56,
                  ),
                  const SizedBox(width: 18),
                  IconButton(
                    onPressed: _loading ? null : _goNext,
                    icon: const Icon(Icons.skip_next_rounded,
                        color: AppColors.white),
                    iconSize: 34,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppButton(
                label:     isLast ? 'إنهاء الجولة' : 'التالي',
                onPressed: _loading ? () {} : _goNext,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}


// SCREEN 7 — SUMMARY

class SummaryScreen extends StatelessWidget {
  final List<PlaceModel> places;
  const SummaryScreen({super.key, required this.places});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const GlowOrb(size: 100),
                const SizedBox(height: 28),
                Text('اكتملت الجولة',
                    style: AppTextStyles.display().copyWith(fontSize: 30)),
                const SizedBox(height: 10),
                Text('شكراً لمرافقتنا في هذه الرحلة',
                    style: AppTextStyles.caption()),
                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MetricBox(value: '${places.length * 5}', label: 'دقيقة'),
                    const SizedBox(width: 12),
                    MetricBox(value: '${places.length}',     label: 'محطات'),
                  ],
                ),
                const SizedBox(height: 26),
                AppButton(
                  label: 'العودة للرئيسية',
                  onPressed: () =>
                      Navigator.popUntil(context, (r) => r.isFirst),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
