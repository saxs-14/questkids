import 'package:flutter/material.dart';

/// A small vest sticker cosmetic can add on top of a helmet re-colour.
/// Purely decorative -- never affects gameplay, scoring, or unlocks.
enum CosmeticSticker { none, star, compass }

/// A purchasable Quest Boy cosmetic. `null` fields mean "keep the
/// classic default" so items only need to specify what they change.
class CosmeticSkin {
  final Color? helmetColor;
  final Color? helmetColorDark;
  final CosmeticSticker sticker;

  const CosmeticSkin({
    this.helmetColor,
    this.helmetColorDark,
    this.sticker = CosmeticSticker.none,
  });

  @override
  bool operator ==(Object other) =>
      other is CosmeticSkin &&
      other.helmetColor == helmetColor &&
      other.helmetColorDark == helmetColorDark &&
      other.sticker == sticker;

  @override
  int get hashCode => Object.hash(helmetColor, helmetColorDark, sticker);
}

class TradingPostItem {
  final String id;
  final String name;
  final String description;
  final int priceGold;
  final String previewEmoji;

  /// `null` means the classic default look (no overrides).
  final CosmeticSkin? skin;

  const TradingPostItem({
    required this.id,
    required this.name,
    required this.description,
    required this.priceGold,
    required this.previewEmoji,
    this.skin,
  });
}

/// Fixed cosmetic catalog for Quest Boy. Config-driven and small by
/// design -- add new entries here rather than hardcoding items in the
/// Trading Post / Hideout screens.
class TradingPostCatalog {
  TradingPostCatalog._();

  /// Owned by every learner from account creation -- the classic look,
  /// free, and can't be purchased or sold.
  static const String starterItemId = 'classic_explorer';

  static const List<TradingPostItem> items = [
    TradingPostItem(
      id: starterItemId,
      name: 'Classic Explorer',
      description: "Quest Boy's original tan pith helmet.",
      priceGold: 0,
      previewEmoji: '🪖',
    ),
    TradingPostItem(
      id: 'forest_ranger',
      name: 'Forest Ranger',
      description: 'A deep green helmet for jungle trails.',
      priceGold: 50,
      previewEmoji: '🟢',
      skin: CosmeticSkin(
        helmetColor: Color(0xFF4C8C4A),
        helmetColorDark: Color(0xFF356B33),
      ),
    ),
    TradingPostItem(
      id: 'sunset_voyager',
      name: 'Sunset Voyager',
      description: 'A warm sunset-red helmet.',
      priceGold: 50,
      previewEmoji: '🔴',
      skin: CosmeticSkin(
        helmetColor: Color(0xFFD9583D),
        helmetColorDark: Color(0xFFB33F28),
      ),
    ),
    TradingPostItem(
      id: 'ocean_explorer',
      name: 'Ocean Explorer',
      description: 'A cool ocean-blue helmet.',
      priceGold: 50,
      previewEmoji: '🔵',
      skin: CosmeticSkin(
        helmetColor: Color(0xFF3E7CB8),
        helmetColorDark: Color(0xFF2C5C8A),
      ),
    ),
    TradingPostItem(
      id: 'star_badge',
      name: 'Star Badge',
      description: 'A gold star sticker for the vest.',
      priceGold: 30,
      previewEmoji: '⭐',
      skin: CosmeticSkin(sticker: CosmeticSticker.star),
    ),
    TradingPostItem(
      id: 'compass_badge',
      name: 'Compass Badge',
      description: 'An extra compass sticker for the vest.',
      priceGold: 30,
      previewEmoji: '🧭',
      skin: CosmeticSkin(sticker: CosmeticSticker.compass),
    ),
  ];

  static TradingPostItem byId(String id) =>
      items.firstWhere((i) => i.id == id, orElse: () => items.first);
}
