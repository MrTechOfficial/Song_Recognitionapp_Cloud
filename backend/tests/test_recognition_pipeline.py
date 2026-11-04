"""Provider-contract fixtures, not live singing accuracy or paid API tests."""
import io
import math
import os
import wave
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase, mock
from fastapi.testclient import TestClient
from backend import main as server


def wav_bytes():
    out=io.BytesIO()
    with wave.open(out,'wb') as audio:
        audio.setnchannels(1);audio.setsampwidth(2);audio.setframerate(8000)
        audio.writeframes(b'\x10\x00'*64000)
    return out.getvalue()

class RecognitionPipelineTests(TestCase):
    def setUp(self):
        self.client=TestClient(server.app)
        self.audio=wav_bytes()
        self.temp=TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.path=Path(self.temp.name)/'voice.wav';self.path.write_bytes(self.audio)

    def provider_response(self,payload,status=200):
        result=mock.Mock(status_code=status)
        result.json.return_value=payload
        result.raise_for_status.side_effect=None if status<400 else RuntimeError('HTTP failure')
        return result

    def test_acr_scores_are_real_normalized_measurements_not_invented_defaults(self):
        payload={'status':{'code':'0'},'metadata':{'humming':[
            {'title':'Happy Birthday','artists':[{'name':'Traditional'}],'score':82},
            {'title':'Unknown melody','artist':'Singer'}]}}
        with mock.patch.object(server,'acrcloud_configured',return_value=True),mock.patch.object(server.requests,'post',return_value=self.provider_response(payload)):
            kind,candidates=server.recognize_with_acrcloud(str(self.path))
        self.assertEqual(kind,'humming');self.assertEqual(candidates[0]['confidence'],.82)
        self.assertIsNone(candidates[1]['confidence'])

    def test_acr_service_errors_are_distinct_from_no_match(self):
        for code,expected in [(1001,'no_match'),(3003,'quota_exceeded'),(3001,'provider_error')]:
            with self.subTest(code=code),mock.patch.object(server,'acrcloud_configured',return_value=True),mock.patch.object(server.requests,'post',return_value=self.provider_response({'status':{'code':code}})):
                self.assertEqual(server.recognize_with_acrcloud(str(self.path))[0],expected)
        for code,expected in [(401,'authentication_error'),(429,'quota_exceeded')]:
            with mock.patch.object(server,'acrcloud_configured',return_value=True),mock.patch.object(server.requests,'post',return_value=self.provider_response({},code)):
                self.assertEqual(server.recognize_with_acrcloud(str(self.path))[0],expected)

    def test_bad_credentials_do_not_repeat_the_same_failure_for_all_audio_windows(self):
        with mock.patch.object(server,'acrcloud_configured',return_value=True),mock.patch.object(server,'build_acr_audio_passes',return_value=[('full',str(self.path)),('window',str(self.path))]),mock.patch.object(server,'recognize_with_acrcloud',return_value=('authentication_error',[])) as provider:
            _,_,meta=server.recognize_with_acrcloud_consensus(str(self.path),str(self.path),self.temp.name,'quiet')
        self.assertEqual(provider.call_count,1)
        self.assertEqual(meta['provider_statuses'],['authentication_error'])

    def test_shared_budget_reaches_catalog_worker_threads_and_expired_budget_sends_no_http(self):
        token=server._request_deadline.set(server.time.monotonic()-1)
        try:
            with ThreadPoolExecutor(max_workers=1) as executor:
                remaining=server.submit_recognition_work(executor,server.remaining_budget).result()
            self.assertEqual(remaining,0)
            with self.assertRaises(server.RecognitionBudgetExceeded):server.provider_timeout()
            with mock.patch.object(server,'acrcloud_configured',return_value=True),mock.patch.object(server.requests,'post') as provider:
                kind,_=server.recognize_with_acrcloud(str(self.path))
                self.assertEqual(kind,'timeout');provider.assert_not_called()
        finally:server._request_deadline.reset(token)

    def test_groq_has_finite_timeout_and_no_hidden_sdk_retries(self):
        client=mock.Mock()
        client.with_options.return_value.audio.transcriptions.create.return_value=mock.Mock(text='a useful sung phrase')
        with mock.patch.object(server,'groq_client',client):
            result=server.transcribe_with_groq(str(self.path),'en','test-model')
        self.assertEqual(result['status'],'ok')
        self.assertEqual(client.with_options.call_args.kwargs['max_retries'],0)
        self.assertLessEqual(client.with_options.call_args.kwargs['timeout'],12)

    def test_genius_failures_produce_status_without_lyrics_in_logs(self):
        meta={}
        with mock.patch.object(server,'GENIUS_ACCESS_TOKEN','test-token'),mock.patch.object(server.requests,'get',return_value=self.provider_response({},401)):
            results=server.genius_candidates_from_lyrics('private sung words in this clip','en',diagnostics=meta)
        self.assertEqual(results,[]);self.assertTrue(meta['genius_statuses'])
        self.assertNotIn('private',str(meta))
        self.assertEqual(set(meta['genius_statuses']),{'http_401'})

    def test_non_finite_scores_are_not_promoted_to_confident_matches(self):
        for value in [math.nan,math.inf,-1,101,'bad']:
            self.assertIsNone(server.normalize_score(value))

    def test_health_reports_missing_providers_without_exposing_secrets(self):
        with mock.patch.object(server,'acrcloud_configured',return_value=False),mock.patch.object(server,'groq_client',None):
            response=self.client.get('/health').json()
        self.assertEqual(response['status'],'degraded')
        self.assertEqual(response['pipeline_version'],'3.4')
        self.assertNotIn('access_key',response)

    def run_api(self,acr_candidates,statuses=None,lyric_meta=None,verify=None):
        groups=[(label,'humming',[
            dict(c,recognition_type='humming',acrcloud_rank=i+1)
            for i,c in enumerate(acr_candidates)]) for label in ('full','window')]
        kind,candidates,meta=server._aggregate_acr_pass_results(groups)
        meta['provider_statuses']=statuses or ['humming']
        def enrich(items,language):
            return [dict(item,selection_score=item['confidence']*.8,version_penalty=0,version_kind='canonical',evidence_count=1) for item in items]
        def links(candidate,language):
            candidate['playback_link_verified']=verify(candidate) if verify else True
            if candidate['playback_link_verified']:candidate['spotify_url']='https://open.spotify.com/track/example'
        with mock.patch.object(server,'acrcloud_configured',return_value=True),mock.patch.object(server,'recognize_with_acrcloud_consensus',return_value=('humming',candidates,meta)),mock.patch.object(server,'lyric_fallback_candidates',return_value=([],lyric_meta or {})),mock.patch.object(server,'enrich_candidates',side_effect=enrich),mock.patch.object(server,'attach_direct_canonical_playback_links',side_effect=links):
            return self.client.post('/recognize',files={'file':('voice.wav',self.audio,'audio/wav')},data={'auto_play':'true'}).json()

    def test_humming_fixture_survives_catalog_score_weighting(self):
        data=self.run_api([{'title':'Happy Birthday','artist':'Traditional','confidence':.85,'source':'acrcloud_humming'}, {'title':'Different Song','artist':'Another Singer','confidence':.36,'source':'acrcloud_humming'}])
        self.assertTrue(data['success']);self.assertEqual(data['results'][0]['title'],'Happy Birthday')
        self.assertEqual(data['confidence'],.85)
        self.assertAlmostEqual(data['selection_score'],.68)
        self.assertEqual(data['recognition_meta']['pipeline_version'],'3.4')

    def test_unavailable_playback_link_does_not_hide_the_best_recognition(self):
        data=self.run_api([{'title':'Leading song','artist':'Original singer','confidence':.85,'source':'acrcloud_humming'}, {'title':'Other song','artist':'Another singer','confidence':.65,'source':'acrcloud_humming'}],verify=lambda c:c['title']=='Other song')
        self.assertEqual(data['results'][0]['title'],'Leading song')
        self.assertEqual(data['title'],data['results'][0]['title'])
        self.assertFalse(data['results'][0]['playback_link_verified'])

    def test_provider_outage_is_not_reported_as_bad_singing(self):
        data=self.run_api([],statuses=['authentication_error'])
        self.assertFalse(data['success']);self.assertEqual(data['reason'],'provider_unavailable')
        self.assertTrue(data['retryable'])

    def test_real_no_match_and_rate_limit_are_distinct(self):
        self.assertEqual(self.run_api([],statuses=['no_match'])['reason'],'no_match')
        self.assertEqual(self.run_api([],statuses=['quota_exceeded'])['reason'],'provider_rate_limited')

    def test_expired_request_returns_timeout_instead_of_no_match(self):
        with mock.patch.object(server,'remaining_budget',return_value=0):
            data=self.run_api([],statuses=['no_match'])
        self.assertEqual(data['reason'],'recognition_timeout')

    def test_unused_lyric_catalog_does_not_override_audio_provider_status(self):
        data=self.run_api([],statuses=['no_match'],lyric_meta={
            'transcription_statuses':['ok'],'genius_statuses':['http_401']})
        self.assertEqual(data['reason'],'no_match')

    def test_repeated_birthday_and_chorus_phrases_are_usable_lyrics(self):
        self.assertTrue(server.transcript_looks_useful('Happy birthday to you ' * 6))
        self.assertTrue(server.transcript_looks_useful('Let it be ' * 8))
        self.assertFalse(server.transcript_looks_useful('you ' * 12))
        self.assertFalse(server.transcript_looks_useful(''))

    def test_digital_silence_never_spends_provider_calls(self):
        silent=io.BytesIO()
        with wave.open(silent,'wb') as audio:
            audio.setnchannels(1);audio.setsampwidth(2);audio.setframerate(8000)
            audio.writeframes(b'\x00\x00'*16000)
        with mock.patch.object(server,'acrcloud_configured',return_value=True),mock.patch.object(server,'recognize_with_acrcloud_consensus') as provider:
            data=self.client.post('/recognize',files={'file':('silent.wav',silent.getvalue(),'audio/wav')}).json()
        self.assertEqual(data['reason'],'no_audio_signal');provider.assert_not_called()

    def test_repeated_sung_phrase_reaches_the_real_lyric_candidate_pipeline(self):
        client=mock.Mock()
        client.with_options.return_value.audio.transcriptions.create.return_value=mock.Mock(text='Happy birthday to you ' * 6)
        payload={'response':{'hits':[{'result':{'id':42,'title':'Happy Birthday','primary_artist':{'name':'Traditional'}}}]}}
        with mock.patch.object(server,'groq_client',client),mock.patch.object(server,'GENIUS_ACCESS_TOKEN','test-token'),mock.patch.object(server.requests,'get',return_value=self.provider_response(payload)):
            candidates,meta=server.lyric_fallback_candidates(str(self.path),'en')
        self.assertTrue(candidates)
        self.assertEqual(candidates[0]['title'],'Happy Birthday')
        self.assertTrue(meta['transcription_statuses'])
        self.assertEqual(set(meta['genius_statuses']),{'ok'})
