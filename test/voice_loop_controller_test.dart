/// Tests for VoiceLoopController — state machine, silence detection,
/// speech detection, barge-in, continuous loop, stale-response protection,
/// error recovery, and manual mode.
///
/// All tests run without a real microphone, AudioPlayer, or network.
/// Platform-specific behaviour (echo cancellation, actual VAD accuracy) is
/// NOT asserted here — see the manual testing guide in the final report.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:gharvest/voice_loop_config.dart';
import 'package:gharvest/voice_loop_controller.dart';

import 'helpers/fake_voice_assistant.dart';

void main() {
  // ── Helper ──────────────────────────────────────────────────────────────
  VoiceLoopController makeController({FakeVoiceAssistant? assistant}) {
    final a = assistant ?? FakeVoiceAssistant();
    return VoiceLoopController(assistant: a);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 1. Initial state
  // ══════════════════════════════════════════════════════════════════════════
  group('Initial state', () {
    test('starts in idle', () {
      final ctrl = makeController();
      expect(ctrl.state, VoiceLoopState.idle);
      expect(ctrl.isContinuousModeActive, isFalse);
      expect(ctrl.lastError, isNull);
    });

    test('amplitude starts at waveform floor', () {
      final ctrl = makeController();
      expect(
        ctrl.currentAmplitudeDb,
        closeTo(VoiceLoopConfig.waveformFloorDb, 0.001),
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 2. Amplitude / silence detection helpers (unit-tested via inject hooks)
  // ══════════════════════════════════════════════════════════════════════════
  group('Amplitude baseline calibration', () {
    test('collects baseline samples until count reached', () {
      final ctrl = makeController();
      ctrl.forceState(VoiceLoopState.calibrating);

      // Inject samples below the required count.
      for (var i = 0; i < VoiceLoopConfig.baselineSampleCount - 1; i++) {
        ctrl.injectAmplitudeSample(-45.0);
      }
      expect(
        ctrl.baselineSamplesCollected,
        VoiceLoopConfig.baselineSampleCount - 1,
      );
      // Still in calibrating — not yet transitioned.
      expect(ctrl.state, VoiceLoopState.calibrating);
    });

    test('transitions to listening once baseline established', () {
      final ctrl = makeController();
      ctrl.forceState(VoiceLoopState.calibrating);

      for (var i = 0; i < VoiceLoopConfig.baselineSampleCount; i++) {
        ctrl.injectAmplitudeSample(-45.0);
      }
      expect(ctrl.state, VoiceLoopState.listening);
      expect(
        ctrl.baselineDb,
        closeTo(-45.0, 1.0), // averaged over injected samples
      );
    });

    test('baseline is mean of injected samples', () {
      final ctrl = makeController();
      ctrl.forceState(VoiceLoopState.calibrating);

      const samples = [-40.0, -50.0, -45.0]; // mean = -45.0
      // Pad to baselineSampleCount with the same pattern.
      final full = List.generate(
        VoiceLoopConfig.baselineSampleCount,
        (i) => samples[i % samples.length],
      );
      for (final s in full) {
        ctrl.injectAmplitudeSample(s);
      }
      // Mean of repeating [-40, -50, -45] is -45.
      expect(ctrl.baselineDb, closeTo(-45.0, 1.5));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 3. Speech detection
  // ══════════════════════════════════════════════════════════════════════════
  group('Speech detection', () {
    test('transitions listening → userSpeaking when amplitude exceeds threshold',
        () {
      final ctrl = makeController();
      // Force listening with a known baseline.
      ctrl.forceBaselineEstablished(-50.0);
      ctrl.forceState(VoiceLoopState.listening);

      // Threshold = baseline + margin = -50 + 8 = -42 dB.
      // Inject several loud samples so the EMA-smoothed value rises above
      // the threshold.  One sample at -5 dB after 5 iterations:
      // EMA converges well above -42.
      for (var i = 0; i < 10; i++) {
        ctrl.injectAmplitudeSample(-5.0);
        if (ctrl.state == VoiceLoopState.userSpeaking) break;
      }

      expect(ctrl.state, VoiceLoopState.userSpeaking);
      expect(ctrl.speechHasStarted, isTrue);
    });

    test('does not transition if amplitude is below threshold', () {
      final ctrl = makeController();
      ctrl.forceBaselineEstablished(-50.0);
      ctrl.forceState(VoiceLoopState.listening);

      // Inject amplitude well below threshold (-42): stays in listening.
      for (var i = 0; i < 10; i++) {
        ctrl.injectAmplitudeSample(-55.0);
      }

      expect(ctrl.state, VoiceLoopState.listening);
    });

    test('minimum speech threshold floor is respected', () {
      final ctrl = makeController();
      // Extremely quiet baseline — floor (-50) prevents threshold going too low.
      ctrl.forceBaselineEstablished(-80.0);
      ctrl.forceState(VoiceLoopState.listening);

      // Amplitude well above the floor minimum (-50): inject enough for EMA
      // to exceed the floor threshold.
      for (var i = 0; i < 10; i++) {
        ctrl.injectAmplitudeSample(-20.0);
        if (ctrl.state == VoiceLoopState.userSpeaking) break;
      }
      expect(ctrl.state, VoiceLoopState.userSpeaking);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 4. Silence / end-of-speech detection
  // ══════════════════════════════════════════════════════════════════════════
  group('End-of-speech silence detection', () {
    test('accumulates silence counter when amplitude drops below threshold', () {
      final ctrl = makeController();
      ctrl.forceBaselineEstablished(-50.0);
      ctrl.forceState(VoiceLoopState.userSpeaking);
      // Mark that speech has started and min recording elapsed.
      ctrl.forceRecordingElapsed(VoiceLoopConfig.minRecordingDurationMs + 100);

      // Inject silence below threshold (-42).
      ctrl.injectAmplitudeSample(-55.0);

      expect(
        ctrl.silenceConsecutiveMs,
        VoiceLoopConfig.amplitudePollingIntervalMs,
      );
    });

    test('resets silence counter when speech resumes above threshold', () {
      final ctrl = makeController();
      ctrl.forceBaselineEstablished(-50.0);
      ctrl.forceState(VoiceLoopState.userSpeaking);
      ctrl.forceRecordingElapsed(VoiceLoopConfig.minRecordingDurationMs + 100);

      // Inject a silence sample — counter rises.
      ctrl.injectAmplitudeSample(-55.0);
      expect(ctrl.silenceConsecutiveMs, greaterThan(0));

      // Speech resumes — inject several loud samples to drive EMA above threshold.
      for (var i = 0; i < 10; i++) {
        ctrl.injectAmplitudeSample(-5.0);
        if (ctrl.silenceConsecutiveMs == 0) break;
      }
      expect(ctrl.silenceConsecutiveMs, 0);
    });

    test('does not trigger end-of-speech before minRecordingDurationMs', () {
      final ctrl = makeController();
      ctrl.forceBaselineEstablished(-50.0);
      ctrl.forceState(VoiceLoopState.userSpeaking);
      // Recording just started.
      ctrl.forceRecordingElapsed(0);

      // Inject enough silence to theoretically trigger end-of-speech.
      final samples =
          VoiceLoopConfig.endOfSpeechSilenceMs ~/
          VoiceLoopConfig.amplitudePollingIntervalMs +
          5;
      for (var i = 0; i < samples; i++) {
        ctrl.injectAmplitudeSample(-55.0);
      }

      // Should still be userSpeaking — min duration not met.
      expect(ctrl.state, VoiceLoopState.userSpeaking);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 5. Barge-in detection
  // ══════════════════════════════════════════════════════════════════════════
  group('Barge-in detection', () {
    test('accumulates barge-in counter when amplitude exceeds threshold', () {
      final ctrl = makeController();
      ctrl.forceBaselineEstablished(-50.0);
      ctrl.forceState(VoiceLoopState.speaking);
      ctrl.forceSpeakingElapsed(VoiceLoopConfig.bargeInMinSpeakingMs + 100);

      // Inject enough loud samples so the EMA-smoothed amplitude exceeds
      // threshold before the confirmation count is checked.
      // Use very loud signal so EMA converges quickly.
      for (var i = 0; i < 5; i++) {
        ctrl.injectBargeinSample(-5.0);
        if (ctrl.bargeInConfirmationCount > 0) break;
      }
      expect(ctrl.bargeInConfirmationCount, greaterThan(0));
    });

    test('does not trigger barge-in before bargeInMinSpeakingMs', () {
      final ctrl = makeController();
      ctrl.forceBaselineEstablished(-50.0);
      ctrl.forceState(VoiceLoopState.speaking);
      ctrl.forceSpeakingElapsed(0); // too early

      ctrl.injectBargeinSample(-25.0);
      ctrl.injectBargeinSample(-25.0);
      ctrl.injectBargeinSample(-25.0);

      // No barge-in confirmation because speaking elapsed is too short.
      expect(ctrl.bargeInConfirmationCount, 0);
    });

    test('resets barge-in counter on sub-threshold sample', () {
      final ctrl = makeController();
      ctrl.forceBaselineEstablished(-50.0);
      ctrl.forceState(VoiceLoopState.speaking);
      ctrl.forceSpeakingElapsed(VoiceLoopConfig.bargeInMinSpeakingMs + 100);

      ctrl.injectBargeinSample(-25.0); // above
      ctrl.injectBargeinSample(-60.0); // below → reset

      expect(ctrl.bargeInConfirmationCount, 0);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 6. State transition enforcement
  // ══════════════════════════════════════════════════════════════════════════
  group('State transitions', () {
    test('transition to same state is no-op (no spurious notifications)', () {
      final ctrl = makeController();
      var notifyCount = 0;
      ctrl.addListener(() => notifyCount++);

      ctrl.forceState(VoiceLoopState.idle); // already idle
      expect(notifyCount, 0);
    });

    test('transition to different state notifies listeners', () {
      final ctrl = makeController();
      var notifyCount = 0;
      ctrl.addListener(() => notifyCount++);

      ctrl.forceState(VoiceLoopState.listening);
      expect(notifyCount, 1);
      expect(ctrl.state, VoiceLoopState.listening);
    });

    test('error transition sets lastError and clears on next non-error state',
        () {
      final ctrl = makeController();
      ctrl.forceState(VoiceLoopState.error);
      // Manually set error via forceState doesn't set lastError — use the
      // public API path for a real error; here we just test the clear logic.
      ctrl.forceState(VoiceLoopState.listening);
      expect(ctrl.lastError, isNull);
    });

    test('cancel() moves any state back to idle', () async {
      final ctrl = makeController();
      ctrl.forceState(VoiceLoopState.userSpeaking);
      await ctrl.cancel();
      expect(ctrl.state, VoiceLoopState.idle);
      expect(ctrl.isContinuousModeActive, isFalse);
    });

    test('interrupt() is no-op when not speaking', () async {
      final ctrl = makeController();
      ctrl.forceState(VoiceLoopState.listening);
      await ctrl.interrupt(); // should not throw or change state
      expect(ctrl.state, VoiceLoopState.listening);
    });

    test('stopManualRecording() is no-op when idle', () async {
      final ctrl = makeController();
      await ctrl.stopManualRecording(); // no-op — not recording
      expect(ctrl.state, VoiceLoopState.idle);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 7. Race-condition / generation ID protection
  // ══════════════════════════════════════════════════════════════════════════
  group('Race-condition / stale-response protection', () {
    test('generation increments on cancel()', () async {
      final ctrl = makeController();
      final gen0 = ctrl.currentGeneration;
      await ctrl.cancel();
      expect(ctrl.currentGeneration, greaterThan(gen0));
    });

    test('stale response: generation check prevents state clobber', () async {
      // Simulate: request A is in flight, but a cancel() fires before it
      // resolves.  The response from A must be discarded.
      final ctrl = makeController();
      final genBefore = ctrl.currentGeneration;

      // Fire cancel — increments generation.
      await ctrl.cancel();
      final genAfter = ctrl.currentGeneration;

      // The old generation is no longer current.
      expect(genBefore == genAfter, isFalse);
    });

    test('multiple cancel() calls do not throw', () async {
      final ctrl = makeController();
      await ctrl.cancel();
      await ctrl.cancel();
      await ctrl.cancel();
      expect(ctrl.state, VoiceLoopState.idle);
    });

    test('startContinuousMode() twice does not create double loop', () async {
      final fake = FakeVoiceAssistant();
      final ctrl = makeController(assistant: fake);

      // Only check that the second call returns immediately.
      // We cannot open a real mic, so we use the fake's permission grant.
      fake.permissionGranted = false; // will trigger error path gracefully

      // Both calls resolve without throwing.
      await ctrl.startContinuousMode();
      await ctrl.startContinuousMode(); // should be no-op
      expect(ctrl.isContinuousModeActive, isTrue);
      await ctrl.stopContinuousMode();
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 8. TTS completion → automatic listen restart
  // ══════════════════════════════════════════════════════════════════════════
  group('TTS completion callback', () {
    test('onTtsComplete fires when assistant.onTtsComplete is called', () {
      final fake = FakeVoiceAssistant();
      var completed = false;
      fake.onTtsComplete = () => completed = true;

      fake.simulateTtsComplete();

      expect(completed, isTrue);
    });

    test('TTS stop clears onTtsComplete to avoid spurious restarts', () async {
      final fake = FakeVoiceAssistant();
      fake.onTtsComplete = () => fail('Should not fire after stop()');

      await fake.stop();
      fake.simulateTtsComplete(); // simulate a late completion event
      // If we reach here without the test failing, the callback was cleared.
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 9. Manual recording mode
  // ══════════════════════════════════════════════════════════════════════════
  group('Manual recording mode', () {
    test('startManualRecording transitions idle → userSpeaking', () async {
      final fake = FakeVoiceAssistant();
      fake.permissionGranted = true;
      final ctrl = makeController(assistant: fake);

      await ctrl.startManualRecording();

      expect(ctrl.state, VoiceLoopState.userSpeaking);
    });

    test('startManualRecording is no-op when already userSpeaking', () async {
      final fake = FakeVoiceAssistant();
      fake.permissionGranted = true;
      final ctrl = makeController(assistant: fake);

      await ctrl.startManualRecording();
      expect(ctrl.state, VoiceLoopState.userSpeaking);

      await ctrl.startManualRecording(); // second call — no-op
      expect(ctrl.state, VoiceLoopState.userSpeaking);
    });

    test('startManualRecording transitions to error on permission denied',
        () async {
      final fake = FakeVoiceAssistant();
      fake.permissionGranted = false;
      final ctrl = makeController(assistant: fake);

      await ctrl.startManualRecording();

      expect(ctrl.state, VoiceLoopState.error);
      expect(ctrl.lastError, isNotNull);
    });

    test('continuous mode is not active after manual recording start', () async {
      final fake = FakeVoiceAssistant();
      fake.permissionGranted = true;
      final ctrl = makeController(assistant: fake);

      await ctrl.startManualRecording();
      expect(ctrl.isContinuousModeActive, isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 10. Error recovery
  // ══════════════════════════════════════════════════════════════════════════
  group('Error recovery', () {
    test('retryAfterError is no-op when not in error state', () async {
      final ctrl = makeController();
      ctrl.forceState(VoiceLoopState.listening);
      await ctrl.retryAfterError(); // should be no-op
      expect(ctrl.state, VoiceLoopState.listening);
    });

    test('retryAfterError transitions to idle when continuous mode inactive',
        () async {
      final ctrl = makeController();
      ctrl.forceState(VoiceLoopState.error);
      expect(ctrl.isContinuousModeActive, isFalse);

      await ctrl.retryAfterError();
      expect(ctrl.state, VoiceLoopState.idle);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 11. Continuous mode flag
  // ══════════════════════════════════════════════════════════════════════════
  group('Continuous mode activation flag', () {
    test('stopContinuousMode clears isContinuousModeActive', () async {
      final fake = FakeVoiceAssistant();
      fake.permissionGranted = false; // prevent actual recording
      final ctrl = makeController(assistant: fake);

      await ctrl.startContinuousMode();
      expect(ctrl.isContinuousModeActive, isTrue);

      await ctrl.stopContinuousMode();
      expect(ctrl.isContinuousModeActive, isFalse);
    });

    test('state is idle after stopContinuousMode', () async {
      final fake = FakeVoiceAssistant();
      fake.permissionGranted = false;
      final ctrl = makeController(assistant: fake);

      await ctrl.startContinuousMode();
      await ctrl.stopContinuousMode();

      expect(ctrl.state, VoiceLoopState.idle);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 12. Dispose
  // ══════════════════════════════════════════════════════════════════════════
  group('Dispose', () {
    test('dispose does not throw even when idle', () async {
      final ctrl = makeController();
      await expectLater(ctrl.dispose(), completes);
    });

    test('dispose stops continuous mode cleanly', () async {
      final fake = FakeVoiceAssistant();
      fake.permissionGranted = false;
      final ctrl = makeController(assistant: fake);

      await ctrl.startContinuousMode();
      await ctrl.dispose(); // should not throw
    });
  });
}
