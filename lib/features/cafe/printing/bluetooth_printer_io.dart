import 'dart:io';

import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../core/error/app_exception.dart';
import 'bluetooth_printer.dart';

class PlatformBluetoothPrinter implements BluetoothPrinter {
  /// Alamat printer yang sedang tersambung, agar cetak berikutnya tidak menyambung ulang.
  static String? _connected;

  @override
  bool get supported => Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows;

  Future<void> _ensureReady() async {
    if (!supported) throw const AppException('Printer Bluetooth tidak didukung di perangkat ini.');
    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      throw const AppException('Izinkan akses Bluetooth (Perangkat sekitar) untuk aplikasi ini di pengaturan HP.');
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) throw const AppException('Bluetooth masih mati. Nyalakan dulu.');
  }

  @override
  Future<List<PrinterDevice>> pairedDevices() async {
    await _ensureReady();
    final list = await PrintBluetoothThermal.pairedBluetooths;
    return [for (final d in list) PrinterDevice(name: d.name, address: d.macAdress)];
  }

  @override
  Future<void> printBytes(String address, List<int> bytes) async {
    await _ensureReady();
    final alive = _connected == address && await PrintBluetoothThermal.connectionStatus;
    if (!alive) {
      if (_connected != null) await PrintBluetoothThermal.disconnect;
      _connected = null;
      if (!await PrintBluetoothThermal.connect(macPrinterAddress: address)) {
        throw const AppException('Printer tidak tersambung. Pastikan printer menyala dan dekat dengan HP.');
      }
      _connected = address;
    }
    if (!await PrintBluetoothThermal.writeBytes(bytes)) {
      _connected = null;
      throw const AppException('Gagal mengirim struk ke printer. Coba cetak ulang.');
    }
  }
}
