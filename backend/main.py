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
GROQ_RATE_LIMIT_DEFAULT_COOLDOWN_SECONDS = float(
    os.getenv("GROQ_RATE_LIMIT_DEFAULT_COOLDOWN_SECONDS", "5")
)
groq_client = Groq(api_key=GROQ_API_KEY) if GROQ_API_KEY else None

# A 429 on one Whisper model should not make Reczt repeatedly hammer that same
# model while its quota is still cooling down. The other Whisper model can still
# be tried because Groq publishes separate model limits.
_groq_rate_limit_lock = threading.Lock()
_groq_rate_limit_until: Dict[str, float] = {}

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

# Reczt is intentionally conservative about alternate releases. A user who
# sings or hums a familiar song usually wants the canonical/original recording,
# not a karaoke cut, tribute, cover, club mix, workout version, or novelty edit.
# Explicit covers/imitation products are rejected outright; official remixes and
# alternate mixes remain technically eligible but receive a large ranking penalty
# unless we can safely canonicalize them back to the original catalog recording.
BLOCKED_VERSION_PHRASES = (
    "karaoke",
    "karaoke version",
    "sing along",
    "sing-along",
    "tribute",
    "tribute to",
    "tribute band",
    "in the style of",
    "made famous by",
    "as made famous by",
    "originally performed by",
    "sound alike",
    "sound-alike",
    "soundalike",
    "backing track",
    "backing vocals",
    "instrumental version",
    "instrumental cover",
    "cover version",
    "acoustic cover",
    "piano cover",
    "guitar cover",
    "orchestral cover",
    "cover by",
    "workout mix",
    "fitness version",
    "nightcore",
    "8d audio",
)

# These are not hard-blocked because a major artist can legitimately release an
# official remix or alternate version. They are, however, strongly disfavored.
STRONG_DERIVATIVE_PHRASES = (
    "club mix",
    "club remix",
    "dance mix",
    "dance remix",
    "extended mix",
    "extended remix",
    "extended version",
    "dj mix",
    "dj remix",
    "dub mix",
    "dub remix",
    "house mix",
    "house remix",
    "techno mix",
    "techno remix",
    "festival mix",
    "festival remix",
    "vip mix",
    "bootleg",
    "mashup",
    "mash-up",
    "rework",
    "re-edit",
    "re edit",
    "workout mix",
    "fitness version",
    "sped up",
    "speed up",
    "slowed",
    "slowed down",
    "reverb",
    "reverbed",
    "nightcore",
    "8d audio",
)

LOW_PREFERENCE_VERSION_PHRASES = (
    "radio edit",
    "single edit",
    "edit",
    "live",
    "acoustic",
    "demo",
    "alternate take",
    "alternate version",
)

# Version descriptors are removed only for catalog lookup / same-song matching.
# The recognized title itself is preserved until a strong Spotify/Apple catalog
# result confirms that it is safe to map the result back to the canonical track.
_VERSION_WORDS_RE = re.compile(
    r"\b(?:remix|mix|edit|rework|re-edit|version|club|dance|extended|dj|dub|"
    r"house|techno|festival|vip|bootleg|mashup|mash-up|sped\s+up|slowed|"
    r"reverb|nightcore|8d\s+audio|live|acoustic|demo|cover|karaoke)\b",
    re.IGNORECASE,
)

app = FastAPI(title="Reczt Song Recognition Engine", version="3.1")
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


def _combined_version_text(title: str, artist: str = "") -> str:
    return f"{title or ''} {artist or ''}".casefold().strip()


def version_kind(title: str, artist: str = "") -> str:
    """Classify release/version text for ranking and canonicalization."""
    title_text = (title or "").casefold().strip()
    combined = _combined_version_text(title, artist)

    # Tribute/cover branding is often placed in the artist field, so the hard
    # reject scans title + artist. Remix/live descriptors, however, are evaluated
    # on the title only so an artist name cannot accidentally trigger them.
    if any(phrase in combined for phrase in BLOCKED_VERSION_PHRASES):
        return "blocked_cover_or_novelty"

    if re.search(
        r"(?:\(|\[|\-|–|—|:)\s*(?:cover|remake)(?:\s+version)?\b|"
        r"\b(?:cover|remake)\s+version\b",
        title_text,
        flags=re.IGNORECASE,
    ):
        return "blocked_cover_or_novelty"

    if any(phrase in title_text for phrase in STRONG_DERIVATIVE_PHRASES):
        if re.search(r"\b(?:club|dance|extended|dj|dub|house|techno|festival|vip)\b", title_text):
            return "club_or_extended_mix"
        if re.search(r"\b(?:bootleg|mashup|mash-up|rework|re-edit|re edit)\b", title_text):
            return "bootleg_or_rework"
        return "novelty_edit"

    if re.search(r"\bremix\b", title_text):
        return "remix"

    # Avoid treating an ordinary word such as "mix" as a derivative unless it
    # appears in a common release-descriptor position or next to a qualifier.
    if re.search(
        r"(?:\(|\[|\-|–|—|:)\s*[^\]\)]{0,35}\b(?:mix|edit)\b|"
        r"\b(?:radio|single|original|album)\s+(?:mix|edit)\b",
        title_text,
        flags=re.IGNORECASE,
    ):
        return "alternate_mix_or_edit"

    if re.search(r"\blive\b", title_text):
        return "live"
    if re.search(r"\bacoustic\b", title_text):
        return "acoustic"
    if re.search(r"\bdemo\b|\balternate\s+(?:take|version)\b", title_text):
        return "alternate"

    return "canonical"


def strip_version_descriptors(title: str) -> str:
    """Return a conservative base title for canonical catalog lookup.

    Parenthetical/bracketed/trailing segments are removed only when they contain
    obvious version words. This keeps legitimate punctuation and subtitles that
    are part of the actual song title.
    """
    value = (title or "").strip()
    if not value:
        return value

    def remove_bracketed(match: re.Match) -> str:
        content = match.group(0)
        return "" if _VERSION_WORDS_RE.search(content) else content

    value = re.sub(r"\([^)]*\)|\[[^\]]*\]", remove_bracketed, value)

    # Remove a trailing release descriptor after a separator, but only when that
    # suffix actually contains a version keyword.
    parts = re.split(r"\s+[\-–—:]\s+", value)
    while len(parts) > 1 and _VERSION_WORDS_RE.search(parts[-1] or ""):
        parts.pop()
    value = " - ".join(parts)

    # Handle simple suffixes such as "Song Remix" or "Song Club Mix" when no
    # punctuation separates the descriptor.
    value = re.sub(
        r"\s+(?:club\s+mix|club\s+remix|dance\s+mix|dance\s+remix|"
        r"extended\s+mix|extended\s+remix|dj\s+mix|dj\s+remix|dub\s+mix|"
        r"house\s+mix|festival\s+mix|radio\s+edit|single\s+edit|remix)\s*$",
        "",
        value,
        flags=re.IGNORECASE,
    )

    value = re.sub(r"\s+", " ", value).strip(" -–—:()[]")
    return value or (title or "").strip()


def is_unwanted_version(title: str, artist: str) -> bool:
    return version_kind(title, artist) == "blocked_cover_or_novelty"


