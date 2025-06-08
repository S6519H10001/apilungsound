import 'package:flutter/material.dart';
import 'package:flutter_application_1/analyzis.dart';
import 'package:flutter_application_1/pairdevice.dart';
import 'package:flutter_application_1/player.dart';

// 1. main()
void main() {
  runApp(MyApp());
}

// 2. MyApp ตัวเดียว
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'stethomi core',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color.fromARGB(255, 150, 199, 170),
        scaffoldBackgroundColor: Color(0xFF22282F),
      ),
      home: HomePage(), // <<=== เปิดเข้า HomePage เลย
    );
  }
}

// 3. หน้า HomePage ตัวอย่าง
class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "STETHOMICORE",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 32),
              HomeButton(
                icon: Icons.settings_accessibility,
                text: "Setting",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PairDevicePage()),
                  );
                },
              ),
              SizedBox(height: 16),
              HomeButton(
                icon: Icons.book_online_rounded,
                text: "วิธีการใช้งาน",
                onTap: () {},
              ),
              SizedBox(height: 16),
              HomeButton(
                icon: Icons.play_arrow,
                text: "Start Listening",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LiveWaveformPage()),
                  );
                },
              ),
              SizedBox(height: 16),
              HomeButton(
                icon: Icons.analytics,
                text: "Analyze with AI",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LungSoundApp()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 4. HomeButton widget
class HomeButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const HomeButton({
    Key? key,
    required this.icon,
    required this.text,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 48,
      child: OutlinedButton.icon(
        icon: Icon(icon, color: Colors.black87),
        label: Text(
          text,
          style: TextStyle(
            fontSize: 17,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(color: Colors.black87, width: 1.4),
          backgroundColor: Colors.white,
        ),
        onPressed: onTap,
      ),
    );
  }
}
