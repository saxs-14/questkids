import 'package:flutter/material.dart';

/// Small loading placeholder shown while a game's content pack asset is
/// being read + parsed. Content packs are bundled Flutter assets (not a
/// network fetch), so this is on screen for a frame or two at most.
class ContentPackLoadingView extends StatelessWidget {
  final Color color;
  const ContentPackLoadingView({super.key, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: color),
      ),
    );
  }
}
