import 'bluetooth_printer_stub.dart' if (dart.library.io) 'bluetooth_printer_io.dart' as impl;

/// Printer Bluetooth yang sudah dipasangkan (paired) di perangkat.
class PrinterDevice {
  const PrinterDevice({required this.name, required this.address});

  final String name;

  /// Alamat MAC (Android) / id perangkat (iOS).
  final String address;
}

/// Koneksi ke printer thermal Bluetooth. Di web tidak tersedia: struk dicetak lewat dialog cetak browser.
abstract interface class BluetoothPrinter {
  factory BluetoothPrinter() = impl.PlatformBluetoothPrinter;

  bool get supported;

  /// Printer yang sudah dipasangkan lewat pengaturan Bluetooth HP. Melempar AppException bila Bluetooth mati / tanpa izin.
  Future<List<PrinterDevice>> pairedDevices();

  /// Menyambung (bila perlu) lalu mengirim [bytes] ESC/POS.
  Future<void> printBytes(String address, List<int> bytes);
}
