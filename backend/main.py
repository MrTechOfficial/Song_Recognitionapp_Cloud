import os
import time
import base64
import hashlib
import hmac
import shutil
import requests
from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware

# =====================================================================
# 🔑 STEP 1: INPUT YOUR ACRCLOUD KEYS HERE
# =====================================================================
config = {
    'host': 'identify-us-west-2.acrcloud.com',           # Your ACRCloud Host Link
    'access_key': 'a9d1192c3bd32cfac5189730d8609eed',       # Paste Access Key here
    'access_secret': 'O6aptwHzdCjsQAROiLCoYzFhjlFv6imWs3VVFw6G', # Paste Access Secret here
    'timeout': 10
}

# =====================================================================
# 🚀 FASTAPI APP SETUP & CORS CONFIGURATION
# =====================================================================
app = FastAPI(title="Song Recognition Backend")

# Allows your Flutter app to make network requests to this backend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =====================================================================
# 🔐 HELPER FUNCTION: ACRCLOUD HMAC SIGNATURE GENERATOR
# =====================================================================
def generate_acr_signature(host, access_key, access_secret):
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

    signature = base64.b64encode(sign).decode('utf-8')

    return {
        'access_key': access_key,
        'data_type': data_type,
        'signature': signature,
        'signature_version': signature_version,
        'timestamp': timestamp,
    }

# =====================================================================
# 🌐 API ENDPOINTS
# =====================================================================
@app.get("/")
def read_root():
    """Health check endpoint to verify the server is running."""
    return {"status": "ACRCloud Song Recognition Active"}


@app.post("/recognize")
async def recognize_audio(file: UploadFile = File(...)):
    """Receives audio file from Flutter, sends to ACRCloud, and returns match info."""
    file_ext = os.path.splitext(file.filename)[1] or ".wav"
    temp_filename = f"temp_recording{file_ext}"

    try:
        # Save audio clip temporarily
        with open(temp_filename, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        file_size = os.path.getsize(temp_filename)
        print(f"\n[SERVER LOG] Received audio clip: {temp_filename} ({file_size} bytes)")

        # Generate signature and prepare request
        sign_data = generate_acr_signature(config['host'], config['access_key'], config['access_secret'])
        url = f"https://{config['host']}/v1/identify"

        # Send request to ACRCloud
        with open(temp_filename, "rb") as audio_file:
            files = {'sample': audio_file}
            response = requests.post(url, data=sign_data, files=files, timeout=config['timeout'])

        result = response.json()
        print("============== RAW ACRCLOUD RESPONSE ==============")
        print(f"ACRCloud Output: {result}")
        print("===================================================\n")

        status_code = result.get('status', {}).get('code', -1)
        metadata = result.get('metadata', {})

        # Humming/Singing API returns results under 'humming' or 'music'
        items = metadata.get('humming') or metadata.get('music') or []

        if status_code == 0 and len(items) > 0:
            music_data = items[0]
            title = music_data.get('title', 'Unknown Title')
            
            artists = music_data.get('artists', [])
            artist = artists[0]['name'] if artists else 'Unknown Artist'

# Safely extract Spotify Track ID from any ACRCloud format
            spotify_url = ""
            external_metadata = music_data.get('external_metadata', {})
            spotify_data = external_metadata.get('spotify')

            track_id = None
            if isinstance(spotify_data, dict):
                track_id = spotify_data.get('track', {}).get('id') or spotify_data.get('id')
            elif isinstance(spotify_data, list) and len(spotify_data) > 0:
                first_item = spotify_data[0]
                if isinstance(first_item, dict):
                    track_id = first_item.get('track', {}).get('id') or first_item.get('id')

            if track_id:
                # ⚡ Native URI scheme: opens track card directly in the Spotify app
                spotify_url = f"spotify:track:{track_id}"
            else:
                # Fallback search query only if no track ID was extracted
                search_query = f"{title} {artist}".replace(" ", "%20")
                spotify_url = f"spotify:search:{search_query}"

            print(f"DEBUG Generated Spotify URL: {spotify_url}")

            print(f"✅ MATCH FOUND: {title} by {artist}")

            return {
                "success": True,
                "title": title,
                "artist": artist,
                "spotify_url": spotify_url
            }
        else:
            msg = result.get('status', {}).get('msg', 'No match found.')
            return {
                "success": False,
                "message": f"Could not recognize singing. Try singing a bit louder! ({msg})"
            }

    except Exception as e:
        print(f"Error processing audio: {e}")
        return {
            "success": False,
            "message": f"Server processing error: {e}"
        }

    finally:
        # Guarantee cleanup of temporary file after every request
        if os.path.exists(temp_filename):
            os.remove(temp_filename)