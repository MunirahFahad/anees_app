import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AsrService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  // ── CONFIGURATION ─────────────────────────────────────────────────────────
  static const String _baseUrl = 'https://elmodels.ngrok.app';
  static const String _apiKey  = 'YOUR_ASR_KEY_HERE';

  bool _isInitialized = false;
  bool _isRecording   = false;
  bool get isRecording => _isRecording;
  String? _recordingPath;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('[ASR] ❌ Microphone permission denied');
      return;
    }
    await _recorder.openRecorder();
    _isInitialized = true;
    debugPrint('[ASR] ✅ Recorder initialized');
  }

  // ── Start recording ───────────────────────────────────────────────────────
  Future<void> startRecording() async {
    if (!_isInitialized) await init();
    if (!_isInitialized) return;

    final dir = await getTemporaryDirectory();
    _recordingPath = '${dir.path}/anees_asr.wav';

    // Delete previous recording if it exists
    final existing = File(_recordingPath!);
    if (await existing.exists()) await existing.delete();

    await _recorder.startRecorder(
      toFile: _recordingPath,
      codec: Codec.pcm16WAV,
      sampleRate: 16000,
      numChannels: 1,
    );
    _isRecording = true;
    debugPrint('[ASR] 🎤 Recording started → $_recordingPath');
  }

  // ── Stop + transcribe ─────────────────────────────────────────────────────
  Future<String> stopAndTranscribe() async {
    if (!_isRecording) {
      debugPrint('[ASR] ⚠️ Not recording');
      return '';
    }
    _isRecording = false;
    await _recorder.stopRecorder();
    debugPrint('[ASR] ⏹ Recording stopped');

    if (_recordingPath == null) return '';

    final audioFile = File(_recordingPath!);
    if (!await audioFile.exists()) {
      debugPrint('[ASR] ❌ Audio file not found');
      return '';
    }

    final fileSize = await audioFile.length();
    debugPrint('[ASR] 📦 File size: $fileSize bytes');

    // If less than 1KB the user likely didn't say anything
    if (fileSize < 1000) {
      debugPrint('[ASR] ❌ Recording too short — probably silence');
      return '';
    }

    try {
      // ── Send as multipart/form-data ──────────────────────────────────────
      // This is the correct format for OpenAI-compatible ASR APIs.
      // The old base64 JSON approach was wrong for most ASR endpoints.
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/v1/audio/transcriptions'),
      );

      request.headers['Authorization'] = 'Bearer $_apiKey';

      request.files.add(await http.MultipartFile.fromPath(
        'file',                   // field name expected by OpenAI-compatible APIs
        _recordingPath!,
        filename: 'recording.wav',
      ));

      request.fields['model']    = 'elm-asr';
      request.fields['language'] = 'ar';

      debugPrint('[ASR] 📡 Sending to API...');
      final streamed  = await request.send();
      final response  = await http.Response.fromStream(streamed);

      debugPrint('[ASR] 📥 Status:  ${response.statusCode}');
      debugPrint('[ASR] 📥 Body:    ${response.body}');

      if (response.statusCode != 200) {
        debugPrint('[ASR] ❌ API returned ${response.statusCode}');
        return '';
      }

      // Parse response
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      // OpenAI standard: {"text": "..."}
      String text = (data['text'] as String? ?? '').trim();

      // Some APIs use {"results": [{"transcript": "..."}]}
      if (text.isEmpty && data['results'] is List) {
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          text = (results[0]['transcript'] as String? ?? '').trim();
        }
      }

      debugPrint('[ASR] ✅ Transcribed: "$text"');
      return text;

    } catch (e) {
      debugPrint('[ASR] ❌ Exception: $e');
      return '';
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────
  Future<void> dispose() async {
    if (_isRecording) await _recorder.stopRecorder();
    await _recorder.closeRecorder();
    _isInitialized = false;
    _isRecording   = false;
  }
}
