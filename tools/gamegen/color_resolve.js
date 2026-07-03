'use strict';

// Mirrors lib/core/theme/app_colors.dart subject accent colors.
const APP_COLORS_HEX = {
  'AppColors.math': '#FF6B35',
  'AppColors.science': '#00BFA5',
  'AppColors.english': '#E91E63',
  'AppColors.socialSciences': '#43A047',
  'AppColors.technology': '#7C4DFF',
  'AppColors.lifeSkills': '#FF9800',
};

/** Resolves a Dart color expression ("AppColors.math" or "Color(0xFF...)")
 * into a #RRGGBB(AA) hex string for the JSON content pack. */
function resolveColorHex(colorExpr) {
  if (APP_COLORS_HEX[colorExpr]) return APP_COLORS_HEX[colorExpr];
  const m = colorExpr.match(/Color\(0x([0-9A-Fa-f]{8})\)/);
  if (m) {
    const argb = m[1]; // AARRGGBB
    return `#${argb.slice(2)}`; // -> #RRGGBB
  }
  throw new Error(`Cannot resolve color hex for expression "${colorExpr}"`);
}

module.exports = { resolveColorHex };
