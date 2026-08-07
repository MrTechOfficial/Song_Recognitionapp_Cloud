import os
import time
import base64
import hashlib
import hmac
import shutil
import re
import requests
from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from groq import Groq

# =====================================================================
# 🔑 CONFIGURATION
# =====================================================================

ACR_CONFIG = {
    'host': os.getenv('ACR_HOST', 'identify-us-west-2.acrcloud.com'),
    'access_key': os.getenv('ACR_ACCESS_KEY', 'a9d1192c3bd32cfac5189730d8609eed'),
    'access_secret': os.getenv('ACR_ACCESS_SECRET', 'O6aptwHzdCjsQAROiLCoYzFhjlFv6imWs3VVFw6G'),
    'timeout': 10
}

GROQ_API_KEY = os.getenv('GROQ_API_KEY', '')
groq_client = Groq(api_key=GROQ_API_KEY) if GROQ_API_KEY else None

SPOTIFY_CLIENT_ID = os.getenv('SPOTIFY_CLIENT_ID', '')
SPOTIFY_CLIENT_SECRET = os.getenv('SPOTIFY_CLIENT_SECRET', '')
GENIUS_ACCESS_TOKEN = os.getenv('GENIUS_ACCESS_TOKEN', '')

app = FastAPI(title="Song Recognition Engine")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

COVER_KEYWORDS = ['cover', 'tribute', 'karaoke', 'in the style of', 'version', 'remix']

def generate_acr_signature(host, access_key, access_secret):
    http_method, http_uri, data_type, signature_version = "POST", "/v1/identify", "audio", "1"
    timestamp = str(int(time.time()))
    string_to_sign = f"{http_method}\n{http_uri}\n{access_key}\n{data_type}\n{signature_version}\n{timestamp}"
    sign = hmac.new(access_secret.encode('utf-8'), string_to_sign.encode('utf-8'), digestmod=hashlib.sha1).digest()
    return {
        'access_key': access_key, 'data_type': data_type,
        'signature': base64.b64encode(sign).decode('utf-8'),
        'signature_version': signature_version, 'timestamp': timestamp,
    }

def is_cover_version(title: str, artist: str) -> bool:
    text = f"{title} {artist}".lower()
    return any(keyword in text for keyword in COVER_KEYWORDS)

def get_spotify_access_token():
    if not SPOTIFY_CLIENT_ID or not SPOTIFY_CLIENT_SECRET:
        return None
    url = "https://accounts.spotify.com/api/token"
    auth_header = base64.b64encode(f"{SPOTIFY_CLIENT_ID}:{SPOTIFY_CLIENT_SECRET}".encode()).decode()
    try:
        res = requests.post(url, headers={"Authorization": f"Basic {auth_header}"}, data={"grant_type": "client_credentials"}, timeout=5)
        if res.status_code == 200:
            return res.json().get('access_token')
    except Exception as e:
        print(f"[SPOTIFY AUTH ERROR]: {e}")
    return None

def resolve_lyrics_to_song_with_genius(lyrics: str):
    """Uses Genius API to translate transcribed lyrics into the true Title & Artist."""
    if not GENIUS_ACCESS_TOKEN:
        return None
    
    url = f"https://api.genius.com/search?q={requests.utils.quote(lyrics)}"
    headers = {"Authorization": f"Bearer {GENIUS_ACCESS_TOKEN}"}
    try:
        res = requests.get(url, headers=headers, timeout=5)
        if res.status_code == 200:
            hits = res.json().get('response', {}).get('hits', [])
            if hits:
                top = hits[0]['result']
                title = top.get('title')
                artist = top.get('primary_artist', {}).get('name')
                print(f"[GENIUS LYRIC MATCH]: '{title}' by {artist}")
                return {"title": title, "artist": artist}
    except Exception as e:
        print(f"[GENIUS API ERROR]: {e}")
    return None

def get_apple_music_url(title: str, artist: str) -> str:
    """Queries the iTunes Search API to fetch the direct Apple Music link."""
    clean_title = re.sub(r"[^\w\s]", "", title)
    clean_artist = re.sub(r"[^\w\s]", "", artist)
    query = f"{clean_title} {clean_artist}".strip()
    
    if not query:
        return ""

    url = f"https://itunes.apple.com/search?term={requests.utils.quote(query)}&entity=song&limit=1"
    try:
        res = requests.get(url, timeout=5)
        if res.status_code == 200:
            results = res.json().get('results', [])
            if results:
                apple_url = results[0].get('trackViewUrl')
                print(f"[APPLE MUSIC WINNER]: {apple_url}")
                return apple_url or ""
    except Exception as e:
        print(f"[APPLE MUSIC SEARCH ERROR]: {e}")
        
    return f"https://music.apple.com/us/search?term={requests.utils.quote(query)}"

