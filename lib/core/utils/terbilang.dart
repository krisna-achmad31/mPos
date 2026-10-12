const _satuan = ['', 'Satu', 'Dua', 'Tiga', 'Empat', 'Lima', 'Enam', 'Tujuh', 'Delapan', 'Sembilan', 'Sepuluh', 'Sebelas'];

/// Angka ke kata dalam bahasa Indonesia, mis. 2478000 -> "Dua Juta Empat Ratus Tujuh Puluh Delapan Ribu".
String terbilang(int n) {
  if (n < 0) return 'Minus ${terbilang(-n)}';
  if (n == 0) return 'Nol';
  return _words(n).trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Untuk nota: "Dua Juta ... Ribu Rupiah".
String terbilangRupiah(int n) => '${terbilang(n)} Rupiah';

String _words(int n) {
  if (n < 12) return _satuan[n];
  if (n < 20) return '${_satuan[n - 10]} Belas';
  if (n < 100) return '${_satuan[n ~/ 10]} Puluh ${_words(n % 10)}';
  if (n < 200) return 'Seratus ${_words(n - 100)}';
  if (n < 1000) return '${_satuan[n ~/ 100]} Ratus ${_words(n % 100)}';
  if (n < 2000) return 'Seribu ${_words(n - 1000)}';
  if (n < 1000000) return '${_words(n ~/ 1000)} Ribu ${_words(n % 1000)}';
  if (n < 1000000000) return '${_words(n ~/ 1000000)} Juta ${_words(n % 1000000)}';
  if (n < 1000000000000) return '${_words(n ~/ 1000000000)} Miliar ${_words(n % 1000000000)}';
  return '${_words(n ~/ 1000000000000)} Triliun ${_words(n % 1000000000000)}';
}
