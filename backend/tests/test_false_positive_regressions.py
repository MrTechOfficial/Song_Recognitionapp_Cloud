"""Reject unsupported recognition, using mocked providers rather than paid APIs."""
import io
import wave
from contextlib import ExitStack
from unittest import TestCase, mock

from fastapi.testclient import TestClient

from backend import main as server


def audio_bytes():
    out = io.BytesIO()
    with wave.open(out, 'wb') as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(8000)
        audio.writeframes(b'\x10\x00' * 64000)
    return out.getvalue()


def melody(title='Supported song', score=.96, rank=1, kind='humming'):
    return dict(title=title, artist='Recognized artist', confidence=score,
                score=score, source='acrcloud_' + kind,
                recognition_type=kind, acrcloud_rank=rank)


def passes(*scores, title='Supported song', rank=1, kind='humming'):
    return [(f'window-{i}', kind, [melody(title, score, rank, kind)])
            for i, score in enumerate(scores)]


class FalsePositiveRegressions(TestCase):
    def setUp(self):
        self.client = TestClient(server.app)
        self.audio = audio_bytes()

    def recognize(self, pass_results=(), lyrics=None, form=None, enrich=None):
        kind, candidates, meta = server._aggregate_acr_pass_results(list(pass_results))
        meta['provider_statuses'] = [kind if candidates else 'no_match']

        def catalog(items, language):
            return [dict(item, selection_score=.99, spotify_popularity=100,
                         version_kind='canonical', version_penalty=0)
                    for item in items]

        def links(candidate, language):
            candidate.update(playback_link_verified=True,
                             spotify_url='https://open.spotify.com/track/fixture')

        with ExitStack() as stack:
            stack.enter_context(mock.patch.object(server, 'acrcloud_configured', return_value=True))
            stack.enter_context(mock.patch.object(server, 'recognize_with_acrcloud_consensus',
                                                 return_value=(kind, candidates, meta)))
            lyric_provider = stack.enter_context(mock.patch.object(
                server, 'lyric_fallback_candidates', return_value=(lyrics or [], {})))
            stack.enter_context(mock.patch.object(server, 'enrich_candidates', side_effect=enrich or catalog))
            link_provider = stack.enter_context(mock.patch.object(
                server, 'attach_direct_canonical_playback_links', side_effect=links))
            data = self.client.post('/recognize',
                files={'file': ('voice.wav', self.audio, 'audio/wav')},
                data=form or {}).json()
        return data, lyric_provider, link_provider

    def assert_rejected(self, data):
        self.assertIs(data['success'], False, data)
        self.assertFalse(data.get('results'), data)
        self.assertFalse(data.get('title'), data)
        self.assertFalse(data.get('spotify_url'), data)

    def test_unrelated_top_guesses_are_not_matches_without_audio_evidence(self):
        # User's reported false guesses; these are not expected song fixtures.
        lyrics = [dict(title=title, artist='Search artist', confidence=.84 - i*.04,
                       score=.84 - i*.04, source='groq_genius', genius_hits=4)
                  for i, title in enumerate(['Wish You Were Here', 'Umculo', 'The Wizard'])]
        data, lyric_provider, links = self.recognize(lyrics=lyrics)
        self.assert_rejected(data)
        lyric_provider.assert_not_called()
        links.assert_not_called()

    def test_popular_search_hit_cannot_promote_a_weak_audio_guess(self):
        lyrics = [dict(title='Supported song', artist='Recognized artist',
                       confidence=.90, source='groq_genius', genius_hits=4)]
        data, _, _ = self.recognize(passes(.24, .26), lyrics=lyrics)
        self.assert_rejected(data)

    def test_two_weak_alternatives_cannot_bypass_rejection(self):
        group = [('full', 'humming', [melody(score=.30), melody('Other song', .29, 2)])]
        for auto_play in ('true', 'false'):
            for background in ('true', 'false'):
                with self.subTest(auto_play=auto_play, background=background):
                    data, _, _ = self.recognize(group, form={
                        'auto_play': auto_play, 'background_queue': background})
                    self.assert_rejected(data)

    def test_multiple_crops_do_not_invent_high_provider_confidence(self):
        _, candidates, _ = server._aggregate_acr_pass_results(passes(.68, .68, .68, .68))
        self.assertAlmostEqual(candidates[0]['confidence'], .68)
        data, _, _ = self.recognize(passes(.68, .68, .68, .68))
        self.assert_rejected(data)

    def test_repeated_lower_ranked_guess_is_not_top_match_consensus(self):
        data, _, _ = self.recognize(passes(.88, .88, .88, rank=3))
        self.assert_rejected(data)

    def test_high_but_conflicting_audio_matches_are_rejected(self):
        group = [(f'window-{i}', 'humming',
                  [melody(score=.96), melody('Different melody', .95, 2)])
                 for i in range(3)]
        data, _, _ = self.recognize(group)
        self.assert_rejected(data)

    def test_inconsistent_crops_cannot_borrow_one_lucky_high_score(self):
        data, _, _ = self.recognize(passes(.94, .24, .25))
        self.assert_rejected(data)

    def test_one_mediocre_humming_guess_needs_more_audio_support(self):
        data, _, _ = self.recognize(passes(.80))
        self.assert_rejected(data)

    def test_missing_scores_cannot_be_rescued_by_search_or_catalog(self):
        item = melody()
        item['confidence'] = item['score'] = None
        data, _, _ = self.recognize([('full', 'humming', [item])])
        self.assert_rejected(data)

    def test_strong_repeated_humming_is_still_accepted(self):
        data, _, _ = self.recognize(passes(.85, .84, title='Provider-confirmed melody'))
        self.assertTrue(data['success'], data)
        self.assertEqual(data['title'], 'Provider-confirmed melody')
        self.assertAlmostEqual(data['confidence'], .85)
        self.assertEqual(len(data['results']), 1)

    def test_strong_isolated_recording_fingerprint_is_still_accepted(self):
        data, _, _ = self.recognize(passes(.97, kind='music'))
        self.assertTrue(data['success'], data)

    def test_high_catalog_ranking_cannot_replace_the_audio_identity(self):
        def wrong_catalog(items, language):
            return [dict(item, title='Unrelated catalog song', artist='Other artist',
                         selection_score=.99) for item in items]
        data, _, _ = self.recognize(passes(.97), enrich=wrong_catalog)
        self.assert_rejected(data)

    def test_noisy_environment_does_not_relax_the_audio_gate(self):
        data, _, _ = self.recognize(passes(.81, .80), form={'environment': 'loud'})
        self.assert_rejected(data)

    def test_search_rank_is_not_recognition_confidence(self):
        response = mock.Mock(status_code=200)
        response.json.return_value = {'response': {'hits': [{'result': {
            'id': 42, 'title': 'Unrelated search result',
            'primary_artist': {'name': 'Search artist'}}}]}}
        with mock.patch.object(server, 'GENIUS_ACCESS_TOKEN', 'fixture'), \
             mock.patch.object(server.requests, 'get', return_value=response):
            results = server.genius_candidates_from_lyrics('ordinary speech about something else', 'en')
        self.assertTrue(results)
        self.assertIsNone(results[0].get('confidence'))
        self.assertIsNone(results[0].get('score'))

    def test_agreeing_transcription_models_do_not_verify_a_song(self):
        item = dict(title='Search result', artist='Search artist', source='groq_genius',
                    confidence=None, search_rank_score=.9)
        merged = server._merge_groq_candidate_sets([item], [item])
        self.assertIsNone(merged[0].get('confidence'))
        self.assertIsNone(merged[0].get('score'))

    def test_search_agreement_does_not_inflate_audio_when_candidates_are_fused(self):
        audio = melody(score=.26)
        search = dict(audio, source='groq_genius', confidence=.9, genius_hits=4)
        combined = server.merge_candidates([audio], [search])
        self.assertAlmostEqual(combined[0]['confidence'], .26)
        self.assertEqual(combined[0]['evidence_count'], 1)

    def real_audio_pipeline(self, payload, status=200):
        response = mock.Mock(status_code=status)
        response.json.return_value = payload
        response.raise_for_status.side_effect = None
        empty_catalog = mock.Mock(status_code=200)
        empty_catalog.json.return_value = {'results': []}
        empty_catalog.raise_for_status.side_effect = None
        speech_model = mock.Mock()
        with mock.patch.multiple(server, ACR_HOST='fixture.invalid',
                                 ACR_ACCESS_KEY='fixture', ACR_ACCESS_SECRET='fixture',
                                 SPOTIFY_CLIENT_ID='', SPOTIFY_CLIENT_SECRET='',
                                 groq_client=speech_model, GENIUS_ACCESS_TOKEN='fixture'), \
             mock.patch.object(server.requests, 'post', return_value=response) as provider, \
             mock.patch.object(server.requests, 'get', return_value=empty_catalog) as catalog:
            # Real WAV parsing, cropping, ACR JSON parsing, consensus, decision,
            # enrichment and response handling. Only remote services are mocked.
            data = self.client.post('/recognize',
                files={'file': ('voice.wav', self.audio, 'audio/wav')}).json()
        speech_model.with_options.assert_not_called()
        self.assertFalse(any('genius.com' in str(call) for call in catalog.call_args_list))
        return data, provider.call_count

    def test_complete_audio_pipeline_no_match_does_not_fabricate_guesses(self):
        data, calls = self.real_audio_pipeline({'status': {'code': 1001}})
        self.assert_rejected(data)
        self.assertEqual(data['reason'], 'no_match')
        self.assertLessEqual(calls, 4)

    def test_complete_audio_pipeline_weak_repeated_scores_stay_rejected(self):
        data, calls = self.real_audio_pipeline({'status': {'code': 0}, 'metadata': {
            'humming': [{'title': 'Unrelated guess', 'artists': [{'name': 'Artist'}], 'score': 48}]}})
        self.assert_rejected(data)
        self.assertLessEqual(calls, 4)

    def test_complete_audio_pipeline_accepts_consistent_strong_humming_without_inflation(self):
        data, calls = self.real_audio_pipeline({'status': {'code': 0}, 'metadata': {
            'humming': [{'title': 'Happy Birthday', 'artists': [{'name': 'Traditional'}], 'score': 85}]}})
        self.assertTrue(data['success'], data)
        self.assertEqual(data['title'], 'Happy Birthday')
        self.assertAlmostEqual(data['confidence'], .85)
        self.assertEqual(calls, 2)
        self.assertEqual(data['recognition_meta']['audio_top_votes'], 2)

    def test_complete_audio_pipeline_rejects_conflicting_high_scores(self):
        data, calls = self.real_audio_pipeline({'status': {'code': 0}, 'metadata': {
            'humming': [{'title': title, 'artists': [{'name': 'Artist'}], 'score': score}
                        for title, score in [('First melody', 96), ('Other melody', 95)]]}})
        self.assert_rejected(data)
        self.assertEqual(data['recognition_meta']['audio_gate'], 'ambiguous_audio')
        self.assertLessEqual(calls, 4)

    def test_complete_audio_pipeline_stops_on_provider_auth_failure(self):
        data, calls = self.real_audio_pipeline({}, status=403)
        self.assert_rejected(data)
        self.assertEqual(data['reason'], 'provider_unavailable')
        self.assertEqual(calls, 1)

    def test_lyric_credentials_alone_do_not_claim_audio_recognition_is_available(self):
        with mock.patch.object(server, 'acrcloud_configured', return_value=False), \
             mock.patch.object(server, 'groq_client', mock.Mock()), \
             mock.patch.object(server, 'GENIUS_ACCESS_TOKEN', 'fixture'), \
             mock.patch.object(server, 'lyric_fallback_candidates') as provider:
            health = self.client.get('/health').json()
            response = self.client.post('/recognize',
                files={'file': ('voice.wav', self.audio, 'audio/wav')})
        self.assertEqual(health['status'], 'degraded')
        self.assertFalse(health['lyric_only_matches_enabled'])
        self.assertTrue(health['lyric_search_configured'])
        self.assertEqual(response.status_code, 503)
        provider.assert_not_called()
