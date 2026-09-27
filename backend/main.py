1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
28
29
30
31
32
33
34
35
36
37
38
39
40
41
42
43
44
45
46
47
48
49
50
51
52
53
54
55
56
57
58
59
60
61
62
63
64
65
66
67
68
69
70
71
72
73
74
75
76
77
78
79
80
81
82
83
84
85
86
87
88
89
90
91
92
93
94
95
96
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
