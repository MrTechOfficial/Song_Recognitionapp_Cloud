/// Catalog ordering is not a calibrated recognition confidence. Keep them
/// separate when deciding whether to play, ask, or retry.
class RecognitionEvidence {
  const RecognitionEvidence(
      {this.confidence,
      this.rankingScore,
      this.knownArtist = true,
      this.evidenceCount = 1,
      this.canAutoPlay = true});
  final double? confidence, rankingScore;
  final bool knownArtist, canAutoPlay;
  final int evidenceCount;
}

enum RecognitionDecision { accept, voiceChoice, manualChoice, retry }

double? normalizeRecognitionScore(Object? value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  if (number == null || !number.isFinite || number < 0 || number > 100) {
    return null;
  }
  return number > 1 ? number / 100 : number;
}

bool recognitionResponseSucceeded(Map<String, dynamic> data) {
  if (data['success'] == false) return false;
  if (data['success'] == true) return true;
  final status = data['status'];
  if (status is Map && status.containsKey('code')) {
    return status['code'].toString() == '0';
  }
  return data['results'] is List ||
      data['metadata'] is Map ||
      data['humming'] is List;
}

String recognitionFailureKey(Map<String, dynamic> data) {
  switch (data['reason']) {
    case 'no_audio_signal':
      return 'sing_louder';
    case 'provider_unavailable':
    case 'provider_rate_limited':
    case 'not_configured':
      return 'activity_error';
    case 'recognition_timeout':
      return 'search_timed_out';
    default:
      return 'no_valid_match';
  }
}

RecognitionDecision decideRecognition(List<RecognitionEvidence> candidates,
    {required bool autoPlay, String environment = 'quiet'}) {
  if (candidates.isEmpty) return RecognitionDecision.retry;
  final top = candidates.first;
  final score = top.confidence;
  if (score == null) return RecognitionDecision.manualChoice;
  final noisy = environment.toLowerCase() == 'loud';
  final outdoors = environment.toLowerCase() == 'outdoors';
  final plausibleFloor = outdoors
      ? .36
      : noisy
          ? .34
          : .32;
  if (score < plausibleFloor) return RecognitionDecision.retry;
  final reliableFloor = outdoors
      ? .64
      : noisy
          ? .62
          : .58;
  final second = candidates.length > 1 ? candidates[1] : null;
  final secondScore = second?.confidence;
  final close = secondScore != null &&
      secondScore >= plausibleFloor &&
      score - secondScore < .08;
  final artistIsSafe = top.knownArtist || score >= .72;
  if (score >= reliableFloor &&
      artistIsSafe &&
      top.canAutoPlay &&
      (!close || score >= .92)) {
    return RecognitionDecision.accept;
  }
  if (!autoPlay || second == null || secondScore == null) {
    return RecognitionDecision.manualChoice;
  }
  final topFloor = (outdoors
          ? .55
          : noisy
              ? .53
              : .50) -
      (top.evidenceCount >= 2 ? .04 : 0);
  final secondFloor = (outdoors
          ? .42
          : noisy
              ? .40
              : .38) -
      (second.evidenceCount >= 2 ? .025 : 0);
  if (score >= topFloor &&
      secondScore >= secondFloor &&
      (top.knownArtist || score >= .70) &&
      (second.knownArtist || secondScore >= .66)) {
    return RecognitionDecision.voiceChoice;
  }
  // A weak runner-up cannot invalidate the leading candidate. Let the user
  // confirm plausible results, while leaving automatic playback disabled.
  return RecognitionDecision.manualChoice;
}
