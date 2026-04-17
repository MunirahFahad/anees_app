import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/components.dart';
import '../models/place_model.dart';
import '../services/api_services.dart';
import '../services/tts_service.dart';
import '../services/asr_service.dart';
import '../services/location_simulator.dart';

class JourneyScreen extends StatefulWidget {
  final List<PlaceModel> places;
  const JourneyScreen({super.key, required this.places});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen>
    with TickerProviderStateMixin {

  final ApiService _api = ApiService();
  final TtsService _tts = TtsService();
  final AsrService _asr = AsrService();
  late LocationSimulator _sim;

  int    _currentIndex  = 0;
  String _storyText     = '';
  String _walkingText   = '';
  String _qaText        = '';
  bool   _isPaused      = false;
  bool   _isFinished    = false;
  _Phase _phase         = _Phase.walking;

  double _walkProgress  = 0.0;
  double _distRemaining = 0.0;

  static const _timeoutSec = 25;
  int    _countdown = _timeoutSec;
  Timer? _countdownTimer;

  // Token-based audio routing — prevents phase collisions
  _AudioToken _expectedToken = _AudioToken.none;

  late AnimationController _orbCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _arcCtrl;
  late Animation<double>   _orbAnim;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();

    _orbCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _orbAnim = Tween<double>(begin: 0.22, end: 0.55).animate(
        CurvedAnimation(parent: _orbCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _arcCtrl = AnimationController(
        vsync: this, duration: Duration(seconds: _timeoutSec));

    _tts.init();
    _asr.init();
    _tts.onPlaybackEnded = _onAudioFinished;

    _sim = LocationSimulator(
      places: widget.places,
      onArrived:        _onArrived,
      onPositionUpdate: _onPositionUpdate,
    );
    _sim.start(0);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _sim.dispose();
    _tts.dispose();
    _asr.dispose();
    _orbCtrl.dispose();
    _fadeCtrl.dispose();
    _arcCtrl.dispose();
    super.dispose();
  }

  // ── Simulator callbacks ───────────────────────────────────────────────────

  void _onArrived(int index) {
    if (!mounted) return;
    _countdownTimer?.cancel();
    setState(() {
      _currentIndex = index;
      _phase        = _Phase.loading;
      _walkProgress = 0.0;
      _storyText    = '';
      _walkingText  = '';
      _qaText       = '';
    });
    _loadStory();
  }

  void _onPositionUpdate(double lat, double lng, double progress) {
    if (!mounted) return;
    double dist = 0;
    if (_currentIndex < widget.places.length - 1) {
      dist = LocationSimulator.distanceBetween(
        PlaceModel(id:0, name:'', lat:lat, lng:lng, radius:0,
            type:'', role:'', history:'', sensory:'', transition:'',
            summary:'', keywords:[], qaContext:''),
        widget.places[_currentIndex + 1],
      );
    }
    setState(() { _walkProgress = progress; _distRemaining = dist; });
  }

  // ── Story ─────────────────────────────────────────────────────────────────

  Future<void> _loadStory() async {
    await _fadeCtrl.reverse();
    setState(() { _storyText = ''; });
    try {
      final story = await _api.getStory(widget.places[_currentIndex]);
      if (!mounted) return;
      await _fadeCtrl.forward();
      setState(() { _storyText = story; _phase = _Phase.speaking; });
      _expectedToken = _AudioToken.story;
      await _tts.speak(story);
    } catch (e) {
      if (!mounted) return;
      await _fadeCtrl.forward();
      setState(() {
        _storyText = 'تعذّر تحميل القصة. تأكد من مفتاح API.';
        _phase     = _Phase.speaking;
      });
      _afterStoryEnds();
    }
  }

  // ── Audio-finished router ─────────────────────────────────────────────────

  void _onAudioFinished() {
    if (!mounted || _isPaused) return;
    final token    = _expectedToken;
    _expectedToken = _AudioToken.none;
    switch (token) {
      case _AudioToken.story:          _afterStoryEnds();   break;
      case _AudioToken.questionPrompt: _showQuestionUI();   break;
      case _AudioToken.answer:         _startWalking();     break;
      case _AudioToken.transition:
        if (mounted) setState(() => _phase = _Phase.walking);
        break;
      case _AudioToken.none: break;
    }
  }

  void _afterStoryEnds() {
    final isLast = _currentIndex == widget.places.length - 1;
    if (isLast) {
      setState(() { _phase = _Phase.done; _isFinished = true; });
    } else {
      _playQuestionPrompt();
    }
  }

  // ── Question prompt ───────────────────────────────────────────────────────

  Future<void> _playQuestionPrompt() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.questionPrompt);
    const text = 'إذا كان لديك سؤال، اضغط على الدائرة للتحدث.';
    _expectedToken = _AudioToken.questionPrompt;
    await _tts.speak(text);
  }

