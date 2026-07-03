import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'game_config.dart';

/// Loads and parses this topic's generated content pack
/// (assets/content/{grade}/{subject}/{catalogId}.json). Returns null when
/// the config has no [GameConfig.contentPackPath] (an ad-hoc preset, not a
/// catalog entry) or the asset can't be loaded/parsed — callers should fall
/// back to their engine's built-in demo content in that case, never a red
/// screen.
Future<Map<String, dynamic>?> loadContentPack(GameConfig config) async {
  final path = config.contentPackPath;
  if (path == null) return null;
  try {
    final raw = await rootBundle.loadString(path);
    return jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}
