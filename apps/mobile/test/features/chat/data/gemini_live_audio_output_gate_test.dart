import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_audio_output_gate.dart';

void main() {
  test('failed setup and cleanup cannot be mistaken for a prepared owner',
      () async {
    final gate = GeminiLiveAudioOutputGate();
    final owner = Object();
    var setupCalls = 0;
    var releaseCalls = 0;
    Future<void> setup() async {
      if (++setupCalls == 1) throw StateError('setup failed');
    }

    Future<void> release() async {
      if (++releaseCalls == 1) throw StateError('release failed');
    }

    await expectLater(gate.prepare(owner, setup: setup, release: release),
        throwsA(isA<StateError>()));
    await gate.prepare(owner, setup: setup, release: release);
    expect(setupCalls, 2);
    expect(releaseCalls, 2);
    await gate.release(owner);
  });

  test('a delayed prior cleanup or feed cannot touch the next call output',
      () async {
    final gate = GeminiLiveAudioOutputGate();
    final first = Object();
    final second = Object();
    final events = <String>[];
    await gate.prepare(first,
        setup: () async => events.add('setup:first'),
        release: () async => events.add('release:first'));
    await gate.prepare(second,
        setup: () async => events.add('setup:second'),
        release: () async => events.add('release:second'));

    await gate.feed(first, () async => events.add('stale:feed'));
    await gate.release(first);
    await gate.feed(second, () async => events.add('feed:second'));

    expect(events,
        ['setup:first', 'release:first', 'setup:second', 'feed:second']);
    expect(gate.owns(second), isTrue);
    await gate.release(second);
    expect(events.last, 'release:second');
  });

  testWidgets('a timed out release still excludes a new native setup',
      (tester) async {
    final gate = GeminiLiveAudioOutputGate();
    final first = Object();
    final second = Object();
    final released = Completer<void>();
    var secondSetupCalls = 0;
    await gate.prepare(first,
        setup: () async {}, release: () => released.future);

    final releaseExpectation =
        expectLater(gate.release(first), throwsA(isA<TimeoutException>()));
    await tester.pump();
    final prepareExpectation = expectLater(
      gate.prepare(second,
          setup: () async => secondSetupCalls++, release: () async {}),
      throwsA(isA<TimeoutException>()),
    );
    await tester.pump(const Duration(seconds: 8));
    await releaseExpectation;
    await prepareExpectation;
    expect(secondSetupCalls, 0);
    expect(gate.owns(first), isTrue);

    released.complete();
    await tester.pump();
    // A timed-out waiter is gone; it must not start a call later by itself.
    expect(secondSetupCalls, 0);
    await gate.prepare(second,
        setup: () async => secondSetupCalls++, release: () async {});
    expect(secondSetupCalls, 1);
    await gate.release(second);
  });

  testWidgets('late setup completes before its cleanup and the next setup',
      (tester) async {
    final gate = GeminiLiveAudioOutputGate();
    final first = Object();
    final second = Object();
    final setupDone = Completer<void>();
    final events = <String>[];
    final setupExpectation = expectLater(
      gate.prepare(first,
          setup: () async {
            events.add('setup:first');
            await setupDone.future;
            events.add('ready:first');
          },
          release: () async => events.add('release:first')),
      throwsA(isA<TimeoutException>()),
    );
    await tester.pump(const Duration(seconds: 8));
    await setupExpectation;
    final next = gate.prepare(second,
        setup: () async => events.add('setup:second'), release: () async {});
    await tester.pump();
    expect(events, ['setup:first']);
    setupDone.complete();
    await next;
    expect(events,
        ['setup:first', 'ready:first', 'release:first', 'setup:second']);
    await gate.release(second);
  });
}