  void _showQuestionUI() {
    if (!mounted) return;
    setState(() { _phase = _Phase.question; _countdown = _timeoutSec; });
    _arcCtrl.reset();
    _arcCtrl.forward();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) { t.cancel(); _startWalking(); }
    });
  }


  Future<void> _startWalking() async {
    if (!mounted) return;
    _countdownTimer?.cancel();
    _arcCtrl.stop();

    final isLast = _currentIndex == widget.places.length - 1;
    if (isLast) {
      setState(() { _phase = _Phase.done; _isFinished = true; });
      return;
    }

    final from = widget.places[_currentIndex];

    // Use the transition field directly from JSON — no API call needed
    final transitionText = from.transition.isNotEmpty
        ? from.transition
        : 'استمر في السير نحو النقطة التالية.';

    setState(() {
      _phase       = _Phase.walkingNarration;
      _walkingText = transitionText;
    });

    _sim.continueWalking();

    // Speak the transition text directly — no LLM call
    _expectedToken = _AudioToken.transition;
    await _tts.speak(transitionText);
  }

  // ── TOGGLE recording: first tap = start, second tap = stop ───────────────

  Future<void> _onOrbTap() async {
    // Only interactive during question phase
    if (_phase != _Phase.question && _phase != _Phase.recording) return;

    if (_phase == _Phase.question) {
      // ── START recording ──
      _countdownTimer?.cancel();
      _arcCtrl.stop();
      await _tts.stop();
      setState(() { _phase = _Phase.recording; _qaText = ''; });
      await _asr.startRecording();

    } else if (_phase == _Phase.recording) {
      // ── STOP recording and process ──
      setState(() => _phase = _Phase.processing);
      final question = await _asr.stopAndTranscribe();
      if (!mounted) return;

      if (question.isEmpty) {
        // ASR returned nothing — show text input fallback so user is not stuck
        _showTextInputFallback();
        return;
      }

      await _answerQuestion(question);
    }
  }

  // ── Text input fallback (shown when ASR returns empty) ────────────────────
  void _showTextInputFallback() {
    if (!mounted) return;
    setState(() { _phase = _Phase.question; _countdown = _timeoutSec; });

    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('لم يتم التعرف على الصوت',
                style: AppTextStyles.caption(color: AppColors.orange),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('اكتب سؤالك هنا أو اضغط تخطي',
                style: AppTextStyles.caption(),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: AppTextStyles.body(),
              cursorColor: AppColors.orange,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.send,
              onSubmitted: (text) async {
                final trimmed = text.trim();
                Navigator.pop(ctx);
                if (trimmed.isEmpty) {
                  _startWalking();
                } else {
                  await _answerQuestion(trimmed);
                }
              },
              decoration: InputDecoration(
                hintText: 'اكتب سؤالك...',
                hintStyle: AppTextStyles.caption(),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.orange),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'تخطي',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _startWalking();
                    },
                    backgroundColor: AppColors.brownCard,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'إرسال',
                    onPressed: () async {
                      final text = controller.text.trim();
                      Navigator.pop(ctx);
                      if (text.isEmpty) {
                        _startWalking();
                      } else {
                        await _answerQuestion(text);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).then((_) {
      // If user dismissed the sheet without doing anything → walk
      if (mounted && _phase == _Phase.question) _startWalking();
    });
  }

  // ── Send question to LLM and play answer ──────────────────────────────────
  Future<void> _answerQuestion(String question) async {
    if (!mounted) return;
    setState(() {
      _qaText = 'سؤالك: $question\n\nجاري البحث عن الإجابة...';
      _phase  = _Phase.answering;
    });

    try {
      final answer = await _api.answerQuestion(
          widget.places[_currentIndex], question);
      if (!mounted) return;
      setState(() => _qaText = 'سؤالك: $question\n\n$answer');
      _expectedToken = _AudioToken.answer;
      await _tts.speak(answer);
    } catch (_) {
      if (!mounted) return;
      setState(() => _qaText = 'تعذّر الحصول على إجابة.');
      _startWalking();
    }
  }

  // ── Pause / skip ──────────────────────────────────────────────────────────

  Future<void> _togglePause() async {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _sim.pause(); _orbCtrl.stop();
      _countdownTimer?.cancel(); _arcCtrl.stop();
      await _tts.pause();
    } else {
      _sim.resume(); _orbCtrl.repeat(reverse: true);
      switch (_phase) {
        case _Phase.speaking:
        case _Phase.answering:
        case _Phase.walkingNarration:
        case _Phase.questionPrompt:
          await _tts.resume();
          break;
        case _Phase.question:
          _arcCtrl.forward();
          _countdownTimer =
              Timer.periodic(const Duration(seconds: 1), (t) {
                if (!mounted) { t.cancel(); return; }
                setState(() => _countdown--);
                if (_countdown <= 0) { t.cancel(); _startWalking(); }
              });
          break;
        case _Phase.walking:
          _sim.continueWalking();
          break;
        default: break;
      }
    }
  }

  Future<void> _skipToNext() async {
    if (_currentIndex >= widget.places.length - 1) return;
    _expectedToken = _AudioToken.none;
    await _tts.stop();
    _startWalking();
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  String get _statusLabel {
    if (_isPaused) return 'متوقف مؤقتاً';
    return switch (_phase) {
      _Phase.loading          => 'جاري التحميل...',
      _Phase.speaking         => 'يُحكى...',
      _Phase.questionPrompt   => 'يُحكى...',
      _Phase.question         => 'اضغط الدائرة إذا كان لديك سؤال',
      _Phase.recording        => 'جاري التسجيل... اضغط مجدداً للإرسال',
      _Phase.processing       => 'جاري المعالجة...',
      _Phase.answering        => 'الإجابة...',
      _Phase.walkingNarration => 'في الطريق...',
      _Phase.walking          => _currentIndex < widget.places.length - 1
          ? 'في الطريق إلى ${widget.places[_currentIndex + 1].name}'
          : 'جاري المشي...',
      _Phase.done             => 'اكتملت الرحلة',
    };
  }

  IconData get _orbIcon => switch (_phase) {
    _Phase.loading          => Icons.hourglass_top_rounded,
    _Phase.speaking         => Icons.volume_up_rounded,
    _Phase.questionPrompt   => Icons.volume_up_rounded,
    _Phase.question         => Icons.mic_none_rounded,
    _Phase.recording        => Icons.stop_rounded,
    _Phase.processing       => Icons.hourglass_top_rounded,
    _Phase.answering        => Icons.volume_up_rounded,
    _Phase.walkingNarration => Icons.volume_up_rounded,
    _Phase.walking          => Icons.directions_walk_rounded,
    _Phase.done             => Icons.check_rounded,
  };

  bool get _orbGlows =>
      (_phase == _Phase.speaking  || _phase == _Phase.answering     ||
          _phase == _Phase.walkingNarration || _phase == _Phase.recording ||
          _phase == _Phase.questionPrompt) && !_isPaused;

  Color get _orbTint =>
      _phase == _Phase.recording
          ? const Color(0xFFE63A3A)
          : AppColors.orange;

  bool get _orbTappable =>
      _phase == _Phase.question || _phase == _Phase.recording;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final place  = widget.places[_currentIndex];
    final isLast = _currentIndex == widget.places.length - 1;
    final routeP = (_currentIndex +
        (_phase == _Phase.walking || _phase == _Phase.walkingNarration
            ? _walkProgress : 0.0)) /
        widget.places.length;

    final bool showWalkBar = _phase == _Phase.walking ||
        _phase == _Phase.walkingNarration;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ── Top bar ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () async {
                      _expectedToken = _AudioToken.none;
                      _sim.stop(); await _tts.stop();
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    child: Text('إنهاء',
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
                      'محطة ${_currentIndex + 1} من ${widget.places.length}',
                      style: AppTextStyles.caption(color: AppColors.orange),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Route progress ────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: routeP, minHeight: 4,
                  backgroundColor: AppColors.darkCard,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.orange),
                ),
              ),

              const SizedBox(height: 24),

              // ── Orb (tappable during question + recording) ────────
              GestureDetector(
                onTap: _orbTappable ? _onOrbTap : null,
                child: AnimatedBuilder(
                  animation: _orbAnim,
                  builder: (_, __) => Stack(
                    alignment: Alignment.center,
                    children: [
                      // Countdown arc
                      if (_phase == _Phase.question ||
                          _phase == _Phase.recording)
                        AnimatedBuilder(
                          animation: _arcCtrl,
                          builder: (_, __) => SizedBox(
                            width: 190, height: 190,
                            child: CircularProgressIndicator(
                              value: _phase == _Phase.recording
                                  ? null           // spinning = recording
                                  : 1 - _arcCtrl.value,
                              strokeWidth: 5,
                              backgroundColor: AppColors.darkCard,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _phase == _Phase.recording
                                    ? const Color(0xFFE63A3A)
                                    : AppColors.orange.withOpacity(0.6),
                              ),
                            ),
                          ),
                        ),
                      // Orb body
                      Container(
                        width: 164, height: 164,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _phase == _Phase.recording
                                  ? const Color(0xFFFF7070)
                                  : AppColors.orangeLight,
                              _orbTint,
                              _phase == _Phase.recording
                                  ? const Color(0xFF8B0000)
                                  : const Color(0xFFB44F1B),
                            ],
                            stops: const [0.15, 0.55, 1.0],
                          ),
                          boxShadow: [BoxShadow(
                            color: _orbTint.withOpacity(
                                _orbGlows ? _orbAnim.value : 0.18),
                            blurRadius:   _orbGlows ? 48 : 18,
                            spreadRadius: _orbGlows ? 14 :  2,
                          )],
                        ),
                        child: Center(
                          child: Container(
                            width: 118, height: 118,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.35),
                                  width: 2),
                            ),
                            child: Center(
                              child: Icon(_orbIcon,
                                  color: Colors.white.withOpacity(0.9),
                                  size: 44),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Place name ────────────────────────────────────────
              Text(place.name,
                  style: AppTextStyles.title(),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),

              // ── Status + distance + countdown ─────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_phase == _Phase.loading ||
                      _phase == _Phase.processing)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(width: 12, height: 12,
                          child: CircularProgressIndicator(
                              color: AppColors.orange, strokeWidth: 2)),
                    ),
                  Flexible(
                    child: Text(_statusLabel,
                        style: AppTextStyles.caption(color: AppColors.orange),
                        textAlign: TextAlign.center),
                  ),
                  if (showWalkBar && _distRemaining > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.brownCard,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('${_distRemaining.toStringAsFixed(0)} م',
                          style: AppTextStyles.caption(
                              color: AppColors.white)),
                    ),
                  ],
                  if (_phase == _Phase.question) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.brownCard,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('${_countdown}ث',
                          style: AppTextStyles.caption(
                              color: AppColors.white)),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 8),

              // ── Walk progress bar ─────────────────────────────────
              if (showWalkBar)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _walkProgress, minHeight: 6,
                      backgroundColor: AppColors.darkCard,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.brownBorder),
                    ),
                  ),
                ),

              // ── Text card ─────────────────────────────────────────
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: AppCard(
                    child: _storyText.isEmpty && _walkingText.isEmpty &&
                        _qaText.isEmpty
                        ? const Center(child: CircularProgressIndicator(
                        color: AppColors.orange))
                        : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (_storyText.isNotEmpty)
                            Text(_storyText,
                                style: AppTextStyles.body(),
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.right),
                          if (_walkingText.isNotEmpty) ...[
                            if (_storyText.isNotEmpty)
                              Divider(color: AppColors.brownBorder
                                  .withOpacity(0.4), height: 20),
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.end,
                              children: [
                                const Icon(
                                    Icons.directions_walk_rounded,
                                    color: AppColors.muted, size: 14),
                                const SizedBox(width: 4),
                                Text('نص الانتقال',
                                    style: AppTextStyles.caption()),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(_walkingText,
                                style: AppTextStyles.body(
                                    color: AppColors.muted),
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.right),
                          ],
                          if (_qaText.isNotEmpty) ...[
                            if (_storyText.isNotEmpty)
                              Divider(color: AppColors.brownBorder
                                  .withOpacity(0.4), height: 20),
                            Text(_qaText,
                                style: AppTextStyles.body(
                                    color: AppColors.orangeLight),
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.right),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Bottom controls ───────────────────────────────────
              if (!_isFinished)
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: _isPaused ? 'استئناف' : 'إيقاف مؤقت',
                        onPressed: _togglePause,
                        backgroundColor: AppColors.brownCard,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        label: 'تخطي ←',
                        onPressed: isLast ? () {} : _skipToNext,
                        backgroundColor:
                        isLast ? AppColors.darkCard : AppColors.orange,
                      ),
                    ),
                  ],
                ),

              if (_isFinished)
                AppButton(
                  label: 'عرض ملخص الرحلة',
                  onPressed: () => Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) =>
                          _SummaryScreen(places: widget.places))),
                ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Audio token ───────────────────────────────────────────────────────────────
enum _AudioToken { none, story, questionPrompt, answer, transition }

// ── Phase ─────────────────────────────────────────────────────────────────────
enum _Phase {
  loading, speaking, questionPrompt, question,
  recording, processing, answering,
  walkingNarration, walking, done,
}

// ── Summary ───────────────────────────────────────────────────────────────────
class _SummaryScreen extends StatelessWidget {
  final List<PlaceModel> places;
  const _SummaryScreen({required this.places});

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
                    MetricBox(value: '${places.length}', label: 'محطات'),
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
