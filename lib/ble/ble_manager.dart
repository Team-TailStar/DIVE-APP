// lib/ble/ble_manager.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app_settings/app_settings.dart';

class BleManager {
  BleManager._();
  static final BleManager I = BleManager._();

  BluetoothDevice? _device;

  // 외부 바인딩용 상태
  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  final ValueNotifier<String?> deviceName = ValueNotifier(null);
  final ValueNotifier<int?> heartRate = ValueNotifier(null);

  // 표준 Heart Rate UUID
  static final Guid _svcHeartRate = Guid("0000180d-0000-1000-8000-00805f9b34fb");
  static final Guid _charHrMeas  = Guid("00002a37-0000-1000-8000-00805f9b34fb");

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _hrNotifySub;

  // -----------------------------
  // 내부 유틸
  // -----------------------------

  Future<bool> _ensurePermissions() async {
    if (Platform.isAndroid) {
      // Android 12+ : BLUETOOTH_SCAN/CONNECT (핵심)
      // 특정 기기 스캔 버그 대비 위치 whenInUse는 보조로 요청
      final req = <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ];

      if (await Permission.bluetoothScan.shouldShowRequestRationale ||
          await Permission.bluetoothConnect.shouldShowRequestRationale) {
        // 필요하면 여기서 스낵바/토스트 안내 가능
      }

      final statuses = await req.request();

      // 영구 거부 → 설정 화면 유도
      final forever = statuses.values.any((s) => s.isPermanentlyDenied);
      if (forever) {
        await openAppSettings();
        return false;
      }

      final scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? false;
      final connOk = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
      // 위치 권한은 기기 따라 불필요할 수 있음(있으면 +)
      return scanOk && connOk;
    }

