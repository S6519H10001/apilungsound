import librosa
import librosa.display
import matplotlib.pyplot as plt

y, sr = librosa.load("data/wheezing/LSA006.wav", sr=None)

plt.figure(figsize=(10, 4))
librosa.display.waveshow(y, sr=sr)
plt.title("Waveform")
plt.xlabel("Time (s)")
plt.ylabel("Amplitude")
plt.tight_layout()
plt.show()