def get_official_spotify_track(title: str, artist: str):
    """Searches Spotify, strips conflicting punctuation, and enforces a minimum popularity score."""
    token = get_spotify_access_token()
    
    MIN_POPULARITY = 60

    clean_title = re.sub(r"[^\w\s]", "", title)
    clean_artist = re.sub(r"[^\w\s]", "", artist)
    query = f"{clean_title} {clean_artist}"

    if not token:
        return {"title": title, "artist": artist, "spotify_url": f"spotify:search:{requests.utils.quote(query)}"}

    search_url = f"https://api.spotify.com/v1/search?q={requests.utils.quote(query)}&type=track&limit=10"
    headers = {"Authorization": f"Bearer {token}"}
    
    try:
        res = requests.get(search_url, headers=headers, timeout=5)
        if res.status_code == 200:
            tracks = res.json().get('tracks', {}).get('items', [])
            
            valid_tracks = [
                t for t in tracks 
                if not is_cover_version(t.get('name', ''), t['artists'][0]['name'] if t.get('artists') else '')
                and t.get('popularity', 0) >= MIN_POPULARITY
            ]
            
            if not valid_tracks:
                valid_tracks = [
                    t for t in tracks 
                    if not is_cover_version(t.get('name', ''), t['artists'][0]['name'] if t.get('artists') else '')
                ] or tracks

            if valid_tracks:
                valid_tracks.sort(key=lambda x: x.get('popularity', 0), reverse=True)
                top_hit = valid_tracks[0]

                t_name = top_hit.get('name')
                a_name = top_hit['artists'][0]['name']
                track_id = top_hit.get('id')

                print(f"[SPOTIFY WINNER]: '{t_name}' by {a_name} (Popularity Score: {top_hit.get('popularity')})")

                return {
                    "title": t_name,
                    "artist": a_name,
                    "spotify_url": f"spotify:track:{track_id}" if track_id else f"spotify:search:{requests.utils.quote(query)}"
                }
    except Exception as e:
        print(f"[SPOTIFY SEARCH ERROR]: {e}")

    return {"title": title, "artist": artist, "spotify_url": f"spotify:search:{requests.utils.quote(query)}"}

def transcribe_audio_with_groq(audio_file_path: str, language: str = "en") -> str:
    if not groq_client:
        return ""
    try:
        with open(audio_file_path, "rb") as audio_file:
            # Language-aware prompt tuning
            prompt_text = "Transcribe lyrics sung in audio clip."
            if language != "en":
                prompt_text = f"Transcribe lyrics sung in {language} language."

            kwargs = {
                "model": "whisper-large-v3-turbo",
                "file": audio_file,
                "prompt": prompt_text,
                "language": language  # Force Whisper to listen specifically for this language code
            }

            transcript = groq_client.audio.transcriptions.create(**kwargs)
            print(f"[GROQ TRANSCRIPTION ({language})]: '{transcript.text.strip()}'")
            return transcript.text.strip()
    except Exception as e:
        print(f"[GROQ ERROR]: {e}")
        return ""

@app.get("/")
def read_root():
    return {"status": "ACRCloud + Groq Whisper + Spotify + Apple Music + Genius Active"}

@app.post("/recognize")
async def recognize_audio(
    file: UploadFile = File(...),
    language: str = Form("en")
):
    file_ext = os.path.splitext(file.filename)[1] or ".wav"
    temp_filename = f"temp_recording{file_ext}"

    try:
        with open(temp_filename, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # -------------------------------------------------------------
        # STAGE 1: ACRCLOUD (Exact Fingerprint Match)
        # -------------------------------------------------------------
        sign_data = generate_acr_signature(ACR_CONFIG['host'], ACR_CONFIG['access_key'], ACR_CONFIG['access_secret'])
        url = f"https://{ACR_CONFIG['host']}/v1/identify"

        with open(temp_filename, "rb") as audio_file:
            response = requests.post(url, data=sign_data, files={'sample': audio_file}, timeout=ACR_CONFIG['timeout'])
            acr_result = response.json()

        status_code = acr_result.get('status', {}).get('code', -1)
        metadata = acr_result.get('metadata', {})
        items = metadata.get('humming') or metadata.get('music') or []

        if status_code == 0 and len(items) > 0:
            top_match = items[0]
            title = top_match.get('title', '')
            artists = top_match.get('artists', [])
            artist = artists[0]['name'] if artists else ''

            if not is_cover_version(title, artist):
                song_info = get_official_spotify_track(title, artist)
                apple_music_url = get_apple_music_url(song_info['title'], song_info['artist'])
                
                return {
                    "success": True,
                    "title": song_info['title'],
                    "artist": song_info['artist'],
                    "spotify_url": song_info['spotify_url'],
                    "apple_music_url": apple_music_url
                }

        # -------------------------------------------------------------
        # STAGE 2: GROQ WHISPER + GENIUS LYRIC RESOLVER
        # -------------------------------------------------------------
        lyrics = transcribe_audio_with_groq(temp_filename, language=language)

        if lyrics and len(lyrics) > 3:
            genius_match = resolve_lyrics_to_song_with_genius(lyrics)
            
            if genius_match:
                song_info = get_official_spotify_track(genius_match['title'], genius_match['artist'])
            else:
                song_info = get_official_spotify_track(lyrics, "")

            apple_music_url = get_apple_music_url(song_info['title'], song_info['artist'])

            return {
                "success": True,
                "title": song_info['title'],
                "artist": song_info['artist'],
                "spotify_url": song_info['spotify_url'],
                "apple_music_url": apple_music_url
            }

        return {"success": False, "message": "Could not recognize lyrics. Try singing clearer!"}

    except Exception as e:
        return {"success": False, "message": f"Server error: {e}"}

    finally:
        if os.path.exists(temp_filename):
            os.remove(temp_filename)