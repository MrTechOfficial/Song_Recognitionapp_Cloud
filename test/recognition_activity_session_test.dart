import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_recognition_app/seasonal/recognition_activity_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/reczt/activity');
  final calls = <MethodCall>[];
  late RecognitionActivitySession session;
  setUp(() {
    calls.clear();
    session = RecognitionActivitySession(channel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'startRecognitionActivity' ? 'session-one' : null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test(
      'one result consumes the run; late errors or metadata cannot resurface it',
      () async {
    await session.start({'source': 'app'});
    await session.update('searching');
    await session.result(title: 'Song', artist: 'Artist', redirecting: true);
    await session.finish('noMatch');
    await session.result(title: 'Late song', artist: 'Late artist');
    expect(calls.map((c) => c.method), [
      'startRecognitionActivity',
      'updateRecognitionActivity',
      'showRecognitionResult'
    ]);
    final args = calls.last.arguments as Map;
    expect(args['sessionID'], 'session-one');
    expect(args['redirecting'], true);
  });

  test('simultaneous success and final cleanup publish only one terminal outcome', () async {
    await session.start({'source': 'app'});
    await Future.wait([
      session.result(title: 'Song', artist: 'Artist'),
      session.finish('error'),
    ]);
    expect(calls.where((c) => ['showRecognitionResult', 'endRecognitionActivity'].contains(c.method)), hasLength(1));
    expect(calls.last.method, 'showRecognitionResult');
  });

  test('leaving the app clears the run and resume never starts another Island',
      () async {
    await session.start({'source': 'app'});
    await session.suspend();
    await session.result(title: 'Song', artist: 'Artist');
    await session.update('searching');
    await session.resume();
    await session.result(title: 'Late song', artist: 'Artist');
    expect(calls.map((c) => c.method), [
      'startRecognitionActivity',
      'dismissAppRecognitionActivities',
      'resumeAppRecognitionActivities'
    ]);
  });

  test('a start completing after backgrounding is ended by its own ID',
      () async {
    final started = Completer<String>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'startRecognitionActivity' ? started.future : null;
    });
    final pending = session.start({'source': 'app'});
    await Future<void>.delayed(Duration.zero);
    await session.suspend();
    started.complete('late-session');
    await pending;
    expect(calls.last.method, 'endRecognitionActivity');
    expect((calls.last.arguments as Map)['sessionID'], 'late-session');
    await session.resume();
    final count = calls.length;
    await session.result(title: 'Late', artist: 'Artist');
    expect(calls.length, count);
  });

  test('an older backend failure cannot end a newer microphone run', () async {
    await session.start({'source': 'app'});
    final originalRevision = session.revision;
    await session.start({'source': 'app'});
    final count = calls.length;
    await session.finish('error', expectedRevision: originalRevision);
    await session.result(
        title: 'Old result',
        artist: 'Artist',
        expectedRevision: originalRevision);
    expect(calls.length, count);
    await session.update('listening', secondsRemaining: 5);
    expect(calls.last.method, 'updateRecognitionActivity');
  });
  test('failure dismisses once and the next explicit run can start normally',
      () async {
    await session.start({'source': 'app'});
    await session.finish('noMatch');
    await session.finish('error');
    await session.start({'source': 'app'});
    await session.update('listening', secondsRemaining: 6);
    expect(
        calls.where((c) => c.method == 'endRecognitionActivity'), hasLength(1));
    expect((calls.last.arguments as Map)['secondsRemaining'], 6);
  });
}
