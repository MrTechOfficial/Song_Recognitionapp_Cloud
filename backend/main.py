import os
import time
import base64
import hashlib
import hmac
import math
import re
import shutil
import tempfile
import threading
import unicodedata
import wave
from array import array
from concurrent.futures import ThreadPoolExecutor, as_completed
from difflib import SequenceMatcher
from functools import lru_cache
from typing import Any, Dict, List, Optional, Tuple

import requests
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from groq import Groq


# =====================================================================
# CONFIGURATION
# =====================================================================

ACR_HOST = os.getenv("ACR_HOST", "identify-us-west-2.acrcloud.com").strip()
ACR_ACCESS_KEY = os.getenv("ACR_ACCESS_KEY", "").strip()
ACR_ACCESS_SECRET = os.getenv("ACR_ACCESS_SECRET", "").strip()
ACR_TIMEOUT_SECONDS = float(os.getenv("ACR_TIMEOUT_SECONDS", "9"))

GROQ_API_KEY = os.getenv("GROQ_API_KEY", "").strip()
GROQ_TURBO_MODEL = os.getenv("GROQ_TURBO_MODEL", "whisper-large-v3-turbo").strip()
GROQ_ACCURACY_MODEL = os.getenv("GROQ_ACCURACY_MODEL", "whisper-large-v3").strip()
groq_client = Groq(api_key=GROQ_API_KEY) if GROQ_API_KEY else None

SPOTIFY_CLIENT_ID = os.getenv("SPOTIFY_CLIENT_ID", "").strip()
SPOTIFY_CLIENT_SECRET = os.getenv("SPOTIFY_CLIENT_SECRET", "").strip()
GENIUS_ACCESS_TOKEN = os.getenv("GENIUS_ACCESS_TOKEN", "").strip()

# Optional comma-separated browser origins. Native iOS/Android requests do not
# require CORS, but this keeps a Flutter web build usable as well.
_cors_env = os.getenv("CORS_ALLOW_ORIGINS", "*").strip()
CORS_ALLOW_ORIGINS = ["*"] if _cors_env == "*" else [
    item.strip() for item in _cors_env.split(",") if item.strip()
]

LANGUAGE_TO_MARKET = {
    "en": {"spotify": "US", "apple": "us"},
    "es": {"spotify": "ES", "apple": "es"},
    "fr": {"spotify": "FR", "apple": "fr"},
    "de": {"spotify": "DE", "apple": "de"},
    "it": {"spotify": "IT", "apple": "it"},
    "pt": {"spotify": "BR", "apple": "br"},
    "ja": {"spotify": "JP", "apple": "jp"},
    "ko": {"spotify": "KR", "apple": "kr"},
    "zh": {"spotify": "TW", "apple": "tw"},
    "hi": {"spotify": "IN", "apple": "in"},
    "ru": {"spotify": "US", "apple": "us"},
    "tr": {"spotify": "TR", "apple": "tr"},
    "ar": {"spotify": "SA", "apple": "sa"},
    "nl": {"spotify": "NL", "apple": "nl"},
    "pl": {"spotify": "PL", "apple": "pl"},
}

LANGUAGE_ALIASES = {
    "english": "en", "eng": "en",
    "spanish": "es", "español": "es", "spa": "es",
    "french": "fr", "français": "fr", "fra": "fr", "fre": "fr",
    "german": "de", "deutsch": "de", "deu": "de", "ger": "de",
    "italian": "it", "italiano": "it", "ita": "it",
    "portuguese": "pt", "português": "pt", "por": "pt",
    "japanese": "ja", "日本語": "ja", "jpn": "ja",
    "korean": "ko", "한국어": "ko", "kor": "ko",
    "chinese": "zh", "中文": "zh", "zho": "zh", "chi": "zh",
    "hindi": "hi", "हिन्दी": "hi", "hin": "hi",
    "russian": "ru", "русский": "ru", "rus": "ru",
    "turkish": "tr", "türkçe": "tr", "tur": "tr",
    "arabic": "ar", "العربية": "ar", "ara": "ar",
    "dutch": "nl", "nederlands": "nl", "nld": "nl", "dut": "nl",
    "polish": "pl", "polski": "pl", "pol": "pl",
}

