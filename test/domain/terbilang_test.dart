import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/core/utils/terbilang.dart';

void main() {
  test('angka ke kata', () {
    expect(terbilang(0), 'Nol');
    expect(terbilang(11), 'Sebelas');
    expect(terbilang(115), 'Seratus Lima Belas');
    expect(terbilang(1000), 'Seribu');
    expect(terbilang(2478000), 'Dua Juta Empat Ratus Tujuh Puluh Delapan Ribu');
    expect(terbilang(1001001), 'Satu Juta Seribu Satu');
    expect(terbilangRupiah(375000), 'Tiga Ratus Tujuh Puluh Lima Ribu Rupiah');
  });
}
