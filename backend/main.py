import os
import time
import base64
import hashlib
import hmac
import shutil
import requests
from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from groq import Groq

# =====================================================================
# 🔑 API KEYS & CONFIGURATION
# =====================================================================

# 1. ACRCloud Credentials
ACR_CONFIG = {
    'host': os.getenv('ACR_HOST', 'identify-us-west-2.acrcloud.com'),
    'access_key': os.getenv('ACR_ACCESS_KEY', 'a9d1192c3bd32cfac5189730d8609eed'),
    'access_secret': os.getenv('ACR_ACCESS_SECRET', 'O6aptwHzdCjsQAROiLCoYzFhjlFv6imWs3VVFw6G'),
    'timeout': 10
}

# 2. Groq Credentials (100% Free Whisper Lyric Transcription)
GROQ_API_KEY = os.getenv('GROQ_API_KEY', 'YOUR_GROQ_API_KEY_HERE')
groq_client = Groq(api_key=GROQ_API_KEY) if GROQ_API_KEY != 'YOUR_GROQ_API_KEY_HERE' else None

# 3. Spotify Credentials (for Popularity Ranking)
SPOTIFY_CLIENT_ID = os.getenv('SPOTIFY_CLIENT_ID', 'YOUR_SPOTIFY_CLIENT_ID_HERE')
SPOTIFY_CLIENT_SECRET = os.getenv('SPOTIFY_CLIENT_SECRET', 'YOUR_SPOTIFY_CLIENT_SECRET_HERE')

# =====================================================================
# 🚀 FASTAPI SETUP & CORS
# =====================================================================
app = FastAPI(title="Groq + ACRCloud Song Recognition Engine")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

COVER_KEYWORDS = [
    'cover', 'tribute', 'karaoke', 'in the style of', 
    'originally performed by', 'acoustic cover', 'version', 'remix'
]

# =====================================================================
# 🔐 HELPER FUNCTIONS
# =====================================================================

def generate_acr_signature(host, access_key, access_secret):
    """Generates security HMAC signature required by ACRCloud API."""
    http_method = "POST"
    http_uri = "/v1/identify"
    data_type = "audio"
    signature_version = "1"
    timestamp = str(int(time.time()))

    string_to_sign = f"{http_method}\n{http_uri}\n{access_key}\n{data_type}\n{signature_version}\n{timestamp}"
    
    sign = hmac.new(
        access_secret.encode('utf-8'),
        string_to_sign.encode('utf-8'),
        digestmod=hashlib.sha1
    ).digest()

    return {
        'access_key': access_key,
        'data_type': data_type,
        'signature': base64.b64encode(sign).decode('utf-8'),
        'signature_version': signature_version,
        'timestamp': timestamp,
    }


def is_cover_version(title: str, artist: str) -> bool:
    """Detects whether a track is a cover, karaoke, or tribute version."""
    text = f"{title} {artist}".lower()
    return any(keyword in text for keyword in COVER_KEYWORDS)


def get_spotify_access_token():
    """Obtains a client credentials access token from Spotify Web API."""
    if SPOTIFY_CLIENT_ID == 'YOUR_SPOTIFY_CLIENT_ID_HERE':
        return None
        
    url = "https://accounts.spotify.com/api/token"
    auth_header = base64.b64encode(f"{SPOTIFY_CLIENT_ID}:{SPOTIFY_CLIENT_SECRET}".encode()).decode()
    headers = {"Authorization": f"Basic {auth_header}"}
    data = {"grant_type": "client_credentials"}

    try:
        response = requests.post(url, headers=headers, data=data, timeout=5)
        if response.status_code == 200:
            return response.json().get('access_token')
    except Exception as e:
        print(f"[SPOTIFY AUTH ERROR]: {e}")
    return None


def search_spotify_by_lyrics(query: str):
    """
    Queries Spotify Web API using text lyrics transcribed by Groq,
    filters out cover tracks, and picks the #1 most popular hit track.
    """
    token = get_spotify_access_token()
    if not token:
        clean_query = query.replace(" ", "%20")
        return {
            "title": query.capitalize(),
            "artist": "Original Artist",
            "spotify_url": f"spotify:search:{clean_query}"
        }

    search_url = f"https://api.spotify.com/v1/search?q={requests.utils.quote(query)}&type=track&limit=10"
    headers = {"Authorization": f"Bearer {token}"}

    try:
        response = requests.get(search_url, headers=headers, timeout=5)
        if response.status_code == 200:
            tracks = response.json().get('tracks', {}).get('items', [])
            
            valid_tracks = []
            for track in tracks:
                title = track.get('name', '')
                artist = track['artists'][0]['name'] if track.get('artists') else ''
                
                # Filter out cover songs
                if is_cover_version(title, artist):
                    continue
                    
                valid_tracks.append(track)

            if not valid_tracks:
                valid_tracks = tracks

            if valid_tracks:
                # ⭐ Sort remaining tracks by Spotify Popularity Score (highest first)
                valid_tracks.sort(key=lambda x: x.get('popularity', 0), reverse=True)
                top_hit = valid_tracks[0]

                track_id = top_hit.get('id')
                title = top_hit.get('name')
                artist = top_hit['artists'][0]['name']
                
                print(f"[SPOTIFY POPULARITY WINNER]: '{title}' by {artist} (Score: {top_hit.get('popularity')})")

                return {
                    "title": title,
                    "artist": artist,
                    "spotify_url": f"spotify:track:{track_id}" if track_id else f"spotify:search:{title}%20{artist}"
                }
    except Exception as e:
        print(f"[SPOTIFY SEARCH ERROR]: {e}")

    return {
        "title": query,
        "artist": "Search Results",
        "spotify_url": f"spotify:search:{query.replace(' ', '%20')}"
    }


