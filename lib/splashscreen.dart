import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset("assets/Lung.mp4")
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
    _controller.setLooping(false);

    // เปลี่ยนหน้าหลังวิดีโอจบ
    _controller.addListener(() {
      if (_controller.value.position >= _controller.value.duration) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF22282F), // เทาเข้ม
      body: Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _controller.value.isInitialized
          ? SizedBox(
              width: 50,    // <--- ปรับขนาดที่ต้องการ เช่น 240x160
              height: 50,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20), // มุมโค้ง
                child: VideoPlayer(_controller),
              ),
            )
          : CircularProgressIndicator(),
      SizedBox(height: 24),
      Text(
        "stethomi core",
        style: TextStyle(
          color: Color.fromARGB(255, 36, 37, 37), // เขียว
          fontWeight: FontWeight.bold,
          fontSize: 36,
          letterSpacing: 2,
          shadows: [
            Shadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 4,
              offset: Offset(1, 2),
            ),
          ],
        ),
      ),
    ],
  ),
),
    );
  }
}
//       floatingActionButton: FloatingActionButton(