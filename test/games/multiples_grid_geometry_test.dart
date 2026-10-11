import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/multiples_grid/multiples_grid_game.dart';

// These pure geometry functions are what the drag-to-connect gesture
// relies on to turn a raw pointer position into "which cube is this over,
// if any" -- the most bug-prone part of that feature, and the part a
// widget test can't easily exercise (the grid's cube-to-number layout is
// shuffled per round, so there's no fixed screen position to drag to/from
// in a black-box widget test). Tested directly here instead.
void main() {
  // A 212x212 square: 5 cells + 4 gaps of 8 => cell = (212 - 32) / 5 = 36.
  const size = Size(212, 212);

  group('gridCubeCenter', () {
    test('cube 0 is the top-left cell\'s center', () {
      final center = gridCubeCenter(0, size);
      expect(center.dx, closeTo(18, 0.001)); // 36/2
      expect(center.dy, closeTo(18, 0.001));
    });

    test('cube 4 is in the same row as cube 0, far right', () {
      final row0 = gridCubeCenter(0, size);
      final row0col4 = gridCubeCenter(4, size);
      expect(row0col4.dy, closeTo(row0.dy, 0.001));
      expect(row0col4.dx, greaterThan(row0.dx));
    });

    test('cube 24 is the bottom-right cell\'s center', () {
      final center = gridCubeCenter(24, size);
      // stride = 36 + 8 = 44; col 4 -> 4*44 + 18 = 194
      expect(center.dx, closeTo(194, 0.001));
      expect(center.dy, closeTo(194, 0.001));
    });
  });

  group('hitTestGridCubeIndex', () {
    test('a point at a cube\'s own center hits that cube', () {
      for (var i = 0; i < 25; i++) {
        final center = gridCubeCenter(i, size);
        expect(hitTestGridCubeIndex(center, size), i, reason: 'cube $i');
      }
    });

    test('a point in the gap between cube 0 and cube 1 hits nothing', () {
      // cube 0 spans x in [0, 36]; cube 1 starts at x=44. x=40 is in the
      // 8px gap between them.
      expect(hitTestGridCubeIndex(const Offset(40, 18), size), isNull);
    });

    test('a point outside the grid entirely hits nothing', () {
      expect(hitTestGridCubeIndex(const Offset(-5, 18), size), isNull);
      expect(hitTestGridCubeIndex(const Offset(18, 300), size), isNull);
    });
  });
}