def transcribe_audio_with_groq(audio_file_path: str) -> str:
    """Uses Groq's high-speed Whisper LPU API to transcribe singing into lyrics."""
    if not groq_client:
        print("[GROQ LOG]: Groq client not configured.")
        return ""

    try:
        print("[GROQ LOG]: Transcribing vocal audio clip using Groq Whisper...")
        with open(audio_file_path, "rb") as audio_file:
            transcript = groq_client.audio.transcriptions.create(
                model="whisper-large-v3-turbo",
                file=audio_file,
                prompt="Transcribe lyrics from singing audio clip."
            )
        lyrics = transcript.text.strip()
        print(f"[GROQ TRANSCRIPT]: '{lyrics}'")
        return lyrics
    except Exception as e:
        print(f"[GROQ ERROR]: {e}")
        return ""

# =====================================================================
# 🌐 API ENDPOINTS
# =====================================================================

@app.get("/")
def read_root():
    return {"status": "ACRCloud + Groq Whisper + Spotify Active"}


@app.post("/recognize")
async def recognize_audio(file: UploadFile = File(...)):
    file_ext = os.path.splitext(file.filename)[1] or ".wav"
    temp_filename = f"temp_recording{file_ext}"

    try:
        # Save temporary recording
        with open(temp_filename, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # -------------------------------------------------------------
        # STAGE 1: TRY ACRCLOUD (Audio Fingerprinting & Pitch Match)
        # -------------------------------------------------------------
        sign_data = generate_acr_signature(ACR_CONFIG['host'], ACR_CONFIG['access_key'], ACR_CONFIG['access_secret'])
        url = f"https://{ACR_CONFIG['host']}/v1/identify"

        acr_result = None
        with open(temp_filename, "rb") as audio_file:
            files = {'sample': audio_file}
            response = requests.post(url, data=sign_data, files=files, timeout=ACR_CONFIG['timeout'])
            acr_result = response.json()

        status_code = acr_result.get('status', {}).get('code', -1)
        metadata = acr_result.get('metadata', {})
        items = metadata.get('humming') or metadata.get('music') or []

        if status_code == 0 and len(items) > 0:
            top_match = items[0]
            title = top_match.get('title', 'Unknown Title')
            artists = top_match.get('artists', [])
            artist = artists[0]['name'] if artists else 'Unknown Artist'

            if not is_cover_version(title, artist):
                print(f"✅ STAGE 1 (ACRCloud Direct Match): '{title}' by {artist}")
                
                external_metadata = top_match.get('external_metadata', {})
                spotify_data = external_metadata.get('spotify')
                track_id = None
                if isinstance(spotify_data, dict):
                    track_id = spotify_data.get('track', {}).get('id') or spotify_data.get('id')

                spotify_url = f"spotify:track:{track_id}" if track_id else f"spotify:search:{title}%20{artist}"

                return {
                    "success": True,
                    "title": title,
                    "artist": artist,
                    "spotify_url": spotify_url
                }
            else:
                print(f"⚠️ STAGE 1 SKIPPED COVER MATCH: '{title}' by {artist}. Handing off to Groq Whisper...")

        # -------------------------------------------------------------
        # STAGE 2: FALLBACK TO GROQ WHISPER (Lyric Extraction)
        # -------------------------------------------------------------
        lyrics = transcribe_audio_with_groq(temp_filename)

        if lyrics and len(lyrics) > 3:
            # -------------------------------------------------------------
            # STAGE 3: SPOTIFY POPULARITY RANKING
            # -------------------------------------------------------------
            spotify_result = search_spotify_by_lyrics(lyrics)
            print(f"✅ STAGE 2/3 (Groq + Spotify Hit): '{spotify_result['title']}' by {spotify_result['artist']}")

            return {
                "success": True,
                "title": spotify_result['title'],
                "artist": spotify_result['artist'],
                "spotify_url": spotify_result['spotify_url']
            }

        return {
            "success": False,
            "message": "Could not recognize song or transcribe lyrics clearly. Try singing louder!"
        }

    except Exception as e:
        print(f"Server Error: {e}")
        return {
            "success": False,
            "message": f"Server error: {e}"
        }

    finally:
        if os.path.exists(temp_filename):
            os.remove(temp_filename)