def version_preference_penalty(
    title: str,
    artist: str,
    *,
    popularity: float = 0.0,
) -> float:
    """Strongly prefer canonical studio releases.

    Popularity can soften a penalty slightly for a major official alternate
    release, but it no longer lets a club/remix version nearly tie the original.
    """
    kind = version_kind(title, artist)
    popularity = max(0.0, min(float(popularity or 0.0), 1.0))

    if kind == "blocked_cover_or_novelty":
        return 1.0
    if kind == "club_or_extended_mix":
        return 0.30 if popularity >= 0.75 else 0.36 if popularity >= 0.50 else 0.42
    if kind == "bootleg_or_rework":
        return 0.34 if popularity >= 0.70 else 0.43
    if kind == "novelty_edit":
        return 0.36 if popularity >= 0.70 else 0.44
    if kind == "remix":
        return 0.24 if popularity >= 0.75 else 0.31 if popularity >= 0.50 else 0.38
    if kind == "alternate_mix_or_edit":
        return 0.16 if popularity >= 0.70 else 0.23
    if kind == "live":
        return 0.08 if popularity >= 0.70 else 0.14
    if kind == "acoustic":
        return 0.06 if popularity >= 0.70 else 0.11
    if kind == "alternate":
        return 0.10 if popularity >= 0.70 else 0.16
    return 0.0


def _same_song_base_title(first_title: str, second_title: str) -> float:
    """Similarity of underlying song titles after version suffixes are removed."""
    return similarity(
        strip_version_descriptors(first_title),
        strip_version_descriptors(second_title),
    )


def _artist_similarity(first_artist: str, second_artist: str) -> float:
    if not first_artist or not second_artist:
        return 0.0
    return similarity(first_artist, second_artist)

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


def wav_duration_seconds(path: str) -> float:
    """Return PCM WAV duration, or 0.0 when the file cannot be inspected."""
    try:
        with wave.open(path, "rb") as source:
            rate = source.getframerate()
            frames = source.getnframes()
        if rate <= 0:
            return 0.0
        return max(0.0, frames / float(rate))
    except Exception:
        return 0.0


def extract_pcm_wav_segment(
    input_path: str,
    output_path: str,
    start_seconds: float,
    duration_seconds: float,
) -> bool:
    """Write a time slice of a PCM WAV without introducing another codec/DSP.

    Recognition windows are intentionally cut losslessly from the uploaded WAV.
    If the file is not a readable PCM WAV, return False and keep the full-file
    recognition path available.
    """
    try:
        with wave.open(input_path, "rb") as source:
            channels = source.getnchannels()
            sample_width = source.getsampwidth()
            frame_rate = source.getframerate()
            frame_count = source.getnframes()
            compression = source.getcomptype()

            if (
                compression != "NONE"
                or channels < 1
                or sample_width < 1
                or frame_rate <= 0
                or frame_count <= 0
            ):
                return False

            start_frame = max(0, min(frame_count, int(start_seconds * frame_rate)))
            wanted_frames = max(1, int(duration_seconds * frame_rate))
            end_frame = min(frame_count, start_frame + wanted_frames)
            if end_frame <= start_frame:
                return False

            source.setpos(start_frame)
            frames = source.readframes(end_frame - start_frame)

        if not frames:
            return False

        with wave.open(output_path, "wb") as target:
            target.setnchannels(channels)
            target.setsampwidth(sample_width)
            target.setframerate(frame_rate)
            target.setcomptype("NONE", "not compressed")
            target.writeframes(frames)
        return True
    except Exception as exc:
        print(f"[AUDIO WINDOW WARNING] {type(exc).__name__}")
        return False


def _meaningfully_different_files(first: str, second: str) -> bool:
    """Avoid duplicate ACR calls when silence trimming did not change the clip."""
    try:
        first_size = os.path.getsize(first)
        second_size = os.path.getsize(second)
        if first_size <= 0 or second_size <= 0:
            return False
        size_delta = abs(first_size - second_size) / max(first_size, second_size)
        return size_delta >= 0.025
    except OSError:
        return False


def build_acr_audio_passes(
    raw_path: str,
    processed_path: str,
    temp_dir: str,
) -> List[Tuple[str, str]]:
    """Build complementary full-clip and overlapping-window ACR inputs.

    The same singing attempt is examined several ways:
    - silence-trimmed full clip
    - raw full clip when trimming materially changed it
    - overlapping 8-second slices for 10-12 second recordings

    This gives Reczt consensus evidence without making the user sing repeatedly.
    """
    passes: List[Tuple[str, str]] = [("trimmed_full", processed_path)]

    if _meaningfully_different_files(raw_path, processed_path):
        passes.append(("raw_full", raw_path))

    duration = wav_duration_seconds(processed_path)

    # Even an 8-second Quiet clip gets two complementary 6-second windows.
    # Longer Loud/Outdoor clips use 8-second windows.
    if duration >= 7.25:
        window = 6.0 if duration < 9.25 else 8.0
        last_start = max(0.0, duration - window)
        starts = [0.0, last_start]

        # Add a center view only when the raw-vs-trimmed comparison did not
        # already consume our fourth provider call.
        if len(passes) < 2 and last_start >= 1.5:
            starts.insert(1, last_start / 2.0)

        unique_starts: List[float] = []
        for start in starts:
            rounded = round(start, 2)
            if all(abs(rounded - prior) >= 0.35 for prior in unique_starts):
                unique_starts.append(rounded)

        for index, start in enumerate(unique_starts):
            if len(passes) >= 4:
                break
            segment_path = os.path.join(
                temp_dir,
                f"acr_window_{index}_{int(start * 1000)}.wav",
            )
            if extract_pcm_wav_segment(
                processed_path,
                segment_path,
                start,
                window,
            ):
                passes.append((f"window_{start:.2f}", segment_path))

    # Four concurrent ACR calls is a deliberate quality/latency/cost ceiling.
    return passes[:4]


def _source_family(source: str) -> str:
    source = (source or "").casefold()
    if "acrcloud" in source:
        return "acrcloud"
    if "genius" in source or "groq" in source:
        return "lyrics"
    return source or "unknown"


def _candidate_match_strength(
    first: Dict[str, Any],
    second: Dict[str, Any],
) -> float:
    """Fuzzy same-song matching across providers and release variants.

    ACRCloud may name a remix while Genius/Spotify names the canonical track.
    If the base title and primary artist strongly agree, treat those as evidence
    for the same underlying song; merge logic will keep the cleaner release name.
    Covers by a different artist remain separate.
    """
    first_title = str(first.get("title") or "")
    second_title = str(second.get("title") or "")
    title_score = _same_song_base_title(first_title, second_title)
    if title_score < 0.90:
        return 0.0

    first_artist = str(first.get("artist") or "")
    second_artist = str(second.get("artist") or "")
    if not first_artist or not second_artist:
        return title_score if title_score >= 0.98 else 0.0

    artist_score = _artist_similarity(first_artist, second_artist)
    if title_score >= 0.97 and artist_score >= 0.62:
        return (0.76 * title_score) + (0.24 * artist_score)
    if title_score >= 0.92 and artist_score >= 0.78:
        return (0.72 * title_score) + (0.28 * artist_score)
    return 0.0

# =====================================================================
# ACRCLOUD

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


