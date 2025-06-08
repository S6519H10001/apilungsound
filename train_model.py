import os
import random
import numpy as np
import librosa
import librosa.display
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix, ConfusionMatrixDisplay
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Conv2D, MaxPooling2D, Flatten, Dense, Dropout
from tensorflow.keras.utils import to_categorical
from tensorflow.keras.optimizers import Adam
import tensorflow as tf

SEED = 2025
os.environ['PYTHONHASHSEED'] = str(SEED)
random.seed(SEED)
np.random.seed(SEED)
tf.random.set_seed(SEED)

DATA_PATH = 'data'
CLASSES = ['normal', 'wheezing']
SAMPLE_RATE = 16000
DURATION = 3
N_MELS = 128
FIXED_SHAPE = (128, 128)

def extract_mel(file_path):
    y, sr = librosa.load(file_path, sr=SAMPLE_RATE)
    max_amp = np.max(np.abs(y))
    if max_amp > 0:
        y = y / max_amp
    y = librosa.util.fix_length(y, size=SAMPLE_RATE * DURATION)
    mel = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=N_MELS)
    mel_db = librosa.power_to_db(mel, ref=np.max)
    mel_resized = librosa.util.fix_length(mel_db, size=FIXED_SHAPE[1], axis=1)
    return mel_resized

X, y = [], []
for label, cls in enumerate(CLASSES):
    folder = os.path.join(DATA_PATH, cls)
    for file in os.listdir(folder):
        if file.endswith('.wav'):
            path = os.path.join(folder, file)
            mel = extract_mel(path)
            X.append(mel)
            y.append(label)

X = np.array(X)
y = np.array(y)
X = X[..., np.newaxis]      
y_cat = to_categorical(y)         

X_train, X_test, y_train, y_test = train_test_split(X, y_cat, test_size=0.4, random_state=SEED)
model = Sequential([
    Conv2D(32, (3, 3), activation='relu', input_shape=(128, 128, 1)),
    MaxPooling2D((2, 2)),
    Dropout(0.2),
    Conv2D(64, (3, 3), activation='relu'),
    MaxPooling2D((2, 2)),
    Dropout(0.2),
    Flatten(),
    Dense(128, activation='relu'),
    Dropout(0.3),
    Dense(2, activation='softmax')])

model.compile(optimizer=Adam(learning_rate=0.0005),loss='categorical_crossentropy',metrics=['accuracy'])
history = model.fit(X_train, y_train, epochs=100, batch_size=8, validation_data=(X_test, y_test))

y_pred = model.predict(X_test)
y_pred_label = np.argmax(y_pred, axis=1)
y_true_label = np.argmax(y_test, axis=1)

print("Classification Report")
print(classification_report(y_true_label, y_pred_label, target_names=CLASSES))

cm = confusion_matrix(y_true_label, y_pred_label)
disp = ConfusionMatrixDisplay(confusion_matrix=cm, display_labels=CLASSES)
disp.plot(cmap=plt.cm.Blues)
plt.title("Confusion Matrix")
plt.tight_layout()
plt.show()
plt.figure(figsize=(12, 4))
plt.subplot(1, 2, 1)
plt.plot(history.history['accuracy'], label='Train Acc')
plt.plot(history.history['val_accuracy'], label='Val Acc')
plt.title("Accuracy per Epoch")
plt.xlabel("Epoch")
plt.ylabel("Accuracy")
plt.legend()
plt.subplot(1, 2, 2)
plt.plot(history.history['loss'], label='Train Loss')
plt.plot(history.history['val_loss'], label='Val Loss')
plt.title("Loss per Epoch")
plt.xlabel("Epoch")
plt.ylabel("Loss")
plt.legend()
plt.tight_layout()
plt.show()

model.save("lung_cnn_model.h5")
