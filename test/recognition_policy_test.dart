import 'package:flutter_test/flutter_test.dart';
import 'package:song_recognition_app/recognition/recognition_policy.dart';
import 'package:song_recognition_app/main.dart' show LanguageMatcher;

void main() {
  test(
      'a catalog-weighted score cannot turn a strong recognition into a rejection',
      () {
    expect(
        decideRecognition(const [
          RecognitionEvidence(confidence: .70, rankingScore: .56),
          RecognitionEvidence(confidence: .36, rankingScore: .288),
        ], autoPlay: true),
        RecognitionDecision.accept);
  });
  test(
      'a weak runner-up offers confirmation rather than invalidating a plausible lead',
      () {
    expect(
        decideRecognition(const [
          RecognitionEvidence(confidence: .56, rankingScore: .448),
          RecognitionEvidence(confidence: .30, rankingScore: .24),
        ], autoPlay: true),
        RecognitionDecision.manualChoice);
  });
  test('two plausible close candidates still support a hands-free voice choice',
      () {
    expect(
        decideRecognition(const [
          RecognitionEvidence(confidence: .64, rankingScore: .51),
          RecognitionEvidence(confidence: .60, rankingScore: .48),
        ], autoPlay: true),
        RecognitionDecision.voiceChoice);
    expect(
        decideRecognition(const [
          RecognitionEvidence(confidence: .64),
          RecognitionEvidence(confidence: .60)
        ], autoPlay: false),
        RecognitionDecision.manualChoice);
  });
  test('truly weak or empty recognition never auto-plays', () {
    expect(decideRecognition([], autoPlay: true), RecognitionDecision.retry);
    expect(
        decideRecognition(
            const [RecognitionEvidence(confidence: .15, rankingScore: .95)],
            autoPlay: true),
        RecognitionDecision.retry);
    expect(
        decideRecognition(const [RecognitionEvidence(rankingScore: .99)],
            autoPlay: true),
        RecognitionDecision.manualChoice);
    expect(
        decideRecognition(
            const [RecognitionEvidence(confidence: .8, knownArtist: false)],
            autoPlay: true),
        RecognitionDecision.accept);
  });
  test('a single lyric search ranking still needs user confirmation', () {
    expect(
        decideRecognition(
            const [RecognitionEvidence(confidence: .78, canAutoPlay: false)],
            autoPlay: true),
        RecognitionDecision.manualChoice);
  });
  test(
      'an explicit failed response cannot be accepted just because results exist',
      () {
    expect(
        recognitionResponseSucceeded({
          'success': false,
          'results': [
            {'title': 'Song'}
          ]
        }),
        false);
    expect(
        recognitionResponseSucceeded({
          'status': {'code': 3003},
          'metadata': {}
        }),
        false);
    expect(
        recognitionResponseSucceeded({
          'status': {'code': '0'},
          'metadata': {}
        }),
        true);
    expect(
        recognitionResponseSucceeded({'success': true, 'results': []}), true);
  });
  test('service errors and no-match produce different localized status keys',
      () {
    expect(recognitionFailureKey({'reason': 'provider_unavailable'}),
        'activity_error');
    expect(recognitionFailureKey({'reason': 'provider_rate_limited'}),
        'activity_error');
    expect(recognitionFailureKey({'reason': 'recognition_timeout'}),
        'search_timed_out');
    expect(recognitionFailureKey({'reason': 'no_match'}), 'no_valid_match');
    expect(recognitionFailureKey({'reason': 'no_audio_signal'}), 'sing_louder');
  });
  test(
      'score normalization accepts percentages and rejects malformed or non-finite values',
      () {
    expect(normalizeRecognitionScore(82), .82);
    expect(normalizeRecognitionScore('0.82'), .82);
    for (final value in [double.nan, double.infinity, -1, 101, 'bad', null]) {
      expect(normalizeRecognitionScore(value), null);
    }
  });
  test(
      'confirmed canonical identity is not blocked by stale cover-album metadata',
      () {
    expect(
        LanguageMatcher.isValidOriginalSong({
          'title': 'Song',
          'artist': 'Original Artist',
          'album': 'Karaoke tribute collection',
          'version_kind': 'canonical',
          'canonicalized_from_version': true
        }),
        true);
    expect(
        LanguageMatcher.isValidOriginalSong(
            {'title': 'Song (Karaoke)', 'artist': 'Cover Artist'}),
        false);
  });
}
