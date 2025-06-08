from fastapi import FastAPI, File, UploadFile, HTTPException, WebSocket
from fastapi.responses import JSONResponse
import numpy as np
import librosa
from tensorflow.keras.models import load_model
from io import BytesIO
from fastapi.middleware.cors import CORSMiddleware

MODEL_PATH = 'lung_cnn_model.h5'
SAMPLE_RATE = 16000
DURATION = 3
N_MELS = 128
FIXED_SHAPE = (128, 128)
CLASSES = ['normal', 'wheezing']
model = load_model(MODEL_PATH)

app = FastAPI(title="Lung Sound Classifier API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
    return {"message": "Lung Sound Classification API is running."}

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    if not file.filename.endswith(".wav"):
        raise HTTPException(status_code=400, detail="Only .wav files are supported")

    try:
        file_bytes = await file.read()
        mel = extract_mel_from_wav(file_bytes)
        X = np.expand_dims(mel, axis=0)
        pred = model.predict(X)
        print(pred)
        class_idx = int(np.argmax(pred))
        print(class_idx)
        confidence = float(pred[0][class_idx])
        print(confidence)
        print({
            "class": CLASSES[class_idx],
            "confidence": round(confidence, 4)
        })
        return {
            "class": CLASSES[class_idx],
            "confidence": round(confidence, 4)
        }
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})

@app.websocket("/audio")
async def websocket_audio(ws: WebSocket):
    await ws.accept()
    print("🟢 Client connected")

    try:
        while True:
            audio_data = await ws.receive_bytes()
            result = analyze_audio_buffer(audio_data)
            print("Result:", result)
            await ws.send_json(result)
    except Exception as e:
        print("Client disconnected:", e)