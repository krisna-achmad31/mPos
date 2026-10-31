import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mpos/core/widgets/product_image_view.dart';

void main() {
  testWidgets('foto terbuka utuh dengan zoom dan dapat ditutup', (tester) async {
    final photo = base64Encode(img.encodePng(img.Image(width: 120, height: 200)));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ProductImageView(imageBase64: photo, fallbackIcon: Icons.inventory, size: 96, enablePreview: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    final image = tester.widget<Image>(find.descendant(of: find.byType(Dialog), matching: find.byType(Image)));
    expect(image.fit, BoxFit.contain);
    await tester.tap(find.byTooltip('Tutup pratinjau'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('gambar default tidak membuka dialog kosong', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProductImageView(imageBase64: '', fallbackIcon: Icons.inventory, size: 96, enablePreview: true),
        ),
      ),
    );
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });
}