# Short prompts in the same language as the expected audio. Groq recommends
# supplying ISO-639-1 language codes; matching-language prompts help avoid
# steering multilingual transcription back toward English.
GROQ_PROMPTS = {
    "en": "Popular song lyrics being sung. Transcribe the sung words accurately.",
    "es": "Letra de una canción popular cantada. Transcribe con precisión las palabras cantadas.",
    "fr": "Paroles d'une chanson populaire chantée. Transcris précisément les paroles chantées.",
    "de": "Gesungener Text eines bekannten Liedes. Transkribiere die gesungenen Wörter genau.",
    "it": "Testo cantato di una canzone popolare. Trascrivi accuratamente le parole cantate.",
    "pt": "Letra cantada de uma música popular. Transcreva com precisão as palavras cantadas.",
    "ja": "よく知られた曲の歌詞を歌っています。歌われた言葉を正確に文字起こししてください。",
    "ko": "잘 알려진 노래의 가사를 부르고 있습니다. 부른 가사를 정확하게 받아쓰세요.",
    "zh": "正在演唱一首流行歌曲的歌词。请准确转写唱出的歌词。",
    "hi": "एक लोकप्रिय गीत के बोल गाए जा रहे हैं। गाए गए शब्दों को सटीक रूप से लिखें।",
    "ru": "Поются слова популярной песни. Точно расшифруй спетые слова.",
    "tr": "Popüler bir şarkının sözleri söyleniyor. Söylenen sözleri doğru şekilde yazıya dök.",
    "ar": "يتم غناء كلمات أغنية معروفة. انسخ الكلمات المغناة بدقة.",
    "nl": "Er worden songteksten van een bekend lied gezongen. Transcribeer de gezongen woorden nauwkeurig.",
    "pl": "Śpiewany jest tekst popularnej piosenki. Dokładnie przepisz śpiewane słowa.",
}

# We reject obvious imitation products, but do not blanket-reject words such as
# "version" or "remix" because legitimate official releases can contain them.
BLOCKED_VERSION_PHRASES = (
    "karaoke",
    "tribute",
    "in the style of",
    "made famous by",
    "sound alike",
    "sound-alike",
    "backing track",
    "instrumental version",
    "cover version",
)

