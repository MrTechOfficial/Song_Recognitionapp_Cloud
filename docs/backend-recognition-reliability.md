# Recognition false-positive hotfix: backend 3.4

Version 3.3 could return unrelated songs as successful recognition. Genius
search positions were assigned artificial confidence values; repeated, overlapping
queries and transcription models increased those values. Even weak audio could
inherit a strong search score. A weak alternative also bypassed a rejection rule.
The prior tests did not adequately cover those false-positive paths.

The reported example was singing Happy Birthday in a quiet room and receiving
Wish You Were Here, Umculo and The Wizard as Top Guesses. The regression suite
reproduces the unsupported-search path using those three titles. They are not
hard-coded into recognition, and there is no special-case Birthday answer.

## Corrected behavior

- The server requires measured ACRCloud audio evidence before returning success.
  Unverified lyric search is disabled in `/recognize`; Groq and Genius are not
  called to manufacture alternatives when audio recognition fails. Their existing
  discovery helpers retain search ranking separately, with no song confidence.
- Crop votes and model/search agreement no longer increase measured confidence.
  Only top-ranked crop results count toward top-match consensus. Missing scores,
  inconsistent crops and close competing audio matches are rejected.
- Quiet-room humming needs a measured maximum of .82 plus consistent top-rank
  support from at least two crops; recording fingerprints need .86. Supporting
  top scores must include two scores within .04 of that floor, have a mean at
  least that high and cover at least half the attempted crops. A single attempt
  requires .94 for humming or .95 for recordings. A runner-up margin of .12 is
  required. Loud/outdoor floors increase .03; background queues add .02 and use
  a .15 margin. These conservative bounds are **not a calibration claim** that
  provider scores represent probabilities or guarantee real-world accuracy.
- Adaptive ACR stopping uses the same decision rule as the response. No time is
  reserved for unverified lyric search; the existing 28-second soft budget,
  four-request ceiling and auth/quota failure stops remain.
- Catalog popularity, a playable URL or a second weak guess cannot rescue an
  unsupported match. Enrichment cannot replace the supported song/performer with
  an unrelated catalog result. Only the supported audio identity is returned.
- No match returns `success: false` and an empty result list, so existing app
  installations do not offer unrelated Top Guesses. Existing localized failure
  keys remain compatible. No UI/Xcode change or new Python dependency is needed.

## Deploy the individual file to the existing service

The user's deployment log identifies `main` at `ac197f9` as the currently watched
branch. Replace **`backend/main.py`** there with the complete 3.4 file. Keep the
existing Render root directory, commands, environment variables and service plan.
Commit and wait for Auto-Deploy, or use Manual Deploy if it does not start. This
workspace does not directly deploy the live Render service. The prepared
`recognition-backend-fix` branch also contains the matching file and tests.

Open `https://song-recognitionapp-cloud.onrender.com/health` **in a browser** after
Render reports Live. The JSON should contain `pipeline_version: "3.4"`,
`match_policy: "audio_evidence_required"` and `lyric_only_matches_enabled: false`.
This is the health JSON, rather than Render's build/deployment log.

## Singing capability still needs checking

An ACRCloud project must support the appropriate humming/cover-song recognition
mode to identify a self-sung rendition. Ordinary recording fingerprints do not
provide that capability. The health endpoint can show credentials are present;
it cannot verify their validity, quota, catalog coverage or enabled recognition
mode. If ACRCloud is absent, health is degraded and recognition returns 503 even
when Groq/Genius are configured. This is intentional: unverified search alone
must not masquerade as audio recognition.

The existing variables remain `ACR_HOST`, `ACR_ACCESS_KEY`, `ACR_ACCESS_SECRET`,
`GROQ_API_KEY`, `GENIUS_ACCESS_TOKEN` and optional Spotify credentials. No key
values should be put in source or chat. Content-free `[RECOGNITION DECISION]`
logs include the request ID, provider kind, audio gate, measured score, margin
and top-vote count, without recording/transcript content.

## Verification

**39 backend tests pass**, including the previously failing unsupported guesses,
weak audio/search fusion, ambiguous high scores, inconsistent/repeated crops,
missing scores, provider outages, silence and missing ACR configuration. Tests
also exercise the complete WAV/cropping/parser/consensus/enrichment/API path with
mocked remote responses: supported humming succeeds after two crops, while no
match, weak guesses and conflicting matches do not become song results.

All remote providers in tests are mocked; no paid provider calls are made. A
mocked Happy Birthday recognition fixture does not demonstrate real singing
accuracy. The live Render endpoint is blocked by this workspace's network proxy,
so a deployed real recording and provider configuration still need verification.
