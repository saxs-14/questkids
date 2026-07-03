import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ChildQrCode extends StatelessWidget {
  final String code;
  final double size;
  const ChildQrCode({super.key, required this.code, this.size = 200});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Column(children: [
      QrImageView(
        data: code,
        version: QrVersions.auto,
        size: size,
        gapless: false,
        eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: color),
        dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square, color: color),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ElevatedButton.icon(
          onPressed: () => Share.share('QuestKids Link Code: $code'),
          icon: const Icon(Icons.share),
          label: const Text('Share Code'),
        ),
      ])
    ]);
  }
}