def recognize_with_acrcloud_consensus(
    raw_path: str,
    processed_path: str,
    temp_dir: str,
    environment: str,
) -> Tuple[str, List[Dict[str, Any]], Dict[str, Any]]:
    """Run several complementary ACR passes and rank by repeatability.

    A wrong one-off candidate is less trustworthy than a song that wins across
    the full clip and multiple overlapping melodic windows.
    """
    passes = build_acr_audio_passes(raw_path, processed_path, temp_dir)
    pass_results: List[Tuple[str, str, List[Dict[str, Any]]]] = []

    if not acrcloud_configured():
        return "unavailable", [], {
            "passes_attempted": 0,
            "passes_with_candidates": 0,
            "top_votes": 0,
        }

    with ThreadPoolExecutor(max_workers=min(4, max(1, len(passes)))) as executor:
        futures = {
            executor.submit(recognize_with_acrcloud, path): label
            for label, path in passes
        }
        for future in as_completed(futures):
            label = futures[future]
            try:
                kind, candidates = future.result()
            except Exception as exc:
                print(f"[ACR PASS ERROR] label={label} type={type(exc).__name__}")
                continue

            for candidate in candidates:
                candidate["acr_pass_label"] = label
            pass_results.append((label, kind, candidates))

    aggregated: List[Dict[str, Any]] = []
    kinds: Dict[str, int] = {}

    for label, kind, candidates in pass_results:
        if candidates:
            kinds[kind] = kinds.get(kind, 0) + 1

        # A lower-ranked result can still be useful consensus evidence, but cap
        # each pass so one noisy response cannot overwhelm the vote.
        for candidate in candidates[:4]:
            incoming = dict(candidate)
            incoming_conf = float(incoming.get("confidence") or 0.0)

            matched: Optional[Dict[str, Any]] = None
            best_strength = 0.0
            for current in aggregated:
                strength = _candidate_match_strength(current, incoming)
                if strength > best_strength:
                    best_strength = strength
                    matched = current

            if matched is None or best_strength <= 0.0:
                incoming["acr_pass_votes"] = 1
                incoming["acr_pass_labels"] = [label]
                incoming["acr_confidence_sum"] = incoming_conf
                incoming["acr_max_confidence"] = incoming_conf
                aggregated.append(incoming)
                continue

            labels = list(matched.get("acr_pass_labels") or [])
            if label not in labels:
                labels.append(label)
                matched["acr_pass_votes"] = int(
                    matched.get("acr_pass_votes") or 1
                ) + 1
                matched["acr_confidence_sum"] = float(
                    matched.get("acr_confidence_sum") or 0.0
                ) + incoming_conf

            matched["acr_pass_labels"] = labels
            matched["acr_max_confidence"] = max(
                float(matched.get("acr_max_confidence") or 0.0),
                incoming_conf,
            )

            # Preserve metadata from the strongest pass.
            if incoming_conf > float(matched.get("confidence") or 0.0):
                protected = {
                    "acr_pass_votes": matched.get("acr_pass_votes"),
                    "acr_pass_labels": matched.get("acr_pass_labels"),
                    "acr_confidence_sum": matched.get("acr_confidence_sum"),
                    "acr_max_confidence": matched.get("acr_max_confidence"),
                }
                matched.update(incoming)
                matched.update(protected)
            else:
                for key, value in incoming.items():
                    if not matched.get(key) and value:
                        matched[key] = value

    passes_attempted = len(pass_results)
    for candidate in aggregated:
        votes = int(candidate.get("acr_pass_votes") or 1)
        max_conf = float(
            candidate.get("acr_max_confidence")
            or candidate.get("confidence")
            or 0.0
        )
        mean_conf = float(candidate.get("acr_confidence_sum") or max_conf) / max(
            1,
            votes,
        )

        # Repeatability is evidence, but the provider's actual confidence remains
        # dominant. This avoids turning several mediocre guesses into certainty.
        vote_bonus = min(0.11, 0.035 * max(0, votes - 1))
        consistency_bonus = 0.02 if votes >= 2 and mean_conf >= 0.55 else 0.0
        confidence = min(0.98, max_conf + vote_bonus + consistency_bonus)
        candidate["confidence"] = round(confidence, 4)
        candidate["score"] = candidate["confidence"]
        candidate["acr_mean_confidence"] = round(mean_conf, 4)
        candidate["acr_passes_attempted"] = passes_attempted
        candidate["source"] = f"{candidate.get('source', 'acrcloud')}+multipass"

    aggregated.sort(
        key=lambda c: (
            float(c.get("confidence") or 0.0),
            int(c.get("acr_pass_votes") or 1),
        ),
        reverse=True,
    )

    dominant_kind = "no_match"
    if kinds:
        dominant_kind = max(kinds, key=kinds.get)
    if aggregated:
        dominant_kind = str(
            aggregated[0].get("recognition_type")
            or dominant_kind
        )

    meta = {
        "passes_attempted": passes_attempted,
        "passes_with_candidates": sum(1 for _, _, c in pass_results if c),
        "top_votes": int(aggregated[0].get("acr_pass_votes") or 0)
        if aggregated
        else 0,
        "top_mean_confidence": float(
            aggregated[0].get("acr_mean_confidence") or 0.0
        )
        if aggregated
        else 0.0,
    }
    print(
        f"[ACR MULTIPASS] passes={meta['passes_attempted']} "
        f"candidate_passes={meta['passes_with_candidates']} "
        f"top_votes={meta['top_votes']} environment={environment}"
    )
    return dominant_kind, aggregated, meta


def acr_result_is_decisive(
    kind: str,
    candidates: List[Dict[str, Any]],
    environment: str,
) -> bool:
    if not candidates:
        return False

    top_candidate = candidates[0]
    top = float(top_candidate.get("confidence") or 0.0)
    second = (
        float(candidates[1].get("confidence") or 0.0)
        if len(candidates) > 1
        else None
    )
    votes = int(top_candidate.get("acr_pass_votes") or 1)
    passes = int(top_candidate.get("acr_passes_attempted") or 1)
    noise_adjustment = 0.025 if environment in {"loud", "outdoors"} else 0.0

    top_title = str(top_candidate.get("title") or "")
    top_artist = str(top_candidate.get("artist") or "")
    top_variant_penalty = version_preference_penalty(
        top_title,
        top_artist,
        popularity=0.0,
    )

    if top_variant_penalty >= 0.045:
        return False

    # Multi-pass agreement is more important than a single provider score.
    if passes >= 2 and votes < 2 and top < 0.93:
        return False

    if kind == "music":
        threshold = 0.84 + noise_adjustment
    else:
        threshold = 0.73 + noise_adjustment

    if top < threshold:
        return False

    if second is None:
        return votes >= 2 or top >= 0.91

    gap = top - second
    return gap >= 0.075 or top >= 0.93


# =====================================================================
# GROQ + GENIUS LYRIC FALLBACK
# =====================================================================

def _groq_exception_status_code(exc: Exception) -> Optional[int]:
    """Best-effort HTTP status extraction without depending on one SDK version."""
    status_code = getattr(exc, "status_code", None)
    if isinstance(status_code, int):
        return status_code

    response = getattr(exc, "response", None)
    response_status = getattr(response, "status_code", None)
    if isinstance(response_status, int):
        return response_status

    # Last-resort compatibility for older/newer SDK exception text.
    match = re.search(r"\b(4\d\d|5\d\d)\b", str(exc))
    return int(match.group(1)) if match else None


def _groq_retry_after_seconds(exc: Exception) -> float:
    response = getattr(exc, "response", None)
    headers = getattr(response, "headers", None) or {}
    raw = None
    try:
        raw = headers.get("retry-after")
    except Exception:
        raw = None

    if raw is not None:
        try:
            return max(0.5, float(raw))
        except (TypeError, ValueError):
            pass

    return max(0.5, GROQ_RATE_LIMIT_DEFAULT_COOLDOWN_SECONDS)


