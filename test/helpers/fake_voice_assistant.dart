/// FakeVoiceAssistant — test double for VoiceAssistantBase.
///
/// Implements [VoiceAssistantBase] without using any platform plugins
/// (no FlutterTts, no AudioPlayer, no AudioRecorder).  This allows
/// [VoiceLoopController] unit tests to run in the Dart VM without
/// WidgetsFlutterBinding or any platform channels.
library;

import 'dart:async';

import 'package:gharvest/services/ai_bridge_service.dart';
import 'package:gharvest/voice_assistant.dart';
import 'package:gharvest/voice_preferences.dart';

class FakeVoiceAssistant implements VoiceAssistantBase {
  // ── Configuration ──────────────────────────────────────────────────────

  /// Whether [startListening] succeeds (true) or throws a permission error.
  bool permissionGranted = true;

  /// If non-null, [startListening] throws with this message.
  String? startListeningError;

  /// Reply returned by [stopListening]; uses a sensible default if null.
  VoiceReply? stopReply;

  /// If non-null, [stopListening] throws with this message.
  String? stopListeningError;

  // ── Tracking ───────────────────────────────────────────────────────────

  int startListeningCallCount = 0;
  int stopListeningCallCount = 0;
  int stopCallCount = 0;
  int cancelRecordingCallCount = 0;
  int speakCallCount = 0;
  int startBargeInMonitorCallCount = 0;
  int stopBargeInMonitorCallCount = 0;
  String? lastSpokenText;

  // ── Internal state ─────────────────────────────────────────────────────

  bool _recording = false;
  bool _ttsPlaying = false;

  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();

  // ── VoiceAssistantBase interface ───────────────────────────────────────

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  bool get isRecording => _recording;

  @override
  bool get isPlaying => _ttsPlaying;

  @override
  String get selectedLanguage => 'en-GH';

  @override
  VoicePreferences get voicePrefs => const VoicePreferences(
        continuousMode: false,
        autoSpeak: true,
      );

  @override
  void Function()? onTtsComplete;

  @override
  Future<void> startListening() async {
    startListeningCallCount++;
    if (startListeningError != null) {
      throw AiBridgeException(startListeningError!);
    }
    if (!permissionGranted) {
      throw const AiBridgeException(
        'Microphone permission was not granted.',
      );
    }
    _recording = true;
  }

  @override
  Future<VoiceReply?> stopListening({bool shouldSpeak = false}) async {
    stopListeningCallCount++;
    _recording = false;
    if (stopListeningError != null) {
      throw AiBridgeException(stopListeningError!);
    }
    return stopReply ??
        const VoiceReply(
          transcript: 'Test transcript',
          reply: AiReply(message: 'Test Kofi response'),
          conversationId: 'conv-1',
        );
  }

  @override
  Future<void> cancelRecording() async {
    cancelRecordingCallCount++;
    _recording = false;
  }

  @override
  Future<void> startBargeInMonitor() async {
    startBargeInMonitorCallCount++;
  }

  @override
  Future<void> stopBargeInMonitor() async {
    stopBargeInMonitorCallCount++;
  }

  @override
  Future<void> stop() async => stopPlayback();

  @override
  Future<void> promoteBargeInToRecording() async {
    _recording = true;
  }

  @override
  Future<void> stopPlayback({bool keepMicrophone = false}) async {
    stopCallCount++;
    onTtsComplete = null;
    _ttsPlaying = false;
    if (!keepMicrophone) _recording = false;
  }

  @override
  Future<void> speak(String text) async {
    speakCallCount++;
    lastSpokenText = text;
    _ttsPlaying = true;
    // TTS completion is triggered manually via simulateTtsComplete().
  }


  @override
  Future<void> dispose() async {
    onTtsComplete = null;
    _recording = false;
    _ttsPlaying = false;
    await _amplitudeController.close();
  }

  // ── Test helpers ───────────────────────────────────────────────────────

  /// Emit an amplitude value into the stream (simulates mic level).
  void emitAmplitude(double db) {
    if (!_amplitudeController.isClosed) {
      _amplitudeController.add(db);
    }
  }

  /// Simulate natural TTS completion (fires [onTtsComplete]).
  void simulateTtsComplete() {
    _ttsPlaying = false;
    onTtsComplete?.call();
  }
}
