import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../auth/auth_providers.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../settings/domain/store_settings.dart';
import '../../../settings/settings_providers.dart';
import '../../domain/entities/invoice.dart';
import '../../sales_providers.dart';
import '../invoice_pdf.dart';

/// Pratinjau invoice A4: cetak, unduh, atau bagikan PDF.
class InvoicePrintView extends ConsumerWidget {
  const InvoicePrintView({super.key, required this.invoice});

  final Invoice invoice;

  AppUser? _customer(WidgetRef ref) {
    final id = invoice.customerId;
    if (id == null) return null;
    final user = ref.watch(currentUserProvider);
    if (user.uid == id) return user;
    if (!user.isOwner) return null;
    return ref.watch(customersProvider).value?.where((c) => c.uid == id).firstOrNull;
  }

  /// Pesanan online dibayar belakangan: metodenya ada di riwayat pembayaran.
  String _paymentLabel(WidgetRef ref) {
    if (invoice.isOpenCredit) {
      final due = invoice.dueDate;
      return due == null ? 'Tempo' : 'Tempo s/d ${DateFormat('dd/MMM/yyyy', 'id_ID').format(due)}';
    }
    final method = invoice.paymentMethod ?? ref.watch(paymentsProvider(invoice.id)).value?.lastOrNull?.method;
    return method?.label ?? '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distributor = ref.watch(currentDistributorProvider);
    final settings = ref.watch(storeSettingsProvider);
    final logo = ref.watch(distributorLogoProvider);
    final ready = !distributor.isLoading && !settings.isLoading && !logo.isLoading;
    final data = InvoicePrintData(
      invoice: invoice,
      distributorName: (settings.value?.storeName ?? '').trim().isNotEmpty
          ? settings.value!.storeName.trim()
          : distributor.value?.name ?? '',
      settings: settings.value ?? const StoreSettings(),
      logoPng: logo.value,
      customer: _customer(ref),
      paymentLabel: _paymentLabel(ref),
    );
    final fileName = invoicePdfFileName(invoice);
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice ${invoice.number}'),
        actions: [
          if (ready) ...[
            TextButton.icon(
              // Di web: mengunduh file PDF; di HP: membuka menu bagikan / simpan.
              onPressed: () async => Printing.sharePdf(bytes: await buildInvoicePdf(data), filename: fileName),
              icon: const Icon(Icons.download),
              label: const Text('Unduh PDF'),
            ),
            FilledButton.icon(
              onPressed: () => Printing.layoutPdf(name: invoice.number, format: PdfPageFormat.a4, onLayout: (_) => buildInvoicePdf(data)),
              icon: const Icon(Icons.print),
              label: const Text('Cetak'),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : PdfPreview(
              key: ValueKey(Object.hash(data.distributorName, data.settings, data.logoPng?.length, data.customer, data.paymentLabel)),
              build: (_) => buildInvoicePdf(data),
              initialPageFormat: PdfPageFormat.a4,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: fileName,
              useActions: false,
              onError: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Pratinjau gagal ditampilkan: $error\nGunakan tombol Unduh PDF / Cetak.', textAlign: TextAlign.center),
                ),
              ),
            ),
    );
  }
}