    if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      return status.isGranted;
    }

    // 기타 플랫폼 미지원
    return false;
  }

  Future<void> _ensureSwitchesOn() async {
    // 1) 블루투스 어댑터 ON 확인
    try {
      var state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        try {
          await FlutterBluePlus.turnOn(); // 단말/OS에 따라 미지원 가능
          // 켜질 때까지 잠깐 대기
          state = await FlutterBluePlus.adapterState
              .firstWhere((s) => s == BluetoothAdapterState.on)
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          // 전용 BT 설정화면으로 유도
          try {
            await AppSettings.openAppSettings(
              type: AppSettingsType.bluetooth,
              asAnotherTask: true,
            );
          } catch (_) {
            await AppSettings.openAppSettings();
          }
        }
      }
    } catch (_) {
      // 어댑터 상태 획득 실패 → 무시하고 계속 시도
    }

    // 2) 위치 서비스 (안드로이드 일부 기기에서 스캔 안정성용)
    if (Platform.isAndroid) {
      final on = await Geolocator.isLocationServiceEnabled();
      if (!on) {
        try {
          await AppSettings.openAppSettings(
            type: AppSettingsType.location,
            asAnotherTask: true,
          );
        } catch (_) {
          await AppSettings.openAppSettings();
        }
      }
    }
    // (iOS 메모) 시스템 정책상 직접 ON 불가 → 설정 화면만 열 수 있음
  }

  Future<void> _connect(BluetoothDevice d) async {
    // 이전 notify 구독 정리
    await _hrNotifySub?.cancel();
    _hrNotifySub = null;

    _device = d;

    // 연결 상태 스트림
    await _connSub?.cancel();
    _connSub = d.connectionState.listen((s) {
      isConnected.value = (s == BluetoothConnectionState.connected);
    });

    try {
      await d.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      // already connected 류는 무시
      if (!e.toString().toLowerCase().contains("already")) {
        rethrow;
      }
    }

    deviceName.value = d.platformName.isNotEmpty ? d.platformName : d.remoteId.str;
    isConnected.value = true;

    // 서비스/특성 탐색
    final services = await d.discoverServices();

    BluetoothService? hrSvc = services.where((s) => s.uuid == _svcHeartRate).cast<BluetoothService?>().firstOrNull;
    BluetoothCharacteristic? hrChar;
    if (hrSvc != null) {
      hrChar = hrSvc.characteristics.where((c) => c.uuid == _charHrMeas).cast<BluetoothCharacteristic?>().firstOrNull;
    }

    // 심박 notify 구독(있을 때만)
    if (hrChar != null && (hrChar.properties.notify || hrChar.properties.indicate)) {
      try { await hrChar.setNotifyValue(true); } catch (_) {}
      await _hrNotifySub?.cancel();
      _hrNotifySub = hrChar.onValueReceived.listen((data) {
        if (data.isEmpty) return;
        final flags = data[0];
        final hr16 = (flags & 0x01) == 0x01;
        int bpm = 0;
        if (hr16 && data.length >= 3) {
          bpm = data[1] | (data[2] << 8);
        } else if (data.length >= 2) {
          bpm = data[1];
        }
        heartRate.value = bpm;
      });
    }
  }

  // -----------------------------
  // 외부 API
  // -----------------------------

  /// 권한/스위치 준비만 미리 수행 (거부/미준비 시 false)
  Future<bool> prepare() async {
    if (!await _ensurePermissions()) return false;
    await _ensureSwitchesOn();
    return true;
  }

  /// 스캔 없이 사용자가 고른 디바이스로 직접 연결
  Future<void> connectToDevice(BluetoothDevice device) async {
    if (Platform.isAndroid == false && Platform.isIOS == false) {
      throw Exception("BLE는 Android/iOS에서만 지원됩니다.");
    }
    if (!await _ensurePermissions()) {
      throw Exception("필수 권한이 허용되지 않았습니다. (Bluetooth)");
    }
    await _ensureSwitchesOn();
    await _connect(device);
  }

  /// 이름에 [containsName]이 포함된 첫 장치 또는 [exactMac] 일치하는 장치 연결.
  /// 아무 필터도 없으면 이름이 비어있지 않은 첫 스캔 결과에 연결.
  Future<void> scanAndConnect({String? exactMac, String? containsName}) async {
    if (Platform.isAndroid == false && Platform.isIOS == false) {
      throw Exception("BLE는 Android/iOS에서만 지원됩니다.");
    }

    if (!await _ensurePermissions()) {
      throw Exception("필수 권한이 허용되지 않았습니다. (Bluetooth)");
    }
    await _ensureSwitchesOn();

    // 이미 연결된 경우 스킵
    if (_device != null) return;

    // 중복 스캔 방지/정리
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;

    // 재시도 로직: 최대 2회
    Exception? lastError;
    for (int attempt = 0; attempt < 2 && _device == null; attempt++) {
      final found = Completer<void>();
      final seenIds = <String>{};

      // 스캔 결과 수신
      _scanSub = FlutterBluePlus.scanResults.listen((results) async {
        for (final r in results) {
          final name = r.device.platformName;
          final id   = r.device.remoteId.str;

          if (!seenIds.add(id)) continue; // 중복 제외

          // 필터
          final match =
              (exactMac != null && id.toUpperCase() == exactMac.toUpperCase()) ||
                  (containsName != null && name.toLowerCase().contains(containsName.toLowerCase())) ||
                  (exactMac == null && containsName == null && name.isNotEmpty);

          if (kDebugMode) {
            // debugPrint('scan: $name ($id) rssi=${r.rssi} match=$match');
          }

          if (match) {
            try {
              await FlutterBluePlus.stopScan();
            } catch (_) {}
            await _scanSub?.cancel();
            _scanSub = null;

            try {
              await _connect(r.device);
              if (!found.isCompleted) found.complete();
            } catch (e) {
              lastError = e is Exception ? e : Exception(e.toString());
              if (!found.isCompleted) found.completeError(e);
            }
            break;
          }
        }
      });

      // 스캔 시작
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // 완료/타임아웃 대기
      try {
        await found.future.timeout(const Duration(seconds: 14));
      } on TimeoutException catch (e) {
        lastError = e;
      } finally {
        try { await FlutterBluePlus.stopScan(); } catch (_) {}
        await _scanSub?.cancel();
        _scanSub = null;
      }
    }

    if (_device == null) {
      throw Exception(lastError?.toString() ?? "조건에 맞는 BLE 기기를 찾지 못했습니다.");
    }
  }

  /// 연결 해제 및 스트림/스캔 정리
  Future<void> disconnect() async {
    await _hrNotifySub?.cancel(); _hrNotifySub = null;
    await _connSub?.cancel();     _connSub = null;
    await _scanSub?.cancel();     _scanSub = null;

    if (_device != null) {
      try { await _device!.disconnect(); } catch (_) {}
    }

    _device = null;
    isConnected.value = false;
    deviceName.value = null;
    heartRate.value = null;
  }

  Future<void> refresh() async {
    // 대부분 HR은 notify 기반이라 별도 처리 없음
  }
}

// Dart <3.5 환경 호환용 extension (firstOrNull)
extension _IterExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
