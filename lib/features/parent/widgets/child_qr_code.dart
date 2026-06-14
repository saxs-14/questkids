import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ChildQrCode extends StatelessWidget {
  final String code;
  final double size;
  const ChildQrCode({super.key, required this.code, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      QrImage(
        data: code,
        version: QrVersions.auto,
        size: size,
        gapless: false,
        foregroundColor: Theme.of(context).primaryColor,
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ElevatedButton(onPressed: () {
          // TODO: implement share/download
        }, child: const Text('Share/Download')),
      ])
    ]);
  }
}
