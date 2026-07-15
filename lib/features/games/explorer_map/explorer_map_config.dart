import 'package:flutter/material.dart';

import '../core/game_config.dart';

/// Which code-drawn backdrop [_MapBackdropPainter] renders behind the
/// pins. `geography` (ocean + landmass + compass rose) suits real-world
/// map content; `space` (starfield + sun glow) is for the Solar System
/// pack, where an ocean/landmass backdrop would be factually wrong.
enum MapBackdropTheme { geography, space }

/// A pin on the explorer map — not always a province (also used for
/// biomes, climate zones, rivers, planets, career pathways, ...), so
/// [capital] is empty when the concept has no natural "capital".
class ProvincePin {
  final String id; // e.g. 'GP'
  final String name; // e.g. 'Gauteng'
  final String capital; // e.g. 'Johannesburg' — '' if not applicable
  final String emoji; // representative emoji
  final Color color; // color used for this pin's chip
  final Offset position; // fractional position on the map image (0-1)
  final List<String> facts; // quick facts shown after correct answer

  const ProvincePin({
    required this.id,
    required this.name,
    this.capital = '',
    required this.emoji,
    required this.color,
    required this.position,
    required this.facts,
  });
}

/// One question in the explorer map game.
class MapQuestion {
  final String question;
  final String correctId; // province id of the correct answer
  final List<String> optionIds; // 4 province ids (includes correct)
  final String feedbackFact; // shown after answering

  const MapQuestion({
    required this.question,
    required this.correctId,
    required this.optionIds,
    required this.feedbackFact,
  });
}

class ExplorerMapConfig {
  final List<ProvincePin> provinces;
  final List<MapQuestion> questions;
  final MapBackdropTheme backdropTheme;

  const ExplorerMapConfig({
    required this.provinces,
    required this.questions,
    this.backdropTheme = MapBackdropTheme.geography,
  });

