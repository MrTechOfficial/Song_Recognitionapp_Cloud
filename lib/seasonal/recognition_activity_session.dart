import 'package:flutter/services.dart';

/// Each callback belongs to one microphone run. Only completion/cancellation
/// retires it; backgrounding preserves it without permitting new starts.
class RecognitionActivitySession {
  RecognitionActivitySession(this.channel);
  final MethodChannel channel;
  Future<void>? _starting;
  String? _sessionID;
  int _revision = 0;
  bool _foreground = true;
  int get revision => _revision;

  Future<void> start(Map<String, Object?> arguments) async {
    if (!_foreground) return;
    final revision = ++_revision;
    _sessionID = null;
    final pending = () async {
      final id = await channel.invokeMethod<String>(
          'startRecognitionActivity', arguments);
      if (id == null) return;
      if (revision == _revision) {
        _sessionID = id;
      } else {
        await channel.invokeMethod<void>(
            'endRecognitionActivity', {'phase': 'cancelled', 'sessionID': id});
      }
    }();
    _starting = pending;
    await pending;
  }

  Future<String?> _current(int? expectedRevision) async {
    final expected = expectedRevision ?? _revision;
    await _starting;
    return expected == _revision ? _sessionID : null;
  }

  Future<void> update(String phase,
      {int? secondsRemaining, int? expectedRevision}) async {
    final id = await _current(expectedRevision);
    if (id == null || _sessionID != id) return;
    await channel.invokeMethod<void>('updateRecognitionActivity', {
      'sessionID': id,
      'phase': phase,
      if (secondsRemaining != null) 'secondsRemaining': secondsRemaining,
    });
  }

  Future<void> result(
      {required String title,
      required String artist,
      bool redirecting = false,
      int? expectedRevision}) async {
    final id = await _current(expectedRevision);
    if (id == null || _sessionID != id) return;
    _sessionID = null;
    _revision++;
    await channel.invokeMethod<void>('showRecognitionResult', {
      'sessionID': id,
      'title': title,
      'artist': artist,
      'redirecting': redirecting,
    });
  }

  Future<void> finish(String phase, {int? expectedRevision}) async {
    final id = await _current(expectedRevision);
    if (id == null || _sessionID != id) return;
    _sessionID = null;
    _revision++;
    await channel.invokeMethod<void>(
        'endRecognitionActivity', {'sessionID': id, 'phase': phase});
  }

  Future<void> suspend() async {
    _foreground = false;
    // Backgrounding is not a cancellation. The existing microphone run must
    // remain visible while a user looks at the Island or another app.
    await channel.invokeMethod<void>('backgroundAppRecognitionActivities');
  }

  Future<void> cancel() async {
    _foreground = false;
    _revision++;
    _sessionID = null;
    await channel.invokeMethod<void>('dismissAppRecognitionActivities');
  }

  Future<void> resume() async {
    await channel.invokeMethod<void>('resumeAppRecognitionActivities');
    _foreground = true;
  }
}
