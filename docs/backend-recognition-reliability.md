# Recognition reliability update: backend 3.3

The iOS app calls `https://song-recognitionapp-cloud.onrender.com/recognize` in
Debug/Profile/Release. Xcode does not make every song fail a confidence test,
and installing an Xcode ZIP does not deploy the server.

## What changed

The app previously mixed the backend's catalog-weighted `selection_score` with
recognition `confidence`. For example, raw confidence .70 could rank at .56,
while the runner-up's .36 could rank at .288. Auto Play treated that as ambiguity,
then rejected the whole recording because the runner-up failed the voice-choice
floor. The new policy uses recognition confidence for acceptance/confirmation,
while keeping catalog scores for ordering. A plausible lead can be displayed
for confirmation; genuinely weak evidence is still rejected. Lyric search
rankings need confirmation rather than silently auto-playing one search result.

Explicit `success:false` and provider error status codes now remain failures,
even if a payload also contains a results field. Confirmed canonical identity
is checked against final title/artist rather than stale cover-album metadata.
Explicitly unverified playback links are not auto-launched. Service failures get a localized
unavailable/timeout message instead of being presented as poor singing. All
visible text reuses the existing fifteen-language dictionaries.

The server starts from the newer **3.2 backend on main**, preserving its balanced
cover handling, artist repair and canonical catalog improvements. Additional fixes:

- Recognition order survives a failed catalog/link lookup. A weaker playable
  candidate no longer replaces the strongest recognition solely due to its URL.
- Provider errors, quota/authentication problems, genuine no-match and deadline
  exhaustion have different response reasons. A missing ACR score no longer
  receives an invented .55/.88 confidence.
- Repeated multiword lyric phrases remain eligible; digital silence is rejected
  before provider calls, without adding a loudness cutoff for quiet singers.
- Groq uses finite per-call timeouts and zero hidden SDK retries. A shared soft
  request budget defaults to 28 seconds, propagates to provider worker threads,
  and shortens/skips late network calls. This is below the app's 32-second
  response wait; it is not a hard wall-clock guarantee for every transport or
  a Render cold start.
- Authentication/quota/timeout failures do not retry the same ACR endpoint on
  more audio crops. The existing four-pass ceiling and adaptive strong-match
  early exit remain; a long ACR stage reserves time for lyric fallback.
- `/health` exposes version, configured recognition modes and booleans only.
  Responses include request IDs and content-free timing/provider diagnostics.
  Audio and transcript content are not added to diagnostics.

## Deploy to your existing Render service

The tested server-only branch is **`recognition-backend-fix`**. It is based on
main and contains backend code/tests/documentation changes only. Its `backend/main.py`
is identical to the one included in the matching seasonal app ZIP.

1. Open your existing service in Render, then **Settings → Build & Deploy**.
2. Confirm it is linked to `MrTechOfficial/Song_Recognitionapp_Cloud` and set
   **Branch** to `recognition-backend-fix`. Save.
3. If deployment does not start automatically, use **Manual Deploy → Deploy
   latest commit**. Keep the existing Root Directory, Build Command, Start
   Command, environment variables and service plan.
4. Open `https://song-recognitionapp-cloud.onrender.com/health`. The new response
   includes `pipeline_version: "3.3"`. Retest a real singing clip in the app.

This cloud workspace cannot reach the live Render endpoint: its network proxy
rejects that host. No Render service configuration or live deployment has been
changed here. A published branch is prepared code, not proof of a deployment.
No GitHub Actions workflow or additional provider service is required. The
existing workflow runs on main/master, not this server branch.

Use the seasonal ZIP for Xcode, not this server branch. Changing Render's branch
also changes which branch it watches for future server updates.

## Recognition provider configuration

A health value of `true` means credentials are present, not that the provider
accepted them or that quota remains. For singing/humming, the ACRCloud project
must support humming/cover recognition; ordinary recording fingerprints alone
cannot identify an arbitrary self-sung rendition. Alternatively, lyric fallback
needs both Groq and Genius credentials. Spotify availability affects playback,
not whether a melody candidate is retained.

Required existing variable names remain `ACR_HOST`, `ACR_ACCESS_KEY`,
`ACR_ACCESS_SECRET`, `GROQ_API_KEY`, `GENIUS_ACCESS_TOKEN` and optional Spotify
credentials. No key values need to be placed in source or chat.

## Verification limits

Backend tests mock provider responses and network errors, including a
provider-supplied Happy Birthday candidate. They verify the decision/response
pipeline, not actual singing accuracy, paid-account configuration or catalog
coverage. Live accuracy requires a real recording and the deployed providers.

Validation: **17 backend tests**, **80 Flutter tests**, **23 installer/native
resource checks**, and the production web release build pass. Swift syntax
parses; all fifteen native dictionaries still match. The actual Flutter app was
also exercised with a simulated recording and mocked backend responses: an
uncertain pair offered confirmation, a stronger lead was accepted, and an
explicitly unverified playback URL did not open. These are controlled fixtures,
not real provider accuracy measurements.