app = FastAPI(title="Reczt Song Recognition Engine", version="2.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ALLOW_ORIGINS,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =====================================================================
# SMALL HELPERS
# =====================================================================

def normalize_language(value: str) -> str:
    cleaned = (value or "en").strip().casefold()
    if cleaned in LANGUAGE_TO_MARKET:
        return cleaned
    if cleaned in LANGUAGE_ALIASES:
        return LANGUAGE_ALIASES[cleaned]
    if "-" in cleaned:
        prefix = cleaned.split("-", 1)[0]
        if prefix in LANGUAGE_TO_MARKET:
            return prefix
    return "en"


def parse_bool(value: str) -> bool:
    return str(value).strip().casefold() in {"1", "true", "yes", "on"}


def normalize_environment(value: str) -> str:
    cleaned = (value or "quiet").strip().casefold()
    if cleaned in {"outdoor", "outdoors"}:
        return "outdoors"
    if cleaned == "loud":
        return "loud"
    return "quiet"


def normalize_score(value: Any, default: Optional[float] = None) -> Optional[float]:
    try:
        score = float(value)
    except (TypeError, ValueError):
        return default
    if score > 1.0:
        score /= 100.0
    return max(0.0, min(score, 1.0))


def clean_text(value: str) -> str:
    normalized = unicodedata.normalize("NFKC", value or "").casefold()
    normalized = re.sub(r"[^\w\s]", " ", normalized, flags=re.UNICODE)
    return re.sub(r"\s+", " ", normalized).strip()


def similarity(a: str, b: str) -> float:
    a_clean, b_clean = clean_text(a), clean_text(b)
    if not a_clean or not b_clean:
        return 0.0
    return SequenceMatcher(None, a_clean, b_clean).ratio()


def candidate_key(title: str, artist: str) -> str:
    return f"{clean_text(title)}|{clean_text(artist)}"


def is_unwanted_version(title: str, artist: str) -> bool:
    combined = f"{title} {artist}".casefold()
    if any(phrase in combined for phrase in BLOCKED_VERSION_PHRASES):
        return True
    descriptor = re.compile(
        r"(?:\(|\[|\-|–|—|:)\s*(?:cover|remake)(?:\s+version)?\b|\b(?:cover|remake)\s+version\b",
        re.IGNORECASE,
    )
    return bool(descriptor.search(combined))


def extract_artist(item: Dict[str, Any]) -> str:
    artist = item.get("artist")
    if isinstance(artist, str) and artist.strip():
        return artist.strip()
    artists = item.get("artists")
    if isinstance(artists, list) and artists:
        first = artists[0]
        if isinstance(first, dict):
            return str(first.get("name") or "").strip()
        return str(first).strip()
    return ""


def extract_language(item: Dict[str, Any]) -> str:
    language = item.get("language")
    if isinstance(language, list) and language:
        language = language[0]
    if not language:
        return ""
    value = str(language).strip()
    lowered = value.casefold()
    if lowered in LANGUAGE_ALIASES:
        return LANGUAGE_ALIASES[lowered]
    if lowered in LANGUAGE_TO_MARKET:
        return lowered
    return value


# =====================================================================
# AUDIO PREPROCESSING
# =====================================================================

def _silence_threshold_db(environment: str) -> float:
    return {"quiet": -46.0, "loud": -36.0, "outdoors": -38.0}.get(environment, -42.0)


def trim_pcm_wav_silence(input_path: str, output_path: str, environment: str) -> None:
    """Trim leading/trailing silence from the mono PCM WAV produced by Reczt.

    This intentionally uses only Python's standard library so Render does not
    need pydub/ffmpeg. If the upload is not 16-bit PCM WAV, it falls back to an
    unchanged copy rather than risking destructive conversion.
    """
    try:
        with wave.open(input_path, "rb") as source:
            channels = source.getnchannels()
            sample_width = source.getsampwidth()
            frame_rate = source.getframerate()
            frame_count = source.getnframes()
            compression = source.getcomptype()
            frames = source.readframes(frame_count)

        if compression != "NONE" or sample_width != 2 or channels < 1 or frame_rate <= 0:
            shutil.copyfile(input_path, output_path)
            return

        samples = array("h")
        samples.frombytes(frames)
        if not samples:
            shutil.copyfile(input_path, output_path)
            return

        chunk_frames = max(1, int(frame_rate * 0.02))  # 20 ms
        threshold_amplitude = 32767.0 * (10.0 ** (_silence_threshold_db(environment) / 20.0))
        total_frames = len(samples) // channels
        active_ranges: List[Tuple[int, int]] = []

        for start_frame in range(0, total_frames, chunk_frames):
            end_frame = min(total_frames, start_frame + chunk_frames)
            start_sample = start_frame * channels
            end_sample = end_frame * channels
            chunk = samples[start_sample:end_sample]
            if not chunk:
                continue
            rms = math.sqrt(sum(int(v) * int(v) for v in chunk) / len(chunk))
            if rms >= threshold_amplitude:
                active_ranges.append((start_frame, end_frame))

        if not active_ranges:
            shutil.copyfile(input_path, output_path)
            return

        padding_frames = int(frame_rate * 0.22)
        start_frame = max(0, active_ranges[0][0] - padding_frames)
        end_frame = min(total_frames, active_ranges[-1][1] + padding_frames)

        # Keep at least one second. Very short clips are less useful to either
        # ACRCloud or Whisper, so do not over-trim them.
        if end_frame - start_frame < frame_rate:
            shutil.copyfile(input_path, output_path)
            return

        trimmed = samples[start_frame * channels:end_frame * channels]
        with wave.open(output_path, "wb") as target:
            target.setnchannels(channels)
            target.setsampwidth(sample_width)
            target.setframerate(frame_rate)
            target.setcomptype("NONE", "not compressed")
            target.writeframes(trimmed.tobytes())
    except Exception as exc:
        print(f"[AUDIO TRIM WARNING] {exc}; using original audio")
        shutil.copyfile(input_path, output_path)


# =====================================================================
# ACRCLOUD
# =====================================================================

def acrcloud_configured() -> bool:
    return bool(ACR_HOST and ACR_ACCESS_KEY and ACR_ACCESS_SECRET)


def generate_acr_signature() -> Dict[str, str]:
    http_method = "POST"
    http_uri = "/v1/identify"
    data_type = "audio"
    signature_version = "1"
    timestamp = str(int(time.time()))
    string_to_sign = (
        f"{http_method}\n{http_uri}\n{ACR_ACCESS_KEY}\n"
        f"{data_type}\n{signature_version}\n{timestamp}"
    )
    signature = base64.b64encode(
        hmac.new(
            ACR_ACCESS_SECRET.encode("utf-8"),
            string_to_sign.encode("utf-8"),
            digestmod=hashlib.sha1,
        ).digest()
    ).decode("utf-8")
    return {
        "access_key": ACR_ACCESS_KEY,
        "data_type": data_type,
        "signature": signature,
        "signature_version": signature_version,
        "timestamp": timestamp,
    }


def recognize_with_acrcloud(audio_path: str) -> Tuple[str, List[Dict[str, Any]]]:
    if not acrcloud_configured():
        return "unavailable", []

    request_data = generate_acr_signature()
    request_data["sample_bytes"] = str(os.path.getsize(audio_path))
    identify_url = f"https://{ACR_HOST}/v1/identify"

    try:
        with open(audio_path, "rb") as audio_file:
            response = requests.post(
                identify_url,
                data=request_data,
                files={"sample": ("reczt.wav", audio_file, "audio/wav")},
                timeout=(4, ACR_TIMEOUT_SECONDS),
            )
        response.raise_for_status()
        payload = response.json()
    except Exception as exc:
        print(f"[ACRCLOUD ERROR] {exc}")
        return "error", []

    status_code = payload.get("status", {}).get("code", -1)
    if status_code != 0:
        print(f"[ACRCLOUD NO MATCH] status={payload.get('status')}")
        return "no_match", []

    metadata = payload.get("metadata") or {}
    if metadata.get("humming"):
        kind = "humming"
        raw_items = metadata.get("humming") or []
    else:
        kind = "music"
        raw_items = metadata.get("music") or []

    candidates: List[Dict[str, Any]] = []
    for index, item in enumerate(raw_items[:5]):
        if not isinstance(item, dict):
            continue
        title = str(item.get("title") or item.get("name") or "").strip()
        artist = extract_artist(item)
        if not title or is_unwanted_version(title, artist):
            continue

        default_score = 0.55 if kind == "humming" else 0.88
        confidence = normalize_score(item.get("score"), default=default_score)
        candidate = {
            "title": title,
            "artist": artist,
            "confidence": confidence,
            "score": confidence,
            "language": extract_language(item),
            "source": f"acrcloud_{kind}",
            "recognition_type": kind,
            "acrcloud_rank": index + 1,
        }

        for optional_key in ("genres", "album", "external_metadata", "acrid", "release_date"):
            if optional_key in item:
                candidate[optional_key] = item[optional_key]
        candidates.append(candidate)

    candidates.sort(key=lambda c: c.get("confidence") or 0.0, reverse=True)
    return kind, candidates


def acr_result_is_decisive(kind: str, candidates: List[Dict[str, Any]], environment: str) -> bool:
    if not candidates:
        return False
    top = candidates[0].get("confidence") or 0.0
    second = candidates[1].get("confidence") if len(candidates) > 1 else None
    noise_adjustment = 0.03 if environment in {"loud", "outdoors"} else 0.0

    if kind == "music":
        return top >= (0.86 + noise_adjustment)

    threshold = 0.76 + noise_adjustment
    if top < threshold:
        return False
    if second is None:
        return True
    return (top - second) >= 0.07 or top >= 0.92


# =====================================================================
# GROQ + GENIUS LYRIC FALLBACK
# =====================================================================

def transcribe_with_groq(audio_path: str, language: str, model: str) -> str:
    if not groq_client:
        return ""
    try:
        with open(audio_path, "rb") as audio_file:
            transcript = groq_client.audio.transcriptions.create(
                model=model,
                file=audio_file,
                language=language,
                prompt=GROQ_PROMPTS.get(language),
                response_format="json",
                temperature=0.0,
            )
        text = str(getattr(transcript, "text", "") or "").strip()
        print(f"[GROQ {model} {language}] {text!r}")
        return text
    except Exception as exc:
        print(f"[GROQ ERROR {model}] {exc}")
        return ""


def transcript_looks_useful(text: str) -> bool:
    words = [w for w in re.split(r"\s+", text.strip()) if w]
    if len(words) < 3:
        return False
    normalized = clean_text(text)
    if len(normalized) < 10:
        return False
    # Whisper hallucinations on silence often repeat the same short token.
    unique_ratio = len(set(words)) / max(1, len(words))
    return unique_ratio >= 0.35


def build_lyric_queries(lyrics: str) -> List[str]:
    words = [w for w in lyrics.strip().split() if w]
    if not words:
        return []
    if len(words) <= 8:
        return [" ".join(words)]

    window = 7
    starts = [0]
    if len(words) >= 14:
        starts.append(max(0, len(words) // 2 - window // 2))
    if len(words) >= 10:
        starts.append(max(0, len(words) - window))
    if len(words) >= 18:
        starts.append(7)

    queries: List[str] = []
    for start in starts:
        query = " ".join(words[start:start + window]).strip()
        if query and query not in queries:
            queries.append(query)
    return queries[:4]


def genius_candidates_from_lyrics(lyrics: str, language: str) -> List[Dict[str, Any]]:
    if not GENIUS_ACCESS_TOKEN or not lyrics.strip():
        return []

    headers = {"Authorization": f"Bearer {GENIUS_ACCESS_TOKEN}"}
    aggregated: Dict[str, Dict[str, Any]] = {}

    queries = build_lyric_queries(lyrics)

    def search_query(query_index: int, query: str) -> Tuple[int, List[Dict[str, Any]]]:
        try:
            response = requests.get(
                "https://api.genius.com/search",
                params={"q": query},
                headers=headers,
                timeout=(2.5, 5),
            )
            if response.status_code != 200:
                return query_index, []
            hits = response.json().get("response", {}).get("hits", [])[:5]
            return query_index, hits if isinstance(hits, list) else []
        except Exception as exc:
            print(f"[GENIUS ERROR] {exc}")
            return query_index, []

    query_results: List[Tuple[int, List[Dict[str, Any]]]] = []
    with ThreadPoolExecutor(max_workers=min(4, max(1, len(queries)))) as executor:
        futures = [executor.submit(search_query, i, q) for i, q in enumerate(queries)]
        for future in as_completed(futures):
            query_results.append(future.result())

    for query_index, hits in query_results:
        for rank, hit in enumerate(hits):
            result = hit.get("result") or {}
            title = str(result.get("title") or "").strip()
            artist = str((result.get("primary_artist") or {}).get("name") or "").strip()
            if not title or is_unwanted_version(title, artist):
                continue

            key = str(result.get("id") or candidate_key(title, artist))
            rank_score = 0.66 - (rank * 0.045) - (query_index * 0.015)
            current = aggregated.get(key)
            if current is None:
                aggregated[key] = {
                    "title": title,
                    "artist": artist,
                    "confidence": max(0.44, rank_score),
                    "score": max(0.44, rank_score),
                    "language": language,
                    "source": "groq_genius",
                    "genius_hits": 1,
                }
            else:
                current["genius_hits"] = int(current.get("genius_hits", 1)) + 1
                # Appearing for more than one independent lyric snippet is much
                # stronger evidence than a single Genius search ranking.
                boosted = max(current.get("confidence") or 0.0, rank_score) + 0.055
                current["confidence"] = min(0.84, boosted)
                current["score"] = current["confidence"]

    results = list(aggregated.values())
    results.sort(key=lambda c: c.get("confidence") or 0.0, reverse=True)
    return results[:5]


def lyric_fallback_candidates(audio_path: str, language: str) -> List[Dict[str, Any]]:
    if not groq_client or not GENIUS_ACCESS_TOKEN:
        return []

    turbo_text = transcribe_with_groq(audio_path, language, GROQ_TURBO_MODEL)
    turbo_candidates = genius_candidates_from_lyrics(turbo_text, language) if transcript_looks_useful(turbo_text) else []
    if turbo_candidates:
        return turbo_candidates

    # Only pay the latency/cost of the accuracy model when Turbo did not yield
    # a usable Genius match. This is especially helpful for sung/off-key words.
    if GROQ_ACCURACY_MODEL and GROQ_ACCURACY_MODEL != GROQ_TURBO_MODEL:
        accurate_text = transcribe_with_groq(audio_path, language, GROQ_ACCURACY_MODEL)
        if transcript_looks_useful(accurate_text):
            return genius_candidates_from_lyrics(accurate_text, language)
    return []


# =====================================================================
# SPOTIFY + APPLE MUSIC ENRICHMENT
# =====================================================================

_spotify_token_lock = threading.Lock()
_spotify_token: Optional[str] = None
_spotify_token_expires_at = 0.0


def get_spotify_access_token() -> Optional[str]:
    global _spotify_token, _spotify_token_expires_at
    if not SPOTIFY_CLIENT_ID or not SPOTIFY_CLIENT_SECRET:
        return None

    with _spotify_token_lock:
        if _spotify_token and time.time() < _spotify_token_expires_at - 60:
            return _spotify_token

        try:
            response = requests.post(
                "https://accounts.spotify.com/api/token",
                auth=(SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET),
                data={"grant_type": "client_credentials"},
                timeout=(2.5, 5),
            )
            if response.status_code != 200:
                print(f"[SPOTIFY AUTH] HTTP {response.status_code}")
                return None
            payload = response.json()
            _spotify_token = payload.get("access_token")
            expires_in = int(payload.get("expires_in") or 3600)
            _spotify_token_expires_at = time.time() + expires_in
            return _spotify_token
        except Exception as exc:
            print(f"[SPOTIFY AUTH ERROR] {exc}")
            return None


def _spotify_track_quality(track: Dict[str, Any], title: str, artist: str) -> float:
    track_title = str(track.get("name") or "")
    track_artist = ""
    artists = track.get("artists") or []
    if artists:
        track_artist = str((artists[0] or {}).get("name") or "")

    title_similarity = similarity(track_title, title)
    artist_similarity = similarity(track_artist, artist) if artist else 0.0
    popularity = float(track.get("popularity") or 0) / 100.0

    if artist:
        quality = 0.62 * title_similarity + 0.33 * artist_similarity + 0.05 * popularity
    else:
        quality = 0.90 * title_similarity + 0.10 * popularity

    lowered = f"{track_title} {track_artist}".casefold()
    if is_unwanted_version(track_title, track_artist):
        quality -= 0.45
    if "remix" in lowered and "remix" not in title.casefold():
        quality -= 0.08
    return quality


@lru_cache(maxsize=512)
def spotify_lookup(title: str, artist: str, language: str) -> Dict[str, Any]:
    token = get_spotify_access_token()
    query = f"{title} {artist}".strip()
    if not query:
        return {}
    if not token:
        return {"spotify_url": f"https://open.spotify.com/search/{requests.utils.quote(query)}"}

    market = LANGUAGE_TO_MARKET.get(language, LANGUAGE_TO_MARKET["en"])["spotify"]
    try:
        response = requests.get(
            "https://api.spotify.com/v1/search",
            params={"q": query, "type": "track", "limit": 10, "market": market},
            headers={"Authorization": f"Bearer {token}"},
            timeout=(2.5, 5),
        )
        if response.status_code != 200:
            return {"spotify_url": f"https://open.spotify.com/search/{requests.utils.quote(query)}"}
        tracks = response.json().get("tracks", {}).get("items", [])
    except Exception as exc:
        print(f"[SPOTIFY SEARCH ERROR] {exc}")
        return {"spotify_url": f"https://open.spotify.com/search/{requests.utils.quote(query)}"}

    ranked = sorted(
        ((track, _spotify_track_quality(track, title, artist)) for track in tracks),
        key=lambda pair: pair[1],
        reverse=True,
    )
    if not ranked or ranked[0][1] < 0.56:
        return {"spotify_url": f"https://open.spotify.com/search/{requests.utils.quote(query)}"}

    track, quality = ranked[0]
    artists = track.get("artists") or []
    track_artist = str((artists[0] or {}).get("name") or artist) if artists else artist
    external_urls = track.get("external_urls") or {}
    track_id = track.get("id")
    spotify_url = external_urls.get("spotify") or (
        f"spotify:track:{track_id}" if track_id else f"https://open.spotify.com/search/{requests.utils.quote(query)}"
    )
    return {
        "title": str(track.get("name") or title),
        "artist": track_artist,
        "spotify_url": spotify_url,
        "spotify_match_quality": round(quality, 4),
    }


@lru_cache(maxsize=512)
def apple_lookup(title: str, artist: str, language: str) -> Dict[str, Any]:
    query = f"{title} {artist}".strip()
    if not query:
        return {}
    country = LANGUAGE_TO_MARKET.get(language, LANGUAGE_TO_MARKET["en"])["apple"]

    try:
        response = requests.get(
            "https://itunes.apple.com/search",
            params={"term": query, "entity": "song", "limit": 8, "country": country},
            timeout=(2.5, 5),
        )
        if response.status_code != 200:
            return {}
        results = response.json().get("results", [])
    except Exception as exc:
        print(f"[APPLE LOOKUP ERROR] {exc}")
        return {}

    def quality(item: Dict[str, Any]) -> float:
        title_score = similarity(str(item.get("trackName") or ""), title)
        artist_score = similarity(str(item.get("artistName") or ""), artist) if artist else 0.0
        return 0.68 * title_score + 0.32 * artist_score if artist else title_score

    ranked = sorted(((item, quality(item)) for item in results), key=lambda pair: pair[1], reverse=True)
    if not ranked or ranked[0][1] < 0.54:
        return {}

    item, _ = ranked[0]
    artwork = str(item.get("artworkUrl100") or "")
    if artwork:
        artwork = artwork.replace("100x100bb", "600x600bb")
    return {
        "apple_music_url": str(item.get("trackViewUrl") or ""),
        "cover_url": artwork,
        "genre": str(item.get("primaryGenreName") or ""),
    }


def enrich_candidate(candidate: Dict[str, Any], language: str) -> Dict[str, Any]:
    enriched = dict(candidate)
    title = str(enriched.get("title") or "").strip()
    artist = str(enriched.get("artist") or "").strip()

    # If ACRCloud already supplied a Spotify ID, prefer that direct ID.
    external_metadata = enriched.get("external_metadata")
    if isinstance(external_metadata, dict):
        spotify_meta = external_metadata.get("spotify")
        if isinstance(spotify_meta, dict):
            track = spotify_meta.get("track")
            spotify_id = track.get("id") if isinstance(track, dict) else spotify_meta.get("id")
            if spotify_id:
                enriched["spotify_url"] = f"https://open.spotify.com/track/{spotify_id}"

    # Spotify and Apple lookups are independent, so run them together.
    with ThreadPoolExecutor(max_workers=2) as executor:
        spotify_future = executor.submit(spotify_lookup, title, artist, language)
        apple_future = executor.submit(apple_lookup, title, artist, language)
        spotify = spotify_future.result()
        apple = apple_future.result()

    if not enriched.get("spotify_url") and spotify.get("spotify_url"):
        enriched["spotify_url"] = spotify["spotify_url"]

    # For lyric/Genius candidates, a strong Spotify catalog confirmation is a
    # useful canonicalization of punctuation/featured-artist formatting.
    if enriched.get("source") == "groq_genius" and (spotify.get("spotify_match_quality") or 0) >= 0.72:
        enriched["title"] = spotify.get("title") or title
        enriched["artist"] = spotify.get("artist") or artist

    # If Spotify canonicalized the title/artist, refresh the Apple lookup key
    # only when the first result was weak/missing. This avoids a second request
    # in the normal case.
    for key in ("apple_music_url", "cover_url", "genre"):
        if apple.get(key):
            enriched[key] = apple[key]

    return enriched


def enrich_candidates(candidates: List[Dict[str, Any]], language: str) -> List[Dict[str, Any]]:
    if not candidates:
        return []
    enriched_by_index: Dict[int, Dict[str, Any]] = {}
    with ThreadPoolExecutor(max_workers=min(3, len(candidates))) as executor:
        future_to_index = {
            executor.submit(enrich_candidate, candidate, language): index
            for index, candidate in enumerate(candidates)
        }
        for future in as_completed(future_to_index):
            index = future_to_index[future]
            try:
                enriched_by_index[index] = future.result()
            except Exception as exc:
                print(f"[CATALOG ENRICHMENT WARNING] {exc}")
                enriched_by_index[index] = dict(candidates[index])
    return [enriched_by_index[i] for i in range(len(candidates))]


# =====================================================================
# CANDIDATE FUSION
# =====================================================================

def merge_candidates(*groups: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    merged: Dict[str, Dict[str, Any]] = {}
    for group in groups:
        for candidate in group:
            title = str(candidate.get("title") or "").strip()
            artist = str(candidate.get("artist") or "").strip()
            if not title or is_unwanted_version(title, artist):
                continue
            key = candidate_key(title, artist)
            if not key.strip("|"):
                continue

            incoming = dict(candidate)
            if key not in merged:
                merged[key] = incoming
                continue

            current = merged[key]
            current_score = current.get("confidence") or 0.0
            incoming_score = incoming.get("confidence") or 0.0
            different_sources = current.get("source") != incoming.get("source")
            best = max(float(current_score), float(incoming_score))
            if different_sources:
                best = min(0.99, best + 0.06)
                current["source"] = f"{current.get('source')}+{incoming.get('source')}"
            current["confidence"] = best
            current["score"] = best
            for k, v in incoming.items():
                if not current.get(k) and v:
                    current[k] = v

    results = list(merged.values())
    results.sort(key=lambda c: c.get("confidence") or 0.0, reverse=True)
    return results


# =====================================================================
# API
# =====================================================================

@app.get("/")
def read_root() -> Dict[str, Any]:
    return {
        "status": "Reczt recognition backend online",
        "version": "2.0",
        "pipeline": "ACRCloud humming/music + Groq Whisper + Genius + Spotify + Apple Music",
    }


@app.get("/health")
def health_check() -> Dict[str, Any]:
    # Never expose secret values. This is intentionally only a configured/not
    # configured diagnostic so you can verify Render environment variables.
    return {
        "status": "ok",
        "services": {
            "acrcloud": acrcloud_configured(),
            "groq": bool(GROQ_API_KEY),
            "genius": bool(GENIUS_ACCESS_TOKEN),
            "spotify": bool(SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET),
            "apple_music_lookup": True,
        },
    }


@app.post("/recognize")
def recognize_audio(
    file: UploadFile = File(...),
    language: str = Form("en"),
    vocal_isolation: str = Form("true"),
    environment: str = Form("quiet"),
) -> Dict[str, Any]:
    language = normalize_language(language)
    environment = normalize_environment(environment)
    vocal_isolation_requested = parse_bool(vocal_isolation)

    if not acrcloud_configured() and not (groq_client and GENIUS_ACCESS_TOKEN):
        raise HTTPException(
            status_code=503,
            detail="Recognition services are not configured on the server.",
        )

    with tempfile.TemporaryDirectory(prefix="reczt_") as temp_dir:
        raw_path = os.path.join(temp_dir, "raw.wav")
        processed_path = os.path.join(temp_dir, "processed.wav")

        try:
            with open(raw_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)
            if not os.path.exists(raw_path) or os.path.getsize(raw_path) == 0:
                return {"success": False, "message": "Empty audio upload."}

            # The Flutter app already applies microphone noise suppression when
            # appropriate. Server-side we use conservative silence trimming only;
            # aggressive "vocal isolation" DSP can damage the melody fingerprint.
            trim_pcm_wav_silence(raw_path, processed_path, environment)

            acr_kind, acr_candidates = recognize_with_acrcloud(processed_path)
            print(
                f"[ACR RESULT] type={acr_kind} candidates={len(acr_candidates)} "
                f"environment={environment} vocal_isolation={vocal_isolation_requested}"
            )

            lyric_candidates: List[Dict[str, Any]] = []
            if not acr_result_is_decisive(acr_kind, acr_candidates, environment):
                lyric_candidates = lyric_fallback_candidates(processed_path, language)

            combined = merge_candidates(acr_candidates, lyric_candidates)
            if not combined:
                return {
                    "success": False,
                    "message": "Could not confidently recognize this song. Try singing a clear 8–12 second section.",
                }

            # Avoid hands-free autoplay of extremely weak guesses. The Flutter
            # app handles ordinary ambiguity itself (and only shows Top Guesses
            # when Auto Play is off), but the server rejects near-random matches.
            top_confidence = combined[0].get("confidence") or 0.0
            if top_confidence < 0.35:
                return {
                    "success": False,
                    "message": "Recognition confidence was too low. Try again with a clearer melody or lyric phrase.",
                }

            results = enrich_candidates(combined[:3], language)
            results.sort(key=lambda c: c.get("confidence") or 0.0, reverse=True)
            top = results[0]

            # Backward-compatible top-level fields plus the new scored list that
            # your optimized main.dart understands.
            response: Dict[str, Any] = {
                "success": True,
                "title": top.get("title", ""),
                "artist": top.get("artist", ""),
                "spotify_url": top.get("spotify_url", ""),
                "apple_music_url": top.get("apple_music_url", ""),
                "confidence": top.get("confidence"),
                "genre": top.get("genre", ""),
                "cover_url": top.get("cover_url", ""),
                "source": top.get("source", ""),
                "recognition_type": top.get("recognition_type", acr_kind),
                "results": results,
            }
            return response

        except HTTPException:
            raise
        except Exception as exc:
            print(f"[SERVER ERROR] {type(exc).__name__}: {exc}")
            # A true server failure should be a 5xx response so the optimized
            # Flutter retry/offline-queue logic knows not to discard the clip.
            raise HTTPException(status_code=500, detail="Recognition server error") from exc