def _groq_model_in_cooldown(model: str) -> Tuple[bool, float]:
    now = time.time()
    with _groq_rate_limit_lock:
        until = float(_groq_rate_limit_until.get(model, 0.0) or 0.0)
        if until <= now:
            _groq_rate_limit_until.pop(model, None)
            return False, 0.0
        return True, max(0.0, until - now)


def _mark_groq_model_rate_limited(model: str, retry_after: float) -> None:
    until = time.time() + max(0.5, retry_after)
    with _groq_rate_limit_lock:
        previous = float(_groq_rate_limit_until.get(model, 0.0) or 0.0)
        _groq_rate_limit_until[model] = max(previous, until)


def transcribe_with_groq(
    audio_path: str,
    language: str,
    model: str,
) -> Dict[str, Any]:
    """Transcribe once and return status metadata instead of hiding 429s.

    The old function returned an empty string for every Groq failure, which made
    a quota error indistinguishable from a genuinely unusable transcription.
    Reczt can now immediately fall through to the other Whisper model when one
    model is rate-limited.
    """
    if not groq_client:
        return {
            "text": "",
            "status": "unavailable",
            "model": model,
            "retry_after": 0.0,
        }

    cooling_down, seconds_left = _groq_model_in_cooldown(model)
    if cooling_down:
        print(
            f"[GROQ COOLDOWN {model}] remaining_seconds={seconds_left:.1f}"
        )
        return {
            "text": "",
            "status": "rate_limited",
            "model": model,
            "retry_after": seconds_left,
        }

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

        # Never log recognized lyrics/user speech.
        print(
            f"[GROQ {model} {language}] "
            f"status=ok transcript_chars={len(text)}"
        )
        return {
            "text": text,
            "status": "ok",
            "model": model,
            "retry_after": 0.0,
        }

    except Exception as exc:
        status_code = _groq_exception_status_code(exc)

        if status_code == 429:
            retry_after = _groq_retry_after_seconds(exc)
            _mark_groq_model_rate_limited(model, retry_after)
            print(
                f"[GROQ RATE LIMIT {model}] "
                f"retry_after_seconds={retry_after:.1f}"
            )
            return {
                "text": "",
                "status": "rate_limited",
                "model": model,
                "retry_after": retry_after,
            }

        # Keep logs content-free, but preserve enough metadata to diagnose
        # provider/server failures.
        print(
            f"[GROQ ERROR {model}] "
            f"status_code={status_code or 'unknown'} "
            f"type={type(exc).__name__}"
        )
        return {
            "text": "",
            "status": "error",
            "model": model,
            "retry_after": 0.0,
        }


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


def genius_candidates_from_lyrics(
    lyrics: str,
    language: str,
) -> List[Dict[str, Any]]:
    if not GENIUS_ACCESS_TOKEN or not lyrics.strip():
        return []

    headers = {"Authorization": f"Bearer {GENIUS_ACCESS_TOKEN}"}
    aggregated: Dict[str, Dict[str, Any]] = {}

    queries = build_lyric_queries(lyrics)

    def search_query(
        query_index: int,
        query: str,
    ) -> Tuple[int, List[Dict[str, Any]]]:
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
    with ThreadPoolExecutor(
        max_workers=min(4, max(1, len(queries)))
    ) as executor:
        futures = [
            executor.submit(search_query, i, q)
            for i, q in enumerate(queries)
        ]
        for future in as_completed(futures):
            query_results.append(future.result())

    for query_index, hits in query_results:
        for rank, hit in enumerate(hits):
            result = hit.get("result") or {}
            title = str(result.get("title") or "").strip()
            artist = str(
                (result.get("primary_artist") or {}).get("name") or ""
            ).strip()
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
                current["genius_hits"] = (
                    int(current.get("genius_hits", 1)) + 1
                )
                # Appearing for more than one independent lyric snippet is much
                # stronger evidence than a single Genius search ranking.
                boosted = (
                    max(current.get("confidence") or 0.0, rank_score) + 0.055
                )
                current["confidence"] = min(0.84, boosted)
                current["score"] = current["confidence"]

    results = list(aggregated.values())
    results.sort(key=lambda c: c.get("confidence") or 0.0, reverse=True)
    return results[:5]


def _lyric_candidates_are_strong(
    candidates: List[Dict[str, Any]],
) -> bool:
    """Decide whether Turbo evidence is good enough to avoid full V3.

    Turbo remains the fast path. Full V3 is used only for weak/ambiguous Turbo
    evidence, which improves accuracy without doubling Groq traffic on every
    recognition.
    """
    if not candidates:
        return False

    top = candidates[0]
    top_score = float(top.get("confidence") or 0.0)
    top_hits = int(top.get("genius_hits") or 1)

    second_score = (
        float(candidates[1].get("confidence") or 0.0)
        if len(candidates) > 1
        else 0.0
    )
    gap = top_score - second_score

    if top_score >= 0.78:
        return True

    return (
        top_score >= 0.70
        and top_hits >= 2
        and (len(candidates) == 1 or gap >= 0.06)
    )


