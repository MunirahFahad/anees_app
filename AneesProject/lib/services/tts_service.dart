import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class TtsService {
  // ─── CONFIGURATION ──────────────────────────────────────────────────────
  // Replace the value below with your real TTS API key before running.
  static const String _baseUrl = 'https://elmodels.ngrok.app';
  static const String _apiKey  = 'Your TTS API key here';

  final AudioPlayer _player = AudioPlayer();
  bool isPlaying = false;

  /// Fires when audio finishes naturally (not on stop/pause).
  /// AudioScreen uses this to reset the play button UI.
  void Function()? onPlaybackEnded;

  // ─── Init ────────────────────────────────────────────────────────────────
  Future<void> init() async {
    _player.onPlayerComplete.listen((_) {
      isPlaying = false;
      onPlaybackEnded?.call();
    });
  }

  // ─── Speak: fetch audio → save to temp file → play ───────────────────────
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await stop(); // stop any currently playing audio first

    // 1. Call TTS API
    final response = await http.post(
      Uri.parse('$_baseUrl/v1/audio/speech'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'elm-tts',
        'voice': 'default',
        'input': text,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('TTS error ${response.statusCode}: ${response.body}');
    }

    // 2. Save audio bytes to a temp file
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/anees_tts.wav');
    await file.writeAsBytes(response.bodyBytes);

    // 3. Play
    await _player.play(DeviceFileSource(file.path));
    isPlaying = true;
  }

  // ─── Pause (keeps position) ───────────────────────────────────────────────
  Future<void> pause() async {
    await _player.pause();
    isPlaying = false;
  }

  // ─── Resume from where it was paused ─────────────────────────────────────
  Future<void> resume() async {
    await _player.resume();
    isPlaying = true;
  }

  // ─── Stop and reset to beginning ─────────────────────────────────────────
  Future<void> stop() async {
    await _player.stop();
    isPlaying = false;
  }

  // ─── Dispose when screen is closed ───────────────────────────────────────
  Future<void> dispose() async {
    onPlaybackEnded = null;
    await _player.dispose();
    isPlaying = false;
  }
}
