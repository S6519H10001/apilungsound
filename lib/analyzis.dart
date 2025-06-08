import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LungSoundApp extends StatelessWidget {
  const LungSoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lung Sound Classifier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1e88e5)),
        useMaterial3: true,
      ),
      home: const LungSoundHomePage(),
    );
  }
}

class LungSoundHomePage extends StatefulWidget {
  const LungSoundHomePage({super.key});

  @override
  State<LungSoundHomePage> createState() => _LungSoundHomePageState();
}

class _LungSoundHomePageState extends State<LungSoundHomePage> {
  File? _selectedFile;
  String? _fileName;
  String _result = "";
  bool _loading = false;

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
      });
    }
  }

  Future<void> sendFile() async {
    if (_selectedFile == null) {
      setState(() => _result = "⚠ กรุณาเลือกไฟล์ .wav ก่อน");
      return;
    }
    setState(() {
      _loading = true;
      _result = "⏳ กำลังประมวลผล...";
    });
    try {
      var uri = Uri.parse("http://192.168.31.36:8000/predict"); // เปลี่ยนเป็น endpoint จริง
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', _selectedFile!.path));
      var streamed = await request.send();
      var response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _result =
              '✅ ${data["class"]}\n🎯 ความมั่นใจ: ${(data["confidence"] * 100).toStringAsFixed(2)}%';
        });
      } else {
        final data = json.decode(response.body);
        setState(() {
          _result = '❌ Error: ${data["detail"] ?? data["error"] ?? "unknown"}';
        });
      }
    } catch (e) {
      setState(() {
        _result = "❌ ไม่สามารถเชื่อมต่อ API ได้: $e";
      });
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f7f9),
      body: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🔍 Lung Sound Classifier',
                  style: TextStyle(
                    color: Color.fromARGB(255, 100, 101, 101),
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 62, 62, 62),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: pickFile,
                  child: const Text(
                    '📁 เลือกไฟล์เสียง (.wav)',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _fileName != null ? '📌 ไฟล์ที่เลือก: $_fileName' : 'ยังไม่ได้เลือกไฟล์',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 26, 26, 26),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _loading ? null : sendFile,
                  child: const Text(
                    '🚀 วิเคราะห์เสียง',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 18),
                _result.isNotEmpty
                    ? SelectableText(
                        _result,
                        style: const TextStyle(fontSize: 18, color: Color(0xFF333333)),
                        textAlign: TextAlign.center,
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