def _merge_groq_candidate_sets(
    first: List[Dict[str, Any]],
    second: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    """Merge Turbo and full-V3 Genius evidence.

    Agreement between the two independent Whisper passes receives a small
    confidence boost while keeping the existing `groq_genius` source name so
    the rest of Reczt's enrichment/ranking code remains backward compatible.
    """
    merged: Dict[str, Dict[str, Any]] = {}

    for model_index, group in enumerate((first, second)):
        for candidate in group:
            title = str(candidate.get("title") or "").strip()
            artist = str(candidate.get("artist") or "").strip()
            if not title:
                continue

            key = candidate_key(title, artist)
            incoming = dict(candidate)

            if key not in merged:
                incoming["groq_model_votes"] = 1
                merged[key] = incoming
                continue

            current = merged[key]
            current_score = float(current.get("confidence") or 0.0)
            incoming_score = float(incoming.get("confidence") or 0.0)
            votes = int(current.get("groq_model_votes") or 1) + 1

            current["groq_model_votes"] = votes
            current["genius_hits"] = max(
                int(current.get("genius_hits") or 1),
                int(incoming.get("genius_hits") or 1),
            )

            # If Turbo and full V3 independently point to the same song, that
            # agreement is more meaningful than either pass alone.
            consensus_score = min(
                0.90,
                max(current_score, incoming_score) + 0.05,
            )
            current["confidence"] = consensus_score
            current["score"] = consensus_score

    results = list(merged.values())
    results.sort(key=lambda c: c.get("confidence") or 0.0, reverse=True)
    return results[:5]


def lyric_fallback_candidates(
    audio_path: str,
    language: str,
    secondary_audio_path: Optional[str] = None,
) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
    """Turbo-first, accuracy-on-demand, quota-aware lyric evidence.

    The fast transcription uses the silence-trimmed clip. When its evidence is
    weak, full V3 gets a second view of the *raw* upload (when available). This
    is a lightweight A/B check that can recover lyrics altered by trimming or
    device-side processing without exposing transcript text in logs/responses.
    """
    meta: Dict[str, Any] = {
        "attempted_models": [],
        "rate_limited_models": [],
        "all_models_rate_limited": False,
        "used_secondary_audio": False,
        "turbo_useful": False,
        "accuracy_useful": False,
    }

    if not groq_client or not GENIUS_ACCESS_TOKEN:
        return [], meta

    turbo_candidates: List[Dict[str, Any]] = []
    accuracy_candidates: List[Dict[str, Any]] = []

    turbo_result = transcribe_with_groq(
        audio_path,
        language,
        GROQ_TURBO_MODEL,
    )
    meta["attempted_models"].append(GROQ_TURBO_MODEL)

    if turbo_result["status"] == "rate_limited":
        meta["rate_limited_models"].append(GROQ_TURBO_MODEL)
    else:
        turbo_text = str(turbo_result.get("text") or "")
        if transcript_looks_useful(turbo_text):
            meta["turbo_useful"] = True
            turbo_candidates = genius_candidates_from_lyrics(
                turbo_text,
                language,
            )

    if _lyric_candidates_are_strong(turbo_candidates):
        return turbo_candidates, meta

    accuracy_audio_path = audio_path
    if (
        secondary_audio_path
        and secondary_audio_path != audio_path
        and os.path.exists(secondary_audio_path)
        and os.path.getsize(secondary_audio_path) > 0
    ):
        accuracy_audio_path = secondary_audio_path
        meta["used_secondary_audio"] = True

    if GROQ_ACCURACY_MODEL and GROQ_ACCURACY_MODEL != GROQ_TURBO_MODEL:
        accuracy_result = transcribe_with_groq(
            accuracy_audio_path,
            language,
            GROQ_ACCURACY_MODEL,
        )
        meta["attempted_models"].append(GROQ_ACCURACY_MODEL)

        if accuracy_result["status"] == "rate_limited":
            meta["rate_limited_models"].append(GROQ_ACCURACY_MODEL)
        else:
            accuracy_text = str(accuracy_result.get("text") or "")
            if transcript_looks_useful(accuracy_text):
                meta["accuracy_useful"] = True
                accuracy_candidates = genius_candidates_from_lyrics(
                    accuracy_text,
                    language,
                )

    attempted = set(meta["attempted_models"])
    limited = set(meta["rate_limited_models"])
    meta["all_models_rate_limited"] = bool(attempted) and attempted == limited

    if turbo_candidates and accuracy_candidates:
        return (
            _merge_groq_candidate_sets(
                turbo_candidates,
                accuracy_candidates,
            ),
            meta,
        )

    if accuracy_candidates:
        return accuracy_candidates, meta

    return turbo_candidates, meta


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

    requested_base = strip_version_descriptors(title)
    track_base = strip_version_descriptors(track_title)
    title_similarity = similarity(track_base, requested_base)
    artist_similarity = similarity(track_artist, artist) if artist else 0.0
    popularity = max(0.0, min(float(track.get("popularity") or 0) / 100.0, 1.0))

    if artist:
        quality = (
            0.60 * title_similarity
            + 0.30 * artist_similarity
            + 0.10 * popularity
        )
    else:
        quality = 0.82 * title_similarity + 0.18 * popularity

    kind = version_kind(track_title, track_artist)
    penalty = version_preference_penalty(
        track_title,
        track_artist,
        popularity=popularity,
    )
    if penalty >= 1.0:
        return -1.0

    # A clean canonical track gets an explicit bonus when the recognition result
    # contained a derivative suffix. This lets the original beat a club/remix
    # result even when the derivative title is textually closer to the query.
    input_kind = version_kind(title, artist)
    canonical_bonus = 0.0
    if kind == "canonical":
        canonical_bonus += 0.055
        if input_kind != "canonical":
            canonical_bonus += 0.055

    return quality + canonical_bonus - penalty


@lru_cache(maxsize=512)
def spotify_lookup(title: str, artist: str, language: str) -> Dict[str, Any]:
    token = get_spotify_access_token()
    base_title = strip_version_descriptors(title)
    query = f"{base_title} {artist}".strip()
    if not query:
        return {}
    if not token:
        return {
            "spotify_url": f"https://open.spotify.com/search/{requests.utils.quote(query)}",
            "catalog_query_title": base_title,
        }

    market = LANGUAGE_TO_MARKET.get(language, LANGUAGE_TO_MARKET["en"])["spotify"]
    try:
        response = requests.get(
            "https://api.spotify.com/v1/search",
            params={"q": query, "type": "track", "limit": 15, "market": market},
            headers={"Authorization": f"Bearer {token}"},
            timeout=(2.5, 5),
        )
        if response.status_code != 200:
            return {
                "spotify_url": f"https://open.spotify.com/search/{requests.utils.quote(query)}",
                "catalog_query_title": base_title,
            }
        tracks = response.json().get("tracks", {}).get("items", [])
    except Exception as exc:
        print(f"[SPOTIFY SEARCH ERROR] {exc}")
        return {
            "spotify_url": f"https://open.spotify.com/search/{requests.utils.quote(query)}",
            "catalog_query_title": base_title,
        }

    ranked = sorted(
        ((track, _spotify_track_quality(track, title, artist)) for track in tracks),
        key=lambda pair: pair[1],
        reverse=True,
    )
    if not ranked or ranked[0][1] < 0.58:
        return {
            "spotify_url": f"https://open.spotify.com/search/{requests.utils.quote(query)}",
            "catalog_query_title": base_title,
        }

    track, quality = ranked[0]
    artists = track.get("artists") or []
    track_artist = str((artists[0] or {}).get("name") or artist) if artists else artist
    track_title = str(track.get("name") or title)
    external_urls = track.get("external_urls") or {}
    track_id = track.get("id")
    spotify_url = external_urls.get("spotify") or (
        f"spotify:track:{track_id}" if track_id else f"https://open.spotify.com/search/{requests.utils.quote(query)}"
    )
    kind = version_kind(track_title, track_artist)
    return {
        "title": track_title,
        "artist": track_artist,
        "spotify_url": spotify_url,
        "spotify_match_quality": round(quality, 4),
        "spotify_popularity": int(track.get("popularity") or 0),
        "spotify_version_kind": kind,
        "spotify_is_canonical": kind == "canonical",
        "catalog_query_title": base_title,
    }


@lru_cache(maxsize=512)
def apple_lookup(title: str, artist: str, language: str) -> Dict[str, Any]:
    base_title = strip_version_descriptors(title)
    query = f"{base_title} {artist}".strip()
    if not query:
        return {}
    country = LANGUAGE_TO_MARKET.get(language, LANGUAGE_TO_MARKET["en"])["apple"]

    try:
        response = requests.get(
            "https://itunes.apple.com/search",
            params={"term": query, "entity": "song", "limit": 12, "country": country},
            timeout=(2.5, 5),
        )
        if response.status_code != 200:
            return {}
        results = response.json().get("results", [])
    except Exception as exc:
        print(f"[APPLE LOOKUP ERROR] {exc}")
        return {}

    def quality(item: Dict[str, Any]) -> float:
        track_title = str(item.get("trackName") or "")
        track_artist = str(item.get("artistName") or "")
        if is_unwanted_version(track_title, track_artist):
            return -1.0

        title_score = similarity(
            strip_version_descriptors(track_title),
            base_title,
        )
        artist_score = similarity(track_artist, artist) if artist else 0.0
        base = 0.68 * title_score + 0.32 * artist_score if artist else title_score
        penalty = version_preference_penalty(
            track_title,
            track_artist,
            popularity=0.0,
        )
        canonical_bonus = 0.05 if version_kind(track_title, track_artist) == "canonical" else 0.0
        if version_kind(title, artist) != "canonical" and version_kind(track_title, track_artist) == "canonical":
            canonical_bonus += 0.04
        return base + canonical_bonus - penalty

    ranked = sorted(
        ((item, quality(item)) for item in results),
        key=lambda pair: pair[1],
        reverse=True,
    )
    if not ranked or ranked[0][1] < 0.56:
        return {}

    item, item_quality = ranked[0]
    artwork = str(item.get("artworkUrl100") or "")
    if artwork:
        artwork = artwork.replace("100x100bb", "600x600bb")
    track_title = str(item.get("trackName") or title)
    track_artist = str(item.get("artistName") or artist)
    kind = version_kind(track_title, track_artist)
    return {
        "title": track_title,
        "artist": track_artist,
        "apple_music_url": str(item.get("trackViewUrl") or ""),
        "cover_url": artwork,
        "genre": str(item.get("primaryGenreName") or ""),
        "apple_match_quality": round(item_quality, 4),
        "apple_version_kind": kind,
        "apple_is_canonical": kind == "canonical",
        "catalog_query_title": base_title,
    }


def enrich_candidate(candidate: Dict[str, Any], language: str) -> Dict[str, Any]:
    enriched = dict(candidate)
    original_title = str(enriched.get("title") or "").strip()
    original_artist = str(enriched.get("artist") or "").strip()
    original_kind = version_kind(original_title, original_artist)
    original_penalty = version_preference_penalty(
        original_title,
        original_artist,
        popularity=0.0,
    )

    enriched["recognized_version_kind"] = original_kind
    enriched["recognized_base_title"] = strip_version_descriptors(original_title)

    # Keep ACRCloud's direct Spotify link only as a fallback. It can point to the
    # exact club/remix recording that ACRCloud heard, which is precisely what Reczt
    # should avoid auto-playing when a canonical release can be confirmed.
    acr_spotify_url: Optional[str] = None
    external_metadata = enriched.get("external_metadata")
    if isinstance(external_metadata, dict):
        spotify_meta = external_metadata.get("spotify")
        if isinstance(spotify_meta, dict):
            track = spotify_meta.get("track")
            spotify_id = track.get("id") if isinstance(track, dict) else spotify_meta.get("id")
            if spotify_id:
                acr_spotify_url = f"https://open.spotify.com/track/{spotify_id}"
                enriched["acr_spotify_url"] = acr_spotify_url

    # Search the canonicalized base title in both catalogs.
    with ThreadPoolExecutor(max_workers=2) as executor:
        spotify_future = executor.submit(
            spotify_lookup,
            original_title,
            original_artist,
            language,
        )
        apple_future = executor.submit(
            apple_lookup,
            original_title,
            original_artist,
            language,
        )
        spotify = spotify_future.result()
        apple = apple_future.result()

    spotify_quality = float(spotify.get("spotify_match_quality") or 0.0)
    spotify_popularity = max(
        0.0,
        min(float(spotify.get("spotify_popularity") or 0) / 100.0, 1.0),
    )
    apple_quality = float(apple.get("apple_match_quality") or 0.0)

    if spotify.get("spotify_popularity") is not None:
        enriched["spotify_popularity"] = int(spotify.get("spotify_popularity") or 0)
    if spotify.get("spotify_match_quality") is not None:
        enriched["spotify_match_quality"] = spotify_quality
    if apple.get("apple_match_quality") is not None:
        enriched["apple_match_quality"] = apple_quality

    # Canonicalization guard: require a strong catalog match and strong base-title
    # + artist agreement before replacing an identified alternate release.
    spotify_title = str(spotify.get("title") or "")
    spotify_artist = str(spotify.get("artist") or "")
    spotify_same_work = (
        spotify_title
        and _same_song_base_title(spotify_title, original_title) >= 0.94
        and (
            not original_artist
            or not spotify_artist
            or _artist_similarity(spotify_artist, original_artist) >= 0.72
        )
    )
    spotify_can_canonicalize = (
        spotify_quality >= 0.72
        and bool(spotify.get("spotify_is_canonical"))
        and spotify_same_work
    )

    apple_title = str(apple.get("title") or "")
    apple_artist = str(apple.get("artist") or "")
    apple_same_work = (
        apple_title
        and _same_song_base_title(apple_title, original_title) >= 0.94
        and (
            not original_artist
            or not apple_artist
            or _artist_similarity(apple_artist, original_artist) >= 0.72
        )
    )
    apple_can_canonicalize = (
        apple_quality >= 0.72
        and bool(apple.get("apple_is_canonical"))
        and apple_same_work
    )

    canonicalized = False

    # Spotify is the primary playback catalog. If it strongly confirms the clean
    # studio release, overwrite ACRCloud's derivative direct-ID URL as well as the
    # title/artist. This specifically prevents "recognized correctly, played club
    # remix" failures.
    if spotify_can_canonicalize:
        enriched["title"] = spotify_title or original_title
        enriched["artist"] = spotify_artist or original_artist
        if spotify.get("spotify_url"):
            enriched["spotify_url"] = spotify["spotify_url"]
        canonicalized = original_kind != "canonical"
    else:
        # For an already-canonical result, a strong Spotify lookup is still the
        # best playback URL. For unresolved derivatives, prefer no exact remix URL
        # over automatically launching the wrong version.
        if original_kind == "canonical" and spotify_quality >= 0.66 and spotify.get("spotify_url"):
            enriched["spotify_url"] = spotify["spotify_url"]
        elif original_kind == "canonical" and acr_spotify_url:
            enriched["spotify_url"] = acr_spotify_url
        elif spotify.get("spotify_url") and spotify_quality >= 0.78:
            enriched["spotify_url"] = spotify["spotify_url"]

    # Apple Music gets the same canonical-release preference.
    if apple_can_canonicalize:
        if not canonicalized and original_kind != "canonical" and not spotify_can_canonicalize:
            enriched["title"] = apple_title or enriched.get("title") or original_title
            enriched["artist"] = apple_artist or enriched.get("artist") or original_artist
            canonicalized = True
        if apple.get("apple_music_url"):
            enriched["apple_music_url"] = apple["apple_music_url"]
    elif original_kind == "canonical" and apple_quality >= 0.64 and apple.get("apple_music_url"):
        enriched["apple_music_url"] = apple["apple_music_url"]

    # Artwork/genre can safely come from the best catalog result even when URL
    # canonicalization was not strong enough to overwrite playback identity.
    if apple.get("cover_url"):
        enriched["cover_url"] = apple["cover_url"]
    if apple.get("genre"):
        enriched["genre"] = apple["genre"]

    # Lyric/Genius candidates benefit from strong canonical catalog formatting.
    if (
        "groq_genius" in str(enriched.get("source") or "")
        and spotify_quality >= 0.72
        and spotify_same_work
    ):
        enriched["title"] = spotify_title or enriched.get("title") or original_title
        enriched["artist"] = spotify_artist or enriched.get("artist") or original_artist

    final_title = str(enriched.get("title") or original_title)
    final_artist = str(enriched.get("artist") or original_artist)
    final_kind = version_kind(final_title, final_artist)

    # If a derivative was safely mapped to a clean catalog track, do not continue
    # penalizing the final original. Otherwise retain the strict penalty associated
    # with the recognized version even if minor metadata normalization changed it.
    if canonicalized and final_kind == "canonical":
        version_penalty = 0.0
    else:
        version_penalty = max(
            original_penalty,
            version_preference_penalty(
                final_title,
                final_artist,
                popularity=spotify_popularity,
            ),
        )

    base_confidence = float(enriched.get("confidence") or 0.0)
    catalog_confirmation = max(0.0, spotify_quality, apple_quality)

    # Recognition evidence remains dominant, but the canonical catalog gets more
    # influence than before and derivative versions now lose a substantial amount.
    selection_score = (
        0.80 * base_confidence
        + 0.12 * min(catalog_confirmation, 1.0)
        + 0.08 * spotify_popularity
        - version_penalty
    )

    # Tiny bonus for a safe derivative->canonical mapping. It breaks near-ties
    # without overpowering recognition evidence.
    if canonicalized:
        selection_score += 0.025

    enriched["canonicalized_from_version"] = canonicalized
    enriched["version_kind"] = final_kind
    enriched["version_penalty"] = round(version_penalty, 4)
    enriched["selection_score"] = round(
        max(0.0, min(selection_score, 1.0)),
        4,
    )

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
    """Fuse melodic and lyric evidence, including fuzzy provider agreement."""
    merged: List[Dict[str, Any]] = []

    for group in groups:
        for candidate in group:
            title = str(candidate.get("title") or "").strip()
            artist = str(candidate.get("artist") or "").strip()
            if not title or is_unwanted_version(title, artist):
                continue

            incoming = dict(candidate)
            incoming_source = str(incoming.get("source") or "unknown")
            incoming_family = _source_family(incoming_source)

            best_match: Optional[Dict[str, Any]] = None
            best_strength = 0.0
            for current in merged:
                strength = _candidate_match_strength(current, incoming)
                if strength > best_strength:
                    best_strength = strength
                    best_match = current

            if best_match is None or best_strength <= 0.0:
                incoming["evidence_sources"] = [incoming_family]
                incoming["evidence_count"] = 1
                merged.append(incoming)
                continue

            current = best_match
            current_source = str(current.get("source") or "unknown")
            current_family = _source_family(current_source)
            sources = set(current.get("evidence_sources") or [current_family])
            before_source_count = len(sources)
            sources.add(incoming_family)

            current_score = float(current.get("confidence") or 0.0)
            incoming_score = float(incoming.get("confidence") or 0.0)
            best_score = max(current_score, incoming_score)

            # Independent provider agreement (melody + lyric) is the strongest
            # signal. Same-family duplicate evidence still earns a smaller boost.
            cross_provider = len(sources) > before_source_count
            agreement_boost = 0.075 if cross_provider else 0.018

            # ACR multipass votes are already reflected in its confidence. Keep
            # them visible as evidence rather than double-counting the full bonus.
            if (
                incoming_family == "acrcloud"
                and int(incoming.get("acr_pass_votes") or 1) >= 2
            ):
                agreement_boost += 0.012

            fused_score = min(0.99, best_score + agreement_boost)
            current["confidence"] = round(fused_score, 4)
            current["score"] = current["confidence"]
            current["evidence_sources"] = sorted(sources)
            current["evidence_count"] = len(sources)

            if cross_provider and incoming_source not in current_source:
                current["source"] = f"{current_source}+{incoming_source}"

            # Prefer the cleaner release representation when two providers agree
            # on the same underlying song. Example: ACRCloud says "Song (Club
            # Mix)" while Genius says "Song" by the same artist. Keep the shared
            # evidence/confidence, but carry the canonical title/artist forward.
            current_penalty = version_preference_penalty(
                str(current.get("title") or ""),
                str(current.get("artist") or ""),
                popularity=0.0,
            )
            incoming_penalty = version_preference_penalty(
                str(incoming.get("title") or ""),
                str(incoming.get("artist") or ""),
                popularity=0.0,
            )
            incoming_is_cleaner = incoming_penalty + 0.03 < current_penalty

            if incoming_is_cleaner or (
                abs(incoming_penalty - current_penalty) < 0.03
                and incoming_score > current_score
            ):
                for key in (
                    "title",
                    "artist",
                    "language",
                    "recognition_type",
                    "genres",
                    "album",
                    "acrid",
                    "release_date",
                ):
                    if incoming.get(key):
                        current[key] = incoming[key]

                # Metadata IDs from the dirtier representation may point directly
                # to a remix/club version. Let catalog enrichment rebuild them.
                if incoming_is_cleaner:
                    current.pop("external_metadata", None)
                    current.pop("spotify_url", None)
                    current.pop("apple_music_url", None)
            elif incoming_score > current_score and incoming.get("external_metadata"):
                current["external_metadata"] = incoming["external_metadata"]

            for key, value in incoming.items():
                if key in {"confidence", "score", "source"}:
                    continue
                if not current.get(key) and value:
                    current[key] = value

            current["acr_pass_votes"] = max(
                int(current.get("acr_pass_votes") or 0),
                int(incoming.get("acr_pass_votes") or 0),
            )
            current["genius_hits"] = max(
                int(current.get("genius_hits") or 0),
                int(incoming.get("genius_hits") or 0),
            )

    merged.sort(
        key=lambda c: (
            float(c.get("confidence") or 0.0),
            int(c.get("evidence_count") or 1),
            int(c.get("acr_pass_votes") or 0),
        ),
        reverse=True,
    )
    return merged


# =====================================================================
# API
# =====================================================================

@app.get("/")
def read_root() -> Dict[str, Any]:
    return {
        "status": "Reczt recognition backend online",
        "version": "3.1",
        "pipeline": "ACRCloud multi-pass consensus + Groq/Genius cross-check + strict canonical-release selection + Spotify + Apple Music",
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
    auto_play: str = Form("true"),
    background_queue: str = Form("false"),
) -> Dict[str, Any]:
    language = normalize_language(language)
    environment = normalize_environment(environment)
    vocal_isolation_requested = parse_bool(vocal_isolation)
    auto_play_requested = parse_bool(auto_play)
    background_queue_requested = parse_bool(background_queue)

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

            # Preserve melody. Server preprocessing is deliberately limited to
            # silence trimming; recognition then compares full/raw/windowed views.
            trim_pcm_wav_silence(raw_path, processed_path, environment)

            acr_kind, acr_candidates, acr_meta = recognize_with_acrcloud_consensus(
                raw_path,
                processed_path,
                temp_dir,
                environment,
            )

            lyric_candidates: List[Dict[str, Any]] = []
            groq_meta: Dict[str, Any] = {
                "attempted_models": [],
                "rate_limited_models": [],
                "all_models_rate_limited": False,
                "used_secondary_audio": False,
            }

            acr_decisive = acr_result_is_decisive(
                acr_kind,
                acr_candidates,
                environment,
            )

            # Cross-check all but genuinely strong, repeated ACR consensus.
            # This keeps the common path fast while using lyric evidence when it
            # can materially resolve a close or one-off melodic guess.
            top_acr_votes = (
                int(acr_candidates[0].get("acr_pass_votes") or 1)
                if acr_candidates
                else 0
            )
            top_acr_confidence = (
                float(acr_candidates[0].get("confidence") or 0.0)
                if acr_candidates
                else 0.0
            )
            should_crosscheck_lyrics = (
                not acr_decisive
                or top_acr_votes < 2
                or top_acr_confidence < 0.88
            )

            if should_crosscheck_lyrics:
                lyric_candidates, groq_meta = lyric_fallback_candidates(
                    processed_path,
                    language,
                    secondary_audio_path=raw_path,
                )

            combined = merge_candidates(acr_candidates, lyric_candidates)

            if not combined:
                if groq_meta.get("all_models_rate_limited"):
                    raise HTTPException(
                        status_code=429,
                        detail=(
                            "Recognition is temporarily rate-limited. "
                            "Please retry shortly."
                        ),
                    )

                return {
                    "success": False,
                    "message": (
                        "Could not confidently recognize this song. "
                        "Try singing a clear 8–12 second melodic or lyric section."
                    ),
                    "retryable": True,
                }

            # Enrich enough choices for robust ranking, but cap catalog traffic.
            results = enrich_candidates(combined[:4], language)
            results.sort(
                key=lambda c: (
                    c.get("selection_score")
                    if c.get("selection_score") is not None
                    else (c.get("confidence") or 0.0)
                ),
                reverse=True,
            )

            # If a clean canonical candidate and an alternate version represent
            # the same song/artist, prefer the clean release whenever it is even
            # reasonably close. The heavier selection-score penalty usually does
            # this already; this guard makes the policy explicit and deterministic.
            if len(results) > 1:
                first = results[0]
                first_kind = str(first.get("version_kind") or version_kind(
                    str(first.get("title") or ""),
                    str(first.get("artist") or ""),
                ))
                if first_kind != "canonical":
                    first_score = float(first.get("selection_score") or 0.0)
                    for idx, candidate in enumerate(results[1:], start=1):
                        candidate_kind = str(candidate.get("version_kind") or version_kind(
                            str(candidate.get("title") or ""),
                            str(candidate.get("artist") or ""),
                        ))
                        if candidate_kind != "canonical":
                            continue
                        same_title = _same_song_base_title(
                            str(first.get("title") or ""),
                            str(candidate.get("title") or ""),
                        ) >= 0.94
                        same_artist = (
                            not str(first.get("artist") or "")
                            or not str(candidate.get("artist") or "")
                            or _artist_similarity(
                                str(first.get("artist") or ""),
                                str(candidate.get("artist") or ""),
                            ) >= 0.72
                        )
                        candidate_score = float(candidate.get("selection_score") or 0.0)
                        if same_title and same_artist and candidate_score >= first_score - 0.16:
                            results.insert(0, results.pop(idx))
                            break

            if not results:
                return {
                    "success": False,
                    "message": "No usable recognition candidates remained.",
                    "retryable": True,
                }

            top = results[0]
            top_selection = float(
                top.get("selection_score")
                if top.get("selection_score") is not None
                else (top.get("confidence") or 0.0)
            )
            top_raw_confidence = float(top.get("confidence") or 0.0)
            evidence_count = int(top.get("evidence_count") or 1)
            acr_votes = int(top.get("acr_pass_votes") or 0)
            top_version_kind = str(top.get("version_kind") or version_kind(
                str(top.get("title") or ""),
                str(top.get("artist") or ""),
            ))
            top_canonicalized = bool(top.get("canonicalized_from_version"))

            # Reczt would rather ask for another attempt than confidently launch a
            # club/remix/novelty recording. A derivative may pass only if it was
            # safely canonicalized to the clean catalog track, or if evidence is
            # exceptionally strong and Auto Play is off (so the user can choose).
            unresolved_strong_derivative = top_version_kind in {
                "club_or_extended_mix",
                "bootleg_or_rework",
                "novelty_edit",
                "remix",
            } and not top_canonicalized

            if unresolved_strong_derivative:
                derivative_can_be_shown_manually = (
                    not auto_play_requested
                    and top_selection >= 0.78
                    and top_raw_confidence >= 0.80
                    and (evidence_count >= 2 or acr_votes >= 2)
                )
                if not derivative_can_be_shown_manually:
                    return {
                        "success": False,
                        "message": (
                            "Reczt found only an alternate/remix version and could "
                            "not safely confirm the original recording. Try singing "
                            "another clear section of the song."
                        ),
                        "retryable": True,
                    }

            second_selection: Optional[float] = None
            if len(results) > 1:
                second = results[1]
                second_selection = float(
                    second.get("selection_score")
                    if second.get("selection_score") is not None
                    else (second.get("confidence") or 0.0)
                )

            if background_queue_requested:
                environment_floor = {
                    "quiet": 0.54,
                    "loud": 0.57,
                    "outdoors": 0.59,
                }.get(environment, 0.59)

                # Independent agreement lets a queued result clear the floor with
                # slightly less raw provider confidence, but unattended matching
                # remains deliberately conservative.
                if evidence_count >= 2 or acr_votes >= 2:
                    environment_floor -= 0.025

                background_is_ambiguous = (
                    second_selection is not None
                    and second_selection >= 0.31
                    and top_selection < 0.84
                    and (top_selection - second_selection) < 0.11
                )

                if (
                    top_raw_confidence < 0.46
                    or top_selection < environment_floor
                    or background_is_ambiguous
                ):
                    return {
                        "success": False,
                        "message": (
                            "Queued recording is not yet strong enough for "
                            "unattended recognition."
                        ),
                        "retryable": True,
                        "background_queue": True,
                    }
            else:
                # Avoid the worst user experience: confidently auto-playing one
                # weak, unsupported guess. If there are two plausible choices,
                # return them so Flutter can ask "first or second" / show Top Guesses.
                base_floor = {
                    "quiet": 0.37 if auto_play_requested else 0.32,
                    "loud": 0.40 if auto_play_requested else 0.34,
                    "outdoors": 0.42 if auto_play_requested else 0.36,
                }.get(environment, 0.40)

                if evidence_count >= 2 or acr_votes >= 2:
                    base_floor -= 0.035

                has_plausible_alternative = (
                    second_selection is not None and second_selection >= 0.28
                )

                if top_selection < base_floor and not has_plausible_alternative:
                    return {
                        "success": False,
                        "message": (
                            "Recognition confidence was too low. Try the same "
                            "melody again a little more clearly."
                        ),
                        "retryable": True,
                    }

            # Backward-compatible top-level fields plus a scored candidate list.
            # recognition_meta intentionally contains no transcript/audio content.
            response: Dict[str, Any] = {
                "success": True,
                "title": top.get("title", ""),
                "artist": top.get("artist", ""),
                "spotify_url": top.get("spotify_url", ""),
                "apple_music_url": top.get("apple_music_url", ""),
                "confidence": top.get("confidence"),
                "selection_score": top.get("selection_score"),
                "genre": top.get("genre", ""),
                "cover_url": top.get("cover_url", ""),
                "source": top.get("source", ""),
                "recognition_type": top.get("recognition_type", acr_kind),
                "results": results[:3],
                "recognition_meta": {
                    "pipeline_version": "3.1",
                    "environment": environment,
                    "acr_passes_attempted": acr_meta.get("passes_attempted", 0),
                    "acr_passes_with_candidates": acr_meta.get(
                        "passes_with_candidates",
                        0,
                    ),
                    "acr_top_votes": acr_meta.get("top_votes", 0),
                    "lyric_crosscheck_used": should_crosscheck_lyrics,
                    "groq_models_attempted": len(
                        groq_meta.get("attempted_models") or []
                    ),
                    "groq_secondary_audio_used": bool(
                        groq_meta.get("used_secondary_audio")
                    ),
                    "vocal_isolation_requested": vocal_isolation_requested,
                },
            }
            return response

        except HTTPException:
            raise
        except Exception as exc:
            print(f"[SERVER ERROR] {type(exc).__name__}: {exc}")
            raise HTTPException(
                status_code=500,
                detail="Recognition server error",
            ) from exc

