import 'dart:async';
import 'dart:math';
import '../models/place_model.dart';

/// Simulates GPS movement along a predefined route.
/// Interpolates coordinates between checkpoints and fires a callback
/// whenever the fake position enters the radius of the next point.
class LocationSimulator {
  final List<PlaceModel> places;
  final void Function(int index) onArrived; // called when reaching a point
  final void Function(double lat, double lng, double progress) onPositionUpdate;

  int     _currentTarget = 0;   // index of the point we are walking toward
  double  _fakeLat       = 0;
  double  _fakeLng       = 0;
  Timer?  _timer;
  bool    _running       = false;
  bool    _arrived       = false; // waiting for story to finish before walking

  // How often we update the position (every 500ms = smooth animation)
  static const _tickMs = 500;

  // Speed: fraction of the distance covered per tick
  // 0.04 means ~20 ticks to cross from one point to the next = ~10 seconds
  static const _stepFraction = 0.04;

  LocationSimulator({
    required this.places,
    required this.onArrived,
    required this.onPositionUpdate,
  });

  /// Start simulating from a given index.
  void start(int fromIndex) {
    _currentTarget = fromIndex;
    _fakeLat = places[fromIndex].lat;
    _fakeLng = places[fromIndex].lng;
    _running = true;
    _arrived = false;

    // Immediately fire arrival at the first point
    _arrived = true;
    onArrived(fromIndex);

    _timer = Timer.periodic(
      const Duration(milliseconds: _tickMs),
      (_) => _tick(),
    );
  }

  /// Call this after the story for the current point has finished playing.
  /// This releases the simulator to start walking toward the next point.
  void continueWalking() {
    _arrived = false;
  }

  void pause()  => _running = false;
  void resume() => _running = true;

  void stop() {
    _timer?.cancel();
    _timer   = null;
    _running = false;
  }

  void dispose() => stop();

  // ── Internal tick ──────────────────────────────────────────────────────────
  void _tick() {
    if (!_running || _arrived) return;

    // If we've reached the last point, stop
    if (_currentTarget >= places.length - 1) return;

    final nextIndex = _currentTarget + 1;
    final target    = places[nextIndex];

    // Interpolate toward target
    final dLat = target.lat - _fakeLat;
    final dLng = target.lng - _fakeLng;

    _fakeLat += dLat * _stepFraction;
    _fakeLng += dLng * _stepFraction;

    // Calculate how far along we are (0.0 → 1.0)
    final from     = places[_currentTarget];
    final totalD   = _distance(from.lat, from.lng, target.lat, target.lng);
    final remainD  = _distance(_fakeLat, _fakeLng, target.lat, target.lng);
    final progress = totalD > 0 ? (1 - remainD / totalD).clamp(0.0, 1.0) : 1.0;

    onPositionUpdate(_fakeLat, _fakeLng, progress);

    // Check if we entered the radius of the next point
    final distToTarget = _distance(_fakeLat, _fakeLng, target.lat, target.lng);
    if (distToTarget <= target.radius) {
      _fakeLat       = target.lat;
      _fakeLng       = target.lng;
      _currentTarget = nextIndex;
      _arrived       = true;
      onPositionUpdate(_fakeLat, _fakeLng, 1.0);
      onArrived(nextIndex);
    }
  }

  // ── Haversine distance in metres ──────────────────────────────────────────
  static double _distance(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0; // Earth radius in metres
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) *
            sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180;

  /// Distance in metres between two route points (for display)
  static double distanceBetween(PlaceModel a, PlaceModel b) =>
      _distance(a.lat, a.lng, b.lat, b.lng);
}
