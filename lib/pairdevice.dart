import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PairDevicePage extends StatefulWidget {
  const PairDevicePage({Key? key}) : super(key: key);

  @override
  State<PairDevicePage> createState() => _PairDevicePageState();
}

class _PairDevicePageState extends State<PairDevicePage> {
  List<dynamic> devices = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchDevices();
  }

  Future<void> fetchDevices() async {
    setState(() {
      loading = true;
    });
    // ตัวอย่าง URL (เปลี่ยนเป็น API จริงของคุณ)
    final url = Uri.parse('https://example.com/api/devices');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      setState(() {
        devices = json.decode(response.body);
        loading = false;
      });
    } else {
      setState(() {
        loading = false;
      });
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดอุปกรณ์ไม่สำเร็จ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("จับคู่ อุปกรณ์"),
        backgroundColor: Color.fromARGB(255, 76, 82, 78),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : devices.isEmpty
              ? Center(child: Text('ไม่พบอุปกรณ์'))
              : ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return ListTile(
                      title: Text(device['name'] ?? 'No Name'),
                      subtitle: Text(device['id'] ?? ''),
                      trailing: ElevatedButton(
                        child: Text('จับคู่'),
                        onPressed: () {
                          // TODO: เขียนฟังก์ชันส่ง API จับคู่อุปกรณ์
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
