// lib/pages/watch/watch_scan_page.dart
import 'package:flutter/material.dart';
import '../../ble/ble_manager.dart';

class WatchScanPage extends StatefulWidget {
  const WatchScanPage({super.key});

  @override
  State<WatchScanPage> createState() => _WatchScanPageState();
}

class _WatchScanPageState extends State<WatchScanPage> {
  bool _isScanning = false;
  String? _error;

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _error = null;
    });

    try {
      // 이름에 "Watch" 들어간 BLE 기기 자동 연결
      await BleManager.I.scanAndConnect(containsName: "Watch");
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _disconnect() async {
    await BleManager.I.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("워치 연결"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: BleManager.I.isConnected,
          builder: (context, connected, _) {
            if (connected) {
              return _buildConnected();
            } else {
              return _buildDisconnected();
            }
          },
        ),
      ),
    );
  }

  Widget _buildDisconnected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                "에러: $_error",
                style: const TextStyle(color: Colors.red),
              ),
            ),
          _isScanning
              ? const Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text("워치 검색 중..."),
            ],
          )
              : ElevatedButton.icon(
            onPressed: _startScan,
            icon: const Icon(Icons.watch),
            label: const Text("워치 스캔 및 연결"),
          ),
        ],
      ),
    );
  }

  Widget _buildConnected() {
    return ValueListenableBuilder<String?>(
      valueListenable: BleManager.I.deviceName,
      builder: (context, name, _) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("연결된 기기: ${name ?? "알 수 없음"}",
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            ValueListenableBuilder<int?>(
              valueListenable: BleManager.I.heartRate,
              builder: (context, hr, _) {
                return Text(
                  hr != null ? "심박수: $hr bpm" : "심박 데이터 없음",
                  style: const TextStyle(fontSize: 16),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _disconnect,
              icon: const Icon(Icons.link_off),
              label: const Text("연결 해제"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            )
          ],
        );
      },
    );
  }
}
