import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ChildQrCode extends StatelessWidget {
  final String code;
  final double size;
  const ChildQrCode({super.key, required this.code, this.size = 200});

  // Scanning a QR code requires a camera, which a desktop/web browser
  // usually doesn't have, and share_plus's web implementation throws
  // (uncaught, with no visible feedback) on browsers/contexts that don't
  // support the Web Share API -- previously the only way to get this
  // code to a second parent was the QR image or a share action that could
  // silently fail, with the plain code never shown as text anywhere on
  // screen. The second parent's own "enter link code" screen needs the
  // literal 6 characters, so they must always be readable/copyable here
  // regardless of whether sharing or scanning is available.
  Future<void> _share(BuildContext context) async {
    try {
      await Share.share('QuestKids Link Code: $code');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: code));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sharing isn\'t available here -- code copied to clipboard instead.')),
        );
      }
    }
  }

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
      const SizedBox(height: 12),
      SelectableText(
        code,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied to clipboard.')),
              );
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy Code'),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => _share(context),
          icon: const Icon(Icons.share),
          label: const Text('Share Code'),
        ),
      ])
    ]);
  }
}
