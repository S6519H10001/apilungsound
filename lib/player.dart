import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

class LiveWaveformPage extends StatefulWidget {
  const LiveWaveformPage({Key? key}) : super(key: key);

  @override
  State<LiveWaveformPage> createState() => _LiveWaveformPageState();
}

class _LiveWaveformPageState extends State<LiveWaveformPage> {
  late WebSocketChannel channel;
  List<int> audioBuffer = [];
  String? savedFilePath;
  AudioPlayer audioPlayer = AudioPlayer();
  bool isSaving = false;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    // เชื่อมต่อ WebSocket ไป FastAPI
    channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.31.36:8000/audio_listen'),
    );

    channel.stream.listen((data) {
      if (data is List<int>) {
        setState(() {
          audioBuffer.addAll(data);
          if (audioBuffer.length > 4096 * 10) {
            // จำกัด buffer (กันหน่วง)
            audioBuffer = audioBuffer.sublist(audioBuffer.length - 4096 * 10);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    channel.sink.close();
    audioPlayer.dispose();
    super.dispose();
  }

  // ---- ฟังก์ชันเซฟไฟล์เสียง (ไปโฟลเดอร์ Music) ----
  Future<void> saveAudio() async {
    if (audioBuffer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ยังไม่มีเสียงสำหรับบันทึก")));
      return;
    }
    setState(() => isSaving = true);

    // ขอ permission
    if (!await Permission.storage.request().isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ไม่ได้รับสิทธิ์การเข้าถึง storage")),
      );
      setState(() => isSaving = false);
      return;
    }

    // ใช้ Music Directory
    final List<Directory>? dirs = await getExternalStorageDirectories(type: StorageDirectory.music);
    if (dirs == null || dirs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ไม่สามารถเข้าถึงโฟลเดอร์ Music")),
      );
      setState(() => isSaving = false);
      return;
    }
    final dir = dirs.first;

    // จำกัด buffer (ตัวอย่าง 10 วิ)
    final maxBuffer = 16000 * 10 * 2;
    List<int> trimmedBuffer = audioBuffer.length > maxBuffer
        ? audioBuffer.sublist(audioBuffer.length - maxBuffer)
        : audioBuffer;

    final wavData = _wrapPcmAsWav(Uint8List.fromList(trimmedBuffer));
    final file = File('${dir.path}/last_lung_sound.wav');
    await file.writeAsBytes(wavData, flush: true);

    setState(() {
      savedFilePath = file.path;
      isSaving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("บันทึกเสียงสำเร็จ: ${file.path}")),
    );
  }

  // ---- ฟังก์ชันเล่นเสียงที่บันทึก ----
  Future<void> playSavedAudio() async {
    if (savedFilePath == null || !File(savedFilePath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ยังไม่มีไฟล์เสียงให้ฟัง")));
      return;
    }
    setState(() => isPlaying = true);
    await audioPlayer.play(DeviceFileSource(savedFilePath!), volume: 1.0);
    audioPlayer.onPlayerComplete.listen((_) {
      setState(() => isPlaying = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    List<int> showBuffer = audioBuffer.length > 4096
        ? audioBuffer.sublist(audioBuffer.length - 4096)
        : audioBuffer;
    return Scaffold(
      appBar: AppBar(title: Text("กำลังฟังเสียงปอด...")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 350,
              height: 120,
              child: CustomPaint(
                painter: WaveformPainter(showBuffer),
                size: Size(350, 120),
              ),
            ),
            SizedBox(height: 18),
            Text("Bytes ล่าสุด: ${audioBuffer.length}"),
            Text("เชื่อมต่อ http://192.168.31.36:8000/audio_listen"),
            SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: isSaving ? null : saveAudio,
                  icon: Icon(Icons.save),
                  label: isSaving ? Text("กำลังบันทึก...") : Text("บันทึกเสียง"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 4, 5, 4),
                    minimumSize: Size(120, 42),
                  ),
                ),
                SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: (savedFilePath != null && !isPlaying) ? playSavedAudio : null,
                  icon: Icon(Icons.play_arrow),
                  label: isPlaying ? Text("กำลังเล่น...") : Text("ฟังเสียงซ้ำ"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 243, 244, 244),
                    minimumSize: Size(120, 42),
                  ),
                ),
              ],
            ),
            if (savedFilePath != null) ...[
              SizedBox(height: 10),
              Text("ไฟล์เสียงล่าสุด: ${savedFilePath!.split('/').last}",
                  style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            ],
          ],
        ),
      ),
    );
  }

  // --- ใส่ header WAV ให้ raw PCM ---
  Uint8List _wrapPcmAsWav(Uint8List pcmData, {int sampleRate = 16000}) {
    int byteRate = sampleRate * 2; // 16bit mono
    int blockAlign = 2;
    int dataLength = pcmData.length;
    int fileLength = 44 + dataLength;

    BytesBuilder bytes = BytesBuilder();
    bytes.add([
      0x52, 0x49, 0x46, 0x46, // 'RIFF'
      ..._intToBytes(fileLength - 8, 4),
      0x57, 0x41, 0x56, 0x45, // 'WAVE'
      0x66, 0x6d, 0x74, 0x20, // 'fmt '
      16, 0, 0, 0,            // subchunk1 size
      1, 0,                   // audio format (1=PCM)
      1, 0,                   // num channels
      ..._intToBytes(sampleRate, 4),
      ..._intToBytes(byteRate, 4),
      blockAlign, 0,
      16, 0,                  // bits per sample
      0x64, 0x61, 0x74, 0x61, // 'data'
      ..._intToBytes(dataLength, 4),
    ]);
    bytes.add(pcmData);
    return bytes.toBytes();
  }

  List<int> _intToBytes(int value, int length) {
    return List<int>.generate(
        length, (i) => (value >> (8 * i)) & 0xff, growable: false);
  }
}

// วาด waveform จาก raw PCM (16-bit signed)
class WaveformPainter extends CustomPainter {
  final List<int> buffer;
  WaveformPainter(this.buffer);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 1.1;
    final middle = size.height / 2;
    if (buffer.length < 2) return;
    int skip = (buffer.length / size.width).ceil().clamp(1, 1000);

    for (int x = 0; x < size.width.toInt(); x++) {
      int idx = x * skip;
      if (idx + 1 >= buffer.length) break;
      int lo = buffer[idx];
      int hi = buffer[idx + 1];
      int sample = (hi << 8) | lo;
      if (sample & 0x8000 > 0) sample -= 0x10000; // signed 16-bit
      double y = middle - (sample / 32768.0) * middle;
      canvas.drawLine(Offset(x.toDouble(), middle), Offset(x.toDouble(), y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
