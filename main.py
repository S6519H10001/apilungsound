from fastapi import FastAPI, WebSocket, WebSocketDisconnect, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import numpy as np
import librosa
import wave
import os
import asyncio
from io import BytesIO
from tensorflow.keras.models import load_model

MODEL_PATH = 'lung_cnn_model.h5'
SAMPLE_RATE = 16000
DURATION = 3
N_MELS = 128
FIXED_SHAPE = (128, 128)
CLASSES = ['normal', 'wheezing']
RAW_AUDIO_FILE = "fastapi_audio.wav"
PROCESSED_AUDIO_DIR = "processed_audio"

app = FastAPI(title="Unified Lung Sound API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

model = load_model(MODEL_PATH)
listeners = set()
os.makedirs(PROCESSED_AUDIO_DIR, exist_ok=True)
if os.path.exists(RAW_AUDIO_FILE):
    os.remove(RAW_AUDIO_FILE)

def extract_mel_from_wav(file_bytes):
    y, sr = librosa.load(BytesIO(file_bytes), sr=SAMPLE_RATE)
    max_amp = np.max(np.abs(y))
    if max_amp > 0:
        y = y / max_amp
    y = librosa.util.fix_length(y, size=SAMPLE_RATE * DURATION)
    mel = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=N_MELS)
    mel_db = librosa.power_to_db(mel, ref=np.max)
    mel_resized = librosa.util.fix_length(mel_db, size=FIXED_SHAPE[1], axis=1)
    return mel_resized[..., np.newaxis]

def analyze_audio_buffer(audio_bytes):
    audio_np = np.frombuffer(audio_bytes, dtype=np.int16).astype(np.float32) / 32768.0
    mel = librosa.feature.melspectrogram(y=audio_np, sr=SAMPLE_RATE, n_mels=N_MELS)
    mel_db = librosa.power_to_db(mel, ref=np.max)
    mel_db = librosa.util.fix_length(mel_db, size=FIXED_SHAPE[1], axis=1)
    mel_db = mel_db[..., np.newaxis]
    X = np.expand_dims(mel_db, axis=0)
    pred = model.predict(X)
    class_idx = int(np.argmax(pred))
    return {
        "class": CLASSES[class_idx],
        "confidence": float(pred[0][class_idx])
    }

@app.get("/")
def read_root():
    return {"message": "Unified Lung Sound Classification API is running."}

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    if not file.filename.endswith(".wav"):
        raise HTTPException(status_code=400, detail="Only .wav files are supported")

    try:
        file_bytes = await file.read()
        mel = extract_mel_from_wav(file_bytes)
        X = np.expand_dims(mel, axis=0)
        pred = model.predict(X)
        class_idx = int(np.argmax(pred))
        confidence = float(pred[0][class_idx])
        return {"class": CLASSES[class_idx], "confidence": round(confidence, 4)}
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})

@app.websocket("/audio")
async def websocket_audio(websocket: WebSocket):
    await websocket.accept()
    print("ESP32 connected for audio stream")
    try:
        with wave.open(RAW_AUDIO_FILE, "wb") as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(SAMPLE_RATE)
            while True:
                data = await websocket.receive_bytes()
                wav_file.writeframes(data)
                result = analyze_audio_buffer(data)

                for client in listeners.copy():
                    try:
                        await client.send_json(result)
                    except Exception:
                        listeners.remove(client)
    except WebSocketDisconnect:
        print("ESP32 disconnected")

@app.websocket("/audio_listen")
async def websocket_audio_listen(websocket: WebSocket):
    await websocket.accept()
    listeners.add(websocket)
    print("Listener connected")
    try:
        while True:
            await asyncio.sleep(1)
    except WebSocketDisconnect:
        listeners.remove(websocket)
        print("Listener disconnected")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
    
    #uvicorn main:app --reload
    # To run the server, use the command: uvicorn main:app --reload