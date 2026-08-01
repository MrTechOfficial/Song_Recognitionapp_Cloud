import os
import time
import base64
import hashlib
import hmac
import shutil
import requests
from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware

# 🔑 REPLACE THESE WITH YOUR HUMMING/SINGING PROJECT KEYS FROM ACRCLOUD
config = {
    'host': 'identify-us-west-2.acrcloud.com',         # e.g., 'identify-us-east-1.acrcloud.com'
    'access_key': 'a9d1192c3bd32cfac5189730d8609eed',   # e.g., 'a1b2c3d4e5...'
    'access_secret': 'O6aptwHzdCjsQAROiLCoYzFhjlFv6imWs3VVFw6G', # e.g., 'x1y2z3...'
    'timeout': 10
}

app = FastAPI()

# Allow Flutter web frontend to talk to this backend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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

@app.get("/")
def read_root():
    return {"status": "ACRCloud Song Recognition Active"}

@app.post("/recognize")
@app.post("/recognize")
async def recognize_audio(file: UploadFile = File(...)):
    file_ext = os.path.splitext(file.filename)[1] or ".wav"
    temp_filename = f"temp_recording{file_ext}"

    # Save audio clip temporarily
    with open(temp_filename, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    file_size = os.path.getsize(temp_filename)
    print(f"\n[SERVER LOG] Received audio clip: {temp_filename} ({file_size} bytes)")

    try:
        sign_data = generate_acr_signature(config['host'], config['access_key'], config['access_secret'])
        url = f"https://{config['host']}/v1/identify"

        with open(temp_filename, "rb") as audio_file:
            files = {'sample': audio_file}
            response = requests.post(url, data=sign_data, files=files, timeout=config['timeout'])

        result = response.json()
        print("============== RAW ACRCLOUD RESPONSE ==============")
        print(f"ACRCloud Output: {result}")
        print("===================================================\n")

        # Clean up temporary file
        if os.path.exists(temp_filename):
            os.remove(temp_filename)

        status_code = result.get('status', {}).get('code', -1)
        metadata = result.get('metadata', {})

        # 🔍 Humming API places results under 'humming' or 'music'
        items = metadata.get('humming') or metadata.get('music') or []

        if status_code == 0 and len(items) > 0:
            music_data = items[0]
            title = music_data.get('title', 'Unknown Title')
            
            artists = music_data.get('artists', [])
            artist = artists[0]['name'] if artists else 'Unknown Artist'

            # Extract Spotify Track URL from metadata
           # Extract Spotify URI scheme to trigger native app
            spotify_url = ""
            external_metadata = music_data.get('external_metadata', {})
            if 'spotify' in external_metadata and 'track' in external_metadata['spotify']:
                track_id = external_metadata['spotify']['track'].get('id')
                if track_id:
                    spotify_url = f"spotify:track:{track_id}"

            # Fallback search URI for native Spotify app
            if not spotify_url:
                search_query = f"{title} {artist}".replace(" ", "%20")
                spotify_url = f"spotify:search:{search_query}"

            print(f"✅ MATCH FOUND & RELAYING: {title} by {artist}")

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
        if os.path.exists(temp_filename):
            os.remove(temp_filename)
        print(f"Error processing audio: {e}")
        return {
            "success": False,
            "message": f"Server processing error: {e}"
        }