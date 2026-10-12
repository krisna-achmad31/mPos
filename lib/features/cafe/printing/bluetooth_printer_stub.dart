import '../../../core/error/app_exception.dart';
import 'bluetooth_printer.dart';

class PlatformBluetoothPrinter implements BluetoothPrinter {
  @override
  bool get supported => false;

  @override
  Future<List<PrinterDevice>> pairedDevices() async => const [];

  @override
  Future<void> printBytes(String address, List<int> bytes) =>
      throw const AppException('Printer Bluetooth hanya tersedia di aplikasi Android / iOS.');
}
