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

  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  final ValueNotifier<String?> deviceName = ValueNotifier(null);
  final ValueNotifier<int?> heartRate = ValueNotifier(null);

  static final Guid _svcHeartRate = Guid("0000180d-0000-1000-8000-00805f9b34fb");
  static final Guid _charHrMeas  = Guid("00002a37-0000-1000-8000-00805f9b34fb");

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _hrNotifySub;

  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  String? _lastExactMac;
  String? _lastContainsName;


  Future<bool> _ensurePermissions() async {
    if (Platform.isAndroid) {
      final req = <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ];
      final statuses = await req.request();
      if (statuses.values.any((s) => s.isPermanentlyDenied)) {
        await openAppSettings();
        return false;
      }
      final scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? false;
      final connOk = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
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
    return false;
  }

  Future<void> _ensureSwitchesOn() async {
    try {
      var state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        try {
          await FlutterBluePlus.turnOn(); // 단말/OS에 따라 미지원일 수 있음
          state = await FlutterBluePlus.adapterState
              .firstWhere((s) => s == BluetoothAdapterState.on)
              .timeout(const Duration(seconds: 5));
        } catch (_) {
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
    } catch (_) {}

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
  }

  Future<void> _connect(BluetoothDevice d) async {
    await _hrNotifySub?.cancel();
    _hrNotifySub = null;

    _device = d;

    await _connSub?.cancel();
    _connSub = d.connectionState.listen((s) {
      final connected = (s == BluetoothConnectionState.connected);
      isConnected.value = connected;

      if (!connected) {
        heartRate.value = null;
        _scheduleReconnect(exactMac: _lastExactMac, containsName: _lastContainsName);
      } else {
        _reconnectAttempt = 0;
        _reconnectTimer?.cancel();
      }
    });

    try {
      await d.connect(autoConnect: false, timeout: const Duration(seconds: 10));
    } catch (e) {
      if (!e.toString().toLowerCase().contains("already")) {
        rethrow;
      }
    }

    deviceName.value = d.platformName.isNotEmpty ? d.platformName : d.remoteId.str;
    isConnected.value = true;

    final services = await d.discoverServices();

    final hrSvc = services.where((s) => s.uuid == _svcHeartRate).firstOrNull;
    BluetoothCharacteristic? hrChar;
    if (hrSvc != null) {
      hrChar = hrSvc.characteristics
          .where((c) => c.uuid == _charHrMeas)
          .firstOrNull;
    }

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

      try {
        final first = await hrChar.read();
        if (first.isNotEmpty) {
          final flags = first[0];
          final hr16 = (flags & 0x01) == 0x01;
          int bpm = 0;
          if (hr16 && first.length >= 3) {
            bpm = first[1] | (first[2] << 8);
          } else if (first.length >= 2) {
            bpm = first[1];
          }
          heartRate.value = bpm;
        }
      } catch (_) {}
    }
  }

  void _scheduleReconnect({String? exactMac, String? containsName}) {
    _reconnectTimer?.cancel();
    final delays = [0.5, 1.0, 2.0, 4.0, 8.0];
    final secs = delays[_reconnectAttempt.clamp(0, delays.length - 1)];
    _reconnectAttempt = (_reconnectAttempt + 1).clamp(0, delays.length - 1);

    _reconnectTimer = Timer(Duration(milliseconds: (secs * 1000).round()), () async {
      try {
        await scanAndConnect(exactMac: exactMac, containsName: containsName);
      } catch (_) {
        _scheduleReconnect(exactMac: exactMac, containsName: containsName);
      }
    });
  }


  Future<bool> prepare() async {
    if (!await _ensurePermissions()) return false;
    await _ensureSwitchesOn();
    return true;
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      throw Exception("BLE는 Android/iOS에서만 지원됩니다.");
    }
    if (!await _ensurePermissions()) {
      throw Exception("필수 권한이 허용되지 않았습니다. (Bluetooth)");
    }
    await _ensureSwitchesOn();
    await _connect(device);
  }

  Future<void> scanAndConnect({String? exactMac, String? containsName}) async {
    _lastExactMac = exactMac;
    _lastContainsName = containsName;

    if (!(Platform.isAndroid || Platform.isIOS)) {
      throw Exception("BLE는 Android/iOS에서만 지원됩니다.");
    }
    if (!await _ensurePermissions()) {
      throw Exception("필수 권한이 허용되지 않았습니다. (Bluetooth)");
    }
    await _ensureSwitchesOn();

    if (_device != null) return;

    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;

    Exception? lastError;
    for (int attempt = 0; attempt < 2 && _device == null; attempt++) {
      final found = Completer<void>();
      final seenIds = <String>{};

      _scanSub = FlutterBluePlus.scanResults.listen((results) async {
        for (final r in results) {
          final name = r.device.platformName;
          final id   = r.device.remoteId.str;

          if (!seenIds.add(id)) continue;

          final match =
              (exactMac != null && id.toUpperCase() == exactMac.toUpperCase()) ||
                  (containsName != null && name.toLowerCase().contains(containsName.toLowerCase())) ||
                  (exactMac == null && containsName == null && name.isNotEmpty);

          if (kDebugMode) {
          }

          if (match) {
            try { await FlutterBluePlus.stopScan(); } catch (_) {}
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

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

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

  Future<void> disconnect() async {
    _reconnectTimer?.cancel(); _reconnectTimer = null;
    _reconnectAttempt = 0;

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
  }
}

extension _IterExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