  /// Builds config from a generated content pack (see
  /// tools/gamegen/content/explorer_map.js for the shape). An optional
  /// top-level `"backdropTheme": "space"` switches the backdrop for
  /// packs that aren't a real-world map (e.g. the Solar System) --
  /// anything else, or a missing field, keeps the default geography
  /// backdrop so every existing pack is unaffected.
  factory ExplorerMapConfig.fromPack(Map<String, dynamic> pack) {
    final pins = (pack['pins'] as List).cast<Map<String, dynamic>>();
    final provinces = pins
        .map((p) => ProvincePin(
              id: p['id'] as String,
              name: p['name'] as String,
              capital: p['capital'] as String? ?? '',
              emoji: p['emoji'] as String,
              color: _colorFromHex(p['color'] as String),
              position: Offset(
                  (p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
              facts: (p['facts'] as List).cast<String>(),
            ))
        .toList();
    final questions = (pack['questions'] as List)
        .cast<Map<String, dynamic>>()
        .map((q) => MapQuestion(
              question: q['question'] as String,
              correctId: q['correctId'] as String,
              optionIds: (q['optionIds'] as List).cast<String>(),
              feedbackFact: q['feedbackFact'] as String,
            ))
        .toList();
    final theme = pack['backdropTheme'] == 'space'
        ? MapBackdropTheme.space
        : MapBackdropTheme.geography;
    return ExplorerMapConfig(
      provinces: provinces,
      questions: questions,
      backdropTheme: theme,
    );
  }

  static ExplorerMapConfig saProvinces(GameConfig config) {
    // Positions are normalised from each province's approximate
    // geographic centre (lat/long) projected onto South Africa's real
    // bounding box (lat -22.0..-34.8, lon 16.5..32.9) -- not pixel-exact
    // borders, but each province sits in its true relative direction
    // and distance from its neighbours, which the previous hand-guessed
    // values didn't reliably do (e.g. Gauteng/KwaZulu-Natal weren't far
    // enough east, Limpopo wasn't far enough north).
    const provinces = [
      ProvincePin(
        id: 'GP',
        name: 'Gauteng',
        capital: 'Johannesburg',
        emoji: '🏙️',
        color: Color(0xFFE53935),
        position: Offset(0.70, 0.33),
        facts: [
          'Gauteng is the smallest province but most populous.',
          'The name means "place of gold" in Sotho.'
        ],
      ),
      ProvincePin(
        id: 'WC',
        name: 'Western Cape',
        capital: 'Cape Town',
        emoji: '🍷',
        color: Color(0xFF1E88E5),
        position: Offset(0.24, 0.86),
        facts: [
          'Table Mountain is one of the New 7 Wonders of Nature.',
          'The Cape Winelands are famous worldwide.'
        ],
      ),
      ProvincePin(
        id: 'KZN',
        name: 'KwaZulu-Natal',
        capital: 'Pietermaritzburg',
        emoji: '🌊',
        color: Color(0xFF43A047),
        position: Offset(0.85, 0.55),
        facts: [
          'The Drakensberg Mountains stretch along its border.',
          'Durban has the busiest port in Africa.'
        ],
      ),
      ProvincePin(
        id: 'LP',
        name: 'Limpopo',
        capital: 'Polokwane',
        emoji: '🦁',
        color: Color(0xFFFB8C00),
        position: Offset(0.79, 0.12),
        facts: [
          'Home to part of the famous Kruger National Park.',
          'The Limpopo River forms South Africa\'s northern border.'
        ],
      ),
      ProvincePin(
        id: 'MP',
        name: 'Mpumalanga',
        capital: 'Mbombela',
        emoji: '🌅',
        color: Color(0xFF8E24AA),
        position: Offset(0.85, 0.27),
        facts: [
          'Mpumalanga means "place where the sun rises" in Zulu.',
          'Blyde River Canyon is the third-largest canyon in the world.'
        ],
      ),
      ProvincePin(
        id: 'NW',
        name: 'North West',
        capital: 'Mahikeng',
        emoji: '💎',
        color: Color(0xFF00ACC1),
        position: Offset(0.55, 0.35),
        facts: [
          'The world\'s largest platinum reserves are here.',
          'Sun City is a famous resort in this province.'
        ],
      ),
      ProvincePin(
        id: 'FS',
        name: 'Free State',
        capital: 'Bloemfontein',
        emoji: '🌾',
        color: Color(0xFFD81B60),
        position: Offset(0.61, 0.51),
        facts: [
          'Bloemfontein is one of South Africa\'s three capital cities.',
          'Known as the "breadbasket" of South Africa.'
        ],
      ),
      ProvincePin(
        id: 'NC',
        name: 'Northern Cape',
        capital: 'Kimberley',
        emoji: '🌵',
        color: Color(0xFF6D4C41),
        position: Offset(0.31, 0.59),
        facts: [
          'Largest province by area — almost one-third of South Africa.',
          'The world\'s largest diamond was found in Kimberley.'
        ],
      ),
      ProvincePin(
        id: 'EC',
        name: 'Eastern Cape',
        capital: 'Bhisho',
        emoji: '🐘',
        color: Color(0xFF00897B),
        position: Offset(0.64, 0.78),
        facts: [
          'Nelson Mandela was born in the Eastern Cape.',
          'Home to the Addo Elephant National Park.'
        ],
      ),
    ];

    const questions = [
      MapQuestion(
        question: 'Which province is home to Johannesburg and Pretoria?',
        correctId: 'GP',
        optionIds: ['GP', 'MP', 'NW', 'LP'],
        feedbackFact:
            'Gauteng is the smallest but most populous province — home to both Johannesburg and Pretoria (Tshwane).',
      ),
      MapQuestion(
        question: 'Cape Town is the capital of which province?',
        correctId: 'WC',
        optionIds: ['WC', 'NC', 'EC', 'FS'],
        feedbackFact:
            'Western Cape has Cape Town as its provincial capital, and Table Mountain overlooks the city.',
      ),
      MapQuestion(
        question:
            'Which province has the Drakensberg Mountains along its border?',
        correctId: 'KZN',
        optionIds: ['KZN', 'EC', 'MP', 'LP'],
        feedbackFact:
            'KwaZulu-Natal shares the Drakensberg range with the Eastern Cape and Lesotho.',
      ),
      MapQuestion(
        question:
            'The Limpopo River forms the northern border of which province?',
        correctId: 'LP',
        optionIds: ['LP', 'NW', 'MP', 'GP'],
        feedbackFact:
            'Limpopo is the northernmost province; the Limpopo River separates it from Zimbabwe and Botswana.',
      ),
      MapQuestion(
        question: 'Which province is known as "the place where the sun rises"?',
        correctId: 'MP',
        optionIds: ['MP', 'LP', 'GP', 'KZN'],
        feedbackFact:
            'Mpumalanga means "place where the sun rises" in Zulu — fitting for South Africa\'s easternmost inland province.',
      ),
      MapQuestion(
        question:
            'Where would you find the world\'s largest platinum reserves?',
        correctId: 'NW',
        optionIds: ['NW', 'GP', 'NC', 'FS'],
        feedbackFact:
            'North West Province sits on the Bushveld Igneous Complex, the world\'s richest platinum deposit.',
      ),
      MapQuestion(
        question: 'Bloemfontein is a capital city in which province?',
        correctId: 'FS',
        optionIds: ['FS', 'NC', 'NW', 'EC'],
        feedbackFact:
            'Free State\'s Bloemfontein is the judicial capital of South Africa.',
      ),
      MapQuestion(
        question: 'Which is the largest province by area?',
        correctId: 'NC',
        optionIds: ['NC', 'LP', 'WC', 'FS'],
        feedbackFact:
            'Northern Cape covers almost one-third of South Africa\'s total land area.',
      ),
      MapQuestion(
        question: 'Nelson Mandela was born in which province?',
        correctId: 'EC',
        optionIds: ['EC', 'KZN', 'WC', 'GP'],
        feedbackFact:
            'Nelson Mandela was born in Mvezo, Eastern Cape, in 1918.',
      ),
    ];

    return const ExplorerMapConfig(
      provinces: provinces,
      questions: questions,
    );
  }
}

Color _colorFromHex(String hex) {
  final clean = hex.replaceFirst('#', '');
  final value = clean.length == 6 ? 'FF$clean' : clean;
  return Color(int.parse(value, radix: 16));
}
